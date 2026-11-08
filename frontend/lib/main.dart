import 'package:flutter/material.dart';
import 'services/api_service.dart';

void main() {
  runApp(const CommunityServiceApp());
}

// ======================================================
// THEME
// ======================================================

class AppColors {
  static const background = Color(0xFFF6F4EE);
  static const surface = Color(0xFFFFFEFA);
  static const forest = Color(0xFF3D5143);
  static const sage = Color(0xFF879783);
  static const lightSage = Color(0xFFE8EDE5);
  static const olive = Color(0xFF657966);
  static const clay = Color(0xFFC98469);
  static const gold = Color(0xFFC5A66B);
  static const text = Color(0xFF343D35);
  static const muted = Color(0xFF858B80);
  static const border = Color(0xFFEAE8DF);
}

class CommunityServiceApp extends StatelessWidget {
  const CommunityServiceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Community Service Hours Tracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.forest),
      ),
      home: const LoginScreen(),
    );
  }
}

// ======================================================
// SHARED HELPERS
// ======================================================

int numberValue(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

double decimalValue(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

String formatDate(dynamic value) {
  if (value == null) return 'Not specified';
  final raw = value.toString();
  if (raw.length < 10) return raw;
  final parts = raw.substring(0, 10).split('-');
  if (parts.length != 3) return raw;
  return '${parts[1]}/${parts[2]}/${parts[0]}';
}

Widget statusBadge(String status) {
  final normalized = status.toLowerCase();
  Color foreground;
  Color background;

  switch (normalized) {
    case 'available':
    case 'approved':
    case 'success':
      foreground = AppColors.olive;
      background = const Color(0xFFE7EEE3);
      break;
    case 'reserved':
    case 'pending':
    case 'recovered':
      foreground = const Color(0xFFAE7756);
      background = const Color(0xFFF4EAE0);
      break;
    case 'rejected':
    case 'cancelled':
    case 'failed':
      foreground = const Color(0xFFAD6255);
      background = const Color(0xFFF5E5E0);
      break;
    default:
      foreground = const Color(0xFF657A8D);
      background = const Color(0xFFE8EEF1);
  }

  final label = normalized.isEmpty
      ? 'Unknown'
      : '${normalized[0].toUpperCase()}${normalized.substring(1)}';

  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: foreground,
        fontSize: 10,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

Widget sectionTitle(String title, String subtitle) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: const TextStyle(
          color: AppColors.text,
          fontSize: 23,
          fontWeight: FontWeight.bold,
        ),
      ),
      const SizedBox(height: 6),
      Text(
        subtitle,
        style: const TextStyle(color: AppColors.muted, fontSize: 12),
      ),
    ],
  );
}

Widget emptyState(String message) {
  return SizedBox(
    width: double.infinity,
    child: Padding(
      padding: const EdgeInsets.all(35),
      child: Column(
        children: [
          const Icon(Icons.inbox_outlined, size: 42, color: AppColors.sage),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.muted),
          ),
        ],
      ),
    ),
  );
}

Widget errorCard(String message) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: const Color(0xFFF5E5E0),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      children: [
        const Icon(Icons.error_outline, color: AppColors.clay),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(color: AppColors.text, fontSize: 12),
          ),
        ),
      ],
    ),
  );
}

// No Spacer() is used in this card. It can safely be placed in scroll views.
Widget statCard(String title, String value, IconData icon, Color color) {
  return Container(
    padding: const EdgeInsets.all(17),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 23),
        const SizedBox(height: 18),
        Text(title, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppColors.text,
          ),
        ),
      ],
    ),
  );
}

InputDecoration appInputDecoration(String label, {IconData? icon}) {
  return InputDecoration(
    labelText: label,
    prefixIcon: icon == null ? null : Icon(icon, color: AppColors.sage),
    filled: true,
    fillColor: AppColors.background,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: AppColors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: AppColors.sage),
    ),
  );
}

