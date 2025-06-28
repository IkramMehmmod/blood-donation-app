import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:blood_donation_app/services/auth_service.dart';
import 'package:blood_donation_app/services/notification_service.dart';
import 'package:blood_donation_app/services/firebase_service.dart';
// import 'package:blood_donation_app/models/notification_model.dart'; // Unused
// import 'package:blood_donation_app/models/donation_model.dart'; // Unused
import 'package:blood_donation_app/widgets/not_signed_in_message.dart';
import 'package:blood_donation_app/services/encryption_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final Map<String, Map<String, dynamic>> _userCache = {};
  final Map<String, Map<String, dynamic>> _decryptedRequestCache = {};
  final Set<String> _loadingRequests = {};

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    final user = context.read<AuthService>().currentUser;
    if (user != null) {
      final notificationService =
          Provider.of<NotificationService>(context, listen: false);
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

  Future<Map<String, dynamic>?> _fetchAndDecryptRequest(
      String referenceId) async {
    if (_decryptedRequestCache.containsKey(referenceId)) {
      return _decryptedRequestCache[referenceId];
    }
    if (_loadingRequests.contains(referenceId)) {
      // Already loading
      return null;
    }
    _loadingRequests.add(referenceId);
    try {
      final doc = await _firebaseService.firestore
          .collection('requests')
          .doc(referenceId)
          .get();
      if (doc.exists) {
        final data = doc.data()!;
        final requesterId = data['requesterId'] ?? data['requester_id'] ?? '';
        final encryptionService = EncryptionService();
        final patientName = await encryptionService.decryptWithUserKey(
            data['patientName'] ?? data['patient_name'] ?? '', requesterId);
        final bloodGroup = data['bloodGroup'] ?? data['blood_group'] ?? '';
        final hospital = await encryptionService.decryptWithUserKey(
            data['hospital'] ?? '', requesterId);
        final location = await encryptionService.decryptWithUserKey(
            data['location'] ?? '', requesterId);
        final contactNumber = await encryptionService.decryptWithUserKey(
            data['contactNumber'] ?? data['contact_number'] ?? '', requesterId);
        final decrypted = {
          'patientName': patientName,
          'bloodGroup': bloodGroup,
          'hospital': hospital,
          'location': location,
          'contactNumber': contactNumber,
        };
        _decryptedRequestCache[referenceId] = decrypted;
        return decrypted;
      }
    } catch (e) {
      debugPrint('Error fetching/decrypting request $referenceId: $e');
    } finally {
      _loadingRequests.remove(referenceId);
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

  Widget _buildNotificationAvatar(Map<String, dynamic> notification,
      Map<String, Map<String, dynamic>> userCache) {
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
    final userData = userCache[userId];
    if (userData == null) {
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
      backgroundImage: imageUrl.isNotEmpty && !imageUrl.contains('placeholder')
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
        body: SingleChildScrollView(
          padding: EdgeInsets.all(24),
          child: NotSignedInMessage(
            message: 'Please sign in to view notifications',
          ),
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
          final notifications = notificationService.notifications;
          final userCache = notificationService.userCache;
          final requestCache = notificationService.requestCache;
          final currentUserId = currentUser.id;
          final filteredNotifications = notifications.where((notification) {
            final referenceId = notification['referenceId']?.toString();
            if (referenceId == null || referenceId.isEmpty) {
              debugPrint(
                  '[NotificationFilter] Notification \\${notification['id']} has no referenceId, keeping.');
              return true; // No reference, show it
            }
            final request = requestCache[referenceId];
            if (request == null) {
              debugPrint(
                  '[NotificationFilter] Notification \\${notification['id']} references missing request $referenceId, hiding.');
              return false; // Strict: hide if request not found
            }
            final requesterId =
                request['requester_id'] ?? request['requesterId'];
            final isOwn = requesterId == currentUserId;
            debugPrint(
                '[NotificationFilter] Notification \\${notification['id']} for request $referenceId, requesterId: $requesterId, currentUser: $currentUserId, isOwn: $isOwn');
            return !isOwn;
          }).toList();
          if (filteredNotifications.isEmpty) {
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
                      fontWeight: FontWeight.w600,
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
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            itemCount: filteredNotifications.length,
            separatorBuilder: (context, index) => const SizedBox(height: 4),
            itemBuilder: (context, index) {
              final notification = filteredNotifications[index];
              final isRead = notification['isRead'] ?? false;
              final formattedDate =
                  _formatNotificationDate(notification['createdAt']);
              final type = notification['type']?.toString();
              final referenceId = notification['referenceId']?.toString();
              final isRequestType =
                  type == 'request' || type == 'blood_request';
              return AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                child: Dismissible(
                  key: Key(notification['id']?.toString() ?? index.toString()),
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
                  child: Card(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                    elevation: isRead ? 1 : 5,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      leading: Stack(
                        children: [
                          _buildNotificationAvatar(notification, userCache),
                          if (!isRead)
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                width: 14,
                                height: 14,
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                  border:
                                      Border.all(color: Colors.white, width: 2),
                                ),
                              ),
                            ),
                        ],
                      ),
                      title: Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text(
                          notification['title']?.toString() ?? 'Notification',
                          style: TextStyle(
                            fontWeight:
                                isRead ? FontWeight.normal : FontWeight.bold,
                            fontSize: 17,
                            color: isRead ? Colors.grey[800] : Colors.red[800],
                          ),
                        ),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: isRequestType && referenceId != null
                            ? _buildDecryptedNotificationSubtitle(
                                referenceId, formattedDate)
                            : Text(
                                notification['message']?.toString() ?? '',
                                style: TextStyle(
                                    fontSize: 14, color: Colors.grey[800]),
                              ),
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.chevron_right, color: Colors.grey[400]),
                          if (!isRead)
                            Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.red[100],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'NEW',
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ),
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
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildRequestNotificationSubtitle(
    Map<String, dynamic> notification,
    Map<String, dynamic>? request,
    String? currentUserId,
    String formattedDate,
  ) {
    final data = notification['data'] as Map<String, dynamic>?;
    final String? dataPatientName = data?['patientName']?.toString();
    final String? requestPatientName = request?['patientName']?.toString();
    final String patientName = (dataPatientName != null &&
            dataPatientName.trim().isNotEmpty)
        ? dataPatientName
        : ((requestPatientName != null && requestPatientName.trim().isNotEmpty)
            ? requestPatientName
            : 'Unknown');
    final String? dataBloodGroup = data?['bloodGroup']?.toString();
    final String? requestBloodGroup = request?['bloodGroup']?.toString();
    final String bloodGroup = (dataBloodGroup != null &&
            dataBloodGroup.trim().isNotEmpty)
        ? dataBloodGroup
        : ((requestBloodGroup != null && requestBloodGroup.trim().isNotEmpty)
            ? requestBloodGroup
            : 'Unknown');
    if (request == null) {
      return Text(
        'Request no longer available.',
        style: TextStyle(
            fontSize: 14, color: Colors.grey[700], fontStyle: FontStyle.italic),
      );
    }
    if (request['status'] == 'closed' || request['status'] == 'expired') {
      return Text(
        'This request has been closed by the user.',
        style: TextStyle(
            fontSize: 14, color: Colors.red[400], fontStyle: FontStyle.italic),
      );
    }
    if (currentUserId != null &&
        (request['responders'] as List?)?.contains(currentUserId) == true) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Text(
            'You have accepted this request.',
            style: TextStyle(
                fontSize: 14,
                color: Colors.green[700],
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.person, size: 16, color: Colors.red),
              const SizedBox(width: 4),
              Text(
                'Patient: ',
                style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w500),
              ),
              Text(
                patientName,
                style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[900],
                    fontWeight: FontWeight.bold),
              ),
            ],
          ),
          Row(
            children: [
              const Icon(Icons.bloodtype, size: 16, color: Colors.red),
              const SizedBox(width: 4),
              Text(
                'Blood Group: ',
                style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w500),
              ),
              Text(
                bloodGroup,
                style: TextStyle(
                    fontSize: 14,
                    color: Colors.red[700],
                    fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            formattedDate,
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),
        ],
      );
    }
    // Show normal message if open and not accepted
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 4),
        Text(
          notification['message']?.toString() ?? '',
          style: TextStyle(fontSize: 14, color: Colors.grey[800]),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            const Icon(Icons.person, size: 16, color: Colors.red),
            const SizedBox(width: 4),
            Text(
              'Patient: ',
              style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w500),
            ),
            Text(
              patientName,
              style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[900],
                  fontWeight: FontWeight.bold),
            ),
          ],
        ),
        Row(
          children: [
            const Icon(Icons.bloodtype, size: 16, color: Colors.red),
            const SizedBox(width: 4),
            Text(
              'Blood Group: ',
              style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w500),
            ),
            Text(
              bloodGroup,
              style: TextStyle(
                  fontSize: 14,
                  color: Colors.red[700],
                  fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          formattedDate,
          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
        ),
      ],
    );
  }

  Widget _buildDefaultNotificationSubtitle(
    Map<String, dynamic> notification,
    String formattedDate,
    bool isRead,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 4),
        Text(
          notification['message']?.toString() ?? '',
          style: TextStyle(fontSize: 14, color: Colors.grey[800]),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Text(
              formattedDate,
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
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
    );
  }

  Widget _buildDecryptedNotificationSubtitle(
      String? referenceId, String formattedDate) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: referenceId != null ? _fetchAndDecryptRequest(referenceId) : null,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 8),
              Text('Loading details...',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600])),
            ],
          );
        }
        final data = snapshot.data;
        final location =
            (data?['location']?.toString().trim().isNotEmpty ?? false)
                ? data!['location']
                : (data?['hospital']?.toString().trim().isNotEmpty ?? false)
                    ? data!['hospital']
                    : 'an unknown location';
        final bloodGroup =
            (data?['bloodGroup']?.toString().trim().isNotEmpty ?? false)
                ? data!['bloodGroup']
                : 'Unknown';
        final summary =
            'A patient in $location needs $bloodGroup blood. Can you help?';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(summary,
                style: TextStyle(fontSize: 15, color: Colors.grey[900])),
            SizedBox(height: 8),
            Text(formattedDate,
                style: TextStyle(fontSize: 12, color: Colors.grey[500])),
          ],
        );
      },
    );
  }
}
