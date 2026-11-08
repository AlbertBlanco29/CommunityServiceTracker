import 'package:flutter/material.dart';
import 'services/api_service.dart';

void main() {
  runApp(const ApiTestApp());
}

class ApiTestApp extends StatelessWidget {
  const ApiTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Database Connection Test',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF3D5143),
        ),
        scaffoldBackgroundColor: const Color(0xFFF6F4EE),
      ),
      home: const ApiTestScreen(),
    );
  }
}

class ApiTestScreen extends StatefulWidget {
  const ApiTestScreen({super.key});

  @override
  State<ApiTestScreen> createState() => _ApiTestScreenState();
}

class _ApiTestScreenState extends State<ApiTestScreen> {
  final emailController = TextEditingController(
    text: 'admin@example.com',
  );

  final passwordController = TextEditingController();

  bool loading = false;
  String? error;
  String? success;

  Map<String, dynamic>? user;
  List<Map<String, dynamic>> activities = [];

  Future<void> connect() async {
    if (emailController.text.trim().isEmpty ||
        passwordController.text.isEmpty) {
      setState(() => error = 'Enter your email and password.');
      return;
    }

    setState(() {
      loading = true;
      error = null;
      success = null;
    });

    try {
      // Authenticate with Laravel.
      final login = await ApiService.instance.login(
        email: emailController.text.trim(),
        password: passwordController.text,
      );

      // Retrieve actual activities from MySQL.
      final records = await ApiService.instance.getActivities();

      if (!mounted) return;

      setState(() {
        user = Map<String, dynamic>.from(login['user']);
        activities = records;
        success = 'Successfully connected to Laravel and MySQL!';
      });
    } on ApiException catch (e) {
      if (!mounted) return;

      setState(() {
        error = 'HTTP ${e.statusCode}: ${e.message}';
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        error = 'Connection failed: $e';
      });
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  Future<void> refreshActivities() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final records = await ApiService.instance.getActivities();

      if (!mounted) return;

      setState(() {
        activities = records;
        success = 'Activities refreshed successfully.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => error = e.toString());
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  InputDecoration decoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: const Color(0xFFF6F4EE),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFFEFA),
        title: const Text(
          'Database Connection Test',
          style: TextStyle(color: Color(0xFF3D5143)),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Container(
            width: 600,
            padding: const EdgeInsets.all(25),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFEFA),
              borderRadius: BorderRadius.circular(17),
              border: Border.all(color: const Color(0xFFEAE8DF)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.volunteer_activism,
                  color: Color(0xFF657966),
                  size: 38,
                ),
                const SizedBox(height: 15),
                const Text(
                  'Community Service Hours Tracker',
                  style: TextStyle(
                    color: Color(0xFF3D5143),
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Test your Flutter, Laravel and MySQL connection.',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 25),
                TextField(
                  controller: emailController,
                  decoration: decoration('Administrator Email'),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: decoration('Password'),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: loading ? null : connect,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3D5143),
                      foregroundColor: Colors.white,
                    ),
                    child: loading
                        ? const CircularProgressIndicator(
                            color: Colors.white,
                          )
                        : const Text('Connect to MySQL'),
                  ),
                ),
                if (error != null) ...[
                  const SizedBox(height: 18),
                  Text(
                    error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ],
                if (success != null) ...[
                  const SizedBox(height: 18),
                  Text(
                    success!,
                    style: const TextStyle(
                      color: Color(0xFF3D5143),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
                if (user != null) ...[
                  const Divider(height: 35),
                  const Text(
                    'Authenticated Account',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF3D5143),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text('Name: ${user!['name']}'),
                  Text('Email: ${user!['email']}'),
                  Text('Role: ${user!['role']}'),
                  const Divider(height: 35),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Activities from MySQL',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF3D5143),
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: loading ? null : refreshActivities,
                        icon: const Icon(Icons.refresh),
                      ),
                    ],
                  ),
                  Text('${activities.length} activities retrieved.'),
                  const SizedBox(height: 15),
                  if (activities.isEmpty) const Text('No activities found.'),
                  ...activities.map((activity) {
                    return Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF6F4EE),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            activity['title']?.toString() ?? '',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF3D5143),
                            ),
                          ),
                          const SizedBox(height: 7),
                          Text('Location: ${activity['location']}'),
                          Text('Category: ${activity['category']}'),
                          Text('Date: ${activity['activity_date']}'),
                          Text('Hours: ${activity['estimated_hours']}'),
                          Text('Capacity: ${activity['capacity']}'),
                          Text('Status: ${activity['status']}'),
                        ],
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
