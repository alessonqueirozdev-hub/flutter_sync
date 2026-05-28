<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="branding/flutter_sync_logo_transparent.png">
    <img alt="FlutterSync" src="branding/flutter_sync_logo.png" width="640">
  </picture>
</p>

<h1 align="center">FlutterSync</h1>

<p align="center">
  <strong>The most powerful offline-first sync engine for Flutter — multi-backend, CRDT-aware, HLC-ordered, with real background sync on every platform.</strong>
</p>

<p align="center">

[![License: Apache 2.0](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](LICENSE)
[![CI](https://github.com/your-org/flutter_sync/actions/workflows/ci.yml/badge.svg)](https://github.com/your-org/flutter_sync/actions/workflows/ci.yml)
[![pub package](https://img.shields.io/pub/v/flutter_sync.svg)](https://pub.dev/packages/flutter_sync)
[![Dart 3.3+](https://img.shields.io/badge/Dart-3.3+-0175C2.svg)](https://dart.dev)
[![Flutter 3.19+](https://img.shields.io/badge/Flutter-3.19+-02569B.svg)](https://flutter.dev)

</p>

> Work in progress — this README will grow phase by phase as the package is built. The complete blueprint lives in `SUPERPROMPT_FLUTTERSYNC.md`; operating guidance is in `CLAUDE.md` and `AGENTS.md`.

---

## Platform support

| Android | iOS | macOS | Windows | Linux | Web |
|:-------:|:---:|:-----:|:-------:|:-----:|:---:|
| Planned | Planned | Planned | Planned | Planned | Planned |

Background sync is implemented natively on every platform listed above (WorkManager on Android, BGTaskScheduler on iOS, system timers on desktop, ServiceWorker on Web).

---

## Roadmap and phase tracker

The package is delivered across 18 numbered phases. Each phase lives on its own branch and lands via a pull request to `develop`.

- [x] Phase 0 — Git and GitHub setup
- [x] Phase 1 — Foundation models and interfaces
- [x] Phase 2 — Hybrid Logical Clock and core engine internals
- [x] Phase 3 — CRDTs (GCounter, PNCounter, TwoPhaseSet, LWWSet, LWWMap, SyncText)
- [x] Phase 4 — Conflict resolvers (LWW, ServerWins, ClientWins, CRDT, FieldLevel)
- [x] Phase 5 — Persistent outbox with exponential-backoff retry
- [x] Phase 6 — Local store (Drift and Hive implementations)
- [x] Phase 7 — Connectivity and bandwidth awareness
- [x] Phase 8 — Scheduler and per-platform background sync
- [x] Phase 9 — Backend adapters (Supabase, Firebase, REST, GraphQL, gRPC, Mock)
- [x] Phase 10 — AES-256-GCM encryption at rest with Argon2id
- [x] Phase 11 — Audit trail and structured logging
- [x] Phase 12 — Schema migrations
- [ ] Phase 13 — Core engine and public API
- [ ] Phase 14 — In-app DevTools overlay
- [ ] Phase 15 — Tests (unit, behavioral, integration, property-based)
- [ ] Phase 16 — Example application (Todos and Notes)
- [ ] Phase 17 — Documentation

---

## Planned features

Items marked WIP are not yet implemented.

### Core engine
- WIP — Declarative entry point: `FlutterSync.configure(...)` and `flutterSync.repository<T>(...)`.
- WIP — Typed CRUD and reactive `watch` streams that always read from the local store.
- WIP — Optimistic local writes with background sync.
- WIP — Total event ordering via Hybrid Logical Clocks (HLC).
- WIP — Delta sync with `lastSyncedAt` advancement per collection.
- WIP — Pluggable conflict resolution at the global, per-collection, and per-field level.

### Outbox and delivery guarantees
- WIP — Persistent outbox that survives crashes, kills, and reboots.
- WIP — Exponential-backoff retry with jitter, dead-letter on permanent failure.
- WIP — SHA-256 idempotency keys for safe server-side deduplication.

### CRDTs
- WIP — `GCounter` (grow-only counter).
- WIP — `PNCounter` (positive-negative counter).
- WIP — `TwoPhaseSet`.
- WIP — `LWWSet<T>` (last-write-wins set).
- WIP — `LWWMap<K, V>` (last-write-wins map).
- WIP — `SyncText` (Logoot-based collaborative text).

### Backend adapters
- WIP — Supabase (Postgres + Realtime + RLS helpers).
- WIP — Firebase (Firestore).
- WIP — REST (JSON + pluggable auth).
- WIP — GraphQL (queries, mutations, subscriptions).
- WIP — gRPC (with shipped `.proto` service definition).
- WIP — Mock adapter for tests.

### Cross-platform background sync
- WIP — Android via `workmanager`.
- WIP — iOS via `BGTaskScheduler` + `background_fetch`.
- WIP — macOS, Windows, Linux via system timer + foreground detection.
- WIP — Web via `ServiceWorker` and `SharedWorker`.

### Security and operations
- WIP — AES-256-GCM encryption at rest, per-field opt-in.
- WIP — Argon2id key derivation with secure-storage-backed `KeyStore`.
- WIP — Bandwidth-aware adaptive batching.
- WIP — Queryable audit trail.
- WIP — Schema migration runner with ordered execution.
- WIP — In-app DevTools overlay with Status, Outbox, Conflicts, HLC, and Network tabs.

---

## Hybrid Logical Clock (HLC)

FlutterSync orders every event in the system through a Hybrid Logical Clock that follows Kulkarni et al. (2014), *"Logical Physical Clocks and Consistent Snapshots in Globally Distributed Databases."* Two devices that have never been online together can still agree on the order of any pair of events, even if their wall clocks drift by minutes or hours.

A timestamp is a `(physicalTime, logicalCounter, nodeId)` triple stored in the canonical wire form `{physicalMs}-{counter}-{nodeId}` — zero-padded so that the string sorts lexicographically. The implementation lives in `lib/src/core/hlc/` and exposes:

- `HLCTimestamp` — immutable value object with comparison operators and a `toWire()` / `parse()` round-trip.
- `HybridLogicalClock` — `tick()` for local events and `receive()` for remote events, with configurable drift tolerance (default 300 s, rejected drifts surface as `HLCDriftException`).
- `HLCNode` — interface for persisting the node identifier and the most recent clock snapshot, with an in-memory implementation suitable for tests.

## Delta sync and conflict merging

Pulls are incremental. Each collection carries a `lastSyncedAt` HLC watermark in `SyncMetadata`; only records strictly newer than that watermark are transferred.

The `DeltaComputer` reads the local store and returns the set of records that must be pushed to the backend. The `DeltaMerger` is the symmetric counterpart: it applies an incoming batch of remote records to the local store, advancing the local HLC on every receive and routing real collisions through the active `ConflictResolver`. The `BatchProcessor` groups individual writes into bounded-size, bounded-age batches that the scheduler hands to the adapter, while the `OptimisticUpdateManager` and `RollbackHandler` keep the local store consistent if a write permanently fails.

## CRDTs

FlutterSync ships six Conflict-free Replicated Data Types in `lib/src/crdt/`. Every type is proven associative, commutative, and idempotent (Phase 15 enforces this with property-based tests).

| Type | When to use it |
|---|---|
| `GCounter` | Monotonically-increasing counters (page views, likes, downloads). |
| `PNCounter` | Counters that need to support both increment and decrement (votes, balances). |
| `TwoPhaseSet<T>` | Sets where a removed element must stay removed (audit-style logs). |
| `LWWSet<T>` | Sets where removal can be undone by a fresher add (tags, labels). |
| `LWWMap<K, V>` | Key/value collections where each key's latest write wins by HLC. |
| `SyncText` | Collaborative text editing via a Logoot-based position model. |

Each type round-trips through `toJson` / `fromJson` so it can be serialized into a `SyncRecord` payload and synced like any other field.

## Conflict resolution

FlutterSync ships five built-in resolvers, plus a per-field combinator. Each is a thin implementation of the `ConflictResolver` interface and can be swapped at the global level (in `FlutterSync.configure`) or per repository (via `flutterSync.repository<T>(..., conflictResolver: ...)`).

| Resolver | Behavior |
|---|---|
| `LWWResolver` | The record with the strictly greater HLC wins. |
| `ServerWinsResolver` | The remote (server-issued) record always wins. |
| `ClientWinsResolver` | The local (device-issued) record always wins. |
| `CRDTResolver` | Each field listed in `mergers` is merged through a `CRDTFieldMerger`; other fields fall back to LWW. |
| `FieldLevelResolver` | Each field is resolved with its own configured strategy (LWW, ServerWins, ClientWins, or a custom merger). |

Custom resolvers implement `ConflictResolver` directly and may compose the built-ins as needed.

## Outbox and delivery guarantees

Every write that the engine reports as successful is durably stored in the **outbox** before the call returns. The outbox is what guarantees that an offline write reaches the server eventually — without it, an app kill or a reboot would silently lose the queued writes.

- `OutboxEntry` carries the record, the operation (`upsert` or `delete`), retry bookkeeping, and a SHA-256 **idempotency key** (`sha256(collection + ':' + id + ':' + hlc)`). The server uses the key to safely deduplicate retries.
- `ExponentialBackoffRetryStrategy` computes the delay before the next attempt: `min(baseDelay * 2^attempts + jitter, maxDelay)`, with defaults of `baseDelay = 1 s`, `maxDelay = 5 min`, `maxAttempts = 20`. A `ConstantRetryStrategy` is shipped for tests.
- `OutboxQueue` is the durable interface (in-memory implementation ships today; the Drift-backed variant lands in Phase 6).
- `OutboxProcessor` drains the queue by batching due entries per collection, calling `SyncAdapter.push`, and translating the result into entry status updates — succeeded entries are TTL-evicted, transient failures are rescheduled with backoff, permanent failures are dead-lettered and surfaced via an `onFailure` callback.

## Connectivity and bandwidth awareness

FlutterSync inspects network conditions before pushing data. The `ConnectivityObserver` wraps `connectivity_plus` and emits a debounced stream of `NetworkState` values (`none`, `wifi`, `mobile`, `ethernet`, `vpn`, `other`); the `BandwidthMonitor` keeps a rolling window of measured push throughput per state and recommends an adaptive batch size so each push completes within a target duration. Wi-Fi and Ethernet get larger batches; mobile data uses smaller batches to keep cost and latency in check; offline returns the minimum batch.

## Background sync (per platform)

`SyncScheduler` owns both the foreground timer (via `ForegroundSync`) and the OS-level background task (selected by `createBackgroundSync`). The concrete background implementations live under `lib/src/scheduler/platform/`:

| Platform | Mechanism | Default interval |
|---|---|---|
| Android | `workmanager` `PeriodicWorkRequest` | 15 min |
| iOS | `background_fetch` + `BGTaskScheduler` | 15 min |
| macOS / Windows / Linux | In-process `Timer.periodic` | 5 min |
| Web | `ServiceWorker` `SyncManager` bridge | 5 min |

Host apps must add the platform manifest entries listed in `doc/background_sync.md` (Phase 17) and register the background callback once in `main()`.

## Backend adapters

FlutterSync ships six adapters out of the box in `lib/src/adapters/`. Every adapter implements the same `SyncAdapter` contract, so swapping backends is a one-line change in `FlutterSync.configure`.

| Adapter | Path | Real-time | Notes |
|---|---|:---:|---|
| `SupabaseSyncAdapter` | `supabase/` | Yes | Includes `SupabaseRlsHelper` for ready-to-paste RLS policies. |
| `FirebaseSyncAdapter` | `firebase/` | Yes | Maps each collection to a top-level Firestore collection. |
| `RestSyncAdapter` | `rest/` | No (polled) | JSON over HTTP/HTTPS; pluggable `RestAuthStrategy`. |
| `GraphQLSyncAdapter` | `graphql/` | If endpoint set | Queries/mutations/subscriptions overridable via `GraphQLDocumentFactory`. |
| `GrpcSyncAdapter` | `grpc/` | Yes | Ships `flutter_sync.proto`; users supply a generated `GrpcSyncTransport`. |
| `MockSyncAdapter` | `mock/` | Yes | For tests and the example app; configurable failure injection. |

## Encryption at rest

When an `EncryptionConfig` is supplied to `FlutterSync.configure`, the `RecordEncryptor` wraps protected fields in an AES-256-GCM envelope before any record reaches the local store or the outbox. Keys are derived from the user's passphrase with Argon2id (default cost `memory = 64 MiB`, `iterations = 3`, `parallelism = 4`) and cached through a pluggable `KeyStore` — `SecureStorageKeyStore` ships as the default, backed by Keychain / Keystore / DPAPI / libsecret on the respective platforms.

Reserved fields (`id`, `collection`, `hlc`, `created_at`, `updated_at`, `is_deleted`, and anything prefixed `_sync_`) are never encrypted because the engine relies on them for routing, dedupe, and ordering.

## Schema migrations

Local-store schema changes (renamed columns, denormalized fields, new indexes) are managed by versioned `SchemaMigration` objects passed to `FlutterSync.configure`. The `MigrationRunner` sorts them by version, asserts there are no gaps or duplicates, and applies every migration whose version is above the recorded one — wrapped in a transaction so a half-applied schema can never be observed by readers. Optional `down` callbacks support rollback for sites with strict release-train policies.

## Documentation

The full developer documentation lands in Phase 17 under `doc/`. Until then, the authoritative references are:

- `SUPERPROMPT_FLUTTERSYNC.md` — complete architectural blueprint and 18-phase execution plan.
- `CLAUDE.md` — Claude-specific operating manual.
- `AGENTS.md` — tool-agnostic agent guide following the agents.md open standard.

---

## License

FlutterSync is released under the [Apache License, Version 2.0](LICENSE).

```
Copyright 2026 The FlutterSync Authors

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0
```
