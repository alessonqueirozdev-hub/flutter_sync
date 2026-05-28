// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 The FlutterSync Authors. All rights reserved.

import 'package:meta/meta.dart';

/// Field names that are never encrypted because the engine needs them in
/// the clear to route, dedupe, and order records.
const Set<String> kReservedClearFields = <String>{
  'id',
  'collection',
  'hlc',
  'created_at',
  'updated_at',
  'is_deleted',
};

/// Per-collection encryption configuration consumed by `RecordEncryptor`.
@immutable
class EncryptionConfig {
  /// Creates an immutable configuration.
  const EncryptionConfig({
    required this.passphrase,
    this.encryptedFields,
    this.argon2Memory = 65536,
    this.argon2Iterations = 3,
    this.argon2Parallelism = 4,
  })  : assert(argon2Memory >= 8192, 'Argon2 memory must be >= 8 MB.'),
        assert(argon2Iterations >= 1, 'Argon2 iterations must be >= 1.'),
        assert(argon2Parallelism >= 1, 'Argon2 parallelism must be >= 1.');

  /// Convenience constructor for the common "encrypt every encryptable
  /// field with a single passphrase" case.
  const EncryptionConfig.fromPassword(String password)
      : this(passphrase: password);

  /// Secret used to derive the AES-256 key via Argon2id. Stored only in
  /// memory; the derived key may be cached by [KeyStore] implementations.
  final String passphrase;

  /// Opt-in allowlist of field names to encrypt. When `null`, every field
  /// that is not in [kReservedClearFields] is encrypted.
  final Set<String>? encryptedFields;

  /// Argon2id memory cost in kibibytes. Default `65536` KiB (64 MiB).
  final int argon2Memory;

  /// Argon2id iteration count. Default `3`.
  final int argon2Iterations;

  /// Argon2id parallelism. Default `4`.
  final int argon2Parallelism;

  /// Returns `true` when [fieldName] should be encrypted under this
  /// configuration.
  bool shouldEncrypt(String fieldName) {
    if (kReservedClearFields.contains(fieldName)) {
      return false;
    }
    if (fieldName.startsWith('_sync_')) {
      return false;
    }
    return encryptedFields == null || encryptedFields!.contains(fieldName);
  }
}
