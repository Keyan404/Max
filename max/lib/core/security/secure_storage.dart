import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorage {
  // Singleton pattern
  static final SecureStorage _instance = SecureStorage._internal();
  factory SecureStorage() => _instance;
  SecureStorage._internal();

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      resetOnError: true,
    ),
  );

  /// Saves a key-value pair securely
  Future<void> write(String key, String value) async {
    await _storage.write(key: key, value: value);
  }

  /// Reads a secure key, returns null if it doesn't exist
  Future<String?> read(String key) async {
    return await _storage.read(key: key);
  }

  /// Checks if a key exists in storage
  Future<bool> containsKey(String key) async {
    return await _storage.containsKey(key: key);
  }

  /// Deletes a specific key
  Future<void> delete(String key) async {
    await _storage.delete(key: key);
  }

  /// Clears all keys (useful for master database purge / security breach)
  Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}
