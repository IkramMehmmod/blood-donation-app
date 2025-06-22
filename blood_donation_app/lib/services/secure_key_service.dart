import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureKeyService {
  static final SecureKeyService _instance = SecureKeyService._internal();
  factory SecureKeyService() => _instance;
  SecureKeyService._internal();

  static const String _encryptionKeyKey = 'encryption_key';
  static const String _encryptionIvKey = 'encryption_iv';

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  Uint8List _generateSecureRandomBytes(int length) {
    final random = Random.secure();
    return Uint8List.fromList(
        List.generate(length, (_) => random.nextInt(256)));
  }

  String _generateEncryptionKey() =>
      base64Encode(_generateSecureRandomBytes(32));
  String _generateEncryptionIv() =>
      base64Encode(_generateSecureRandomBytes(16));

  Future<void> _saveEncryptionKey(String key) async =>
      await _secureStorage.write(key: _encryptionKeyKey, value: key);

  Future<void> _saveEncryptionIv(String iv) async =>
      await _secureStorage.write(key: _encryptionIvKey, value: iv);

  Future<String> getEncryptionKey() async {
    String? key = await _secureStorage.read(key: _encryptionKeyKey);
    key ??= _generateEncryptionKey();
    await _saveEncryptionKey(key);
    return key;
  }

  Future<String> getEncryptionIv() async {
    String? iv = await _secureStorage.read(key: _encryptionIvKey);
    iv ??= _generateEncryptionIv();
    await _saveEncryptionIv(iv);
    return iv;
  }
}
