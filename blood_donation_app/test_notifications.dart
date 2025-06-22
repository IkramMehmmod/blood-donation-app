import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:convert';

// Test script for notifications
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp();

  print('🧪 Starting notification tests...');

  // Test 1: Check permissions
  final hasPermission = await Permission.notification.isGranted;
  print('🔔 Notification permission: $hasPermission');

  // Test 2: Get FCM token
  final token = await FirebaseMessaging.instance.getToken();
  print('📱 FCM Token: $token');

  // Test 3: Send local notification
  await testLocalNotification();

  // Test 4: Send FCM notification via Firestore
  await testFCMNotification();

  print('✅ All tests completed!');
}

Future<void> testLocalNotification() async {
  try {
    print('🧪 Testing local notification...');

    final FlutterLocalNotificationsPlugin localNotifications =
        FlutterLocalNotificationsPlugin();

    // Initialize local notifications
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await localNotifications.initialize(initializationSettings);

    // Create notification channel
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'blood_donation_high_importance',
      'Blood Donation Notifications',
      description: 'Test notifications',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        localNotifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidImplementation != null) {
      await androidImplementation.createNotificationChannel(channel);
    }

    // Show notification
    await localNotifications.show(
      999,
      'Test Notification 🩸',
      'This is a test notification from the test script!',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'blood_donation_high_importance',
          'Blood Donation Notifications',
          channelDescription: 'Test notification',
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          color: Color(0xFFE53E3E),
          playSound: true,
          enableVibration: true,
        ),
      ),
      payload: jsonEncode({'type': 'test', 'referenceId': '123'}),
    );

    print('✅ Local notification sent successfully!');
  } catch (e) {
    print('❌ Error sending local notification: $e');
  }
}

Future<void> testFCMNotification() async {
  try {
    print('🧪 Testing FCM notification...');

    // Create a test notification document in Firestore
    await FirebaseFirestore.instance.collection('test_notifications').add({
      'userId': 'test_user',
      'title': 'Test FCM Notification',
      'body': 'This is a test FCM notification from the test script!',
      'timestamp': FieldValue.serverTimestamp(),
    });

    print('✅ FCM notification document created in Firestore');
    print(
        '📝 Check Firebase Functions logs to see if the notification was sent');
  } catch (e) {
    print('❌ Error sending FCM notification: $e');
  }
}