// ======================================================
// LOGIN SCREEN
// ======================================================

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  String selectedRole = 'student';
  bool loading = false;
  bool obscurePassword = true;
  String? error;

  Future<void> login() async {
    if (emailController.text.trim().isEmpty || passwordController.text.isEmpty) {
      setState(() => error = 'Please complete all fields.');
      return;
    }

    setState(() {
      loading = true;
      error = null;
    });

    try {
      final response = await ApiService.instance.login(
        email: emailController.text.trim(),
        password: passwordController.text,
      );
      final user = Map<String, dynamic>.from(response['user']);
      final actualRole = user['role'].toString();

      if (actualRole != selectedRole) {
        await ApiService.instance.logout();
        throw const ApiException(403, 'This account does not have the selected role.');
      }

      if (!mounted) return;
      final destination = actualRole == 'admin'
          ? AdminDashboard(user: user)
          : StudentDashboard(user: user);

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => destination),
      );
    } on ApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (e) {
      if (mounted) setState(() => error = 'Unable to connect to server: $e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Widget roleButton(String label, String role, IconData icon) {
    final selected = selectedRole == role;
    return InkWell(
      onTap: () => setState(() => selectedRole = role),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: selected ? AppColors.lightSage : AppColors.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.sage : AppColors.border,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.forest),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.forest,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
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
      backgroundColor: AppColors.background,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Container(
            width: 440,
            padding: const EdgeInsets.all(35),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(17),
                    decoration: BoxDecoration(
                      color: AppColors.lightSage,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.volunteer_activism_rounded,
                      size: 40,
                      color: AppColors.forest,
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                const Center(
                  child: Text(
                    'Community Service',
                    style: TextStyle(
                      color: AppColors.forest,
                      fontSize: 23,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Center(
                  child: Text(
                    'HOURS TRACKER',
                    style: TextStyle(
                      color: AppColors.muted,
                      fontSize: 10,
                      letterSpacing: 2,
                    ),
                  ),
                ),
                const SizedBox(height: 35),
                const Text(
                  'Welcome back',
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 7),
                const Text(
                  'Sign in to continue your community service journey.',
                  style: TextStyle(color: AppColors.muted, fontSize: 12),
                ),
                const SizedBox(height: 25),
                const Text(
                  'LOGIN AS',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: roleButton('Student', 'student', Icons.school_outlined)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: roleButton(
                        'Administrator',
                        'admin',
                        Icons.admin_panel_settings_outlined,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                const Text('Email Address', style: TextStyle(fontSize: 12)),
                const SizedBox(height: 8),
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: appInputDecoration(
                    'Enter your email address',
                    icon: Icons.mail_outline,
                  ),
                ),
                const SizedBox(height: 18),
                const Text('Password', style: TextStyle(fontSize: 12)),
                const SizedBox(height: 8),
                TextField(
                  controller: passwordController,
                  obscureText: obscurePassword,
                  onSubmitted: (_) => login(),
                  decoration: appInputDecoration(
                    'Enter your password',
                    icon: Icons.lock_outline,
                  ).copyWith(
                    suffixIcon: IconButton(
                      onPressed: () => setState(
                        () => obscurePassword = !obscurePassword,
                      ),
                      icon: Icon(
                        obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: AppColors.muted,
                      ),
                    ),
                  ),
                ),
                if (error != null) ...[
                  const SizedBox(height: 15),
                  errorCard(error!),
                ],
                const SizedBox(height: 25),
                SizedBox(
                  width: double.infinity,
                  height: 49,
                  child: ElevatedButton(
                    onPressed: loading ? null : login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.forest,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: loading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Sign In'),
                  ),
                ),
                const SizedBox(height: 22),
                const Center(
                  child: Text(
                    'COMMUNITY SERVICE HOURS TRACKER',
                    style: TextStyle(
                      color: AppColors.muted,
                      fontSize: 9,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ======================================================
// SEPARATE ACTIVITY FORM PAGE
// This avoids using a modal dialog for create/edit.
// ======================================================

class ActivityFormPage extends StatefulWidget {
  final Map<String, dynamic>? existing;

  const ActivityFormPage({super.key, this.existing});

  @override
  State<ActivityFormPage> createState() => _ActivityFormPageState();
}

class _ActivityFormPageState extends State<ActivityFormPage> {
  final formKey = GlobalKey<FormState>();
  late final TextEditingController titleController;
  late final TextEditingController categoryController;
  late final TextEditingController locationController;
  late final TextEditingController dateController;
  late final TextEditingController hoursController;
  late final TextEditingController capacityController;
  late final TextEditingController descriptionController;

  bool saving = false;
  String? error;

  @override
  void initState() {
    super.initState();
    final activity = widget.existing;
    final rawDate = activity?['activity_date']?.toString();

    titleController = TextEditingController(text: activity?['title']?.toString() ?? '');
    categoryController = TextEditingController(text: activity?['category']?.toString() ?? '');
    locationController = TextEditingController(text: activity?['location']?.toString() ?? '');
    dateController = TextEditingController(
      text: rawDate != null && rawDate.length >= 10
          ? rawDate.substring(0, 10)
          : DateTime.now().add(const Duration(days: 7)).toIso8601String().substring(0, 10),
    );
    hoursController = TextEditingController(
      text: activity?['estimated_hours']?.toString() ?? '4',
    );
    capacityController = TextEditingController(
      text: activity?['capacity']?.toString() ?? '5',
    );
    descriptionController = TextEditingController(
      text: activity?['description']?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    titleController.dispose();
    categoryController.dispose();
    locationController.dispose();
    dateController.dispose();
    hoursController.dispose();
    capacityController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  String? requiredValidator(String? value) {
    if (value == null || value.trim().isEmpty) return 'This field is required.';
    return null;
  }

  String? dateValidator(String? value) {
    if (value == null || DateTime.tryParse(value.trim()) == null) {
      return 'Use YYYY-MM-DD format.';
    }
    if (widget.existing == null) {
      final selected = DateTime.parse(value.trim());
      final today = DateTime.now();
      final selectedDate = DateTime(selected.year, selected.month, selected.day);
      final todayDate = DateTime(today.year, today.month, today.day);
      if (selectedDate.isBefore(todayDate)) return 'Date cannot be in the past.';
    }
    return null;
  }

  String? hoursValidator(String? value) {
    final number = int.tryParse(value ?? '');
    if (number == null || number < 1 || number > 24) {
      return 'Enter between 1 and 24 hours.';
    }
    return null;
  }

  String? capacityValidator(String? value) {
    final number = int.tryParse(value ?? '');
    if (number == null || number < 1 || number > 1000) {
      return 'Enter between 1 and 1000 slots.';
    }
    return null;
  }

  Widget formField(
    TextEditingController controller,
    String label,
    IconData icon, {
    String? Function(String?)? validator,
    TextInputType keyboard = TextInputType.text,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboard,
        maxLines: maxLines,
        validator: validator ?? requiredValidator,
        decoration: appInputDecoration(label, icon: icon),
      ),
    );
  }

  Future<void> saveActivity() async {
    if (saving || !formKey.currentState!.validate()) return;

    setState(() {
      saving = true;
      error = null;
    });

    final data = <String, dynamic>{
      'title': titleController.text.trim(),
      'category': categoryController.text.trim(),
      'location': locationController.text.trim(),
      'activity_date': dateController.text.trim(),
      'estimated_hours': int.parse(hoursController.text.trim()),
      'capacity': int.parse(capacityController.text.trim()),
      'description': descriptionController.text.trim(),
    };

    try {
      if (widget.existing == null) {
        await ApiService.instance.createActivity(data);
      } else {
        await ApiService.instance.updateActivity(
          numberValue(widget.existing!['id']),
          data,
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        saving = false;
        error = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        saving = false;
        error = 'Unable to save activity: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.existing != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.forest,
        elevation: 0,
        title: Text(editing ? 'Edit Activity' : 'Create Activity'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 650),
              child: Container(
                padding: const EdgeInsets.all(25),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Form(
                  key: formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        editing ? 'Update community activity details' : 'Create a new community service opportunity',
                        style: const TextStyle(
                          color: AppColors.forest,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Complete the information below.',
                        style: TextStyle(color: AppColors.muted, fontSize: 12),
                      ),
                      const SizedBox(height: 25),
                      formField(titleController, 'Activity Name', Icons.event_outlined),
                      formField(categoryController, 'Category', Icons.category_outlined),
                      formField(locationController, 'Location', Icons.location_on_outlined),
                      formField(
                        dateController,
                        'Activity Date (YYYY-MM-DD)',
                        Icons.calendar_month_outlined,
                        validator: dateValidator,
                      ),
                      formField(
                        hoursController,
                        'Estimated Hours',
                        Icons.schedule_outlined,
                        keyboard: TextInputType.number,
                        validator: hoursValidator,
                      ),
                      formField(
                        capacityController,
                        'Available Slots',
                        Icons.groups_outlined,
                        keyboard: TextInputType.number,
                        validator: capacityValidator,
                      ),
                      formField(
                        descriptionController,
                        'Description (optional)',
                        Icons.description_outlined,
                        maxLines: 4,
                        validator: (_) => null,
                      ),
                      if (error != null) ...[
                        errorCard(error!),
                        const SizedBox(height: 12),
                      ],
                      SizedBox(
                        width: double.infinity,
                        height: 49,
                        child: ElevatedButton.icon(
                          onPressed: saving ? null : saveActivity,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.forest,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          icon: saving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.save_outlined),
                          label: Text(
                            saving
                                ? 'Saving...'
                                : editing
                                    ? 'Update Activity'
                                    : 'Save Activity',
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        height: 45,
                        child: OutlinedButton(
                          onPressed: saving ? null : () => Navigator.of(context).pop(false),
                          child: const Text('Cancel'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ======================================================
// REUSABLE CONFIRMATION PAGE (NO MODAL DIALOG)
// ======================================================

class ConfirmationPage extends StatelessWidget {
  final String title;
  final String message;
  final String confirmLabel;

  const ConfirmationPage({
    super.key,
    required this.title,
    required this.message,
    required this.confirmLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.forest,
        title: Text(title),
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.help_outline, size: 42, color: AppColors.olive),
              const SizedBox(height: 16),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.clay,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(confirmLabel),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ======================================================
// SERVICE-HOUR SUBMISSION FORM PAGE (NO MODAL DIALOG)
// ======================================================

class ServiceHourFormPage extends StatefulWidget {
  final Map<String, dynamic> reservation;

  const ServiceHourFormPage({
    super.key,
    required this.reservation,
  });

  @override
  State<ServiceHourFormPage> createState() => _ServiceHourFormPageState();
}

class _ServiceHourFormPageState extends State<ServiceHourFormPage> {
  final formKey = GlobalKey<FormState>();
  late final TextEditingController hoursController;
  final descriptionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final activity = widget.reservation['activity'];
    final estimated = activity is Map ? activity['estimated_hours'] : null;
    hoursController = TextEditingController(text: estimated?.toString() ?? '1');
  }

  @override
  void dispose() {
    hoursController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activity = widget.reservation['activity'] is Map
        ? widget.reservation['activity'] as Map
        : <dynamic, dynamic>{};

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.forest,
        title: const Text('Submit Service Hours'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Form(
                  key: formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        activity['title']?.toString() ?? 'Community Activity',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.forest,
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: hoursController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: appInputDecoration('Completed Hours', icon: Icons.schedule),
                        validator: (value) {
                          final parsed = double.tryParse(value ?? '');
                          if (parsed == null || parsed <= 0 || parsed > 24) {
                            return 'Enter a value greater than 0 and no more than 24.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: descriptionController,
                        maxLines: 4,
                        decoration: appInputDecoration('Service Description', icon: Icons.description_outlined),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please describe the service completed.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 22),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            if (!formKey.currentState!.validate()) return;
                            Navigator.of(context).pop(<String, dynamic>{
                              'hours': double.parse(hoursController.text.trim()),
                              'description': descriptionController.text.trim(),
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.forest,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                          ),
                          child: const Text('Submit for Approval'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Cancel'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ======================================================
// REJECTION REASON PAGE (SUBMITS BEFORE RETURNING)
// This page stays open while the API request runs. It only returns
// to the admin dashboard after the user acknowledges the success state.

class RejectionReasonPage extends StatefulWidget {
  final int serviceHourId;

  const RejectionReasonPage({
    super.key,
    required this.serviceHourId,
  });

  @override
  State<RejectionReasonPage> createState() => _RejectionReasonPageState();
}

class _RejectionReasonPageState extends State<RejectionReasonPage> {
  final controller = TextEditingController();
  bool submitting = false;
  bool submitted = false;
  String? error;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> submitRejection() async {
    final reason = controller.text.trim();
    if (reason.isEmpty || submitting || submitted) {
      setState(() {
        error = 'Please enter a reason for rejection.';
      });
      return;
    }

    setState(() {
      submitting = true;
      error = null;
    });

    try {
      await ApiService.instance.rejectServiceHours(
        widget.serviceHourId,
        reason,
      );

      if (!mounted) return;
      setState(() {
        submitting = false;
        submitted = true;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        submitting = false;
        error = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        submitting = false;
        error = 'Unable to submit rejection: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.forest,
        title: const Text('Reject Submission'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 550),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(
                      submitted ? Icons.check_circle_outline : Icons.rate_review_outlined,
                      color: submitted ? AppColors.olive : AppColors.clay,
                      size: 42,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      submitted ? 'Submission rejected' : 'Reject service-hour submission',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.forest,
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      submitted
                          ? 'The rejection was saved successfully. Return to Service Hours to refresh the records.'
                          : 'Enter a clear reason. The student will be able to review the reason and resubmit their service hours.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                      ),
                    ),
                    if (!submitted) ...[
                      const SizedBox(height: 22),
                      TextField(
                        controller: controller,
                        maxLines: 4,
                        decoration: InputDecoration(
                          labelText: 'Reason for rejection',
                          hintText: 'Explain what needs to be corrected...',
                          filled: true,
                          fillColor: AppColors.background,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ],
                    if (error != null) ...[
                      const SizedBox(height: 14),
                      Text(
                        error!,
                        style: const TextStyle(
                          color: AppColors.clay,
                          fontSize: 12,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: submitted
                            ? () => Navigator.of(context).pop(true)
                            : (submitting ? null : submitRejection),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: submitted
                              ? AppColors.forest
                              : AppColors.clay,
                          foregroundColor: Colors.white,
                        ),
                        child: submitting
                            ? const SizedBox(
                                width: 19,
                                height: 19,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                submitted
                                    ? 'Return to Service Hours'
                                    : 'Submit Rejection',
                              ),
                      ),
                    ),
                    if (!submitted) ...[
                      const SizedBox(height: 9),
                      OutlinedButton(
                        onPressed: submitting
                            ? null
                            : () => Navigator.of(context).pop(false),
                        child: const Text('Cancel'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ADMIN DASHBOARD
// ======================================================

class AdminDashboard extends StatefulWidget {
  final Map<String, dynamic> user;

  const AdminDashboard({super.key, required this.user});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int selectedIndex = 0;
  bool loading = true;
  String? error;

  List<Map<String, dynamic>> activities = [];
  List<Map<String, dynamic>> reservations = [];
  List<Map<String, dynamic>> serviceHours = [];

  final menu = const [
    (Icons.grid_view_rounded, 'Dashboard'),
    (Icons.calendar_month_outlined, 'Activities'),
    (Icons.bookmark_border_rounded, 'Reservations'),
    (Icons.groups_2_outlined, 'Assigned Students'),
    (Icons.schedule_rounded, 'Service Hours'),
    (Icons.bar_chart_outlined, 'Reports'),
  ];

  String get pageTitle => menu[selectedIndex].$2;

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    if (!mounted) return;
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final activityRecords = await ApiService.instance.getActivities();
      final reservationRecords = await ApiService.instance.getReservations();
      final hourRecords = await ApiService.instance.getServiceHours();

      if (!mounted) return;
      setState(() {
        activities = activityRecords;
        reservations = reservationRecords;
        serviceHours = hourRecords;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = e.toString();
        loading = false;
      });
    }
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> logout() async {
    try {
      await ApiService.instance.logout();
    } catch (_) {
      // Clear the local session if the server is unavailable.
    }
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  // Activity create/edit now uses a normal page route, not showDialog.
  Future<void> activityForm({Map<String, dynamic>? existing}) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ActivityFormPage(existing: existing),
      ),
    );

    if (!mounted || saved != true) return;
    await loadData();
    if (mounted) {
      showMessage(existing == null ? 'Activity created successfully.' : 'Activity updated successfully.');
    }
  }

  Future<void> deleteActivity(Map<String, dynamic> activity) async {
    final confirmed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ConfirmationPage(
          title: 'Delete Activity',
          message: 'Are you sure you want to delete "${activity['title']}"?',
          confirmLabel: 'Delete Activity',
        ),
      ),
    );

    if (!mounted || confirmed != true) return;

    try {
      await ApiService.instance.deleteActivity(numberValue(activity['id']));
      await loadData();
      if (mounted) showMessage('Activity deleted successfully.');
    } catch (e) {
      if (mounted) showMessage('Unable to delete activity: $e');
    }
  }

  Future<void> reviewServiceHours(Map<String, dynamic> record, bool approve) async {
    final id = numberValue(record['id']);

    try {
      if (approve) {
        await ApiService.instance.approveServiceHours(id);
      } else {
        final rejected = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) => RejectionReasonPage(serviceHourId: id),
          ),
        );

        if (!mounted || rejected != true) return;

        // Let the rejection page's route finish transitioning before
        // refreshing the parent dashboard's API-backed lists.
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }

      if (!mounted) return;
      await loadData();

      if (mounted) {
        showMessage(
          approve ? 'Service hours approved.' : 'Service hours rejected.',
        );
      }
    } catch (e) {
      if (mounted) {
        showMessage('Unable to process submission: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 850;
        return Scaffold(
          backgroundColor: AppColors.background,
          body: Row(
            children: [
              if (desktop) buildSidebar(),
              Expanded(
                child: Column(
                  children: [
                    buildTopBar(desktop),
                    Expanded(child: buildPage()),
                  ],
                ),
              ),
            ],
          ),
          bottomNavigationBar: desktop
              ? null
              : NavigationBar(
                  backgroundColor: AppColors.surface,
                  selectedIndex: selectedIndex > 3 ? 0 : selectedIndex,
                  onDestinationSelected: (index) => setState(() => selectedIndex = index),
                  destinations: const [
                    NavigationDestination(icon: Icon(Icons.grid_view_rounded), label: 'Home'),
                    NavigationDestination(icon: Icon(Icons.event_outlined), label: 'Activities'),
                    NavigationDestination(icon: Icon(Icons.bookmark_outline), label: 'Bookings'),
                    NavigationDestination(icon: Icon(Icons.schedule_outlined), label: 'Hours'),
                  ],
                ),
        );
      },
    );
  }

  Widget buildSidebar() {
    return Container(
      width: 245,
      color: AppColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(25, 30, 20, 25),
            child: Row(
              children: [
                Icon(Icons.volunteer_activism_rounded, color: AppColors.forest, size: 32),
                SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Community', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.forest)),
                    Text('SERVICE TRACKER', style: TextStyle(fontSize: 9, letterSpacing: 1.5, color: AppColors.muted)),
                  ],
                ),
              ],
            ),
          ),
          const Divider(color: AppColors.border),
          const Padding(
            padding: EdgeInsets.fromLTRB(25, 20, 20, 12),
            child: Text(
              'WORKSPACE',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: AppColors.muted),
            ),
          ),
          ...List.generate(menu.length, (index) {
            final active = selectedIndex == index;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 3),
              child: ListTile(
                selected: active,
                selectedTileColor: AppColors.lightSage,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                leading: Icon(
                  menu[index].$1,
                  color: active ? AppColors.forest : AppColors.muted,
                  size: 19,
                ),
                title: Text(
                  menu[index].$2,
                  style: TextStyle(
                    fontSize: 12,
                    color: active ? AppColors.forest : AppColors.muted,
                    fontWeight: active ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                onTap: () => setState(() => selectedIndex = index),
              ),
            );
          }),
          const Spacer(),
          const Divider(color: AppColors.border),
          ListTile(
            leading: const Icon(Icons.logout_outlined, color: AppColors.clay),
            title: const Text('Sign Out', style: TextStyle(fontSize: 12)),
            onTap: logout,
          ),
          const SizedBox(height: 15),
        ],
      ),
    );
  }

  Widget buildTopBar(bool desktop) {
    return Container(
      height: 76,
      padding: const EdgeInsets.symmetric(horizontal: 25),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Text(
            pageTitle,
            style: const TextStyle(color: AppColors.text, fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          IconButton(
            onPressed: loading ? null : loadData,
            icon: const Icon(Icons.refresh, color: AppColors.olive),
          ),
          const SizedBox(width: 12),
          const CircleAvatar(
            radius: 17,
            backgroundColor: AppColors.lightSage,
            child: Icon(Icons.person_outline, color: AppColors.forest, size: 19),
          ),
          if (desktop) ...[
            const SizedBox(width: 9),
            Text(
              widget.user['name']?.toString() ?? 'Administrator',
              style: const TextStyle(fontSize: 11, color: AppColors.text, fontWeight: FontWeight.w600),
            ),
          ],
        ],
      ),
    );
  }

  Widget buildPage() {
    if (loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.forest));
    }
    if (error != null) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(25),
        child: Column(
          children: [
            errorCard(error!),
            ElevatedButton.icon(
              onPressed: loadData,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
          ],
        ),
      );
    }
    switch (selectedIndex) {
      case 0:
        return buildDashboard();
      case 1:
        return buildActivitiesPage();
      case 2:
        return buildReservationsPage();
      case 3:
        return buildAssignedStudentsPage();
      case 4:
        return buildServiceHoursPage();
      default:
        return buildReportsPage();
    }
  }

  Widget buildDashboard() {
    final available = activities.where((a) => a['status'] == 'available').length;
    final reserved = activities.where((a) => a['status'] == 'reserved').length;
    final approved = activities.where((a) => a['status'] == 'approved').length;
    final approvedHours = serviceHours
        .where((h) => h['approval_status'] == 'approved')
        .fold<double>(0, (sum, h) => sum + decimalValue(h['hours']));

    final cards = [
      ('Total Activities', '${activities.length}', Icons.calendar_month_outlined, AppColors.forest),
      ('Available', '$available', Icons.check_circle_outline, AppColors.olive),
      ('Reserved', '$reserved', Icons.bookmark_border, AppColors.clay),
      ('Approved', '$approved', Icons.verified_outlined, AppColors.gold),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(25),
            decoration: BoxDecoration(
              color: AppColors.lightSage,
              borderRadius: BorderRadius.circular(17),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'COMMUNITY SERVICE MANAGEMENT',
                  style: TextStyle(fontSize: 10, letterSpacing: 1.5, color: AppColors.olive, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 10),
                Text(
                  'Making a difference,\none service hour at a time.',
                  style: TextStyle(color: AppColors.forest, fontSize: 25, height: 1.35, fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 9),
                Text(
                  'Manage activities, student assignments and service records.',
                  style: TextStyle(color: AppColors.olive, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 25),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth < 550 ? 2 : 4;
              return GridView.count(
                crossAxisCount: columns,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 13,
                mainAxisSpacing: 13,
                childAspectRatio: columns == 2 ? 1.7 : 1.25,
                children: cards.map((card) {
                  return statCard(card.$1, card.$2, card.$3, card.$4);
                }).toList(),
              );
            },
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: 260,
            child: statCard(
              'Total Approved Service Hours',
              '${approvedHours.toStringAsFixed(2)} hrs',
              Icons.access_time,
              AppColors.olive,
            ),
          ),
          const SizedBox(height: 28),
          buildActivityRecords(),
        ],
      ),
    );
  }

  Widget buildActivityRecords() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Community Activities',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.text),
                ),
              ),
              TextButton.icon(
                onPressed: () => activityForm(),
                icon: const Icon(Icons.add, size: 17),
                label: const Text('Add Activity'),
              ),
            ],
          ),
          const SizedBox(height: 15),
          if (activities.isEmpty) emptyState('No activities have been created yet.'),
          ...activities.map(buildActivityCard),
        ],
      ),
    );
  }

  Widget buildActivityCard(Map<String, dynamic> activity) {
    final reservedCount = numberValue(activity['reservations_count']);
    final capacity = numberValue(activity['capacity']);
    final remaining = activity['remaining_slots'] == null
        ? capacity - reservedCount
        : numberValue(activity['remaining_slots']);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  activity['title']?.toString() ?? '',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.text),
                ),
              ),
              statusBadge(activity['status']?.toString() ?? ''),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            '${activity['category'] ?? ''} • ${activity['location'] ?? ''}',
            style: const TextStyle(color: AppColors.muted, fontSize: 11),
          ),
          const SizedBox(height: 6),
          Text(
            'Date: ${formatDate(activity['activity_date'])}',
            style: const TextStyle(color: AppColors.muted, fontSize: 11),
          ),
          const SizedBox(height: 6),
          Text(
            'Estimated Hours: ${activity['estimated_hours'] ?? '-'} hrs',
            style: const TextStyle(color: AppColors.muted, fontSize: 11),
          ),
          const SizedBox(height: 6),
          Text(
            'Slots: $reservedCount / $capacity reserved • $remaining remaining',
            style: const TextStyle(color: AppColors.olive, fontSize: 11),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 4,
            children: [
              TextButton.icon(
                onPressed: () => activityForm(existing: activity),
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Edit'),
              ),
              TextButton.icon(
                onPressed: () => deleteActivity(activity),
                icon: const Icon(Icons.delete_outline, size: 16),
                label: const Text('Delete'),
                style: TextButton.styleFrom(foregroundColor: AppColors.clay),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget buildActivitiesPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          sectionTitle('Activity Management', 'Create and manage activities stored in MySQL.'),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => activityForm(),
              icon: const Icon(Icons.add),
              label: const Text('Create New Activity'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.forest,
                foregroundColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 20),
          if (activities.isEmpty) emptyState('No activities found.'),
          ...activities.map(buildActivityCard),
        ],
      ),
    );
  }

  Widget buildReservationsPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          sectionTitle('Reservations', 'Student reservations retrieved from MySQL.'),
          const SizedBox(height: 20),
          if (reservations.isEmpty) emptyState('No student reservations yet.'),
          ...reservations.map(buildReservationCard),
        ],
      ),
    );
  }

  Widget buildAssignedStudentsPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          sectionTitle('Assigned Students', 'Students who reserved community service activities.'),
          const SizedBox(height: 20),
          if (reservations.isEmpty) emptyState('No students assigned yet.'),
          ...reservations.map(buildReservationCard),
        ],
      ),
    );
  }

  Widget buildReservationCard(Map<String, dynamic> reservation) {
    final student = reservation['student'] is Map ? reservation['student'] as Map : {};
    final activity = reservation['activity'] is Map ? reservation['activity'] as Map : {};

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 13),
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person_outline, color: AppColors.olive),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  student['name']?.toString() ?? 'Unknown Student',
                  style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.bold),
                ),
              ),
              statusBadge(reservation['status']?.toString() ?? ''),
            ],
          ),
          const SizedBox(height: 12),
          Text('Activity: ${activity['title'] ?? 'Unknown Activity'}', style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 5),
          Text('Student Email: ${student['email'] ?? '-'}', style: const TextStyle(fontSize: 11, color: AppColors.muted)),
          const SizedBox(height: 5),
          Text('Reservation ID: ${reservation['id']}', style: const TextStyle(fontSize: 11, color: AppColors.olive)),
        ],
      ),
    );
  }

  Widget buildServiceHoursPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          sectionTitle('Service Hours Approval', 'Review student-completed community service hours.'),
          const SizedBox(height: 20),
          if (serviceHours.isEmpty) emptyState('No service-hour submissions yet.'),
          ...serviceHours.map((record) {
            final reservation = record['reservation'] is Map ? record['reservation'] as Map : {};
            final student = reservation['student'] is Map ? reservation['student'] as Map : {};
            final activity = reservation['activity'] is Map ? reservation['activity'] as Map : {};
            final status = record['approval_status']?.toString() ?? '';

            return Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(17),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          student['name']?.toString() ?? 'Student',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.text),
                        ),
                      ),
                      statusBadge(status),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text('Activity: ${activity['title'] ?? '-'}', style: const TextStyle(fontSize: 12)),
                  Text('Hours Submitted: ${record['hours']}', style: const TextStyle(fontSize: 12)),
                  const SizedBox(height: 6),
                  Text(
                    record['description']?.toString() ?? '',
                    style: const TextStyle(color: AppColors.muted, fontSize: 11),
                  ),
                  if (status == 'pending') ...[
                    const SizedBox(height: 13),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => reviewServiceHours(record, false),
                            style: OutlinedButton.styleFrom(foregroundColor: AppColors.clay),
                            child: const Text('Reject'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => reviewServiceHours(record, true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.forest,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Approve'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget buildReportsPage() {
    final approvedHours = serviceHours
        .where((h) => h['approval_status'] == 'approved')
        .fold<double>(0, (sum, h) => sum + decimalValue(h['hours']));
    final pending = serviceHours.where((h) => h['approval_status'] == 'pending').length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          sectionTitle('Reports and Monitoring', 'Summary of actual records from the database.'),
          const SizedBox(height: 20),
          statCard('Total Activities', '${activities.length}', Icons.event, AppColors.forest),
          const SizedBox(height: 13),
          statCard('Total Reservations', '${reservations.length}', Icons.bookmark_outline, AppColors.clay),
          const SizedBox(height: 13),
          statCard('Approved Service Hours', '${approvedHours.toStringAsFixed(2)} hrs', Icons.verified_outlined, AppColors.olive),
          const SizedBox(height: 13),
          statCard('Pending Submissions', '$pending', Icons.pending_actions_outlined, AppColors.gold),
        ],
      ),
    );
  }
}

