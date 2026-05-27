# FlutterSync

> The most powerful offline-first sync engine for Flutter — multi-backend, CRDT-aware, HLC-ordered, with real background sync on every platform.

[![License: Apache 2.0](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](LICENSE)
[![CI](https://github.com/your-org/flutter_sync/actions/workflows/ci.yml/badge.svg)](https://github.com/your-org/flutter_sync/actions/workflows/ci.yml)
[![pub package](https://img.shields.io/pub/v/flutter_sync.svg)](https://pub.dev/packages/flutter_sync)
[![Dart 3.3+](https://img.shields.io/badge/Dart-3.3+-0175C2.svg)](https://dart.dev)
[![Flutter 3.19+](https://img.shields.io/badge/Flutter-3.19+-02569B.svg)](https://flutter.dev)

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
- [ ] Phase 1 — Foundation models and interfaces
- [ ] Phase 2 — Hybrid Logical Clock and core engine internals
- [ ] Phase 3 — CRDTs (GCounter, PNCounter, TwoPhaseSet, LWWSet, LWWMap, SyncText)
- [ ] Phase 4 — Conflict resolvers (LWW, ServerWins, ClientWins, CRDT, FieldLevel)
- [ ] Phase 5 — Persistent outbox with exponential-backoff retry
- [ ] Phase 6 — Local store (Drift and Hive implementations)
- [ ] Phase 7 — Connectivity and bandwidth awareness
- [ ] Phase 8 — Scheduler and per-platform background sync
- [ ] Phase 9 — Backend adapters (Supabase, Firebase, REST, GraphQL, gRPC, Mock)
- [ ] Phase 10 — AES-256-GCM encryption at rest with Argon2id
- [ ] Phase 11 — Audit trail and structured logging
- [ ] Phase 12 — Schema migrations
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
