// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 The FlutterSync Authors. All rights reserved.

import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../models/sync_record.dart';
import 'argon2_key_deriver.dart';
import 'encryption_config.dart';
import 'key_store.dart';

/// Constant marker placed at the start of every encrypted envelope so we
/// can detect double-encryption attempts and warn the user.
const String _envelopeMarker = '@fs1:';

/// AES-256-GCM encryptor for [SyncRecord] payloads.
///
/// Each protected field is wrapped in a base64-encoded envelope of the
/// shape:
///
/// ```
/// @fs1:<base64(salt | nonce | ciphertext | tag)>
/// ```
///
/// where the salt enables key re-derivation from the user passphrase via
/// Argon2id and the GCM tag protects against tampering.
class RecordEncryptor {
  /// Creates an encryptor bound to [config], [keyStore] and [deriver].
  RecordEncryptor({
    required this.config,
    required this.keyStore,
    Argon2KeyDeriver? deriver,
    AesGcm? aes,
  })  : _deriver = deriver ?? Argon2KeyDeriver(),
        _aes = aes ?? AesGcm.with256bits();

  /// Active encryption configuration.
  final EncryptionConfig config;

  /// Backing key store used to cache the derived AES-256 key.
  final KeyStore keyStore;

  final Argon2KeyDeriver _deriver;
  final AesGcm _aes;
  Uint8List? _cachedKey;
  Uint8List? _cachedSalt;

  /// Encrypts every protected field of [record] and returns a new
  /// [SyncRecord] with the same metadata.
  Future<SyncRecord> encrypt(SyncRecord record) async {
    final Map<String, Object?> next = <String, Object?>{};
    for (final MapEntry<String, Object?> entry in record.payload.entries) {
      if (!config.shouldEncrypt(entry.key)) {
        next[entry.key] = entry.value;
        continue;
      }
      next[entry.key] = await _encryptValue(entry.value);
    }
    return record.copyWith(payload: next);
  }

  /// Decrypts every protected field of [record] and returns a new
  /// [SyncRecord] with the same metadata.
  Future<SyncRecord> decrypt(SyncRecord record) async {
    final Map<String, Object?> next = <String, Object?>{};
    for (final MapEntry<String, Object?> entry in record.payload.entries) {
      final Object? value = entry.value;
      if (value is String && value.startsWith(_envelopeMarker)) {
        next[entry.key] = await _decryptValue(value);
      } else {
        next[entry.key] = value;
      }
    }
    return record.copyWith(payload: next);
  }

  Future<String> _encryptValue(Object? value) async {
    final List<int> plain = utf8.encode(jsonEncode(value));
    final Uint8List nonce = _randomBytes(12);
    final Uint8List salt = await _ensureKey();
    final SecretBox box = await _aes.encrypt(
      plain,
      secretKey: SecretKey(_cachedKey!),
      nonce: nonce,
    );
    final BytesBuilder builder = BytesBuilder()
      ..add(salt)
      ..add(box.nonce)
      ..add(box.cipherText)
      ..add(box.mac.bytes);
    return '$_envelopeMarker${base64Encode(builder.toBytes())}';
  }

  Future<Object?> _decryptValue(String envelope) async {
    final Uint8List bytes = base64Decode(envelope.substring(_envelopeMarker.length));
    if (bytes.length < 16 + 12 + 16) {
      throw const FormatException('Encrypted envelope too short.');
    }
    final Uint8List salt = bytes.sublist(0, 16);
    final Uint8List nonce = bytes.sublist(16, 28);
    final Uint8List ciphertextAndTag = bytes.sublist(28);
    final Uint8List ciphertext =
        ciphertextAndTag.sublist(0, ciphertextAndTag.length - 16);
    final Uint8List tagBytes =
        ciphertextAndTag.sublist(ciphertextAndTag.length - 16);
    await _ensureKey(saltOverride: salt);
    final SecretBox box = SecretBox(
      ciphertext,
      nonce: nonce,
      mac: Mac(tagBytes),
    );
    final List<int> plain = await _aes.decrypt(
      box,
      secretKey: SecretKey(_cachedKey!),
    );
    return jsonDecode(utf8.decode(plain));
  }

  Future<Uint8List> _ensureKey({Uint8List? saltOverride}) async {
    if (_cachedKey != null && saltOverride == null) {
      return _cachedSalt!;
    }
    if (saltOverride != null && _cachedSalt != null &&
        _bytesEqual(_cachedSalt!, saltOverride)) {
      return _cachedSalt!;
    }
    final Uint8List? stored = await keyStore.readKey('master');
    if (stored != null && saltOverride == null) {
      _cachedKey = stored;
      _cachedSalt = await keyStore.readKey('master_salt');
      _cachedSalt ??= _randomBytes(16);
      return _cachedSalt!;
    }
    final DerivedKey derived = await _deriver.derive(
      passphrase: config.passphrase,
      salt: saltOverride,
    );
    _cachedKey = derived.key;
    _cachedSalt = derived.salt;
    await keyStore.writeKey('master', derived.key);
    await keyStore.writeKey('master_salt', derived.salt);
    return derived.salt;
  }

  Uint8List _randomBytes(int length) {
    final List<int> bytes = SecretKeyData.random(length: length).bytes;
    return Uint8List.fromList(bytes);
  }

  bool _bytesEqual(Uint8List a, Uint8List b) {
    if (a.length != b.length) {
      return false;
    }
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) {
        return false;
      }
    }
    return true;
  }
}
