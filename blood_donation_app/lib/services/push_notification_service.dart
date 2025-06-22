import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:convert';
import '../models/user_model.dart';

class PushNotificationService {
  static final PushNotificationService _instance =
      PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  // ✅ FIXED: Define the exact same channel as Firebase Functions
  static const AndroidNotificationChannel _androidChannel =
      AndroidNotificationChannel(
    'blood_donation_high_importance', // ✅ Must match Firebase Functions exactly
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

  Function(String? type, String? referenceId)? onNotificationOpened;

  Future<void> initialize([UserModel? updatedUserData]) async {
    try {
      debugPrint('🔔 Initializing Push Notification Service...');

      // Step 1: Request runtime notification permissions
      final hasPermission = await _requestNotificationPermissions();
      if (!hasPermission) {
        debugPrint('❌ Notification permissions not granted');
        return;
      }

      // Step 2: Initialize flutter_local_notifications plugin
      await _initializeLocalNotifications();

      // Step 3: Request Firebase messaging specific permissions
      await _requestFirebaseMessagingPermission();

      // Step 4: Get and log the FCM device token
      final token = await FirebaseMessaging.instance.getToken();
      debugPrint('📱 FCM Token: $token');

      // Step 5: Store the FCM token in Firestore
      if (updatedUserData != null &&
          updatedUserData.id != null &&
          token != null) {
        await _storeFCMToken(updatedUserData.id!, token);
      }

      // Step 6: Set up Firebase Messaging message handlers
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpened);

      // Step 7: Check for initial message
      final initialMessage =
          await FirebaseMessaging.instance.getInitialMessage();
      if (initialMessage != null) {
        debugPrint(
            '📱 Initial message found: ${initialMessage.notification?.title}');
        _handleMessageOpened(initialMessage);
      }

      // Step 8: Subscribe to FCM topics
      if (updatedUserData != null && updatedUserData.id != null) {
        await subscribeToTopic('user_${updatedUserData.id}');

        if (updatedUserData.isDonor && updatedUserData.bloodGroup.isNotEmpty) {
          final bloodTopic =
              'blood_${updatedUserData.bloodGroup.replaceAll('+', 'pos').replaceAll('-', 'neg')}';
          await subscribeToTopic(bloodTopic);
        }
      }

      debugPrint('✅ Push notification service initialized successfully');
    } catch (e) {
      debugPrint('❌ Error initializing push notification service: $e');
    }
  }

