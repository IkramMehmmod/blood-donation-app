import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/notification_service.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_dropdown.dart';
import '../../widgets/custom_text_field.dart';
import '../../routes/app_routes.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  String _selectedBloodGroup = 'A+';
  bool _isDonor = false;
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  DateTime? _lastDonationDate;

  final List<String> _bloodGroups = [
    'A+',
    'A-',
    'B+',
    'B-',
    'AB+',
    'AB-',
    'O+',
    'O-'
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (_formKey.currentState!.validate()) {
      if (_passwordController.text != _confirmPasswordController.text) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Passwords do not match')),
        );
        return;
      }

      final user = UserModel(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        bloodGroup: _selectedBloodGroup,
        isDonor: _isDonor,
        address: '',
        city: '',
        state: '',
        country: '',
        imageUrl: '',
        lastDonation: null,
      );

      final authService = Provider.of<AuthService>(context, listen: false);
      final success = await authService.signUp(
        _emailController.text.trim(),
        _passwordController.text,
        user,
      );

      if (success && mounted) {
        // Initialize notification service
        final notificationService =
            Provider.of<NotificationService>(context, listen: false);
        await notificationService.initialize(authService.currentUser);

        // Navigate to home screen
        Navigator.of(context).pushReplacementNamed(AppRoutes.home);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Failed to register. Please try again.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Register'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Create Account',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                const Text(
                  'Please fill in the form to continue',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 30),
                CustomTextField(
                  controller: _nameController,
                  labelText: 'Full Name',
                  hintText: 'Enter your full name',
                  prefixIcon: Icons.person,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 15),
                CustomTextField(
                  controller: _emailController,
                  labelText: 'Email',
                  hintText: 'Enter your email',
                  prefixIcon: Icons.email,
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your email';
                    }
                    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                        .hasMatch(value)) {
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 15),
                CustomTextField(
                  controller: _phoneController,
                  labelText: 'Phone Number',
                  hintText: 'Enter your phone number',
                  prefixIcon: Icons.phone,
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your phone number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 15),
                CustomDropdown(
                  labelText: 'Blood Group',
                  value: _selectedBloodGroup,
                  items: _bloodGroups.map((group) {
                    return DropdownMenuItem(
                      value: group,
                      child: Text(group),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedBloodGroup = value.toString();
                    });
                  },
                ),
                const SizedBox(height: 15),
                SwitchListTile(
                  title: const Text('I want to be a donor'),
                  value: _isDonor,
                  onChanged: (value) {
                    setState(() {
                      _isDonor = value;
                    });
                  },
                ),
                // Last donation date (only show if user is a donor)
                if (_isDonor) ...[
                  const SizedBox(height: 15),
                  InkWell(
                    onTap: () async {
                      final DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: _lastDonationDate ??
                            DateTime.now().subtract(const Duration(days: 90)),
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now(),
                        helpText: 'Select your last donation date',
                      );
                      if (picked != null) {
                        setState(() {
                          _lastDonationDate = picked;
                        });
                      }
                    },
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Last Donation Date (Optional)',
                        prefixIcon: const Icon(Icons.calendar_today),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        suffixIcon: _lastDonationDate != null
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  setState(() {
                                    _lastDonationDate = null;
                                  });
                                },
                              )
                            : null,
                      ),
                      child: Text(
                        _lastDonationDate != null
                            ? DateFormat('MMMM d, yyyy')
                                .format(_lastDonationDate!)
                            : 'Select your last donation date',
                        style: TextStyle(
                          color: _lastDonationDate != null
                              ? Colors.black
                              : Colors.grey[600],
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 15),
                CustomTextField(
                  controller: _passwordController,
                  labelText: 'Password',
                  hintText: 'Enter your password',
                  prefixIcon: Icons.lock,
                  obscureText: !_isPasswordVisible,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isPasswordVisible
                          ? Icons.visibility
                          : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        _isPasswordVisible = !_isPasswordVisible;
                      });
                    },
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your password';
                    }
                    if (value.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 15),
                CustomTextField(
                  controller: _confirmPasswordController,
                  labelText: 'Confirm Password',
                  hintText: 'Confirm your password',
                  prefixIcon: Icons.lock,
                  obscureText: !_isConfirmPasswordVisible,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isConfirmPasswordVisible
                          ? Icons.visibility
                          : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                      });
                    },
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please confirm your password';
                    }
                    if (value != _passwordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 25),
                CustomButton(
                  text: 'Register',
                  isLoading: authService.isLoading,
                  onPressed: _register,
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Already have an account?'),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context)
                            .pushReplacementNamed(AppRoutes.login);
                      },
                      child: const Text('Sign In'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
