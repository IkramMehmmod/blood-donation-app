import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../routes/app_routes.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Defer the auth check to after the build is complete
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAuth();
    });
  }

  Future<void> _checkAuth() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);

      // Wait for Firebase Auth to initialize
      await authService.initialize();

      // Add a small delay to ensure auth state is properly set
      await Future.delayed(const Duration(milliseconds: 500));

      // Check if user is authenticated
      final currentUser = authService.currentUser;
      final firebaseUser = authService.firebaseUser;

      debugPrint('Current user: ${currentUser?.email}');
      debugPrint('Firebase user: ${firebaseUser?.email}');

      if (mounted) {
        if (currentUser != null && firebaseUser != null) {
          // User is authenticated, initialize notification service
          try {
            final notificationService =
                Provider.of<NotificationService>(context, listen: false);
            await notificationService.initialize(currentUser);
          } catch (e) {
            debugPrint('Error initializing notifications: $e');
          }

          // Navigate to home screen
          debugPrint('Navigating to home screen');
          Navigator.of(context).pushReplacementNamed(AppRoutes.home);
        } else {
          // User is not authenticated, go to login
          debugPrint('Navigating to login screen');
          Navigator.of(context).pushReplacementNamed(AppRoutes.login);
        }
      }
    } catch (e) {
      debugPrint('Error in _checkAuth: $e');
      if (mounted) {
        // On error, go to login screen
        Navigator.of(context).pushReplacementNamed(AppRoutes.login);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/logo.png',
              height: 150,
              width: 150,
            ),
            const SizedBox(height: 20),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
