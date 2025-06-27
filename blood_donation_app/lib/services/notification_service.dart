import 'package:flutter/foundation.dart';
import 'firebase_service.dart';
import '../models/user_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationService extends ChangeNotifier {
  final FirebaseService _firebaseService = FirebaseService();

  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = false;
  int _unreadCount = 0;

  // Maps for fast lookup
  Map<String, Map<String, dynamic>> _requestCache = {};
  Map<String, Map<String, dynamic>> _userCache = {};
  Map<String, Map<String, dynamic>> get requestCache => _requestCache;
  Map<String, Map<String, dynamic>> get userCache => _userCache;

  List<Map<String, dynamic>> get notifications => _notifications;
  bool get isLoading => _isLoading;
  int get unreadCount => _unreadCount;

  // Helper to batch fetch requests by IDs
  Future<void> _fetchRequestsByIds(List<String> requestIds) async {
    _requestCache.clear();
    if (requestIds.isEmpty) return;
    final firestore = _firebaseService.firestore;
    for (int i = 0; i < requestIds.length; i += 10) {
      final batch = requestIds.skip(i).take(10).toList();
      final querySnapshot = await firestore
          .collection('requests')
          .where(FieldPath.documentId, whereIn: batch)
          .get();
      for (var doc in querySnapshot.docs) {
        _requestCache[doc.id] = doc.data();
      }
    }
  }

  // Helper to batch fetch users by IDs
  Future<void> _fetchUsersByIds(List<String> userIds) async {
    _userCache.clear();
    if (userIds.isEmpty) return;
    final firestore = _firebaseService.firestore;
    for (int i = 0; i < userIds.length; i += 10) {
      final batch = userIds.skip(i).take(10).toList();
      final querySnapshot = await firestore
          .collection('users')
          .where(FieldPath.documentId, whereIn: batch)
          .get();
      for (var doc in querySnapshot.docs) {
        _userCache[doc.id] = doc.data();
      }
    }
  }

  // Initial load or manual refresh
  Future<void> fetchNotifications(String userId) async {
    try {
      _isLoading = true;
      notifyListeners();
      _notifications = await _firebaseService.getUserNotifications(userId);
      _unreadCount =
          _notifications.where((n) => !(n['isRead'] ?? false)).length;
      // Collect all referenceIds and userIds
      final requestIds = <String>{};
      final userIds = <String>{};
      for (final n in _notifications) {
        final refId = n['referenceId']?.toString();
        if (refId != null && refId.isNotEmpty) requestIds.add(refId);
        final data = n['data'] as Map<String, dynamic>?;
        if (data != null) {
          for (final key in ['requesterId', 'responderId', 'userId']) {
            final uid = data[key]?.toString();
            if (uid != null && uid.isNotEmpty) userIds.add(uid);
          }
        }
      }
      await _fetchRequestsByIds(requestIds.toList());
      await _fetchUsersByIds(userIds.toList());
      notifyListeners();
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
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) {
      final notifications = snapshot.docs.map((doc) {
        final n = doc.data();
        return {
          ...n,
          'id': doc.id,
        };
      }).toList();
      _notifications = notifications;
      _unreadCount = notifications.where((n) => !(n['isRead'] ?? false)).length;
      notifyListeners();
      return notifications;
    });
  }

  // Method to refresh notifications after accepting requests (can just call fetch)
  Future<void> refreshNotifications(String userId) async {
    await fetchNotifications(userId);
  }
}