// ======================================================
// STUDENT DASHBOARD
// ======================================================

class StudentDashboard extends StatefulWidget {
  final Map<String, dynamic> user;

  const StudentDashboard({super.key, required this.user});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  int selectedIndex = 0;
  bool loading = true;
  String? error;

  List<Map<String, dynamic>> activities = [];
  List<Map<String, dynamic>> reservations = [];
  List<Map<String, dynamic>> serviceHours = [];

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    if (!mounted) return;
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final activityRecords = await ApiService.instance.getActivities();
      final reservationRecords = await ApiService.instance.getReservations();
      final hourRecords = await ApiService.instance.getServiceHours();
      if (!mounted) return;
      setState(() {
        activities = activityRecords;
        reservations = reservationRecords;
        serviceHours = hourRecords;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = e.toString();
        loading = false;
      });
    }
  }

  Future<void> logout() async {
    try {
      await ApiService.instance.logout();
    } catch (_) {
      // The local session is cleared by the login flow if necessary.
    }
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Future<void> reserveActivity(Map<String, dynamic> activity) async {
    try {
      final result = await ApiService.instance.reserveActivity(numberValue(activity['id']));
      await loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message']?.toString() ?? 'Reservation successful.')),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Reservation failed: $e')));
      }
    }
  }

  Future<void> submitHours(Map<String, dynamic> reservation) async {
    final submission = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => ServiceHourFormPage(reservation: reservation),
      ),
    );

    if (!mounted || submission == null) return;

    try {
      await ApiService.instance.submitServiceHours(
        reservationId: numberValue(reservation['id']),
        hours: decimalValue(submission['hours']),
        description: submission['description'].toString(),
      );
      await loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Service hours submitted. Awaiting administrator approval.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Submission failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: const Text(
          'Community Service',
          style: TextStyle(color: AppColors.forest, fontWeight: FontWeight.bold, fontSize: 17),
        ),
        actions: [
          IconButton(
            onPressed: loading ? null : loadData,
            icon: const Icon(Icons.refresh, color: AppColors.olive),
          ),
          IconButton(
            onPressed: logout,
            icon: const Icon(Icons.logout_rounded, color: AppColors.forest),
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.forest))
          : error != null
              ? SingleChildScrollView(
                  padding: const EdgeInsets.all(25),
                  child: Column(
                    children: [
                      errorCard(error!),
                      ElevatedButton(onPressed: loadData, child: const Text('Try Again')),
                    ],
                  ),
                )
              : IndexedStack(
                  index: selectedIndex,
                  children: [
                    buildOverview(),
                    buildActivities(),
                    buildReservations(),
                    buildServiceHours(),
                  ],
                ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: AppColors.surface,
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) => setState(() => selectedIndex = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.grid_view_rounded), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.event_outlined), label: 'Activities'),
          NavigationDestination(icon: Icon(Icons.bookmark_outline), label: 'Reservations'),
          NavigationDestination(icon: Icon(Icons.schedule_outlined), label: 'Hours'),
        ],
      ),
    );
  }

  Widget buildOverview() {
    final approvedHours = serviceHours
        .where((h) => h['approval_status'] == 'approved')
        .fold<double>(0, (sum, h) => sum + decimalValue(h['hours']));
    final pending = serviceHours.where((h) => h['approval_status'] == 'pending').length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.lightSage,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'STUDENT PORTAL',
                  style: TextStyle(color: AppColors.olive, fontSize: 10, letterSpacing: 1.5, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text(
                  'Welcome back, ${widget.user['name']}!',
                  style: const TextStyle(color: AppColors.forest, fontSize: 23, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.user['email']?.toString() ?? '',
                  style: const TextStyle(color: AppColors.olive, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 25),
          const Text(
            'My Service Overview',
            style: TextStyle(color: AppColors.text, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(
                child: statCard(
                  'Approved Hours',
                  '${approvedHours.toStringAsFixed(2)} hrs',
                  Icons.verified_outlined,
                  AppColors.olive,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: statCard(
                  'My Reservations',
                  '${reservations.length}',
                  Icons.bookmark_border,
                  AppColors.clay,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          SizedBox(
            width: 240,
            child: statCard('Pending Submissions', '$pending', Icons.pending_actions_outlined, AppColors.gold),
          ),
          const SizedBox(height: 25),
          const Text(
            'Recent Available Activities',
            style: TextStyle(color: AppColors.text, fontSize: 17, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ...activities.take(3).map(studentActivityCard),
        ],
      ),
    );
  }

  Widget buildActivities() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          sectionTitle('Available Activities', 'Browse community service opportunities.'),
          const SizedBox(height: 20),
          if (activities.isEmpty) emptyState('No activities are currently available.'),
          ...activities.map(studentActivityCard),
        ],
      ),
    );
  }

  Widget studentActivityCard(Map<String, dynamic> activity) {
    final activityId = numberValue(activity['id']);
    final alreadyReserved = reservations.any(
      (reservation) => numberValue(reservation['activity_id']) == activityId,
    );
    final slots = activity['remaining_slots'] == null
        ? numberValue(activity['capacity'])
        : numberValue(activity['remaining_slots']);
    final available = activity['status'] == 'available' && slots > 0;
    final canReserve = available && !alreadyReserved;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  activity['title']?.toString() ?? '',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.text),
                ),
              ),
              statusBadge(alreadyReserved ? 'reserved' : activity['status']?.toString() ?? ''),
            ],
          ),
          const SizedBox(height: 11),
          Text(activity['category']?.toString() ?? '', style: const TextStyle(fontSize: 11, color: AppColors.olive)),
          const SizedBox(height: 5),
          Text('Location: ${activity['location'] ?? '-'}', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
          const SizedBox(height: 5),
          Text('Date: ${formatDate(activity['activity_date'])}', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
          const SizedBox(height: 5),
          Text('Estimated Hours: ${activity['estimated_hours'] ?? '-'}', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
          const SizedBox(height: 5),
          Text('Available Slots: $slots', style: const TextStyle(fontSize: 12, color: AppColors.olive)),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: canReserve ? () => reserveActivity(activity) : null,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.forest,
                side: const BorderSide(color: AppColors.sage),
              ),
              child: Text(
                alreadyReserved
                    ? 'Already Reserved'
                    : slots <= 0
                        ? 'Fully Reserved'
                        : activity['status'] == 'approved'
                            ? 'Completed'
                            : 'Reserve Activity',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildReservations() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          sectionTitle('My Reservations', 'Track activities you have reserved.'),
          const SizedBox(height: 20),
          if (reservations.isEmpty) emptyState('You have not reserved any activities yet.'),
          ...reservations.map((reservation) {
            final activity = reservation['activity'] is Map
                ? reservation['activity'] as Map
                : <dynamic, dynamic>{};
            final records = serviceHours.where(
              (record) => numberValue(record['reservation_id']) == numberValue(reservation['id']),
            );
            final hasRecord = records.isNotEmpty;
            final approval = hasRecord ? records.first['approval_status']?.toString() : null;
            final reservationStatus = reservation['status']?.toString() ?? '';
            final canSubmit = reservationStatus == 'reserved' || reservationStatus == 'completed';

            return Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(17),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    activity['title']?.toString() ?? 'Activity',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.text),
                  ),
                  const SizedBox(height: 9),
                  Text('Reservation ID: ${reservation['id']}', style: const TextStyle(color: AppColors.muted, fontSize: 11)),
                  const SizedBox(height: 8),
                  statusBadge(reservationStatus),
                  if (hasRecord) ...[
                    const SizedBox(height: 9),
                    const Text('Service-hour submission:', style: TextStyle(fontSize: 12)),
                    statusBadge(approval ?? 'pending'),
                  ],
                  if (canSubmit && (!hasRecord || approval == 'rejected')) ...[
                    const SizedBox(height: 13),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => submitHours(reservation),
                        icon: const Icon(Icons.schedule),
                        label: Text(approval == 'rejected' ? 'Resubmit Service Hours' : 'Submit Completed Hours'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.forest,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget buildServiceHours() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          sectionTitle('My Service Hours', 'Track the approval of your submitted hours.'),
          const SizedBox(height: 20),
          if (serviceHours.isEmpty) emptyState('No service-hour submissions yet.'),
          ...serviceHours.map((record) {
            final reservation = record['reservation'] is Map
                ? record['reservation'] as Map
                : <dynamic, dynamic>{};
            final activity = reservation['activity'] is Map
                ? reservation['activity'] as Map
                : <dynamic, dynamic>{};

            return Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 13),
              padding: const EdgeInsets.all(17),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    activity['title']?.toString() ?? 'Activity',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.text),
                  ),
                  const SizedBox(height: 8),
                  Text('Submitted Hours: ${record['hours']}'),
                  const SizedBox(height: 8),
                  Text(record['description']?.toString() ?? '', style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                  const SizedBox(height: 10),
                  statusBadge(record['approval_status']?.toString() ?? ''),
                  if (record['approval_status'] == 'rejected') ...[
                    const SizedBox(height: 10),
                    const Text(
                      'Your submission was rejected. You can resubmit it from My Reservations.',
                      style: TextStyle(color: AppColors.clay, fontSize: 11),
                    ),
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
