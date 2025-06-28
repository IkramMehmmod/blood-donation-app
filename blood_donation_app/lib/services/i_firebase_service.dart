import 'dart:io';
import '../models/user_model.dart';
import '../models/request_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

abstract class IFirebaseService {
  // Firestore getter
  FirebaseFirestore get firestore;

  // User methods
  Future<void> createUser(UserModel user);
  Future<UserModel?> getUser(String userId);
  Future<void> updateUser(UserModel user);
  Future<void> deleteUserData(String userId);
  Future<void> syncUserLastDonationDate(String userId);

  // Donation methods
  Future<List<dynamic>> getUserDonations(String userId);
  bool canUserDonate(DateTime? lastDonation);
  int getDaysUntilCanDonate(DateTime? lastDonation);
  Future<void> createDonationFromAcceptedRequest(
      String userId, RequestModel request);
  Future<Map<String, dynamic>> getUserDonationStats(String userId);

  // Request methods
  Future<void> addRequest(RequestModel request);
  Future<List<RequestModel>> getRequests();
  Future<List<RequestModel>> getUserRequests(String userId);
  Future<void> acceptRequest(String requestId, String userId);
  Future<void> closeRequest(String requestId);
  Future<void> closeExpiredRequests();
  Future<String?> getRequesterId(String requestId);
  Future<List<Map<String, dynamic>>> getResponderDetails(
      List<String> responderIds);

  // Notification methods
  Future<void> createNotification({
    required String userId,
    required String title,
    required String message,
    String? type,
    String? referenceId,
    Map<String, dynamic>? data,
  });

  // Health methods
  Future<Map<String, dynamic>?> getHealthData(String userId);
  Future<void> updateHealthData(String userId, Map<String, dynamic> healthData);

  // Settings methods
  Future<Map<String, dynamic>?> getUserSettings(String userId);
  Future<void> updateUserSettings(String userId, Map<String, dynamic> settings);

  // Utility methods
  Future<String?> uploadImageToCloudinary(File imageFile, String userId);
  Future<List<Map<String, dynamic>>> getFAQs();
  Future<void> submitBugReport({
    required String userId,
    required String title,
    required String description,
    String? deviceInfo,
    String? appVersion,
  });
}
