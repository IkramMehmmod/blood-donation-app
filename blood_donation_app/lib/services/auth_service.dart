import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import 'firebase_service.dart';
import 'push_notification_service.dart';
import 'encryption_service.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseService _firebaseService = FirebaseService();
  final PushNotificationService _pushNotificationService =
      PushNotificationService();
  final EncryptionService _encryptionService = EncryptionService();

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
      // Always try to load existing user first
      try {
        final existingUser = await _firebaseService.getUser(firebaseUser.uid);
        if (existingUser != null) {
          _currentUser = existingUser;
          debugPrint('Loaded existing user: ${existingUser.email}');
        } else {
          // Only create if no document exists
          await _createUserDocumentIfNeeded(firebaseUser);
        }
      } catch (e) {
        debugPrint('Error loading or creating user: $e');
      }
    } else if (firebaseUser == null) {
      _currentUser = null;
      _isGuest = false;
      _encryptionService.clearCache();
    }
    notifyListeners();
  }

  Future<void> _createUserDocumentIfNeeded(User firebaseUser) async {
    try {
      debugPrint('Creating user document for: ${firebaseUser.uid}');

      // Create a new user document with basic info from Firebase Auth
      final newUser = UserModel(
        id: firebaseUser.uid,
        email: firebaseUser.email ?? '',
        name: firebaseUser.displayName ?? '',
        phone: '',
        address: '',
        city: '',
        state: '',
        country: '',
        bloodGroup: '',
        isDonor: false,
        imageUrl: firebaseUser.photoURL ?? '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Save to Firestore
      await _firebaseService.createUser(newUser);
      _currentUser = newUser;
      debugPrint('New user document created: ${newUser.email}');
    } catch (e) {
      debugPrint('Error creating user document: $e');
      _currentUser = null;
    }
  }

  Future<bool> signInAsGuest() async {
    try {
      _isLoading = true;
      notifyListeners();

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
      return true;
    } catch (e) {
      debugPrint('Guest login error: $e');
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

        // Create user document in Firestore
        await _firebaseService.createUser(updatedUserData);

        // Initialize push notifications
        await _pushNotificationService.initialize(updatedUserData);

        _currentUser = updatedUserData;
        _isGuest = false;
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Sign up error: $e');
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

      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user != null) {
        // Load existing user data - DON'T create new
        final existingUser =
            await _firebaseService.getUser(credential.user!.uid);

        if (existingUser != null) {
          _currentUser = existingUser;
          debugPrint('Sign in - Existing user loaded: ${existingUser.email}');
        } else {
          // Only create if absolutely no user document exists
          await _createUserDocumentIfNeeded(credential.user!);
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
      debugPrint('Sign in error: $e');
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

      await _auth.sendPasswordResetEmail(email: email);
      return true;
    } catch (e) {
      debugPrint('Reset password error: $e');
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
      _isLoading = true;
      notifyListeners();

      if (!_isGuest) {
        await _auth.signOut();
      }

      _currentUser = null;
      _isGuest = false;
      _encryptionService.clearCache();
    } catch (e) {
      debugPrint('Sign out error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
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
      return true;
    } catch (e) {
      debugPrint('Delete account error: $e');
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
          await _createUserDocumentIfNeeded(firebaseUser);
          debugPrint('Initialize - New user created: ${_currentUser?.email}');
        }
      } else {
        _currentUser = null;
        _isGuest = false;
        debugPrint('Initialize - No Firebase user found');
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error in initialize: $e');
      _currentUser = null;
      _isGuest = false;
      notifyListeners();
    }
  }
}
