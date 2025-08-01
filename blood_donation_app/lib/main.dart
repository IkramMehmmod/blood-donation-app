import 'package:blood_donation_app/services/notification_service.dart';
import 'package:blood_donation_app/services/push_notification_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart'; // Add this import
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'services/theme_service.dart';
import 'services/encryption_service.dart';
import 'routes/app_routes.dart';
import 'theme/app_theme.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint('🔔 Background message received: ${message.notification?.title}');
  debugPrint('🔔 Background data: ${message.data}');

  await PushNotificationService.showBackgroundNotification(message);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('✅ Firebase initialized');

    // 🔒 SECURITY: Configure App Check with production providers
    try {
      // Temporarily disabled App Check for testing
      debugPrint('⚠️ App Check disabled for testing');
      debugPrint('📝 TODO: Re-enable App Check before production deployment');

      // Uncomment the lines below to enable App Check
      // if (kDebugMode) {
      //   // Development mode - temporarily disable App Check for easier testing
      //   debugPrint('⚠️ App Check disabled for development');
      //   debugPrint('📝 To enable: Add debug token to Firebase Console > App Check > Debug tokens');
      // } else {
      //   // Production mode - use production providers
      //   await FirebaseAppCheck.instance.activate(
      //     androidProvider: AndroidProvider.playIntegrity,
      //     appleProvider: AppleProvider.deviceCheck,
      //   );
      //   debugPrint('✅ Firebase App Check initialized (PRODUCTION MODE)');
      //   debugPrint('🔒 Using Play Integrity (Android) and DeviceCheck (iOS)');
      // }
    } catch (e) {
      debugPrint('⚠️ App Check initialization failed: $e');
      // Continue without App Check for now
      debugPrint(
          '⚠️ Continuing without App Check - this may cause permission issues');
    }

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // ✅ CRITICAL FIX: Create notification channel in main.dart
    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'blood_donation_high_importance',
      'Blood Donation Notifications',
      description:
          'High importance notifications for blood donation requests and responses',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      showBadge: true,
      enableLights: true,
      ledColor: Color(0xFFE53E3E),
    );

    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidImplementation != null) {
      await androidImplementation.createNotificationChannel(channel);
      debugPrint('✅ Notification channel created: ${channel.id}');
    }

    final encryptionService = EncryptionService();
    await encryptionService.initialize();
    debugPrint('✅ Encryption service initialized');

    final token = await FirebaseMessaging.instance.getToken();
    debugPrint('📱 FCM Token: $token');
  } catch (e) {
    debugPrint('❌ Initialization error: $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final PushNotificationService _pushNotificationService =
      PushNotificationService();

  @override
  void initState() {
    super.initState();
    _setupNotificationHandling();
    _pushNotificationService.initialize();
  }

  void _setupNotificationHandling() {
    _pushNotificationService.onNotificationOpened = (type, referenceId) async {
      debugPrint(
          '📱 Notification opened - Type: $type, Reference: $referenceId');
      if (referenceId != null && referenceId.isNotEmpty) {
        // Fetch the request document from Firestore
        final doc = await FirebaseFirestore.instance
            .collection('requests')
            .doc(referenceId)
            .get();
        if (doc.exists) {
          final data = doc.data()!;
          final encryptionService = EncryptionService();
          final requesterId = data['requesterId'] ?? '';
          // Decrypt sensitive fields
          final patientName = await encryptionService.decryptWithUserKey(
              data['patientName'] ?? '', requesterId);
          final bloodGroup = data['bloodGroup'] ?? '';
          final hospital = await encryptionService.decryptWithUserKey(
              data['hospital'] ?? '', requesterId);
          final location = await encryptionService.decryptWithUserKey(
              data['location'] ?? '', requesterId);
          final contactNumber = data['contactNumber'] ?? '';
          // Show the details (replace with your own navigation/dialog logic)
          showDialog(
            context: navigatorKey.currentContext!,
            builder: (context) => AlertDialog(
              title: Text('Blood Request Details'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Patient: $patientName'),
                  Text('Blood Group: $bloodGroup'),
                  Text('Hospital: $hospital'),
                  Text('Location: $location'),
                  Text('Contact: $contactNumber'),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Close'),
                ),
              ],
            ),
          );
        } else {
          // Show error if request not found
          showDialog(
            context: navigatorKey.currentContext!,
            builder: (context) => AlertDialog(
              title: Text('Request Not Found'),
              content: Text('The blood request could not be found.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Close'),
                ),
              ],
            ),
          );
        }
      }
    };
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeService()),
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => NotificationService()),
      ],
      child: Consumer<ThemeService>(
        builder: (context, themeService, child) {
          return MaterialApp(
            title: 'Blood Donation App',
            debugShowCheckedModeBanner: false,
            navigatorKey: navigatorKey,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeService.themeMode,
            initialRoute: AppRoutes.splash,
            onGenerateRoute: AppRoutes.generateRoute,
            onUnknownRoute: (settings) {
              return MaterialPageRoute(
                builder: (context) => Scaffold(
                  appBar: AppBar(title: const Text('Error')),
                  body: const Center(
                    child: Text('Page not found'),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
