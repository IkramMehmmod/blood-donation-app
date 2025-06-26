import 'dart:math';
import 'package:flutter/foundation.dart';

class OTPService {
  static final OTPService _instance = OTPService._internal();
  factory OTPService() => _instance;
  OTPService._internal();

  // Generate a 6-digit OTP
  String generateOTP() {
    final random = Random();
    String otp = '';
    for (int i = 0; i < 6; i++) {
      otp += random.nextInt(10).toString();
    }
    return otp;
  }

  // Verify OTP (in a real app, this would be done server-side)
  bool verifyOTP(String inputOTP, String expectedOTP) {
    return inputOTP == expectedOTP;
  }

  // Send OTP via email (simulated)
  Future<bool> sendOTPEmail(String email, String otp) async {
    try {
      // Simulate API call delay
      await Future.delayed(const Duration(seconds: 2));

      debugPrint('OTP sent to $email: $otp');

      // In a real app, you would integrate with an email service
      // like SendGrid, Mailgun, or Firebase Functions

      return true;
    } catch (e) {
      debugPrint('Error sending OTP email: $e');
      return false;
    }
  }

  // Send OTP via SMS (simulated)
  Future<bool> sendOTPSMS(String phoneNumber, String otp) async {
    try {
      // Simulate API call delay
      await Future.delayed(const Duration(seconds: 1));

      debugPrint('OTP sent to $phoneNumber: $otp');

      // In a real app, you would integrate with an SMS service
      // like Twilio, AWS SNS, or Firebase Functions

      return true;
    } catch (e) {
      debugPrint('Error sending OTP SMS: $e');
      return false;
    }
  }
}