  Future<void> _storeFCMToken(String userId, String token) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update({'fcmToken': token});
      debugPrint('✅ FCM token stored for user: $userId');
    } catch (e) {
      debugPrint('❌ Error storing FCM token: $e');
    }
  }

  Future<bool> _requestNotificationPermissions() async {
    try {
      debugPrint('🔔 Requesting notification permissions...');

      PermissionStatus status = await Permission.notification.status;
      debugPrint('🔔 Current notification permission status: $status');

      if (status.isDenied) {
        debugPrint('🔔 Requesting notification permission...');
        status = await Permission.notification.request();
        debugPrint('🔔 Permission request result: $status');
      }

      if (status.isGranted) {
        debugPrint('✅ Notification permission granted');
        return true;
      } else if (status.isPermanentlyDenied) {
        debugPrint('❌ Notification permission permanently denied');
        return false;
      } else {
        debugPrint('❌ Notification permission denied');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error requesting notification permissions: $e');
      return false;
    }
  }

  Future<void> _requestFirebaseMessagingPermission() async {
    try {
      debugPrint('🔔 Requesting Firebase messaging permissions...');

      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: true,
        provisional: false,
        sound: true,
      );

      debugPrint(
          '🔔 Firebase permission status: ${settings.authorizationStatus}');

      switch (settings.authorizationStatus) {
        case AuthorizationStatus.authorized:
          debugPrint('✅ Firebase messaging permission granted');
          break;
        case AuthorizationStatus.provisional:
          debugPrint('⚠️ Firebase messaging provisional permission granted');
          break;
        case AuthorizationStatus.denied:
          debugPrint('❌ Firebase messaging permission denied');
          break;
        case AuthorizationStatus.notDetermined:
          debugPrint('❓ Firebase messaging permission not determined');
          break;
      }
    } catch (e) {
      debugPrint('❌ Error requesting Firebase messaging permissions: $e');
    }
  }

  // ✅ FIXED: Proper channel creation and initialization
  Future<void> _initializeLocalNotifications() async {
    try {
      debugPrint('🔔 Initializing local notifications...');

      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const DarwinInitializationSettings initializationSettingsIOS =
          DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
        requestCriticalPermission: true,
      );

      const InitializationSettings initializationSettings =
          InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsIOS,
      );

      final bool? initialized = await _localNotifications.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      debugPrint('🔔 Local notifications initialized: $initialized');

      // ✅ CRITICAL FIX: Create the notification channel
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _localNotifications.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      if (androidImplementation != null) {
        // Create the exact same channel as Firebase Functions
        await androidImplementation.createNotificationChannel(_androidChannel);
        debugPrint(
            '✅ Android notification channel created: ${_androidChannel.id}');

        // Request notification permission for Android 13+
        final bool? notificationGranted =
            await androidImplementation.requestNotificationsPermission();
        debugPrint('🔔 Android notification permission: $notificationGranted');
      }
    } catch (e) {
      debugPrint('❌ Error initializing local notifications: $e');
    }
  }

  // ✅ FIXED: Proper foreground message handling with correct channel
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    debugPrint(
        '🔔 Foreground message received: ${message.notification?.title}');
    debugPrint('🔔 Foreground data: ${message.data}');

    final notification = message.notification;

    if (notification != null) {
      await _localNotifications.show(
        notification.hashCode,
        notification.title ?? 'Blood Donation App',
        notification.body ?? 'You have a new notification',
        NotificationDetails(
          android: AndroidNotificationDetails(
            _androidChannel.id, // ✅ Use the exact same channel ID
            _androidChannel.name,
            channelDescription: _androidChannel.description,
            icon: '@mipmap/ic_launcher',
            importance: Importance.max,
            priority: Priority.high,
            color: const Color(0xFFE53E3E),
            playSound: true,
            enableVibration: true,
            enableLights: true,
            ledColor: const Color(0xFFE53E3E),
            styleInformation: BigTextStyleInformation(
              notification.body ?? '',
              contentTitle: notification.title,
              summaryText: 'Blood Donation App',
            ),
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: jsonEncode(message.data),
      );
      debugPrint('✅ Foreground notification displayed');
    }
  }

  void _onNotificationTapped(NotificationResponse notificationResponse) {
    try {
      final payload = notificationResponse.payload;
      debugPrint('📱 Notification tapped with payload: $payload');

      if (payload != null) {
        try {
          final data = jsonDecode(payload) as Map<String, dynamic>;
          final type = data['type'] as String? ?? 'general';
          final referenceId = data['referenceId'] as String? ?? '';

          debugPrint('📱 Notification type: $type, referenceId: $referenceId');

          if (onNotificationOpened != null) {
            onNotificationOpened!(type, referenceId);
          } else {
            debugPrint('⚠️ onNotificationOpened callback is not set');
          }
        } catch (e) {
          debugPrint('❌ Error parsing notification payload: $e');
        }
      }
    } catch (e) {
      debugPrint('❌ Error handling notification tap: $e');
    }
  }

  void _handleMessageOpened(RemoteMessage message) {
    try {
      debugPrint('📱 Message opened: ${message.notification?.title}');
      debugPrint('📱 Message data: ${message.data}');

      final data = message.data;
      final type = data['type'] as String? ?? 'general';
      final referenceId = data['referenceId'] as String? ?? '';

      if (onNotificationOpened != null) {
        onNotificationOpened!(type, referenceId);
      }
    } catch (e) {
      debugPrint('❌ Error handling message opened: $e');
    }
  }

  // ✅ FIXED: Test notification with correct channel
  Future<void> sendTestNotification() async {
    try {
      debugPrint('🧪 Sending test notification...');

      final hasPermission = await Permission.notification.isGranted;
      if (!hasPermission) {
        debugPrint('❌ No notification permission for test');
        return;
      }

      const AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
        'blood_donation_high_importance', // ✅ Use the exact same channel ID
        'Blood Donation Notifications',
        channelDescription: 'Test notification',
        importance: Importance.max,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        color: Color(0xFFE53E3E),
        playSound: true,
        enableVibration: true,
        ticker: 'Test Notification',
      );

      const NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
      );

      await _localNotifications.show(
        999,
        'Test Notification 🩸',
        'This is a test notification to verify the system is working! Tap to test navigation.',
        platformChannelSpecifics,
        payload: jsonEncode({'type': 'test', 'referenceId': '123'}),
      );

      debugPrint('✅ Test notification sent');
    } catch (e) {
      debugPrint('❌ Error sending test notification: $e');
    }
  }

  // ✅ FIXED: Background notification with proper channel creation
  static Future<void> showBackgroundNotification(RemoteMessage message) async {
    try {
      debugPrint(
          '🔔 Showing background notification: ${message.notification?.title}');

      final FlutterLocalNotificationsPlugin localNotifications =
          FlutterLocalNotificationsPlugin();

      // ✅ CRITICAL: Create the channel in background isolate too
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          localNotifications.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      if (androidImplementation != null) {
        await androidImplementation.createNotificationChannel(_androidChannel);
      }

      final notification = message.notification;
      if (notification != null) {
        await localNotifications.show(
          notification.hashCode,
          notification.title ?? 'Blood Donation App',
          notification.body ?? 'You have a new notification',
          NotificationDetails(
            android: AndroidNotificationDetails(
              _androidChannel.id, // ✅ Use the exact same channel ID
              _androidChannel.name,
              channelDescription: _androidChannel.description,
              icon: '@mipmap/ic_launcher',
              importance: Importance.max,
              priority: Priority.high,
              color: const Color(0xFFE53E3E),
              playSound: true,
              enableVibration: true,
            ),
          ),
          payload: jsonEncode(message.data),
        );
        debugPrint('✅ Background notification displayed');
      }
    } catch (e) {
      debugPrint('❌ Error showing background notification: $e');
    }
  }

  Future<String?> getDeviceToken() async {
    try {
      return await FirebaseMessaging.instance.getToken();
    } catch (e) {
      debugPrint('❌ Error getting device token: $e');
      return null;
    }
  }

  Future<void> subscribeToTopic(String topic) async {
    try {
      await FirebaseMessaging.instance.subscribeToTopic(topic);
      debugPrint('✅ Subscribed to topic: $topic');
    } catch (e) {
      debugPrint('❌ Error subscribing to topic: $e');
    }
  }

  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await FirebaseMessaging.instance.unsubscribeFromTopic(topic);
      debugPrint('✅ Unsubscribed from topic: $topic');
    } catch (e) {
      debugPrint('❌ Error unsubscribing from topic: $e');
    }
  }
}
