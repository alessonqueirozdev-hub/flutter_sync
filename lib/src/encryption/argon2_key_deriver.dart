// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 The FlutterSync Authors. All rights reserved.

import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// Result of an Argon2id derivation: the 32-byte key + the salt used.
class DerivedKey {
  /// Creates a derived key.
  const DerivedKey({required this.key, required this.salt});

  /// 32-byte AES-256 key.
  final Uint8List key;

  /// 16-byte salt used during derivation. Persist with the ciphertext so
  /// the key can be re-derived from the same passphrase on the next run.
  final Uint8List salt;
}

/// Argon2id key-derivation helper.
///
/// Defaults match the FlutterSync spec: `memory = 65536 KiB`,
/// `iterations = 3`, `parallelism = 4`. The derivation runs inside a
/// short-lived isolate (`Isolate.run`) because Argon2id is CPU-intensive
/// and would otherwise stall the UI thread.
class Argon2KeyDeriver {
  /// Creates a key deriver with the supplied cost parameters.
  Argon2KeyDeriver({
    this.memoryKib = 65536,
    this.iterations = 3,
    this.parallelism = 4,
  });

  /// Memory cost in kibibytes.
  final int memoryKib;

  /// Iteration cost.
  final int iterations;

  /// Parallelism factor.
  final int parallelism;

  /// Derives a 32-byte key from [passphrase] using [salt]. When [salt] is
  /// `null`, a fresh random salt is generated.
  Future<DerivedKey> derive({
    required String passphrase,
    Uint8List? salt,
  }) async {
    final Uint8List effectiveSalt = salt ?? _randomSalt();
    // Heavy CPU work — run in an isolate so the UI thread stays responsive.
    final Uint8List key = await Isolate.run<Uint8List>(
      () => _deriveInIsolate(
        passphrase: passphrase,
        salt: effectiveSalt,
        memoryKib: memoryKib,
        iterations: iterations,
        parallelism: parallelism,
      ),
    );
    return DerivedKey(key: key, salt: effectiveSalt);
  }

  static Uint8List _randomSalt() {
    final List<int> bytes = SecretKeyData.random(length: 16).bytes;
    return Uint8List.fromList(bytes);
  }

  static Future<Uint8List> _deriveInIsolate({
    required String passphrase,
    required Uint8List salt,
    required int memoryKib,
    required int iterations,
    required int parallelism,
  }) async {
    final Argon2id argon = Argon2id(
      memory: memoryKib,
      iterations: iterations,
      parallelism: parallelism,
      hashLength: 32,
    );
    final SecretKey derived = await argon.deriveKey(
      secretKey: SecretKey(utf8.encode(passphrase)),
      nonce: salt,
    );
    final List<int> bytes = await derived.extractBytes();
    return Uint8List.fromList(bytes);
  }
}
