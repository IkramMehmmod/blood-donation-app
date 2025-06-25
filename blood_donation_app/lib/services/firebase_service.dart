import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/user_model.dart';
import '../models/donation_model.dart';
import '../models/request_model.dart';

class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Cloudinary configuration
  static const String cloudinaryCloudName = 'dhqkxowj3';
  static const String cloudinaryUploadPreset = 'image_upload';
  static const String cloudinaryApiKey = '733145926891947';

  FirebaseFirestore get firestore => _firestore;
  FirebaseAuth get auth => _auth;

  // User Management
  Future<void> createUser(UserModel user) async {
    try {
      debugPrint('Creating user in Firestore: ${user.email}');

      final userData = user.toJson();
      userData['created_at'] = FieldValue.serverTimestamp();
      userData['updated_at'] = FieldValue.serverTimestamp();

      await _firestore.collection('users').doc(user.id).set(userData);
      debugPrint('User created successfully in Firestore');
    } catch (e) {
      debugPrint('Error creating user: $e');
      rethrow;
    }
  }

  Future<UserModel?> getUser(String userId) async {
    try {
      debugPrint('Getting user from Firestore: $userId');

      final doc = await _firestore.collection('users').doc(userId).get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        data['id'] = doc.id;

        final userData = UserModel.fromJson(data);
        debugPrint('User found in Firestore: ${userData.email}');
        return userData;
      } else {
        debugPrint('User document does not exist in Firestore');
        return null;
      }
    } catch (e) {
      debugPrint('Error getting user from Firestore: $e');
      return null;
    }
  }

  Future<void> updateUser(UserModel user) async {
    try {
      debugPrint('Updating user in Firestore: ${user.email}');

      final userData = user.toJson();
      userData['updated_at'] = FieldValue.serverTimestamp();
      userData.remove('created_at');

      await _firestore.collection('users').doc(user.id).update(userData);
      debugPrint('User updated successfully in Firestore');
    } catch (e) {
      debugPrint('Error updating user: $e');
      rethrow;
    }
  }

  // Enhanced Donation Management with Auto-Creation
  Future<void> addDonation(DonationModel donation) async {
    try {
      final donationData = donation.toJson();
      donationData['created_at'] = FieldValue.serverTimestamp();
      donationData['updated_at'] = FieldValue.serverTimestamp();

      await _firestore.collection('donations').add(donationData);
      debugPrint('Donation added successfully');
    } catch (e) {
      debugPrint('Error adding donation: $e');
      rethrow;
    }
  }

  // Create donation record when user accepts a request
  Future<void> createDonationFromAcceptedRequest(
      String userId, RequestModel request) async {
    try {
      // Create the donation document - Firestore will create the collection automatically
      final donationData = {
        'userId': userId,
        'bloodGroup': request.bloodGroup,
        'units': request.units,
        'date': FieldValue.serverTimestamp(),
        'location': request.hospital,
        'status': 'Completed',
        'requestId': request.id,
        'patientName': request.patientName,
        'hospital': request.hospital,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      };

      await _firestore.collection('donations').add(donationData);
      debugPrint('Donation record created for accepted request: ${request.id}');
    } catch (e) {
      debugPrint('Error creating donation from accepted request: $e');
      rethrow;
    }
  }

  // Check if user can donate (3 months rule)
  bool canUserDonate(DateTime? lastDonation) {
    if (lastDonation == null) return true;

    final now = DateTime.now();
    final threeMonthsAgo = DateTime(now.year, now.month - 3, now.day);

    return lastDonation.isBefore(threeMonthsAgo);
  }

  // Get days until user can donate again
  int getDaysUntilCanDonate(DateTime? lastDonation) {
    if (lastDonation == null) return 0;

    final now = DateTime.now();
    final canDonateDate =
        DateTime(lastDonation.year, lastDonation.month + 3, lastDonation.day);

    if (now.isAfter(canDonateDate)) return 0;

    return canDonateDate.difference(now).inDays + 1;
  }

  Future<List<DonationModel>> getUserDonations(String userId) async {
    try {
      final querySnapshot = await _firestore
          .collection('donations')
          .where('userId', isEqualTo: userId)
          .orderBy('date', descending: true)
          .get();

      List<DonationModel> donations = [];
      for (var doc in querySnapshot.docs) {
        try {
          final data = doc.data();

          // Handle Firestore Timestamp conversion
          DateTime donationDate;
          if (data['date'] is Timestamp) {
            donationDate = (data['date'] as Timestamp).toDate();
          } else {
            donationDate = DateTime.now(); // Fallback
          }

          final donation = DonationModel(
            id: doc.id,
            userId: data['userId'] ?? userId,
            bloodGroup: data['bloodGroup'] ?? 'Unknown',
            units: data['units'] ?? 1,
            date: donationDate,
            location: data['location'] ?? data['hospital'] ?? 'Unknown',
            status: data['status'] ?? 'Completed',
            requestId: data['requestId'],
            patientName: data['patientName'] ?? 'Unknown Patient',
            hospital:
                data['hospital'] ?? data['location'] ?? 'Unknown Hospital',
          );

          donations.add(donation);
        } catch (e) {
          debugPrint('Error processing donation ${doc.id}: $e');
        }
      }

      return donations;
    } catch (e) {
      debugPrint('Error getting user donations: $e');
      return [];
    }
  }

  Future<Map<String, int>> getUserDonationStats(String userId) async {
    try {
      final donations = await getUserDonations(userId);
      final totalDonations = donations.length; // Number of donations
      final totalUnits = donations.fold<int>(
          0, (sum, donation) => sum + donation.units); // Sum all units donated
      final livesSaved = totalUnits; // 1 unit = 1 life saved
      final points = totalUnits * 10; // 10 points per unit
      return {
        'totalDonations': totalDonations,
        'totalUnits': totalUnits,
        'livesSaved': livesSaved,
        'points': points,
      };
    } catch (e) {
      debugPrint('Error getting donation stats: $e');
      return {
        'totalDonations': 0,
        'totalUnits': 0,
        'livesSaved': 0,
        'points': 0,
      };
    }
  }

  // Request Management
  Future<void> addRequest(RequestModel request) async {
    try {
      final requestData = request.toJson();
      requestData['created_at'] = FieldValue.serverTimestamp();
      requestData['updated_at'] = FieldValue.serverTimestamp();

      await _firestore.collection('requests').add(requestData);
    } catch (e) {
      debugPrint('Error adding request: $e');
      rethrow;
    }
  }

  Future<List<RequestModel>> getRequests() async {
    try {
      final querySnapshot = await _firestore
          .collection('requests')
          .where('status', isEqualTo: 'open')
          .get();

      final docs = querySnapshot.docs;
      docs.sort((a, b) {
        final aTime = a.data()['created_at'] as Timestamp?;
        final bTime = b.data()['created_at'] as Timestamp?;
        if (aTime == null || bTime == null) return 0;
        return bTime.compareTo(aTime);
      });

      List<RequestModel> requests = [];
      final now = DateTime.now();

      for (var doc in docs) {
        try {
          final data = {...doc.data(), 'id': doc.id};
          final processedRequest = await _processRequestData(data);

          // Filter out expired requests (past required date)
          if (processedRequest.requiredDate.isBefore(now)) {
            // Auto-close expired requests
            await closeRequest(processedRequest.id!);
            continue;
          }

          requests.add(processedRequest);
        } catch (e) {
          debugPrint('Error processing request ${doc.id}: $e');
        }
      }

      return requests;
    } catch (e) {
      debugPrint('Error getting requests: $e');
      return [];
    }
  }

  Future<List<RequestModel>> getUserRequests(String userId) async {
    try {
      final querySnapshot = await _firestore
          .collection('requests')
          .where('requester_id', isEqualTo: userId)
          .get();

      final docs = querySnapshot.docs;
      docs.sort((a, b) {
        final aTime = a.data()['created_at'] as Timestamp?;
        final bTime = b.data()['created_at'] as Timestamp?;
        if (aTime == null || bTime == null) return 0;
        return bTime.compareTo(aTime);
      });

      List<RequestModel> requests = [];
      for (var doc in docs) {
        try {
          final data = {...doc.data(), 'id': doc.id};
          final processedRequest = await _processRequestData(data);
          requests.add(processedRequest);
        } catch (e) {
          debugPrint('Error processing request ${doc.id}: $e');
        }
      }

      return requests;
    } catch (e) {
      debugPrint('Error getting user requests: $e');
      return [];
    }
  }

  Future<List<RequestModel>> getAcceptedRequests(String userId) async {
    try {
      final querySnapshot = await _firestore
          .collection('requests')
          .where('responders', arrayContains: userId)
          .get();

      final docs = querySnapshot.docs;
      docs.sort((a, b) {
        final aTime = a.data()['created_at'] as Timestamp?;
        final bTime = b.data()['created_at'] as Timestamp?;
        if (aTime == null || bTime == null) return 0;
        return bTime.compareTo(aTime);
      });

      List<RequestModel> requests = [];
      for (var doc in docs) {
        try {
          final data = {...doc.data(), 'id': doc.id};
          final processedRequest = await _processRequestData(data);
          requests.add(processedRequest);
        } catch (e) {
          debugPrint('Error processing accepted request ${doc.id}: $e');
        }
      }

      return requests;
    } catch (e) {
      debugPrint('Error getting accepted requests: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getResponderDetails(
      List<String> responderIds) async {
    try {
      if (responderIds.isEmpty) return [];

      final List<Map<String, dynamic>> responders = [];

      for (int i = 0; i < responderIds.length; i += 10) {
        final batch = responderIds.skip(i).take(10).toList();

        final querySnapshot = await _firestore
            .collection('users')
            .where(FieldPath.documentId, whereIn: batch)
            .get();

        for (var doc in querySnapshot.docs) {
          try {
            final userData = doc.data();
            final user = UserModel.fromJson({
              'id': doc.id,
              ...userData,
            });

            responders.add({
              'id': user.id,
              'name': user.name,
              'phone': user.phone,
              'email': user.email,
            });
          } catch (e) {
            debugPrint('Error processing responder data: $e');
            responders.add({
              'id': doc.id,
              'name': doc['name'] ?? 'Unknown',
              'phone': doc['phone'] ?? null,
              'email': doc['email'] ?? 'Unknown',
            });
          }
        }
      }

      return responders;
    } catch (e) {
      debugPrint('Error getting responder details: $e');
      return [];
    }
  }

  Future<RequestModel> _processRequestData(Map<String, dynamic> data) async {
    try {
      debugPrint('Processing request data: ${data.keys.toList()}');

      data['requesterId'] = data['requesterId'] ?? data['requester_id'] ?? '';
      data['requesterName'] =
          data['requesterName'] ?? data['requester_name'] ?? '';
      data['patientName'] = data['patientName'] ?? data['patient_name'] ?? '';
      data['bloodGroup'] = data['bloodGroup'] ?? data['blood_group'] ?? '';
      data['contactNumber'] =
          data['contactNumber'] ?? data['contact_number'] ?? '';
      data['hospital'] = data['hospital'] ?? '';
      data['location'] = data['location'] ?? '';
      data['urgency'] = data['urgency'] ?? 'normal';
      data['status'] = data['status'] ?? 'open';
      data['additionalInfo'] =
          data['additionalInfo'] ?? data['additional_info'] ?? '';
      data['responders'] = data['responders'] ?? [];
      data['units'] = data['units'] ?? data['units_needed'] ?? 1;

      debugPrint('Processed requesterId: ${data['requesterId']}');

      return RequestModel.fromJson(data);
    } catch (e) {
      debugPrint('Error processing request data: $e');
      debugPrint('Data keys: ${data.keys.toList()}');
      debugPrint('Data values: $data');
      rethrow;
    }
  }

  Future<void> updateRequestStatus(String requestId, String status) async {
    try {
      await _firestore.collection('requests').doc(requestId).update({
        'status': status,
        'updated_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error updating request status: $e');
      rethrow;
    }
  }

  Future<void> addResponderToRequest(
      String requestId, String responderId) async {
    try {
      await _firestore.collection('requests').doc(requestId).update({
        'responders': FieldValue.arrayUnion([responderId]),
        'updated_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error adding responder to request: $e');
      rethrow;
    }
  }

  // Enhanced accept request with automatic donation creation
  Future<void> acceptRequest(String requestId, String userId) async {
    try {
      // Add user to responders array and update status
      await _firestore.collection('requests').doc(requestId).update({
        'responders': FieldValue.arrayUnion([userId]),
        'status': 'accepted',
        'updated_at': FieldValue.serverTimestamp(),
      });

      // Get the request details and create donation record
      final requestDoc =
          await _firestore.collection('requests').doc(requestId).get();
      if (requestDoc.exists) {
        final requestData = requestDoc.data()!;
        final request = await _processRequestData({
          'id': requestDoc.id,
          ...requestData,
        });

        // Create donation record automatically
        await createDonationFromAcceptedRequest(userId, request);
      }

      debugPrint('Request accepted and donation recorded for user: $userId');
    } catch (e) {
      debugPrint('Error accepting request: $e');
      rethrow;
    }
  }

  Future<String?> getRequesterId(String requestId) async {
    try {
      final doc = await _firestore.collection('requests').doc(requestId).get();
      if (doc.exists) {
        final data = doc.data();
        return data?['requester_id'] ?? data?['requesterId'];
      }
      return null;
    } catch (e) {
      debugPrint('Error getting requester ID: $e');
      return null;
    }
  }

  Future<void> closeRequest(String requestId) async {
    try {
      await _firestore.collection('requests').doc(requestId).update({
        'status': 'closed',
        'updated_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error closing request: $e');
      rethrow;
    }
  }

  Future<List<RequestModel>> getOpenRequests() async {
    return await getRequests();
  }

  Future<void> closeExpiredRequests() async {
    try {
      final now = DateTime.now();
      final expiredDate = now.subtract(const Duration(days: 30));

      final querySnapshot = await _firestore
          .collection('requests')
          .where('status', isEqualTo: 'open')
          .get();

      final expiredDocs = querySnapshot.docs.where((doc) {
        final createdAt = doc.data()['created_at'] as Timestamp?;
        if (createdAt == null) return false;
        return createdAt.toDate().isBefore(expiredDate);
      }).toList();

      for (var doc in expiredDocs) {
        await doc.reference.update({
          'status': 'expired',
          'updated_at': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      debugPrint('Error closing expired requests: $e');
      rethrow;
    }
  }

  // Notification Management
  // Notification Management Extensions
  Future<List<Map<String, dynamic>>> getUserNotifications(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('notifications')
          .where('userId',
              isEqualTo:
                  userId) // Make sure field name matches your Firestore documents
          .orderBy('createdAt', descending: true) // Field name for timestamp
          .limit(50) // Limit the number of notifications to fetch
          .get();
      return snapshot.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList();
    } catch (e) {
      debugPrint('Error getting user notifications: $e');
      rethrow; // Re-throw to allow NotificationService to catch and handle
    }
  }

  Future<void> markNotificationAsRead(String notificationId) async {
    try {
      await _firestore
          .collection('notifications')
          .doc(notificationId)
          .update({'isRead': true}); // Make sure field name matches Firestore
      debugPrint('Notification $notificationId marked as read.');
    } catch (e) {
      debugPrint('Error marking notification $notificationId as read: $e');
      rethrow;
    }
  }

  // NEW: Add this method to handle deleting notifications
  Future<void> deleteNotification(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).delete();
      debugPrint('Notification $notificationId deleted from Firestore.');
    } catch (e) {
      debugPrint(
          'Error deleting notification $notificationId from Firestore: $e');
      rethrow;
    }
  }

  Future<void> createNotification({
    // Renamed from addNotification to be more descriptive
    required String userId,
    required String title,
    required String message,
    String? type,
    String? referenceId,
    Map<String, dynamic>? data, // Ensure this parameter is present
  }) async {
    try {
      await _firestore.collection('notifications').add({
        'userId': userId,
        'title': title,
        'message': message,
        'type': type,
        'referenceId': referenceId,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
        // Add the 'data' field if it's not null
        if (data != null) 'data': data,
      });
      debugPrint('Notification added to Firestore for $userId');
    } catch (e) {
      debugPrint('Error creating notification in FirebaseService: $e');
      rethrow;
    }
  }

  // Image Upload to Cloudinary
  Future<String?> uploadImageToCloudinary(File imageFile, String userId) async {
    try {
      if (cloudinaryCloudName == 'your_cloud_name' ||
          cloudinaryUploadPreset == 'your_upload_preset') {
        debugPrint(
            'Cloudinary not configured properly. Please set up your credentials.');
        return null;
      }

      final uri = Uri.parse(
          'https://api.cloudinary.com/v1_1/$cloudinaryCloudName/image/upload');

      final request = http.MultipartRequest('POST', uri);
      request.fields['upload_preset'] = cloudinaryUploadPreset;
      request.fields['folder'] = 'blood_bridge/users/$userId';
      request.fields['public_id'] =
          'profile_${DateTime.now().millisecondsSinceEpoch}';

      request.files
          .add(await http.MultipartFile.fromPath('file', imageFile.path));

      final response = await request.send();

      if (response.statusCode == 200) {
        final responseData = await response.stream.bytesToString();
        final jsonData = json.decode(responseData);
        return jsonData['secure_url'];
      } else {
        final responseData = await response.stream.bytesToString();
        debugPrint(
            'Cloudinary upload failed with status: ${response.statusCode}');
        debugPrint('Response: $responseData');
        return null;
      }
    } catch (e) {
      debugPrint('Error uploading image to Cloudinary: $e');
      return null;
    }
  }

  // Device Token Management
  Future<void> saveDeviceToken(String userId, String token) async {
    try {
      await _firestore.collection('device_tokens').doc(userId).set({
        'token': token,
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error saving device token: $e');
      rethrow;
    }
  }

  Future<String?> getDeviceToken(String userId) async {
    try {
      final doc =
          await _firestore.collection('device_tokens').doc(userId).get();
      if (doc.exists) {
        return doc.data()?['token'];
      }
      return null;
    } catch (e) {
      debugPrint('Error getting device token: $e');
      return null;
    }
  }

  Future<void> removeDeviceToken(String userId) async {
    try {
      await _firestore.collection('device_tokens').doc(userId).delete();
    } catch (e) {
      debugPrint('Error removing device token: $e');
      rethrow;
    }
  }

  // Get donors
  Future<List<UserModel>> getDonors() async {
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .where('isDonor', isEqualTo: true)
          .get();

      List<UserModel> donors = [];
      for (var doc in querySnapshot.docs) {
        try {
          final data = {...doc.data(), 'id': doc.id};
          final user = UserModel.fromJson(data);
          donors.add(user);
        } catch (e) {
          debugPrint('Error processing donor ${doc.id}: $e');
        }
      }

      return donors;
    } catch (e) {
      debugPrint('Error getting donors: $e');
      return [];
    }
  }

  // FAQ Management
  Future<List<Map<String, dynamic>>> getFAQs() async {
    try {
      final querySnapshot =
          await _firestore.collection('faqs').orderBy('order').get();

      return querySnapshot.docs
          .map((doc) => {...doc.data(), 'id': doc.id})
          .toList();
    } catch (e) {
      debugPrint('Error getting FAQs: $e');
      return [];
    }
  }

  // Health Data Management
  Future<Map<String, dynamic>?> getHealthData(String userId) async {
    try {
      final doc = await _firestore.collection('healthData').doc(userId).get();
      if (doc.exists) {
        return {...doc.data()!, 'id': doc.id};
      }
      return null;
    } catch (e) {
      debugPrint('Error getting health data: $e');
      return null;
    }
  }

  Future<void> updateHealthData(
      String userId, Map<String, dynamic> healthData) async {
    try {
      healthData['updated_at'] = FieldValue.serverTimestamp();
      await _firestore.collection('healthData').doc(userId).set(
            healthData,
            SetOptions(merge: true),
          );
    } catch (e) {
      debugPrint('Error updating health data: $e');
      rethrow;
    }
  }

  // User Settings Management
  Future<Map<String, dynamic>?> getUserSettings(String userId) async {
    try {
      final doc =
          await _firestore.collection('user_settings').doc(userId).get();
      if (doc.exists) {
        return doc.data();
      }
      return null;
    } catch (e) {
      debugPrint('Error getting user settings: $e');
      return null;
    }
  }

  Future<void> updateUserSettings(
      String userId, Map<String, dynamic> settings) async {
    try {
      settings['updated_at'] = FieldValue.serverTimestamp();
      await _firestore.collection('user_settings').doc(userId).set(
            settings,
            SetOptions(merge: true),
          );
    } catch (e) {
      debugPrint('Error updating user settings: $e');
      rethrow;
    }
  }

  // User Data Management
  Future<void> deleteUserData(String userId) async {
    try {
      // Delete user document
      await _firestore.collection('users').doc(userId).delete();

      // Delete related data
      await _firestore.collection('user_settings').doc(userId).delete();
      await _firestore.collection('healthData').doc(userId).delete();
      await _firestore.collection('device_tokens').doc(userId).delete();

      // Delete user's donations
      final donationsQuery = await _firestore
          .collection('donations')
          .where('userId', isEqualTo: userId)
          .get();

      for (var doc in donationsQuery.docs) {
        await doc.reference.delete();
      }

      // Delete user's requests
      final requestsQuery = await _firestore
          .collection('requests')
          .where('requesterId', isEqualTo: userId)
          .get();

      for (var doc in requestsQuery.docs) {
        await doc.reference.delete();
      }

      // Delete user's notifications
      final notificationsQuery = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .get();

      for (var doc in notificationsQuery.docs) {
        await doc.reference.delete();
      }
    } catch (e) {
      debugPrint('Error deleting user data: $e');
      rethrow;
    }
  }

  // User Data Management
  // Complete user data deletion - removes ALL traces
  Future<void> deleteUserDataCompletely(String userId) async {
    try {
      debugPrint('Starting complete deletion for user: $userId');

      // Use batch operations for better performance and atomicity
      final batch = _firestore.batch();

      // 1. Delete user document
      batch.delete(_firestore.collection('users').doc(userId));

      // 2. Delete user settings
      batch.delete(_firestore.collection('user_settings').doc(userId));

      // 3. Delete health data
      batch.delete(_firestore.collection('healthData').doc(userId));

      // 4. Delete device tokens
      batch.delete(_firestore.collection('device_tokens').doc(userId));

      // Commit the batch for simple documents
      await batch.commit();

      // 5. Delete user's donations (query-based deletion)
      final donationsQuery = await _firestore
          .collection('donations')
          .where('userId', isEqualTo: userId)
          .get();

      for (var doc in donationsQuery.docs) {
        await doc.reference.delete();
      }
      debugPrint('Deleted ${donationsQuery.docs.length} donations');

      // 6. Delete user's requests (query-based deletion)
      final requestsQuery = await _firestore
          .collection('requests')
          .where('requester_id', isEqualTo: userId)
          .get();

      for (var doc in requestsQuery.docs) {
        await doc.reference.delete();
      }
      debugPrint('Deleted ${requestsQuery.docs.length} requests');

      // 7. Remove user from responders arrays in other requests
      final respondedRequestsQuery = await _firestore
          .collection('requests')
          .where('responders', arrayContains: userId)
          .get();

      for (var doc in respondedRequestsQuery.docs) {
        await doc.reference.update({
          'responders': FieldValue.arrayRemove([userId]),
          'updated_at': FieldValue.serverTimestamp(),
        });
      }
      debugPrint(
          'Removed user from ${respondedRequestsQuery.docs.length} responded requests');

      // 8. Delete user's notifications
      final notificationsQuery = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .get();

      for (var doc in notificationsQuery.docs) {
        await doc.reference.delete();
      }
      debugPrint('Deleted ${notificationsQuery.docs.length} notifications');

      // 9. Delete bug reports
      final bugReportsQuery = await _firestore
          .collection('bugReports')
          .where('userId', isEqualTo: userId)
          .get();

      for (var doc in bugReportsQuery.docs) {
        await doc.reference.delete();
      }
      debugPrint('Deleted ${bugReportsQuery.docs.length} bug reports');

      // 10. Delete any FCM tokens or subscriptions
      try {
        await _firestore.collection('fcm_tokens').doc(userId).delete();
      } catch (e) {
        debugPrint('No FCM token to delete: $e');
      }

      debugPrint('✅ Complete user data deletion successful for: $userId');
    } catch (e) {
      debugPrint('❌ Error in complete user data deletion: $e');
      rethrow;
    }
  }

  // Bug Report Management
  Future<void> submitBugReport({
    required String userId,
    required String title,
    required String description,
    String? deviceInfo,
    String? appVersion,
  }) async {
    try {
      await _firestore.collection('bugReports').add({
        'userId': userId,
        'title': title,
        'description': description,
        'device_info': deviceInfo,
        'app_version': appVersion,
        'status': 'open',
        'created_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error submitting bug report: $e');
      rethrow;
    }
  }

  // Get Current User
  Future<UserModel?> getCurrentUser() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        return await getUser(user.uid);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting current user: $e');
      return null;
    }
  }

  // Authentication Methods
  Future<UserModel?> signUp(
      String email, String password, UserModel userData) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user != null) {
        final updatedUserData = userData.copyWith(
          id: credential.user!.uid,
          email: email,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await createUser(updatedUserData);
        return updatedUserData;
      }
      return null;
    } catch (e) {
      debugPrint('Sign up error: $e');
      rethrow;
    }
  }

  Future<UserModel?> signIn(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user != null) {
        return await getUser(credential.user!.uid);
      }
      return null;
    } catch (e) {
      debugPrint('Sign in error: $e');
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      debugPrint('Sign out error: $e');
      rethrow;
    }
  }

  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      debugPrint('Reset password error: $e');
      rethrow;
    }
  }

  // Notification Management Extensions
  Future<List<Map<String, dynamic>>> getNotifications(String userId) async {
    try {
      return await getUserNotifications(userId);
    } catch (e) {
      debugPrint('Error getting notifications: $e');
      return [];
    }
  }

  Future<void> addNotification({
    required String userId,
    required String title,
    required String message,
    String? type,
    String? referenceId,
  }) async {
    try {
      await createNotification(
        userId: userId,
        title: title,
        message: message,
        type: type,
        referenceId: referenceId,
      );
    } catch (e) {
      debugPrint('Error adding notification: $e');
      rethrow;
    }
  }
}
