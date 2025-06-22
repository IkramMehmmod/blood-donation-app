import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/notification_service.dart';

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
    return Consumer<NotificationService>(
      builder: (context, notificationService, _) {
        final unreadCount = notificationService.unreadCount;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            child,
            if (unreadCount > 0)
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
                  child: unreadCount > 9
                      ? Center(
                          child: Text(
                            '9+',
                            style: TextStyle(
                              color: badgeTextColor,
                              fontSize: badgeSize * 0.7,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                      : unreadCount > 1
                          ? Center(
                              child: Text(
                                '$unreadCount',
                                style: TextStyle(
                                  color: badgeTextColor,
                                  fontSize: badgeSize * 0.7,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            )
                          : const SizedBox(),
                ),
              ),
          ],
        );
      },
    );
  }
}
