<p align="center">
  <img alt="FlutterSync" src="branding/flutter_sync_logo.png" width="640">
</p>

<h1 align="center">FlutterSync</h1>

<p align="center">
  <strong>Multi-backend offline-first sync engine for Flutter — Hybrid Logical Clocks, CRDTs, background sync, AES-256-GCM encryption at rest.</strong>
</p>

<p align="center">

[![License: Apache 2.0](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](LICENSE)
[![Status: early-stage](https://img.shields.io/badge/status-early--stage-orange.svg)](#project-status)
[![CI](https://github.com/alessonqueirozdev-hub/flutter_sync/actions/workflows/ci.yml/badge.svg)](https://github.com/alessonqueirozdev-hub/flutter_sync/actions/workflows/ci.yml)
[![Dart 3.3+](https://img.shields.io/badge/Dart-3.3+-0175C2.svg)](https://dart.dev)
[![Flutter 3.19+](https://img.shields.io/badge/Flutter-3.19+-02569B.svg)](https://flutter.dev)
[![PRs welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](CONTRIBUTING.md)

</p>

---

## Project status

**v0.1.0 — early-stage. Architecture complete; production-validation in progress.**

| Stage | What it means | Where we are |
|---|---|---|
| Architecture | Public API, data flow, layer separation | ✅ Done |
| Compile clean | `dart analyze --fatal-infos --fatal-warnings` | ✅ Zero issues |
| Synthetic tests | 52 unit / behavioral / integration tests | ✅ All pass |
| Property-based CRDT tests | Randomized op-sequence convergence | ✅ Basic coverage (20 seeds) — caught a real bug |
| Real backend validation | Live Supabase / Firebase / REST / GraphQL / gRPC | 🟡 Not started |
| Real device validation | Android WorkManager, iOS BGTask, Web ServiceWorker | 🟡 Not started |
| Performance benchmarks | HLC throughput, outbox at 10k+ entries, large batches | 🟡 Not started |
| Production deployment | Real app, real users | 🟡 Not yet |

**Translation:** the codebase is well-architected and internally consistent, but no adapter has been exercised against a live server, and no platform has run the engine on a real device. **It needs collaborators to validate it.** [See ROADMAP.md](ROADMAP.md) for the path to `1.0.0`.

If you're considering this for production today, prefer [PowerSync](https://powersync.com) or [ElectricSQL](https://electric-sql.com) — both are mature, battle-tested, and have years of engineering behind them. FlutterSync is for people who want to **help shape an open, multi-backend alternative** with first-class CRDT types, native encryption, and a clean Dart 3.3+ codebase.

---

## Why FlutterSync

| Problem the ecosystem struggles with | FlutterSync's answer |
|---|---|
| Single-backend lock-in | Six adapters out of the box (Supabase, Firebase, REST, GraphQL, gRPC, Mock) + a `SyncAdapter` interface for anything else. |
| Wall-clock conflict resolution that drifts | Total event ordering via a Hybrid Logical Clock (Kulkarni et al., 2014). |
| Lost offline writes after crashes | Persistent outbox with SHA-256 idempotency keys and exponential-backoff retry. |
| Re-invented CRDTs in every app | Six ready-to-use CRDTs: `GCounter`, `PNCounter`, `TwoPhaseSet`, `LWWSet`, `LWWMap`, `SyncText` (Logoot). |
| Half-baked background sync | Native scheduling on Android (WorkManager), iOS (BGTaskScheduler), macOS / Windows / Linux, and Web (ServiceWorker). |
| Sensitive data in the clear on-device | AES-256-GCM at rest with Argon2id-derived keys (`memory = 64 MiB`, `iterations = 3`). |
| No way to debug live sync state | `FlutterSyncDevTools` overlay with Status, Outbox, and Conflicts tabs. |
| Schema changes break old installs | `MigrationRunner` applies ordered `SchemaMigration` objects in a transaction. |

---

## Platform support

| Android | iOS | macOS | Windows | Linux | Web |
|:-------:|:---:|:-----:|:-------:|:-----:|:---:|
| Y | Y | Y | Y | Y | Y |

---

## Quick start

```dart
// 1. Define your model.
@immutable
class Todo implements SyncModel {
  const Todo({
    required this.id,
    required this.title,
    required this.completed,
    required this.userId,
  });

  @override
  final String id;
  final String title;
  final bool completed;
  final String userId;

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'completed': completed,
    'user_id': userId,
  };

  factory Todo.fromJson(Map<String, dynamic> json) => Todo(
    id: json['id'] as String,
    title: json['title'] as String,
    completed: json['completed'] as bool,
    userId: json['user_id'] as String,
  );
}

// 2. Configure FlutterSync once at app startup.
final flutterSync = await FlutterSync.configure(
  adapter: SupabaseSyncAdapter(client: Supabase.instance.client),
  store: DriftSyncStore(database: FlutterSyncDatabase(NativeDatabase.memory())),
  conflictResolver: const LWWResolver(),
  schedulerConfig: const SyncSchedulerConfig(
    foregroundInterval: Duration(seconds: 30),
    backgroundInterval: Duration(minutes: 15),
    wifiOnly: false,
  ),
  encryptionConfig: const EncryptionConfig.fromPassword('user-secret-key'),
  migrations: <SchemaMigration>[
    SchemaMigration(version: 1, up: (db) async { /* CREATE TABLE ... */ }),
  ],
);

// 3. Use the typed repository in your feature code.
final todoRepo = flutterSync.repository<Todo>(
  'todos',
  serializer: SyncModelSerializer(
    fromJson: Todo.fromJson,
    toJson: (t) => t.toJson(),
  ),
  partialSyncFilter: SyncFilter.where('user_id', isEqualTo: currentUser.id),
);

// 4. Write — applied locally now, synced in the background.
await todoRepo.save(Todo(
  id: uuid.v4(),
  title: 'Learn FlutterSync',
  completed: false,
  userId: currentUser.id,
));

// 5. Read — always from the local store, always fast.
final todos = await todoRepo.findAll(
  SyncQuery().where('user_id', equals: currentUser.id),
);

// 6. Watch — reactive, works offline and online.
todoRepo
    .watch(SyncQuery().where('completed', equals: false))
    .listen((todos) => setState(() => _incompleteTodos = todos));

// 7. Observe sync status.
flutterSync.status.listen((status) {
  switch (status) {
    case SyncStatusSynced():
      showSnackBar('Everything is in sync.');
    case SyncStatusOffline():
      showBanner('Working offline.');
    case SyncStatusError(:final message):
      showError(message);
    case _:
      break;
  }
});

// 8. (Debug only) Add the DevTools overlay.
if (kDebugMode) {
  return FlutterSyncDevTools(
    flutterSync: flutterSync,
    auditTrail: InMemoryAuditTrail(),
    child: MyApp(),
  );
}
```

---

## Architecture at a glance

```
+--------------------------------------------------------+
|                  PUBLIC API LAYER                       |
|  FlutterSync  |  SyncRepository<T>  |  SyncFilter       |
+------------------------+-------------------------------+
|      CORE ENGINE       |   CONFLICT RESOLUTION          |
|  SyncEngine            |  LWW · ServerWins · CRDT       |
|  HybridLogicalClock    |  ClientWins · FieldLevel       |
|  Delta + Optimistic    |                                |
+------------------------+-------------------------------+
|                     DATA LAYER                          |
|  SyncStore (Drift / Hive)  |  OutboxQueue  |  Audit    |
+--------------------------------------------------------+
|                   SCHEDULER LAYER                       |
|  SyncScheduler  |  ForegroundSync  |  BackgroundSync   |
|  ConnectivityObserver  |  BandwidthMonitor             |
+--------------------------------------------------------+
|                    ADAPTER LAYER                        |
|  Supabase | Firebase | REST | GraphQL | gRPC | Mock    |
+--------------------------------------------------------+
```

Deep dive: [`doc/architecture.md`](doc/architecture.md).

---

## Documentation

| Guide | Topic |
|---|---|
| [Getting started](doc/getting_started.md) | Install, configure, first save. |
| [Adapters](doc/adapters.md) | Supabase, Firebase, REST, GraphQL, gRPC, custom. |
| [Conflict resolution](doc/conflict_resolution.md) | LWW, ServerWins, ClientWins, CRDT, FieldLevel. |
| [CRDTs](doc/crdts.md) | When to use each type plus examples. |
| [Background sync](doc/background_sync.md) | Per-platform manifest, callback registration. |
| [Encryption](doc/encryption.md) | AES-256-GCM, Argon2id, key storage. |
| [Migrations](doc/migrations.md) | Versioned schema upgrades. |
| [DevTools](doc/devtools.md) | Inspecting the live engine. |
| [Architecture](doc/architecture.md) | Layer-by-layer deep dive. |

---

## Contributing

**Contributions are explicitly welcome and actively needed.** See [`CONTRIBUTING.md`](CONTRIBUTING.md) for the workflow and [`ROADMAP.md`](ROADMAP.md) for prioritized areas where help moves the needle most.

The highest-value contributions right now:

1. **Validate an adapter against a real backend.** Stand up a Supabase / Firebase / REST / GraphQL project, run the example app, file every bug you find.
2. **Run the engine on a real device.** Background sync correctness on Android (WorkManager) and iOS (BGTaskScheduler) needs real-device verification.
3. **Add CRDT property-tests with more seeds.** Current suite runs 20 seeds; widening to 10k+ would catch edge cases.
4. **Write a tutorial.** "Building X with FlutterSync" — pick any backend.

Before opening a PR please run:

```bash
flutter pub get
dart format --output=none --set-exit-if-changed .
dart analyze --fatal-infos --fatal-warnings
flutter test
```

By contributing you agree your work is released under [Apache 2.0](LICENSE).

See also: [`CODE_OF_CONDUCT.md`](CODE_OF_CONDUCT.md), [`SECURITY.md`](SECURITY.md).

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
