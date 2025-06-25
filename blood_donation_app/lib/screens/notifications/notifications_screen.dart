import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/notification_service.dart';
import '../../services/auth_service.dart';
import '../../services/firebase_service.dart';
import '../../widgets/not_signed_in_message.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final Map<String, Map<String, dynamic>> _userCache = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadNotifications();
    });
  }

  Future<void> _loadNotifications() async {
    final user = Provider.of<AuthService>(context, listen: false).currentUser;
    if (user != null) {
      final notificationService =
          Provider.of<NotificationService>(context, listen: false);
      // Using fetchNotifications for initial load, while the Consumer will handle real-time updates via the stream
      await notificationService.fetchNotifications(user.id!);
    }
  }

  Future<Map<String, dynamic>?> _getUserData(String userId) async {
    if (_userCache.containsKey(userId)) {
      return _userCache[userId];
    }

    try {
      final user = await _firebaseService.getUser(userId);
      if (user != null) {
        final userData = {
          'name': user.name,
          'imageUrl': user.imageUrl,
          'phone': user.phone,
          'email': user.email,
        };
        _userCache[userId] = userData;
        return userData;
      }
    } catch (e) {
      debugPrint('Error fetching user data: $e');
    }
    return null;
  }

  String _formatNotificationDate(dynamic createdAt) {
    try {
      DateTime? dateTime;

      if (createdAt is Timestamp) {
        dateTime = createdAt.toDate();
      } else if (createdAt is int) {
        dateTime = DateTime.fromMillisecondsSinceEpoch(createdAt);
      } else if (createdAt is String) {
        dateTime = DateTime.parse(createdAt);
      } else if (createdAt is DateTime) {
        dateTime = createdAt;
      }

      if (dateTime != null) {
        final now = DateTime.now();
        final difference = now.difference(dateTime);

        if (difference.inDays > 0) {
          if (difference.inDays == 1) {
            return 'Yesterday';
          } else if (difference.inDays < 7) {
            return '${difference.inDays} days ago';
          } else {
            // Include year for dates older than a week
            return DateFormat('MMM d, yyyy').format(dateTime);
          }
        } else if (difference.inHours > 0) {
          return '${difference.inHours}h ago';
        } else if (difference.inMinutes > 0) {
          return '${difference.inMinutes}m ago';
        } else {
          return 'Just now';
        }
      }
    } catch (e) {
      debugPrint('Error parsing notification date: $e');
    }

    return 'Unknown date';
  }

  IconData _getNotificationIcon(dynamic type) {
    if (type == null) return Icons.medical_services;
    String typeStr = type.toString();

    switch (typeStr) {
      case 'donation':
        return Icons.favorite;
      case 'request':
      case 'blood_request':
        return Icons.medical_services;
      case 'message':
      case 'chat_message':
        return Icons.message;
      case 'response':
        return Icons.reply;
      default:
        return Icons.medical_services;
    }
  }

  void _handleNotificationTap(Map<String, dynamic> notification) {
    final type = notification['type']?.toString();
    if (type == null) return;

    if (type == 'donation') {
      Navigator.of(context).pushNamed('/donations');
    } else if (type == 'request' || type == 'blood_request') {
      Navigator.of(context).pushNamed('/requests');
    } else if (type == 'response') {
      Navigator.of(context).pushNamed('/accepted-requests');
    }
  }

  Widget _buildNotificationAvatar(Map<String, dynamic> notification) {
    final data = notification['data'] as Map<String, dynamic>?;
    final referenceId = notification['referenceId']?.toString();

    String? userId;
    if (data != null) {
      userId = data['requesterId']?.toString() ??
          data['responderId']?.toString() ??
          data['userId']?.toString();
    }
    userId ??= referenceId;

    if (userId == null) {
      return CircleAvatar(
        radius: 25,
        backgroundColor: Colors.red.withAlpha((255 * 0.1).round()),
        child: Icon(
          _getNotificationIcon(notification['type']),
          color: Colors.red,
          size: 24,
        ),
      );
    }

    return FutureBuilder<Map<String, dynamic>?>(
      future: _getUserData(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return CircleAvatar(
            radius: 25,
            backgroundColor: Colors.grey.withAlpha((255 * 0.1).round()),
            child: const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }

        final userData = snapshot.data;
        if (userData == null) {
          debugPrint(
              'User data missing for notification: ${notification['id'] ?? ''}');
          return CircleAvatar(
            radius: 25,
            backgroundColor: Colors.red.withAlpha((255 * 0.1).round()),
            child: Text(
              'U',
              style: const TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          );
        }
        final imageUrl = userData['imageUrl']?.toString() ?? '';
        final userName = userData['name']?.toString() ?? 'Unknown User';

        return CircleAvatar(
          radius: 25,
          backgroundColor: Colors.red.withAlpha((255 * 0.1).round()),
          backgroundImage:
              imageUrl.isNotEmpty && !imageUrl.contains('placeholder')
                  ? NetworkImage(imageUrl)
                  : null,
          child: imageUrl.isEmpty || imageUrl.contains('placeholder')
              ? Text(
                  userName.isNotEmpty ? userName[0].toUpperCase() : '?',
                  style: const TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                )
              : null,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = Provider.of<AuthService>(context).currentUser;
    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Notifications'),
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
        ),
        body: const NotSignedInMessage(
          message: 'Please sign in to view notifications',
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadNotifications,
          ),
        ],
      ),
      body: Consumer<NotificationService>(
        builder: (context, notificationService, child) {
          if (notificationService.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          // Use the stream for real-time updates to display notifications
          return StreamBuilder<List<Map<String, dynamic>>>(
            stream: notificationService.getNotificationsStream(
              Provider.of<AuthService>(context)
                  .currentUser!
                  .id!, // Ensure user is logged in
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              final notifications = snapshot.data ?? [];

              if (notifications.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.notifications_none,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No notifications',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'You\'ll see notifications here when you receive them',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                itemCount: notifications.length,
                itemBuilder: (context, index) {
                  final notification = notifications[index];
                  // Corrected from 'is_read' to 'isRead'
                  final isRead = notification['isRead'] ?? false;
                  // Corrected from 'created_at' to 'createdAt'
                  final formattedDate =
                      _formatNotificationDate(notification['createdAt']);

                  return Dismissible(
                    key:
                        Key(notification['id']?.toString() ?? index.toString()),
                    background: Container(
                      color: Colors.red,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    direction: DismissDirection.endToStart,
                    onDismissed: (direction) {
                      if (notification['id'] != null) {
                        notificationService
                            .deleteNotification(notification['id'].toString());
                      }
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: isRead
                            ? Colors.white
                            : Colors.red.withAlpha((255 * 0.05).round()),
                        border: Border(
                          bottom: BorderSide(color: Colors.grey.shade200),
                        ),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        leading: _buildNotificationAvatar(notification),
                        title: Text(
                          notification['title']?.toString() ?? 'Notification',
                          style: TextStyle(
                            fontWeight:
                                isRead ? FontWeight.normal : FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              notification['message']?.toString() ??
                                  notification['body']?.toString() ??
                                  '',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[700],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Text(
                                  formattedDate,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[500],
                                  ),
                                ),
                                const Spacer(),
                                if (!isRead)
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                        onTap: () {
                          if (!isRead && notification['id'] != null) {
                            notificationService
                                .markAsRead(notification['id'].toString());
                          }
                          _handleNotificationTap(notification);
                        },
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
