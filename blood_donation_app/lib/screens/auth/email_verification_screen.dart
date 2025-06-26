import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../theme/app_theme.dart';
import '../../widgets/custom_button.dart';
import '../../routes/app_routes.dart';
import '../../models/user_model.dart';
import '../../services/firebase_service.dart';

class EmailVerificationScreen extends StatefulWidget {
  final String email;
  final String name;
  final String phone;
  final String address;
  final String city;
  final String state;
  final String country;
  final String bloodGroup;
  final bool isDonor;
  final DateTime? lastDonation;
  // Add other user fields as needed

  const EmailVerificationScreen({
    super.key,
    required this.email,
    required this.name,
    required this.phone,
    required this.address,
    required this.city,
    required this.state,
    required this.country,
    required this.bloodGroup,
    required this.isDonor,
    this.lastDonation,
  });

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoading = false;
  bool _isResending = false;
  int _resendCountdown = 0;
  String? _errorMessage;
  String? _successMessage;

  @override
  void initState() {
    super.initState();
    debugPrint(
        'EmailVerificationScreen: initState for email: \\${widget.email}');
    _sendVerificationEmail();
    _startResendCountdown();
  }

  Future<void> _sendVerificationEmail() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });
    try {
      final user = _auth.currentUser;
      debugPrint('Attempting to send verification email to: \\${user?.email}');
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
        debugPrint('Verification email sent to: \\${user.email}');
        setState(() {
          _successMessage = 'Verification email sent to \\${widget.email}';
        });
        _startResendCountdown();
      } else {
        debugPrint(
            'User is null or already verified. user: \\${user?.email}, verified: \\${user?.emailVerified}');
      }
    } on FirebaseAuthException catch (e) {
      debugPrint('FirebaseAuthException: \\${e.code}');
      if (e.code == 'too-many-requests') {
        setState(() {
          _errorMessage =
              'Too many requests. Please wait a few minutes before trying again.';
        });
      } else if (e.code == 'network-request-failed') {
        setState(() {
          _errorMessage =
              'No internet connection. Please check your network and try again.';
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to send verification email: \\${e.message}';
        });
      }
    } catch (e) {
      debugPrint('Failed to send verification email: \\${e.toString()}');
      setState(() {
        _errorMessage = 'Failed to send verification email: \\${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _startResendCountdown() {
    setState(() {
      _resendCountdown = 60;
    });
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() {
        if (_resendCountdown > 0) _resendCountdown--;
      });
      return _resendCountdown > 0;
    });
  }

  Future<void> _checkEmailVerification() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });
    try {
      debugPrint(
          'Checking email verification for: \\${_auth.currentUser?.email}');
      await _auth.currentUser!.reload();
      final user = _auth.currentUser!;
      debugPrint('Reloaded user. Verified: \\${user.emailVerified}');
      if (user.emailVerified) {
        debugPrint('Email verified. Creating Firestore user...');
        // Create Firestore user here
        final userModel = UserModel(
          id: user.uid,
          email: widget.email,
          name: widget.name,
          phone: widget.phone,
          address: widget.address,
          city: widget.city,
          state: widget.state,
          country: widget.country,
          bloodGroup: widget.bloodGroup,
          isDonor: widget.isDonor,
          lastDonation: widget.lastDonation,
          imageUrl: '',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        // You may need to import and use your AuthService or FirebaseService here
        // For example:
        // await Provider.of<AuthService>(context, listen: false).createFirestoreUser(userModel);
        // Or, if you have a FirebaseService instance:
        // await FirebaseService().createUser(userModel);
        // For now, let's use FirebaseService directly:
        await FirebaseService().createUser(userModel);
        debugPrint('Firestore user created for: \\${userModel.email}');
        Navigator.pushNamedAndRemoveUntil(
            context, AppRoutes.home, (route) => false);
      } else {
        debugPrint('Email not verified yet.');
        setState(() {
          _errorMessage =
              'Email not verified yet. Please check your inbox and click the verification link.';
        });
      }
    } catch (e) {
      debugPrint('Failed to check email verification: \\${e.toString()}');
      setState(() {
        _errorMessage = 'Failed to check email verification: \\${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Email Verification'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),
            Icon(
              Icons.email_outlined,
              size: 80,
              color: AppTheme.primaryColor,
            ),
            const SizedBox(height: 24),
            Text(
              'Verify Your Email',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppTheme.textColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'We\'ve sent a verification email to:',
              style: TextStyle(
                fontSize: 16,
                color: AppTheme.textColor.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.primaryColor.withOpacity(0.3),
                ),
              ),
              child: Text(
                widget.email,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryColor,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.blue.withOpacity(0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Verification Steps:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildInstructionStep(
                      '1', 'Check your email inbox (and spam folder)'),
                  _buildInstructionStep(
                      '2', 'Click the verification link in the email'),
                  _buildInstructionStep('3',
                      'Return to this app and tap "I\'ve Verified My Email"'),
                ],
              ),
            ),
            const SizedBox(height: 32),
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (_successMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_outline,
                        color: Colors.green, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _successMessage!,
                        style: TextStyle(
                          color: Colors.green,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            CustomButton(
              onPressed: _isLoading ? null : _checkEmailVerification,
              text: _isLoading ? 'Checking...' : "I've Verified My Email",
              isLoading: _isLoading,
              backgroundColor: AppTheme.primaryColor,
              textColor: Colors.white,
            ),
            const SizedBox(height: 16),
            CustomButton(
              onPressed: _isResending || _resendCountdown > 0
                  ? null
                  : _sendVerificationEmail,
              text: _isResending
                  ? 'Resending...'
                  : _resendCountdown > 0
                      ? 'Resend in $_resendCountdown seconds'
                      : 'Resend Verification Email',
              isLoading: _isResending,
              backgroundColor: Colors.transparent,
              textColor: AppTheme.primaryColor,
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Already have an account? ',
                  style: TextStyle(
                    color: AppTheme.textColor.withOpacity(0.7),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      AppRoutes.login,
                      (route) => false,
                    );
                  },
                  child: Text(
                    'Sign In',
                    style: TextStyle(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructionStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: Colors.blue,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: AppTheme.textColor,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
