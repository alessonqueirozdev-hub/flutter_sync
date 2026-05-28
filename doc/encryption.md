# Encryption at rest

When an `EncryptionConfig` is supplied to `FlutterSync.configure`, every protected payload field is wrapped in an AES-256-GCM envelope before it reaches the local store or the outbox.

## Quick setup

```dart
final flutterSync = await FlutterSync.configure(
  adapter: ...,
  store: ...,
  encryptionConfig: const EncryptionConfig.fromPassword('user-secret'),
);
```

That's it — every field that is not in the reserved-clear list (see below) is encrypted.

## Key derivation

Keys are derived from the user's passphrase via Argon2id:

| Parameter | Default | Override via |
|---|---|---|
| Memory | 65,536 KiB (64 MiB) | `EncryptionConfig.argon2Memory` |
| Iterations | 3 | `EncryptionConfig.argon2Iterations` |
| Parallelism | 4 | `EncryptionConfig.argon2Parallelism` |

Derivation runs inside a short-lived isolate (`Isolate.run`) so the UI thread stays responsive.

## Key storage

The derived 32-byte key is cached through a `KeyStore`. The default is `SecureStorageKeyStore`, backed by `flutter_secure_storage`:

- Android → Keystore
- iOS / macOS → Keychain
- Windows → DPAPI
- Linux → libsecret

For tests, use `InMemoryKeyStore`. For custom backends (HSM, KMS, etc.), implement `KeyStore` directly:

```dart
class MyKeyStore implements KeyStore {
  @override
  Future<Uint8List?> readKey(String keyId) async { ... }
  @override
  Future<void> writeKey(String keyId, Uint8List key) async { ... }
  @override
  Future<void> deleteKey(String keyId) async { ... }
}
```

## Per-field opt-in

By default every field that is *not* in the reserved-clear list is encrypted. To explicitly limit encryption to specific fields:

```dart
encryptionConfig: const EncryptionConfig(
  passphrase: 'user-secret',
  encryptedFields: <String>{'body', 'attachments'},
);
```

## Reserved clear fields

The engine needs these fields in the clear to route, dedupe, and order records — they are *never* encrypted regardless of configuration:

`id`, `collection`, `hlc`, `created_at`, `updated_at`, `is_deleted`, and anything starting with `_sync_`.

## Envelope format

Each encrypted value is base64-encoded with a `@fs1:` prefix:

```
@fs1:<base64(salt | nonce | ciphertext | gcm_tag)>
```

The salt enables key re-derivation across app launches; the GCM tag protects against tampering. The envelope is detectable on read so decryption is fully automatic.
