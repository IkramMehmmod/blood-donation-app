import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import 'firebase_service.dart';
import 'push_notification_service.dart';
import 'encryption_service.dart';
import 'admin_monitoring_service.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseService _firebaseService = FirebaseService();
  final PushNotificationService _pushNotificationService =
      PushNotificationService();
  final EncryptionService _encryptionService = EncryptionService();
  final AdminMonitoringService _adminMonitoring = AdminMonitoringService();

  UserModel? _currentUser;
  bool _isLoading = false;
  bool _isGuest = false;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isGuest => _isGuest;
  User? get firebaseUser => _auth.currentUser;

  AuthService() {
    _auth.authStateChanges().listen(_onAuthStateChanged);
  }

  Future<void> _onAuthStateChanged(User? firebaseUser) async {
    debugPrint('Auth state changed: ${firebaseUser?.email}');

    if (firebaseUser != null && !_isGuest) {
      // Temporarily disabled admin monitoring for testing
      // await _adminMonitoring.logAuthEvent('auth_state_changed',
      //     email: firebaseUser.email, severity: 'low');

      // Always try to load existing user first
      try {
        final existingUser = await _firebaseService.getUser(firebaseUser.uid);
        if (existingUser != null) {
          _currentUser = existingUser;
          debugPrint('Loaded existing user: ${existingUser.email}');

          // Log user loaded event
          // await _adminMonitoring.logUserProfileEvent('user_loaded', {
          //   'userId': existingUser.id,
          //   'email': existingUser.email,
          //   'isVerified': firebaseUser.emailVerified,
          // });
        } else {
          // Do NOT create Firestore user here anymore
          debugPrint('No Firestore user found for: ${firebaseUser.email}');

          // Log missing user event
          // await _adminMonitoring.logUserProfileEvent('user_not_found', {
          //   'email': firebaseUser.email,
          //   'isVerified': firebaseUser.emailVerified,
          // });
        }
      } catch (e) {
        debugPrint('Error loading user: ${e.toString()}');

        // Log error event
        // await _adminMonitoring.logErrorEvent('user_load_error', e.toString(), {
        //   'email': firebaseUser.email,
        // });
      }
    } else if (firebaseUser == null) {
      _currentUser = null;
      _isGuest = false;
      _encryptionService.clearCache();

      // Log logout event
      // await _adminMonitoring.logAuthEvent('user_logout');
    }
    notifyListeners();
  }

  Future<bool> signInAsGuest() async {
    try {
      _isLoading = true;
      notifyListeners();

      // Log guest login attempt
      // await _adminMonitoring.logAuthEvent('guest_login_attempt');

      // Create a guest user without Firebase Auth
      final guestUser = UserModel(
        id: 'guest_${DateTime.now().millisecondsSinceEpoch}',
        email: '',
        name: 'Guest User',
        phone: '',
        address: '',
        city: '',
        state: '',
        country: '',
        bloodGroup: '',
        isDonor: false,
        imageUrl: '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      _currentUser = guestUser;
      _isGuest = true;
      debugPrint('Guest login successful');

      // Log successful guest login
      // await _adminMonitoring.logAuthEvent('guest_login_success');
      return true;
    } catch (e) {
      debugPrint('Guest login error: $e');

      // Log guest login error
      // await _adminMonitoring
      //     .logErrorEvent('guest_login_error', e.toString(), {});
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> signUp(String email, String password, UserModel userData) async {
    try {
      _isLoading = true;
      notifyListeners();

      // Log signup attempt
      // await _adminMonitoring.logAuthEvent('signup_attempt', email: email);

      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user != null) {
        // Update user data with Firebase UID
        final updatedUserData = userData.copyWith(
          id: credential.user!.uid,
          email: email,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // Do NOT create Firestore user here
        // Only set local state
        _currentUser = updatedUserData;
        _isGuest = false;

        // Log successful signup
        // await _adminMonitoring.logAuthEvent('signup_success', email: email);
        // await _adminMonitoring.logUserProfileEvent('user_created', {
        //   'userId': credential.user!.uid,
        //   'email': email,
        //   'name': userData.name,
        // });

        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Sign up error: ${e.toString()}');

      // Log signup error
      // await _adminMonitoring.logErrorEvent('signup_error', e.toString(), {
      //   'email': email,
      // });
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> signIn(String email, String password) async {
    try {
      _isLoading = true;
      notifyListeners();

      // Log signin attempt
      // await _adminMonitoring.logAuthEvent('signin_attempt', email: email);

      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user != null) {
        final user = credential.user!;
        // Load existing user data
        final existingUser = await _firebaseService.getUser(user.uid);

        if (existingUser != null) {
          _currentUser = existingUser;
          debugPrint('Sign in - Existing user loaded: ${existingUser.email}');

          // Log successful signin
          // await _adminMonitoring.logAuthEvent('signin_success', email: email);
          // await _adminMonitoring.logUserProfileEvent('user_loaded', {
          //   'userId': user.uid,
          //   'email': email,
          //   'isVerified': user.emailVerified,
          // });
        } else {
          // Only create Firestore user if email is verified
          if (user.emailVerified) {
            debugPrint(
                'Sign in - No Firestore user found, but email is verified. Creating Firestore user.');
            final newUser = UserModel(
              id: user.uid,
              email: user.email ?? '',
              name: user.displayName ?? '',
              phone: '',
              address: '',
              city: '',
              state: '',
              country: '',
              bloodGroup: '',
              isDonor: false,
              imageUrl: user.photoURL ?? '',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );
            await _firebaseService.createUser(newUser);
            _currentUser = newUser;
            debugPrint(
                'Sign in - Firestore user created for: ${newUser.email}');

            // Log user creation during signin
            // await _adminMonitoring
            //     .logUserProfileEvent('user_created_during_signin', {
            //   'userId': user.uid,
            //   'email': email,
            // });
          } else {
            debugPrint(
                'Sign in - No Firestore user found and email is NOT verified.');

            // Log unverified email signin
            // await _adminMonitoring.logAuthEvent('signin_unverified_email',
            //     email: email);
          }
        }

        // Initialize push notifications if user data is available
        if (_currentUser != null) {
          await _pushNotificationService.initialize(_currentUser!);
        }

        _isGuest = false;
        return _currentUser != null;
      }
      return false;
    } catch (e) {
      debugPrint('Sign in error: ${e.toString()}');

      // Log signin error
      // await _adminMonitoring.logErrorEvent('signin_error', e.toString(), {
      //   'email': email,
      // });
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> resetPassword(String email) async {
    try {
      _isLoading = true;
      notifyListeners();

      // Log password reset attempt
      // await _adminMonitoring.logPasswordChangeEvent('password_reset_requested',
      //     email: email);

      await _auth.sendPasswordResetEmail(email: email);

      // Log successful password reset email
      // await _adminMonitoring.logPasswordChangeEvent('password_reset_email_sent',
      //     email: email);
      return true;
    } catch (e) {
      debugPrint('Reset password error: $e');

      // Log password reset error
      // await _adminMonitoring
      //     .logErrorEvent('password_reset_error', e.toString(), {
      //   'email': email,
      // });
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> changePassword(
      String currentPassword, String newPassword) async {
    try {
      _isLoading = true;
      notifyListeners();

      final user = _auth.currentUser;
      if (user == null) return false;

      // Re-authenticate user
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );

      await user.reauthenticateWithCredential(credential);

      // Update password
      await user.updatePassword(newPassword);
      return true;
    } catch (e) {
      debugPrint('Change password error: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    try {
      // Log signout attempt
      // await _adminMonitoring.logAuthEvent('signout_attempt',
      //     email: _currentUser?.email);

      await _auth.signOut();
      _currentUser = null;
      _isGuest = false;
      _encryptionService.clearCache();

      // Log successful signout
      // await _adminMonitoring.logAuthEvent('signout_success');
      notifyListeners();
    } catch (e) {
      debugPrint('Sign out error: $e');

      // Log signout error
      // await _adminMonitoring.logErrorEvent('signout_error', e.toString(), {});
    }
  }

  Future<bool> deleteAccount({String? password}) async {
    try {
      _isLoading = true;
      notifyListeners();

      if (_isGuest) {
        _currentUser = null;
        _isGuest = false;
        return true;
      }

      final user = _auth.currentUser;
      if (user == null) return false;

      // Log account deletion attempt
      // await _adminMonitoring.logUserProfileEvent('account_deletion_attempted', {
      //   'userId': user.uid,
      //   'email': user.email,
      // });

      // Re-authenticate if password is provided
      if (password != null && user.email != null) {
        try {
          final credential = EmailAuthProvider.credential(
            email: user.email!,
            password: password,
          );
          await user.reauthenticateWithCredential(credential);
        } catch (e) {
          debugPrint('Re-authentication failed: $e');
          return false;
        }
      }

      // Delete user data from Firestore first
      await _firebaseService.deleteUserDataCompletely(user.uid);

      // Delete the Firebase Auth user
      await user.delete();

      _currentUser = null;
      _isGuest = false;
      _encryptionService.clearCache();

      // Log successful account deletion
      // await _adminMonitoring.logUserProfileEvent('account_deleted', {
      //   'userId': user.uid,
      //   'email': user.email,
      // });

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Delete account error: $e');

      // Log account deletion error
      // await _adminMonitoring
      //     .logErrorEvent('account_deletion_error', e.toString(), {
      //   'userId': _auth.currentUser?.uid,
      //   'email': _auth.currentUser?.email,
      // });
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshCurrentUser() async {
    if (_auth.currentUser != null && !_isGuest) {
      final userData = await _firebaseService.getUser(_auth.currentUser!.uid);
      if (userData != null) {
        _currentUser = userData;
        debugPrint('User data refreshed: ${userData.email}');
        notifyListeners();
      }
    }
  }

  Future<void> updateCurrentUser(UserModel updatedUser) async {
    try {
      if (_isGuest) return;

      // Update in Firestore
      await _firebaseService.updateUser(updatedUser);

      // Update local state
      _currentUser = updatedUser;
      debugPrint('Current user updated: ${updatedUser.email}');
      notifyListeners();
    } catch (e) {
      debugPrint('Error updating current user: $e');
      rethrow;
    }
  }

  Future<void> initialize() async {
    try {
      // Wait for Firebase Auth to be ready
      await Future.delayed(const Duration(milliseconds: 100));

      final firebaseUser = _auth.currentUser;
      debugPrint('Initialize - Firebase user: ${firebaseUser?.email}');

      if (firebaseUser != null) {
        // Always load existing user data first
        final existingUser = await _firebaseService.getUser(firebaseUser.uid);
        if (existingUser != null) {
          _currentUser = existingUser;
          debugPrint(
              'Initialize - Existing user loaded: ${_currentUser?.email}');
        } else {
          debugPrint(
              'Initialize - No Firestore user found for: ${firebaseUser.email}');
        }
      } else {
        _currentUser = null;
        _isGuest = false;
        debugPrint('Initialize - No Firebase user found');
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error in initialize: ${e.toString()}');
      _currentUser = null;
      _isGuest = false;
      notifyListeners();
    }
  }

  bool get isEmailVerified {
    return _auth.currentUser?.emailVerified ?? false;
  }

  bool get isSignedIn {
    return _auth.currentUser != null;
  }
}
