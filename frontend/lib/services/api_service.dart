import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;

  const ApiException(this.statusCode, this.message);

  @override
  String toString() => 'ApiException($statusCode): $message';
}

class ApiService {
  ApiService._();

  static final ApiService instance = ApiService._();

  static const String baseUrl = 'http://127.0.0.1:8000/api';

  // =====================================
  // WEEK 13 TEST CONFIGURATION
  // =====================================

  // Set to null for normal use.
  //
  // For recovery test:
  // 'transient_once'
  //
  // For permanent failure test:
  // 'persistent_transient'
  //
  // Return to null after testing.

  static const String? localAutomationTestMode = null;

  final http.Client _client = http.Client();

  String? _token;
  Map<String, dynamic>? _user;

  bool get isAuthenticated => _token != null;

  Map<String, dynamic>? get currentUser => _user;

  // =====================================
  // REQUEST HEADERS
  // =====================================

  Map<String, String> _headers({
    bool authenticated = true,
  }) {
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };

    if (authenticated && _token != null) {
      headers['Authorization'] = 'Bearer $_token';
    }

    return headers;
  }

  // =====================================
  // RESPONSE HANDLING
  // =====================================

  Map<String, dynamic> _decode(http.Response response) {
    dynamic decoded;

    try {
      decoded = response.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(response.body);
    } catch (_) {
      decoded = <String, dynamic>{
        'message': 'The server returned an invalid response.',
      };
    }

    final data = decoded is Map
        ? Map<String, dynamic>.from(decoded)
        : <String, dynamic>{'data': decoded};

    if (response.statusCode < 200 ||
        response.statusCode >= 300) {
      throw ApiException(
        response.statusCode,
        data['message']?.toString() ?? 'Request failed.',
      );
    }

    return data;
  }

  // =====================================
  // LOGIN
  // =====================================

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final response = await _client
        .post(
          Uri.parse('$baseUrl/login'),
          headers: _headers(authenticated: false),
          body: jsonEncode({
            'email': email,
            'password': password,
          }),
        )
        .timeout(const Duration(seconds: 15));

    final data = _decode(response);

    if (data['token'] == null || data['user'] == null) {
      throw const ApiException(
        500,
        'The server did not return a valid login session.',
      );
    }

    _token = data['token'].toString();
    _user = Map<String, dynamic>.from(data['user']);

    return data;
  }

  // =====================================
  // LOGOUT
  // =====================================

  Future<void> logout() async {
    try {
      if (_token != null) {
        final response = await _client
            .post(
              Uri.parse('$baseUrl/logout'),
              headers: _headers(),
            )
            .timeout(const Duration(seconds: 15));

        _decode(response);
      }
    } finally {
      _token = null;
      _user = null;
    }
  }

  // =====================================
  // GET CURRENT USER
  // =====================================

  Future<Map<String, dynamic>> getCurrentUser() async {
    final response = await _client
        .get(
          Uri.parse('$baseUrl/user'),
          headers: _headers(),
        )
        .timeout(const Duration(seconds: 15));

    return _decode(response);
  }

  // =====================================
  // GET ACTIVITIES
  // =====================================

  Future<List<Map<String, dynamic>>> getActivities() async {
    final response = await _client
        .get(
          Uri.parse('$baseUrl/activities'),
          headers: _headers(),
        )
        .timeout(const Duration(seconds: 15));

    final result = _decode(response);
    final records = result['data'];

    if (records is! List) {
      throw const ApiException(
        500,
        'Invalid activities response.',
      );
    }

    return records
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  // =====================================
  // CREATE ACTIVITY
  // =====================================

  Future<Map<String, dynamic>> createActivity(
    Map<String, dynamic> activity,
  ) async {
    final response = await _client
        .post(
          Uri.parse('$baseUrl/activities'),
          headers: _headers(),
          body: jsonEncode(activity),
        )
        .timeout(const Duration(seconds: 15));

    return _decode(response);
  }

  // =====================================
  // UPDATE ACTIVITY
  // =====================================

  Future<Map<String, dynamic>> updateActivity(
    int id,
    Map<String, dynamic> activity,
  ) async {
    final response = await _client
        .put(
          Uri.parse('$baseUrl/activities/$id'),
          headers: _headers(),
          body: jsonEncode(activity),
        )
        .timeout(const Duration(seconds: 15));

    return _decode(response);
  }

  // =====================================
  // DELETE ACTIVITY
  // =====================================

  Future<Map<String, dynamic>> deleteActivity(int id) async {
    final response = await _client
        .delete(
          Uri.parse('$baseUrl/activities/$id'),
          headers: _headers(),
        )
        .timeout(const Duration(seconds: 15));

    return _decode(response);
  }

  // =====================================
  // GET RESERVATIONS
  // =====================================

  Future<List<Map<String, dynamic>>> getReservations() async {
    final response = await _client
        .get(
          Uri.parse('$baseUrl/reservations'),
          headers: _headers(),
        )
        .timeout(const Duration(seconds: 15));

    final result = _decode(response);
    final records = result['data'];

    if (records is! List) {
      throw const ApiException(
        500,
        'Invalid reservations response.',
      );
    }

    return records
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  // =====================================
  // RESERVE ACTIVITY
  // MAXIMUM 3 ATTEMPTS
  // SAME UUID FOR ALL RETRIES
  // =====================================

  Future<Map<String, dynamic>> reserveActivity(
    int activityId,
  ) async {
    // Generate once and reuse for every retry.
    final requestKey = const Uuid().v4();

    const int maxAttempts = 3;

    const Set<int> retryableStatuses = {
      429,
      502,
      503,
      504,
    };

    for (
      int attempt = 1;
      attempt <= maxAttempts;
      attempt++
    ) {
      try {
        final requestHeaders = _headers();

        // Send current attempt number to Laravel.
        requestHeaders['X-Automation-Attempt'] =
            attempt.toString();

        // Optional test header.
        // Laravel only processes it in local environment.
        final testMode = localAutomationTestMode;

        if (testMode != null &&
            {
              'transient_once',
              'persistent_transient',
            }.contains(testMode)) {
          requestHeaders['X-Test-Failure'] = testMode;
        }

        final response = await _client
            .post(
              Uri.parse('$baseUrl/reservations'),
              headers: requestHeaders,
              body: jsonEncode({
                'activity_id': activityId,
                'request_key': requestKey,
              }),
            )
            .timeout(const Duration(seconds: 10));

        // Retry temporary HTTP errors.
        if (retryableStatuses.contains(response.statusCode) &&
            attempt < maxAttempts) {
          await Future.delayed(
            Duration(seconds: attempt),
          );

          continue;
        }

        return _decode(response);

      } on TimeoutException {
        // Handle timeout.
        if (attempt == maxAttempts) {
          throw const ApiException(
            503,
            'Reservation timed out after three attempts.',
          );
        }

        await Future.delayed(
          Duration(seconds: attempt),
        );

      } on http.ClientException {
        // Handle network connection failure.
        if (attempt == maxAttempts) {
          throw const ApiException(
            503,
            'Unable to connect after three attempts.',
          );
        }

        await Future.delayed(
          Duration(seconds: attempt),
        );
      }
    }

    throw const ApiException(
      503,
      'Reservation could not be completed after three attempts.',
    );
  }

  // =====================================
  // GET SERVICE HOURS
  // =====================================

  Future<List<Map<String, dynamic>>> getServiceHours() async {
    final response = await _client
        .get(
          Uri.parse('$baseUrl/service-hours'),
          headers: _headers(),
        )
        .timeout(const Duration(seconds: 15));

    final result = _decode(response);
    final records = result['data'];

    if (records is! List) {
      throw const ApiException(
        500,
        'Invalid service hours response.',
      );
    }

    return records
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  // =====================================
  // SUBMIT SERVICE HOURS
  // =====================================

  Future<Map<String, dynamic>> submitServiceHours({
    required int reservationId,
    required double hours,
    required String description,
  }) async {
    final response = await _client
        .post(
          Uri.parse('$baseUrl/service-hours'),
          headers: _headers(),
          body: jsonEncode({
            'reservation_id': reservationId,
            'hours': hours,
            'description': description,
          }),
        )
        .timeout(const Duration(seconds: 15));

    return _decode(response);
  }

  // =====================================
  // APPROVE SERVICE HOURS
  // =====================================

  Future<Map<String, dynamic>> approveServiceHours(int id) async {
    final response = await _client
        .patch(
          Uri.parse('$baseUrl/service-hours/$id/approve'),
          headers: _headers(),
        )
        .timeout(const Duration(seconds: 15));

    return _decode(response);
  }

  // =====================================
  // REJECT SERVICE HOURS
  // =====================================

  Future<Map<String, dynamic>> rejectServiceHours(
    int id,
    String reason,
  ) async {
    final response = await _client
        .patch(
          Uri.parse('$baseUrl/service-hours/$id/reject'),
          headers: _headers(),
          body: jsonEncode({
            'reason': reason,
          }),
        )
        .timeout(const Duration(seconds: 15));

    return _decode(response);
  }

  // =====================================
  // CLOSE HTTP CLIENT
  // =====================================

  void dispose() {
    _client.close();
    _token = null;
    _user = null;
  }
}