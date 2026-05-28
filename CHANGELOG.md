# Changelog

All notable changes to FlutterSync are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] — 2026-05-27

The initial public release. Every subsystem described in the project blueprint is present and exercised by the test suite.

### Added

- **Public API.** `FlutterSync.configure`, typed `SyncRepository<T>`, `SyncModel` + `SyncModelSerializer`, `SyncStatus` stream, `pause` / `resume`, `debugInfo`.
- **Hybrid Logical Clock.** `HLCTimestamp`, `HybridLogicalClock` (Kulkarni et al. 2014) with drift detection, `HLCNode` for persistent clock state.
- **CRDTs.** `GCounter`, `PNCounter`, `TwoPhaseSet<T>`, `LWWSet<T>`, `LWWMap<K, V>`, `SyncText` (Logoot).
- **Conflict resolvers.** `LWWResolver`, `ServerWinsResolver`, `ClientWinsResolver`, `CRDTResolver`, `FieldLevelResolver`.
- **Outbox.** `OutboxEntry` with SHA-256 idempotency keys, `ExponentialBackoffRetryStrategy` (and a `ConstantRetryStrategy` for tests), persistent `OutboxQueue`, concurrency-safe `OutboxProcessor`.
- **Local store.** `SyncStore` interface plus `DriftSyncStore` (SQLite-backed) and `HiveSyncStore` (key/value) implementations.
- **Connectivity and bandwidth awareness.** `ConnectivityObserver` debouncing `connectivity_plus`; `BandwidthMonitor` with adaptive batch sizing.
- **Scheduler and background sync.** `SyncScheduler` orchestrating foreground + background; per-platform implementations for Android (`workmanager`), iOS (`background_fetch`), desktop (`Timer.periodic`), and Web (`ServiceWorker` bridge).
- **Backend adapters.** `SupabaseSyncAdapter` (with `SupabaseRlsHelper`), `FirebaseSyncAdapter`, `RestSyncAdapter` (with `BearerTokenAuth`, `CallbackBearerAuth`, `ApiKeyAuth`), `GraphQLSyncAdapter`, `GrpcSyncAdapter` (with `flutter_sync.proto`), `MockSyncAdapter`.
- **Encryption.** AES-256-GCM `RecordEncryptor` with Argon2id key derivation (default `64 MiB / 3 iterations / 4 lanes`), `SecureStorageKeyStore` backed by `flutter_secure_storage`.
- **Audit trail.** Queryable `AuditTrail` with `AuditQuery` builder, `AuditEntry` records, and an in-memory ring-buffer default implementation.
- **Structured logging.** `SyncLogger` interface plus a default `ConsoleLogger` that forwards to `dart:developer`.
- **Schema migrations.** `SchemaMigration` versioned contract with optional `down`, `MigrationRunner` enforcing ordered execution and duplicate detection.
- **DevTools.** `FlutterSyncDevTools` overlay with Status, Outbox, and Conflicts tabs and a Conflicts JSON export button.
- **Example app.** Todos + Notes app in `example/` demonstrating the full surface.
- **Tests.** Unit, behavioral, integration, and property-based suites in `test/`. CRDT merges proven associative, commutative, and idempotent on random op sequences.

### License

Apache 2.0 — see `LICENSE` for the full verbatim text.
