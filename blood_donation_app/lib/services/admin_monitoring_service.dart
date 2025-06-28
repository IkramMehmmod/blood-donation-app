import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminMonitoringService {
  static final AdminMonitoringService _instance =
      AdminMonitoringService._internal();
  factory AdminMonitoringService() => _instance;
  AdminMonitoringService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 🔒 SECURITY: Log security event for admin monitoring
  Future<void> logSecurityEvent(
    String eventType,
    Map<String, dynamic> details, {
    String severity = 'medium',
  }) async {
    try {
      final user = _auth.currentUser;
      final userId = user?.uid ?? 'anonymous';
      final email = user?.email ?? 'unknown';

      await _firestore.collection('security_events').add({
        'event': eventType,
        'userId': userId,
        'userEmail': email,
        'details': details,
        'severity': severity,
        'timestamp': FieldValue.serverTimestamp(),
        'platform': 'flutter_mobile',
        'appVersion': '1.0.0',
        'deviceInfo': {
          'platform': 'mobile',
          'timestamp': DateTime.now().toIso8601String(),
        },
      });

      debugPrint('🔒 Security event logged: $eventType for user $userId');
    } catch (e) {
      debugPrint('❌ Error logging security event: $e');
    }
  }

  // 🔒 SECURITY: Log authentication events
  Future<void> logAuthEvent(
    String eventType, {
    String? email,
    String? error,
    String severity = 'medium',
  }) async {
    await logSecurityEvent(
        eventType,
        {
          'email': email,
          'error': error,
          'ipAddress': 'unknown', // Would need to be passed from backend
          'userAgent': 'Flutter Mobile App',
        },
        severity: severity);
  }

  // 🔒 SECURITY: Log suspicious activity
  Future<void> logSuspiciousActivity(
    String activityType,
    Map<String, dynamic> details,
  ) async {
    await logSecurityEvent(
        'suspicious_activity',
        {
          'activityType': activityType,
          ...details,
        },
        severity: 'high');
  }

  // 🔒 SECURITY: Log rate limit violations
  Future<void> logRateLimitViolation(
    String action,
    int limit,
    int actual,
  ) async {
    await logSecurityEvent(
        'rate_limit_exceeded',
        {
          'action': action,
          'limit': limit,
          'actual': actual,
          'timestamp': DateTime.now().toIso8601String(),
        },
        severity: 'medium');
  }

  // 🔒 SECURITY: Log email verification events
  Future<void> logEmailVerificationEvent(
    String eventType,
    String email,
  ) async {
    await logSecurityEvent('email_verification', {
      'eventType': eventType,
      'email': email,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  // 🔒 SECURITY: Log password change events
  Future<void> logPasswordChangeEvent(
    String eventType, {
    String? email,
    String? error,
  }) async {
    await logSecurityEvent('password_change', {
      'eventType': eventType,
      'email': email,
      'error': error,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  // 🔒 SECURITY: Log blood request events
  Future<void> logBloodRequestEvent(
    String eventType,
    Map<String, dynamic> details,
  ) async {
    await logSecurityEvent('blood_request', {
      'eventType': eventType,
      ...details,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  // 🔒 SECURITY: Log donation events
  Future<void> logDonationEvent(
    String eventType,
    Map<String, dynamic> details,
  ) async {
    await logSecurityEvent('donation', {
      'eventType': eventType,
      ...details,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  // 🔒 SECURITY: Log notification events
  Future<void> logNotificationEvent(
    String eventType,
    Map<String, dynamic> details,
  ) async {
    await logSecurityEvent('notification', {
      'eventType': eventType,
      ...details,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  // 🔒 SECURITY: Log app check validation events
  Future<void> logAppCheckEvent(
    String eventType,
    Map<String, dynamic> details,
  ) async {
    await logSecurityEvent(
        'app_check',
        {
          'eventType': eventType,
          ...details,
          'timestamp': DateTime.now().toIso8601String(),
        },
        severity: 'high');
  }

  // 🔒 SECURITY: Log data access events
  Future<void> logDataAccessEvent(
    String collection,
    String operation,
    Map<String, dynamic> details,
  ) async {
    await logSecurityEvent('data_access', {
      'collection': collection,
      'operation': operation,
      ...details,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  // 🔒 SECURITY: Log error events
  Future<void> logErrorEvent(
    String errorType,
    String errorMessage,
    Map<String, dynamic> details,
  ) async {
    await logSecurityEvent(
        'error',
        {
          'errorType': errorType,
          'errorMessage': errorMessage,
          ...details,
          'timestamp': DateTime.now().toIso8601String(),
        },
        severity: 'high');
  }

  // 🔒 SECURITY: Log user profile events
  Future<void> logUserProfileEvent(
    String eventType,
    Map<String, dynamic> details,
  ) async {
    await logSecurityEvent('user_profile', {
      'eventType': eventType,
      ...details,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  // 🔒 SECURITY: Log system health events
  Future<void> logSystemHealthEvent(
    String eventType,
    Map<String, dynamic> details,
  ) async {
    await logSecurityEvent('system_health', {
      'eventType': eventType,
      ...details,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  // 🔒 SECURITY: Log performance events
  Future<void> logPerformanceEvent(
    String eventType,
    Map<String, dynamic> details,
  ) async {
    await logSecurityEvent('performance', {
      'eventType': eventType,
      ...details,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  // 🔒 SECURITY: Log feature usage events
  Future<void> logFeatureUsageEvent(
    String feature,
    Map<String, dynamic> details,
  ) async {
    await logSecurityEvent('feature_usage', {
      'feature': feature,
      ...details,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  // 🔒 SECURITY: Log location access events
  Future<void> logLocationEvent(
    String eventType,
    Map<String, dynamic> details,
  ) async {
    await logSecurityEvent('location_access', {
      'eventType': eventType,
      ...details,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  // 🔒 SECURITY: Log permission events
  Future<void> logPermissionEvent(
    String permission,
    String status,
    Map<String, dynamic> details,
  ) async {
    await logSecurityEvent('permission', {
      'permission': permission,
      'status': status,
      ...details,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  // 🔒 SECURITY: Log encryption events
  Future<void> logEncryptionEvent(
    String eventType,
    Map<String, dynamic> details,
  ) async {
    await logSecurityEvent(
        'encryption',
        {
          'eventType': eventType,
          ...details,
          'timestamp': DateTime.now().toIso8601String(),
        },
        severity: 'high');
  }

  // 🔒 SECURITY: Log session events
  Future<void> logSessionEvent(
    String eventType,
    Map<String, dynamic> details,
  ) async {
    await logSecurityEvent('session', {
      'eventType': eventType,
      ...details,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  // 🔒 SECURITY: Log API call events
  Future<void> logApiCallEvent(
    String endpoint,
    String method,
    Map<String, dynamic> details,
  ) async {
    await logSecurityEvent('api_call', {
      'endpoint': endpoint,
      'method': method,
      ...details,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  // 🔒 SECURITY: Log file access events
  Future<void> logFileAccessEvent(
    String eventType,
    Map<String, dynamic> details,
  ) async {
    await logSecurityEvent('file_access', {
      'eventType': eventType,
      ...details,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  // 🔒 SECURITY: Log network events
  Future<void> logNetworkEvent(
    String eventType,
    Map<String, dynamic> details,
  ) async {
    await logSecurityEvent('network', {
      'eventType': eventType,
      ...details,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  // 🔒 SECURITY: Log device events
  Future<void> logDeviceEvent(
    String eventType,
    Map<String, dynamic> details,
  ) async {
    await logSecurityEvent('device', {
      'eventType': eventType,
      ...details,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  // 🔒 SECURITY: Log privacy events
  Future<void> logPrivacyEvent(
    String eventType,
    Map<String, dynamic> details,
  ) async {
    await logSecurityEvent(
        'privacy',
        {
          'eventType': eventType,
          ...details,
          'timestamp': DateTime.now().toIso8601String(),
        },
        severity: 'high');
  }

  // 🔒 SECURITY: Log compliance events
  Future<void> logComplianceEvent(
    String complianceType,
    Map<String, dynamic> details,
  ) async {
    await logSecurityEvent(
        'compliance',
        {
          'complianceType': complianceType,
          ...details,
          'timestamp': DateTime.now().toIso8601String(),
        },
        severity: 'high');
  }
}
