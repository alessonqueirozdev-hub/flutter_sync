// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 The FlutterSync Authors. All rights reserved.

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'key_store.dart';

/// [KeyStore] backed by `flutter_secure_storage`.
///
/// On each platform the package delegates to the OS-blessed secret store
/// (Keychain on iOS/macOS, Keystore on Android, DPAPI on Windows,
/// libsecret on Linux). The Dart side simply stores the base64-encoded
/// key bytes; the OS handles encryption-at-rest of the secret itself.
class SecureStorageKeyStore implements KeyStore {
  /// Creates a secure-storage-backed store.
  SecureStorageKeyStore({FlutterSecureStorage? storage, this.prefix = 'flutter_sync.'})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  /// Prefix prepended to every key id so FlutterSync entries are easy to
  /// audit and bulk-purge.
  final String prefix;

  @override
  Future<Uint8List?> readKey(String keyId) async {
    final String? raw = await _storage.read(key: '$prefix$keyId');
    if (raw == null) {
      return null;
    }
    return base64Decode(raw);
  }

  @override
  Future<void> writeKey(String keyId, Uint8List key) async {
    await _storage.write(key: '$prefix$keyId', value: base64Encode(key));
  }

  @override
  Future<void> deleteKey(String keyId) async {
    await _storage.delete(key: '$prefix$keyId');
  }
}
