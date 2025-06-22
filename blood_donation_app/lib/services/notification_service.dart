// import 'package:flutter/foundation.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'firebase_service.dart';
// import '../models/user_model.dart';

// class NotificationService extends ChangeNotifier {
//   final FirebaseService _firebaseService = FirebaseService();

//   List<Map<String, dynamic>> _notifications = [];
//   bool _isLoading = false;
//   int _unreadCount = 0;

//   List<Map<String, dynamic>> get notifications => _notifications;
//   bool get isLoading => _isLoading;
//   int get unreadCount => _unreadCount;

//   Future<void> fetchNotifications(String userId) async {
//     try {
//       _isLoading = true;
//       notifyListeners();

//       _notifications = await _firebaseService.getUserNotifications(userId);
//       _unreadCount =
//           _notifications.where((n) => !(n['is_read'] ?? false)).length;
//     } catch (e) {
//       debugPrint('Error fetching notifications: $e');
//     } finally {
//       _isLoading = false;
//       notifyListeners();
//     }
//   }

//   Future<void> markAsRead(String notificationId) async {
//     try {
//       await _firebaseService.markNotificationAsRead(notificationId);

//       // Update local state
//       final index = _notifications.indexWhere((n) => n['id'] == notificationId);
//       if (index != -1) {
//         _notifications[index]['is_read'] = true;
//         _unreadCount =
//             _notifications.where((n) => !(n['is_read'] ?? false)).length;
//         notifyListeners();
//       }
//     } catch (e) {
//       debugPrint('Error marking notification as read: $e');
//     }
//   }

//   Future<void> deleteNotification(String notificationId) async {
//     try {
//       await _firebaseService.deleteNotification(notificationId);

//       // Update local state
//       _notifications.removeWhere((n) => n['id'] == notificationId);
//       _unreadCount =
//           _notifications.where((n) => !(n['is_read'] ?? false)).length;
//       notifyListeners();
//     } catch (e) {
//       debugPrint('Error deleting notification: $e');
//     }
//   }

//   Future<void> sendNotification({
//     required String title,
//     required String content,
//     required String recipientId,
//     String? type,
//     String? referenceId,
//     Map<String, dynamic>? data,
//   }) async {
//     try {
//       await _firebaseService.createNotification(
//         userId: recipientId,
//         title: title,
//         message: content,
//         type: type,
//         referenceId: referenceId,
//         data: data,
//       );
//     } catch (e) {
//       debugPrint('Error sending notification: $e');
//       rethrow;
//     }
//   }

//   Future<void> initialize(UserModel? user) async {
//     if (user != null) {
//       await fetchNotifications(user.id!);
//     }
//   }

//   // Stream for real-time notifications
//   Stream<List<Map<String, dynamic>>> getNotificationsStream(String userId) {
//     return _firebaseService.firestore
//         .collection('notifications')
//         .where('user_id', isEqualTo: userId)
//         .orderBy('created_at', descending: true)
//         .limit(50)
//         .snapshots()
//         .map((snapshot) {
//       final notifications =
//           snapshot.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList();

//       // Update local state
//       _notifications = notifications;
//       _unreadCount =
//           notifications.where((n) => !(n['is_read'] ?? false)).length;
//       notifyListeners();

//       return notifications;
//     });
//   }

//   // Method to refresh notifications after accepting requests
//   Future<void> refreshNotifications(String userId) async {
//     await fetchNotifications(userId);
//   }
// }
import 'package:flutter/foundation.dart';
import 'firebase_service.dart';
import '../models/user_model.dart';

class NotificationService extends ChangeNotifier {
  final FirebaseService _firebaseService = FirebaseService();

  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = false;
  int _unreadCount = 0;

  List<Map<String, dynamic>> get notifications => _notifications;
  bool get isLoading => _isLoading;
  int get unreadCount => _unreadCount;

  // Initial load or manual refresh
  Future<void> fetchNotifications(String userId) async {
    try {
      _isLoading = true;
      notifyListeners();

      _notifications = await _firebaseService.getUserNotifications(userId);
      _unreadCount = _notifications
          .where((n) => !(n['isRead'] ?? false))
          .length; // Corrected field name to 'isRead'
    } catch (e) {
      debugPrint('Error fetching notifications: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      await _firebaseService.markNotificationAsRead(notificationId);

      // Update local state IMMEDIATELY for responsiveness
      final index = _notifications.indexWhere((n) => n['id'] == notificationId);
      if (index != -1) {
        // Ensure the field name matches Firestore document: 'isRead'
        // Accessing via `_notifications` directly, not `notificationService.notifications`
        if (!(_notifications[index]['isRead'] ?? false)) {
          // Only decrement if it was unread
          _unreadCount--;
        }
        _notifications[index]['isRead'] = true;
      }
      notifyListeners(); // Notify listeners after local state update
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
      rethrow;
    }
  }

  Future<void> deleteNotification(String notificationId) async {
    try {
      await _firebaseService.deleteNotification(notificationId);

      // Update local state
      // First, check if the notification was unread before removing it
      final notificationToDelete = _notifications.firstWhere(
        (n) => n['id'] == notificationId,
        orElse: () => {}, // Provide a default empty map if not found
      );

      if (!(notificationToDelete['isRead'] ?? true)) {
        // If it was unread, decrement count
        _unreadCount--;
      }
      _notifications.removeWhere((n) => n['id'] == notificationId);

      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting notification: $e');
      rethrow; // Re-throw to allow higher-level error handling if needed
    }
  }

  Future<void> sendNotification({
    required String title,
    required String content,
    required String recipientId,
    String? type,
    String? referenceId,
    Map<String, dynamic>? data, // Now passing the data map
  }) async {
    try {
      await _firebaseService.createNotification(
        userId: recipientId,
        title: title,
        message: content,
        type: type,
        referenceId: referenceId,
        data: data, // Pass the data map here
      );
    } catch (e) {
      debugPrint('Error sending notification: $e');
      rethrow;
    }
  }

  Future<void> initialize(UserModel? user) async {
    if (user != null) {
      // It's generally better to let the stream handle the initial load if you're using a stream for real-time updates.
      // However, if you explicitly want an initial fetch to populate immediately, you can keep this.
      // If you primarily rely on the stream in the UI, this call might be redundant.
      await fetchNotifications(user.id!);
    }
  }

  // Stream for real-time notifications
  Stream<List<Map<String, dynamic>>> getNotificationsStream(String userId) {
    return _firebaseService.firestore
        .collection('notifications')
        .where('userId',
            isEqualTo: userId) // Corrected from 'user_id' to 'userId'
        .orderBy('createdAt',
            descending: true) // Corrected from 'created_at' to 'createdAt'
        .limit(50) // Good to limit for performance
        .snapshots()
        .map((snapshot) {
      final notifications =
          snapshot.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList();

      // Update local state when stream data changes
      _notifications = notifications;
      _unreadCount = notifications
          .where((n) => !(n['isRead'] ?? false))
          .length; // Corrected field name to 'isRead'
      notifyListeners(); // Notify listeners after local state update
      return notifications;
    });
  }

  // Method to refresh notifications after accepting requests (can just call fetch)
  Future<void> refreshNotifications(String userId) async {
    await fetchNotifications(userId);
  }
}
