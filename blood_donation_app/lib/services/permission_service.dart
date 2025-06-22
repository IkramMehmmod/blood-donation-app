import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  static final PermissionService _instance = PermissionService._internal();
  factory PermissionService() => _instance;
  PermissionService._internal();

  // Request notification permission with user-friendly dialog
  Future<bool> requestNotificationPermission(BuildContext context) async {
    try {
      // Check current status
      PermissionStatus status = await Permission.notification.status;

      if (status.isGranted) {
        debugPrint('✅ Notification permission already granted');
        return true;
      }

      if (status.isPermanentlyDenied) {
        // Show dialog to open settings
        return await _showSettingsDialog(context);
      }

      // Show explanation dialog before requesting permission
      final shouldRequest = await _showPermissionExplanationDialog(context);
      if (!shouldRequest) {
        return false;
      }

      // Request permission
      status = await Permission.notification.request();

      if (status.isGranted) {
        debugPrint('✅ Notification permission granted');
        return true;
      } else if (status.isPermanentlyDenied) {
        return await _showSettingsDialog(context);
      } else {
        debugPrint('❌ Notification permission denied');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error requesting notification permission: $e');
      return false;
    }
  }

  // Show explanation dialog before requesting permission
  Future<bool> _showPermissionExplanationDialog(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.notifications_active, color: Colors.blue),
                  SizedBox(width: 8),
                  Text('Enable Notifications'),
                ],
              ),
              content: const Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'To help save lives, we need to send you notifications about:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.bloodtype, color: Colors.red, size: 20),
                      SizedBox(width: 8),
                      Expanded(child: Text('Urgent blood requests near you')),
                    ],
                  ),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                          child: Text('When someone accepts your request')),
                    ],
                  ),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.schedule, color: Colors.orange, size: 20),
                      SizedBox(width: 8),
                      Expanded(child: Text('Donation reminders and updates')),
                    ],
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Your notifications help connect donors with patients in need.',
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Not Now'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Enable Notifications'),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  // Show dialog to open app settings
  Future<bool> _showSettingsDialog(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.settings, color: Colors.orange),
                  SizedBox(width: 8),
                  Text('Permission Required'),
                ],
              ),
              content: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Notifications are disabled for this app. To receive important blood donation alerts, please:',
                  ),
                  SizedBox(height: 16),
                  Row(
                    children: [
                      Text('1. '),
                      Expanded(child: Text('Open app settings')),
                    ],
                  ),
                  SizedBox(height: 4),
                  Row(
                    children: [
                      Text('2. '),
                      Expanded(child: Text('Enable notifications')),
                    ],
                  ),
                  SizedBox(height: 4),
                  Row(
                    children: [
                      Text('3. '),
                      Expanded(child: Text('Return to the app')),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.of(context).pop(true);
                    await openAppSettings();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Open Settings'),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  // Check if notification permission is granted
  Future<bool> isNotificationPermissionGranted() async {
    try {
      return await Permission.notification.isGranted;
    } catch (e) {
      debugPrint('❌ Error checking notification permission: $e');
      return false;
    }
  }

  // Get current permission status
  Future<PermissionStatus> getNotificationPermissionStatus() async {
    try {
      return await Permission.notification.status;
    } catch (e) {
      debugPrint('❌ Error getting notification permission status: $e');
      return PermissionStatus.denied;
    }
  }
}
