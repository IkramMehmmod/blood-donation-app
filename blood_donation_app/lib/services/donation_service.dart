import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/donation_model.dart';
import '../services/auth_service.dart';

class DonationService extends ChangeNotifier {
  static final DonationService _instance = DonationService._internal();
  factory DonationService() => _instance;
  DonationService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Stream of user's donations
  Stream<List<DonationModel>> getUserDonations(String userId) {
    return _firestore
        .collection('donations')
        .where('userId', isEqualTo: userId)
        .orderBy('date', descending: true)
        .orderBy('__name__', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => DonationModel.fromJson(doc.data()))
            .toList());
  }

  // Get user's last donation
  Future<DonationModel?> getLastDonation(String userId) async {
    try {
      final querySnapshot = await _firestore
          .collection('donations')
          .where('userId', isEqualTo: userId)
          .orderBy('date', descending: true)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return DonationModel.fromJson(querySnapshot.docs.first.data());
      }
      return null;
    } catch (e) {
      debugPrint('Error getting last donation: $e');
      return null;
    }
  }

  // Create a new donation record
  Future<void> createDonation(DonationModel donation) async {
    try {
      await _firestore.collection('donations').add(donation.toJson());
      debugPrint('✅ Donation created successfully');
    } catch (e) {
      debugPrint('❌ Error creating donation: $e');
      rethrow;
    }
  }

  // Update user's last donation date when they accept a blood request
  Future<void> updateUserLastDonation(
      String userId, DateTime donationDate) async {
    try {
      // Update the user's lastDonation field
      await _firestore.collection('users').doc(userId).update({
        'lastDonation': Timestamp.fromDate(donationDate),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });

      debugPrint('✅ User last donation date updated: $donationDate');

      // Notify listeners that user data has changed
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error updating user last donation: $e');
      rethrow;
    }
  }

  // Check if user is eligible to donate based on last donation date (56 days = 8 weeks rule)
  bool isEligibleToDonate(DateTime? lastDonationDate) {
    if (lastDonationDate == null) {
      return true; // No previous donation, eligible
    }

    final now = DateTime.now();
    final canDonateDate = lastDonationDate.add(const Duration(days: 56));
    return now.isAfter(canDonateDate);
  }

  // Get days until next eligible donation (56 days = 8 weeks rule)
  int getDaysUntilEligible(DateTime? lastDonationDate) {
    if (lastDonationDate == null) {
      return 0; // Already eligible
    }

    final now = DateTime.now();
    final canDonateDate = lastDonationDate.add(const Duration(days: 56));
    if (now.isAfter(canDonateDate)) return 0;
    return canDonateDate.difference(now).inDays + 1;
  }

  // Get donation eligibility status
  String getDonationEligibilityStatus(DateTime? lastDonationDate) {
    if (isEligibleToDonate(lastDonationDate)) {
      return 'Available for donation';
    } else {
      final daysRemaining = getDaysUntilEligible(lastDonationDate);
      return 'Available in $daysRemaining days';
    }
  }

  // Get donation eligibility color
  int getDonationEligibilityColor(DateTime? lastDonationDate) {
    if (isEligibleToDonate(lastDonationDate)) {
      return 0xFF4CAF50; // Green
    } else {
      return 0xFFFF9800; // Orange
    }
  }

  // Handle blood request acceptance and update donation records
  Future<void> handleBloodRequestAcceptance({
    required String userId,
    required String requestId,
    required DateTime donationDate,
    required String bloodGroup,
    required String patientName,
    required String hospital,
    required String location,
    int units = 1,
  }) async {
    try {
      final user = AuthService().currentUser;
      // Create donation record
      final donation = DonationModel(
        userId: userId,
        bloodGroup: bloodGroup,
        units: units,
        date: donationDate,
        location: location,
        status: 'completed',
        requestId: requestId,
        patientName: patientName,
        hospital: hospital,
        requesterName: user?.name ?? '',
      );

      // Add donation to Firestore
      await createDonation(donation);

      // Update user's last donation date
      await updateUserLastDonation(userId, donationDate);

      debugPrint('✅ Blood request acceptance processed successfully');
    } catch (e) {
      debugPrint('❌ Error processing blood request acceptance: $e');
      rethrow;
    }
  }
}
