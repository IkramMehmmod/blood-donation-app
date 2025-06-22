import 'package:blood_donation_app/screens/requests/accepted_requests_screen.dart';
import 'package:blood_donation_app/screens/settings/settings.dart';
import 'package:blood_donation_app/widgets/main_container.dart';
import 'package:flutter/material.dart';
import '../screens/splash_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/auth/forgot_password_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/donation/donation_screen.dart';
import '../screens/donation/doners_screens.dart';
import '../screens/requests/requests_screen.dart';
import '../screens/notifications/notifications_screen.dart';
import '../screens/health/health_screen.dart';
import '../screens/map/map_screen.dart';
import '../screens/health/update_health_screen.dart';
import '../screens/support/support_screen.dart';

class AppRoutes {
  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';
  static const String home = '/home';
  static const String profile = '/profile';
  static const String donation = '/donation';
  static const String donors = '/donors';
  static const String requests = '/requests';
  static const String notifications = '/notifications';
  static const String health = '/health';
  static const String settings = '/settings';
  static const String support = '/support';
  static const String map = '/map';
  static const String homeScreen = '/home-screen';
  static const String updateHealth = '/update-health';
  static const String acceptedScreen = '/accepted-screen';

  static Route<dynamic> generateRoute(RouteSettings routeSettings) {
    switch (routeSettings.name) {
      case splash:
        return MaterialPageRoute(builder: (_) => const SplashScreen());
      case login:
        return MaterialPageRoute(builder: (_) => const LoginScreen());
      case register:
        return MaterialPageRoute(builder: (_) => const RegisterScreen());
      case forgotPassword:
        return MaterialPageRoute(builder: (_) => const ForgotPasswordScreen());
      case home:
        return MaterialPageRoute(builder: (_) => const MainContainer());
      case profile:
        return MaterialPageRoute(builder: (_) => const ProfileScreen());
      case donation:
        return MaterialPageRoute(builder: (_) => const DonationScreen());
      case donors:
        return MaterialPageRoute(builder: (_) => const DonersScreen());
      case requests:
        return MaterialPageRoute(builder: (_) => const RequestsScreen());
      case notifications:
        return MaterialPageRoute(builder: (_) => NotificationsScreen());
      case health:
        return MaterialPageRoute(builder: (_) => const HealthScreen());
      case settings:
        return MaterialPageRoute(builder: (_) => const SettingsScreen());
      case support:
        return MaterialPageRoute(builder: (_) => const SupportScreen());
      case map:
        return MaterialPageRoute(builder: (_) => const MapScreen());
      case acceptedScreen:
        return MaterialPageRoute(
            builder: (_) => const AcceptedRequestsScreen());
      case updateHealth:
        return MaterialPageRoute(builder: (_) => const UpdateHealthScreen());
      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(
              child: Text('No route defined for ${routeSettings.name}'),
            ),
          ),
        );
    }
  }
}
