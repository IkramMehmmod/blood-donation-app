import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EncryptionService {
  static final EncryptionService _instance = EncryptionService._internal();
  factory EncryptionService() => _instance;
  EncryptionService._internal();

  static const String _localKeyName = 'local_encryption_key';
  static const String _localIvName = 'local_encryption_iv';
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Cache the encryption keys
  String? _localEncryptionKey;
  String? _localEncryptionIv;
  Map<String, String> _userKeyCache = {};

  // Track initialization state
  bool _isInitialized = false;

  // Initialize encryption keys
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Get or generate local key for device-level encryption
      _localEncryptionKey = await _secureStorage.read(key: _localKeyName);
      if (_localEncryptionKey == null) {
        final key = encrypt.Key.fromSecureRandom(32);
        _localEncryptionKey = base64Encode(key.bytes);
        await _secureStorage.write(
            key: _localKeyName, value: _localEncryptionKey);
        debugPrint('Generated new local encryption key');
      }

      // Get or generate IV
      _localEncryptionIv = await _secureStorage.read(key: _localIvName);
      if (_localEncryptionIv == null) {
        final iv = encrypt.IV.fromSecureRandom(16);
        _localEncryptionIv = base64Encode(iv.bytes);
        await _secureStorage.write(
            key: _localIvName, value: _localEncryptionIv);
        debugPrint('Generated new local encryption IV');
      }

      _isInitialized = true;
      debugPrint('Encryption service initialized successfully');
    } catch (e) {
      debugPrint('Error initializing encryption keys: $e');
      rethrow;
    }
  }

  final Map<String, String> _userKeys = {};

  Future<void> getOrCreateUserKey(String userId) async {
    try {
      // Check if key exists in Firestore
      final doc = await FirebaseFirestore.instance
          .collection('encryption_keys')
          .doc(userId)
          .get();

      if (!doc.exists) {
        // Generate new key
        final key = _generateKey();
        await FirebaseFirestore.instance
            .collection('encryption_keys')
            .doc(userId)
            .set({
          'key': key,
          'created_at': FieldValue.serverTimestamp(),
        });
        _userKeys[userId] = key;
      } else {
        _userKeys[userId] = doc.data()?['key'];
      }
    } catch (e) {
      debugPrint('Error getting or creating user key: $e');
      rethrow;
    }
  }

  void clearCache() {
    _userKeys.clear();
  }

  String _generateKey() {
    // Generate a random 32-character key
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random.secure();
    return String.fromCharCodes(Iterable.generate(
        32, (_) => chars.codeUnitAt(random.nextInt(chars.length))));
  }

  // Get user's encryption key from Firestore
  Future<String?> getUserEncryptionKey(String userId) async {
    // Check cache first
    if (_userKeyCache.containsKey(userId)) {
      return _userKeyCache[userId];
    }

    try {
      final doc =
          await _firestore.collection('encryption_keys').doc(userId).get();

      if (!doc.exists) {
        debugPrint('No encryption key found for user: $userId');
        await _generateAndStoreUserKey(userId);

        // Fetch the newly created key
        final newDoc =
            await _firestore.collection('encryption_keys').doc(userId).get();
        final key = newDoc.data()?['key'] as String?;

        if (key != null) {
          _userKeyCache[userId] = key;
        }

        return key;
      }

      final key = doc.data()?['key'] as String?;

      if (key != null) {
        _userKeyCache[userId] = key;
      }

      return key;
    } catch (e) {
      debugPrint('Error getting user encryption key: $e');
      return null;
    }
  }

  // Generate and store a new encryption key for a user
  Future<void> _generateAndStoreUserKey(String userId) async {
    try {
      // Generate a random encryption key
      final key = encrypt.Key.fromSecureRandom(32);
      final keyBase64 = base64Encode(key.bytes);

      // Store the key in Firestore with secure rules
      await _firestore.collection('encryption_keys').doc(userId).set({
        'key': keyBase64,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Update cache
      _userKeyCache[userId] = keyBase64;

      debugPrint('Generated and stored encryption key for user: $userId');
    } catch (e) {
      debugPrint('Error generating encryption key: $e');
      rethrow;
    }
  }

  // Encrypt data with user's key
  Future<String> encryptWithUserKey(String data, String userId) async {
    if (data.isEmpty) return data;

    try {
      // Ensure service is initialized
      if (!_isInitialized) {
        await initialize();
      }

      // Get user's encryption key
      final keyBase64 = await getUserEncryptionKey(userId);
      if (keyBase64 == null) {
        throw Exception('Encryption key not found for user: $userId');
      }

      // Create key and IV
      final key = encrypt.Key(base64Decode(keyBase64));
      final iv = encrypt.IV.fromSecureRandom(16);

      // Create encrypter
      final encrypter =
          encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.cbc));

      // Encrypt data
      final encrypted = encrypter.encrypt(data, iv: iv);

      // Return IV:encrypted format
      final result = '${base64Encode(iv.bytes)}:${encrypted.base64}';
      debugPrint('✅ Encryption successful');
      return result;
    } catch (e) {
      debugPrint('❌ Error encrypting data: $e');
      // Return original data if encryption fails
      return data;
    }
  }

  // Decrypt data with user's key
  Future<String> decryptWithUserKey(String encryptedData, String userId) async {
    if (encryptedData.isEmpty || !encryptedData.contains(':'))
      return encryptedData;

    try {
      debugPrint('🔐 Decrypting string with user key: $encryptedData');

      // Ensure service is initialized
      if (!_isInitialized) {
        await initialize();
      }

      // Get user's encryption key
      final keyBase64 = await getUserEncryptionKey(userId);
      if (keyBase64 == null) {
        throw Exception('Encryption key not found for user: $userId');
      }

      // Split the IV and encrypted data
      final parts = encryptedData.split(':');
      if (parts.length != 2) {
        debugPrint('❌ Invalid encrypted data format: Expected 2 parts');
        return encryptedData;
      }

      final ivBase64 = parts[0];
      final dataBase64 = parts[1];

      try {
        // Create key and IV
        final key = encrypt.Key(base64Decode(keyBase64));
        final iv = encrypt.IV(base64Decode(ivBase64));

        // Create encrypter
        final encrypter =
            encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.cbc));

        // Decrypt data
        final decrypted = encrypter.decrypt64(dataBase64, iv: iv);
        debugPrint('✅ Decryption successful');
        return decrypted;
      } catch (e) {
        debugPrint('❌ Error decrypting data: $e');
        // Return original data if decryption fails
        return encryptedData;
      }
    } catch (e) {
      debugPrint('❌ Error in decryption process: $e');
      // Return original data if decryption fails
      return encryptedData;
    }
  }

  // Encrypt data with local key (for device-level encryption)
  Future<String> encryptData(String data, String userId) async {
    if (data.isEmpty) return data;

    try {
      // Ensure service is initialized
      if (!_isInitialized) {
        await initialize();
      }

      // Create key and IV objects
      final keyBytes = base64Decode(_localEncryptionKey!);
      final ivBytes = base64Decode(_localEncryptionIv!);

      final key = encrypt.Key(keyBytes);
      final iv = encrypt.IV(ivBytes);

      // Create encrypter
      final encrypter =
          encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.cbc));

      // Encrypt data
      final encrypted = encrypter.encrypt(data, iv: iv);

      // Return IV:encrypted format
      final result = '${_localEncryptionIv}:${encrypted.base64}';
      debugPrint('✅ Local encryption successful');
      return result;
    } catch (e) {
      debugPrint('❌ Error encrypting data locally: $e');
      // Return original data if encryption fails
      return data;
    }
  }

  // Decrypt data with local key
  Future<String> decryptData(String encryptedData, [String? userId]) async {
    if (encryptedData.isEmpty || !encryptedData.contains(':'))
      return encryptedData;

    try {
      debugPrint('🔐 Decrypting string locally: $encryptedData');

      // Ensure service is initialized
      if (!_isInitialized) {
        await initialize();
      }

      // Split the IV and encrypted data
      final parts = encryptedData.split(':');
      if (parts.length != 2) {
        debugPrint('❌ Invalid encrypted data format: Expected 2 parts');
        return encryptedData;
      }

      final ivBase64 = parts[0];
      final dataBase64 = parts[1];

      try {
        // Create key and IV objects
        final keyBytes = base64Decode(_localEncryptionKey!);
        final ivBytes = base64Decode(ivBase64);

        final key = encrypt.Key(keyBytes);
        final iv = encrypt.IV(ivBytes);

        // Create encrypter
        final encrypter =
            encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.cbc));

        // Decrypt data
        final decrypted = encrypter.decrypt64(dataBase64, iv: iv);
        debugPrint('✅ Local decryption successful');
        return decrypted;
      } catch (e) {
        debugPrint('❌ Error decrypting data locally: $e');
        // Return original data if decryption fails
        return encryptedData;
      }
    } catch (e) {
      debugPrint('❌ Error in local decryption process: $e');
      // Return original data if decryption fails
      return encryptedData;
    }
  }

  // Check if a string is likely encrypted
  bool isEncrypted(String? data) {
    if (data == null || data.isEmpty) return false;

    // Check if the data is in the expected format (contains a colon)
    if (!data.contains(':')) {
      return false;
    }

    // Split the string and check if both parts are valid base64
    final parts = data.split(':');
    if (parts.length != 2) return false;

    try {
      // Try to decode both parts as base64
      base64Decode(parts[0]);
      base64Decode(parts[1]);
      return true;
    } catch (e) {
      return false;
    }
  }

  // Create a copy of a model with decrypted fields
  Future<Map<String, dynamic>> decryptFields(
      Map<String, dynamic> data, List<String> fieldsToDecrypt) async {
    // Create a copy of the original data
    final decryptedData = Map<String, dynamic>.from(data);

    // Get current user ID
    final user = _auth.currentUser;
    if (user == null) {
      debugPrint('No user logged in for decryption');
      return decryptedData;
    }

    // Decrypt each field if it's encrypted
    for (final field in fieldsToDecrypt) {
      if (data.containsKey(field) &&
          data[field] != null &&
          isEncrypted(data[field])) {
        try {
          decryptedData[field] =
              await decryptWithUserKey(data[field], user.uid);
        } catch (e) {
          debugPrint('Error decrypting field $field: $e');
          // Keep original value if decryption fails
        }
      }
    }

    return decryptedData;
  }

  // Rotate user's encryption key
  Future<bool> rotateUserEncryptionKey(String userId) async {
    try {
      // Get user data
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        debugPrint('User not found for key rotation');
        return false;
      }

      Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;

      // Get old encryption key
      final oldKeyDoc =
          await _firestore.collection('encryption_keys').doc(userId).get();
      if (!oldKeyDoc.exists) {
        debugPrint('No encryption key found for rotation');
        return false;
      }

      final oldKeyBase64 = oldKeyDoc.data()?['key'] as String?;
      if (oldKeyBase64 == null) {
        debugPrint('Invalid encryption key format');
        return false;
      }

      // Generate new encryption key
      final newKey = encrypt.Key.fromSecureRandom(32);
      final newKeyBase64 = base64Encode(newKey.bytes);

      // Fields to re-encrypt
      final fieldsToReEncrypt = [
        'phone',
        'address',
        'city',
        'state',
        'country'
      ];
      Map<String, dynamic> updates = {};

      // Re-encrypt each field
      for (final field in fieldsToReEncrypt) {
        if (userData[field] != null &&
            userData[field].toString().isNotEmpty &&
            userData[field].toString().contains(':')) {
          try {
            // Decrypt with old key
            final parts = userData[field].toString().split(':');
            if (parts.length != 2) continue;

            final ivBase64 = parts[0];
            final dataBase64 = parts[1];

            final oldKey = encrypt.Key(base64Decode(oldKeyBase64));
            final iv = encrypt.IV(base64Decode(ivBase64));

            final oldEncrypter = encrypt.Encrypter(
                encrypt.AES(oldKey, mode: encrypt.AESMode.cbc));
            final decrypted = oldEncrypter.decrypt64(dataBase64, iv: iv);

            // Encrypt with new key
            final newIv = encrypt.IV.fromSecureRandom(16);
            final newEncrypter = encrypt.Encrypter(
                encrypt.AES(newKey, mode: encrypt.AESMode.cbc));
            final newEncrypted = newEncrypter.encrypt(decrypted, iv: newIv);

            updates[field] =
                '${base64Encode(newIv.bytes)}:${newEncrypted.base64}';
          } catch (e) {
            debugPrint('Error re-encrypting field $field: $e');
          }
        }
      }

      // Update user data with re-encrypted fields
      if (updates.isNotEmpty) {
        await _firestore.collection('users').doc(userId).update(updates);
      }

      // Store new encryption key
      await _firestore.collection('encryption_keys').doc(userId).update({
        'key': newKeyBase64,
        'rotatedAt': FieldValue.serverTimestamp(),
        'previousKey': oldKeyBase64,
      });

      // Update cache
      _userKeyCache[userId] = newKeyBase64;

      debugPrint('Successfully rotated encryption key for user: $userId');
      return true;
    } catch (e) {
      debugPrint('Error rotating encryption key: $e');
      return false;
    }
  }
}
