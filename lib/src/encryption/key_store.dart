// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 The FlutterSync Authors. All rights reserved.

import 'dart:typed_data';

/// Contract every secure key-storage backend must implement.
///
/// FlutterSync derives an AES-256 key from the user's passphrase via
/// Argon2id (see `Argon2KeyDeriver`) and caches the result through a
/// `KeyStore` so that subsequent operations on the same session do not
/// repeat the (expensive) derivation.
///
/// The default implementation is `SecureStorageKeyStore`, backed by
/// `flutter_secure_storage`. Tests typically use an in-memory variant.
abstract interface class KeyStore {
  /// Returns the cached key for [keyId], or `null` when no key has been
  /// stored or the cached entry has been evicted.
  Future<Uint8List?> readKey(String keyId);

  /// Persists [key] under [keyId]. Implementations are encouraged to use
  /// platform secure storage (Keychain on iOS/macOS, Keystore on Android,
  /// DPAPI on Windows, libsecret on Linux).
  Future<void> writeKey(String keyId, Uint8List key);

  /// Removes the key associated with [keyId]. No-op when no such key
  /// exists.
  Future<void> deleteKey(String keyId);
}

/// In-memory [KeyStore] suitable for tests and the first-boot path.
class InMemoryKeyStore implements KeyStore {
  /// Creates an in-memory store.
  InMemoryKeyStore();

  final Map<String, Uint8List> _store = <String, Uint8List>{};

  @override
  Future<Uint8List?> readKey(String keyId) async => _store[keyId];

  @override
  Future<void> writeKey(String keyId, Uint8List key) async {
    _store[keyId] = Uint8List.fromList(key);
  }

  @override
  Future<void> deleteKey(String keyId) async {
    _store.remove(keyId);
  }
}
