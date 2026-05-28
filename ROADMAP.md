# Roadmap

This document tracks where FlutterSync is going. It is updated as priorities shift. Items marked **Help wanted** are explicitly open for community contribution.

The single, blunt summary: **we have a well-architected codebase that has never met a real backend in production**. Every milestone below is about turning that into a credible, validated package.

---

## Now — v0.1.x (current focus)

The goal of the `0.1` line is to **validate every claim made by the architecture against reality**.

### Backends — make the adapters real

- [ ] **Help wanted** — `SupabaseSyncAdapter` end-to-end: stand up a real Supabase project, run example app with RLS, push 100+ records, observe pull + realtime, document caveats.
- [ ] **Help wanted** — `FirebaseSyncAdapter` end-to-end with Firestore.
- [ ] **Help wanted** — `RestSyncAdapter` against a real API (any tutorial backend, e.g. Strapi / Pocketbase / Hasura / custom Express).
- [ ] **Help wanted** — `GraphQLSyncAdapter` against a real GraphQL endpoint with subscriptions.
- [ ] **Help wanted** — `GrpcSyncAdapter` end-to-end with a reference gRPC server.
- [ ] Ship a reference Supabase schema and SQL migration as part of `doc/supabase_quickstart.md`.

### Platforms — make background sync real

- [ ] **Help wanted** — verify Android `WorkManager` sync on a real device; document the manifest entries and any quirks of `vm:entry-point`.
- [ ] **Help wanted** — verify iOS `BGTaskScheduler` sync on a real device; document the Info.plist entries and the simulator caveats.
- [ ] **Help wanted** — write the `flutter_sync_sw.js` service worker that the web bridge expects, with PWA registration docs.
- [ ] Verify desktop `Timer.periodic` driver on macOS / Windows / Linux app builds.

### Local store — make persistence real

- [ ] Wire `DriftSyncStore` into `FlutterSync.configure` as the default (today's default is in-memory) and verify it survives app restarts.
- [ ] Wire a `DriftOutboxQueue` so the outbox is durable across kills/reboots (today's `InMemoryOutboxQueue` loses queued writes).
- [ ] Verify `HiveSyncStore` parity with `DriftSyncStore` on a real Flutter app.

### Tests — go from "passing" to "trustworthy"

- [ ] **Help wanted** — widen CRDT property tests from 20 seeds to 10k seeds across all six CRDT types; surface every failing seed.
- [ ] Add multi-replica simulation tests (4+ replicas, randomized partitions, prove convergence).
- [ ] Add stress tests: 10k records in store, 1k outbox entries, 100k HLC ticks.
- [ ] Hit the published coverage targets (80% overall, 100% on HLC/CRDTs, 95% on core, 100% on conflict resolvers).
- [ ] Set up Codecov or equivalent in CI.

### DevTools — finish the spec

- [ ] Add HLC tab (current value, node id, last 50 emitted timestamps).
- [ ] Add Network tab (current connectivity, throughput, latency history chart).
- [ ] Ship the v0.1 DevTools screenshots in `doc/devtools.md`.

### Documentation — add tutorials

- [ ] **Help wanted** — "Building a Todo app with FlutterSync + Supabase" (full walkthrough, ~30 min reader-time).
- [ ] **Help wanted** — "Building a Notes app with FlutterSync + Firestore".
- [ ] **Help wanted** — "Migrating from PowerSync to FlutterSync" — even if the answer is "don't yet, here's why", the comparison is valuable.
- [ ] DartDoc coverage: every public symbol has a complete first-sentence summary and at least one usage example for non-trivial APIs.

### Operational polish

- [ ] First publication to pub.dev (`dart pub publish`) only after at least one adapter has been validated end-to-end.
- [ ] Pana score target: ≥ 130.
- [ ] CI badges in the README reflect real CI runs.
- [ ] Set up Dependabot or Renovate for dependency upgrades.

---

## Next — v0.2 (after validation)

Once `0.1.x` is validated against real backends, focus shifts to differentiators.

- [ ] **Selective sync at the row level** — per-collection filters that the server enforces.
- [ ] **Multi-user on one device** — distinct stores and key vaults per logged-in user, switchable at runtime.
- [ ] **Bandwidth-adaptive batch sizing across slow networks** — extend `BandwidthMonitor` with calibration probes and a regression model.
- [ ] **CRDT pack: more types** — `OR-Set`, `Map-of-CRDTs`, `RGA` for richer collaborative text.
- [ ] **Schema migration with data backfill helpers** — typed builder DSL beyond raw SQL.
- [ ] **DevTools standalone web app** — open the engine state in a browser tab via WebSocket, like Flutter DevTools itself.
- [ ] **Encrypted attachments** — separate from `payload`, streamed to/from object storage.

---

## Eventually — v1.0 (when it earns the version)

`1.0` is reserved for the day FlutterSync has:

- At least three independent production deployments documented as case studies.
- At least one backend adapter validated against a real server by someone other than the maintainer.
- A third-party security review of the encryption stack.
- Benchmarks comparing it to PowerSync and ElectricSQL on a published reproducible workload.
- A stable public API with a documented deprecation policy.

We do not bump to `1.0` for vanity. The version means something.

---

## Out of scope (probably forever)

To stay focused, FlutterSync explicitly does **not** plan to be:

- A hosted cloud service. It is a client-side engine; the backend is yours to bring.
- An ORM. `SyncStore` is intentionally low-level.
- A code generator. The package is hand-written Dart with no `build_runner` requirement (Drift's optional codegen is consumer-owned).
- A replacement for backend-specific SDKs (`supabase_flutter`, `cloud_firestore`, etc.). Adapters wrap them; they do not replace them.

---

## How to influence this roadmap

- Open a [Discussion](https://github.com/alessonqueirozdev-hub/flutter_sync/discussions) for design conversations.
- Open an [Issue](https://github.com/alessonqueirozdev-hub/flutter_sync/issues) for a concrete bug or feature request.
- Open a PR for a "Help wanted" item — they are explicitly up for grabs.

Priorities will shift based on what real users and contributors actually need. This document is alive.
