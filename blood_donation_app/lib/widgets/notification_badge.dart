import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/notification_service.dart';
import '../services/auth_service.dart';

class NotificationBadge extends StatelessWidget {
  final Widget child;
  final Color badgeColor;
  final double badgeSize;
  final EdgeInsets padding;
  final Color badgeTextColor;

  const NotificationBadge(
      {super.key,
      required this.child,
      this.badgeColor = Colors.red,
      this.badgeSize = 10.0,
      this.padding = const EdgeInsets.only(top: 2.0, right: 2.0),
      this.badgeTextColor = Colors.white});

  @override
  Widget build(BuildContext context) {
    return Consumer2<NotificationService, AuthService>(
      builder: (context, notificationService, authService, _) {
        final currentUser = authService.currentUser;
        final notifications = notificationService.notifications;
        final requestCache = notificationService.requestCache;
        final currentUserId = currentUser?.id;
        // Only count unread notifications that are not for own requests
        final filteredUnreadCount = notifications.where((notification) {
          if (notification['isRead'] ?? false) return false;
          final referenceId = notification['referenceId']?.toString();
          if (referenceId == null || referenceId.isEmpty) return true;
          final request = requestCache[referenceId];
          if (request == null)
            return false; // Strict: hide if request not found
          final requesterId = request['requester_id'] ?? request['requesterId'];
          return requesterId != currentUserId;
        }).length;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            child,
            if (filteredUnreadCount > 0)
              Positioned(
                top: padding.top,
                right: padding.right,
                child: Container(
                  padding: const EdgeInsets.all(2.0),
                  decoration: BoxDecoration(
                    color: badgeColor,
                    shape: BoxShape.circle,
                  ),
                  constraints: BoxConstraints(
                    minWidth: badgeSize,
                    minHeight: badgeSize,
                  ),
                  child: Center(
                    child: Text(
                      filteredUnreadCount > 9 ? '9+' : '$filteredUnreadCount',
                      style: TextStyle(
                        color: badgeTextColor,
                        fontSize: badgeSize * 0.7,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
