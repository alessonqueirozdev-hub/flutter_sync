# Architecture deep dive

This document explains how FlutterSync's layers fit together. For the high-level diagram, see the [README](../README.md#architecture-at-a-glance).

## The write path

1. Caller invokes `SyncRepository.save(model)`.
2. The repository serializes the model with the `SyncModelSerializer`.
3. `OptimisticUpdateManager.applyOptimistic` reads the current local state (for rollback), stamps the write with a fresh `HLCTimestamp` from the clock, and persists the new record through `SyncStore.upsert`.
4. The encryptor (if configured) wraps protected fields.
5. The record is enqueued in the outbox (`OutboxQueue.enqueue`) with operation `upsert` and an idempotency key derived from `(collection, id, hlc)`.
6. `SyncRepository.save` returns success — without waiting for the network.
7. In the background, the `SyncScheduler` ticks, `OutboxProcessor` drains the queue, and the adapter sends batches to the server.

## The read path

1. Caller invokes `SyncRepository.findAll(query)`.
2. The repository forwards the query to `SyncStore.findAll`.
3. Records flow through the encryptor's `decrypt` if needed.
4. The repository deserializes each record back into the typed `T` model.

Reads never block on the network — they always come from the local store.

## The pull path

1. `SyncScheduler.syncNow` (or a periodic tick) calls `SyncEngine.syncNow`.
2. For each collection with metadata, the engine reads `SyncMetadata.lastSyncedAt` and builds a `SyncPullRequest` with `since: lastSyncedAt`.
3. The adapter returns a `SyncPullResult`.
4. `DeltaMerger` integrates each remote record:
   - `clock.receive(remote.hlc)` to advance the local HLC.
   - If no local record exists → insert.
   - If the remote dominates by HLC → apply.
   - If the local dominates → ignore.
   - Otherwise → real conflict → call `ConflictResolver.resolve` → apply the winner.
5. `SyncMetadata.lastSyncedAt` is advanced to the highest HLC observed in the batch.

## HLC details

- 64-bit physical time (milliseconds since the Unix epoch) + 32-bit logical counter + UUID v4 `nodeId`.
- Wire format zero-pads physical and counter to 20 and 10 digits respectively so lexicographic string comparison matches numerical comparison.
- Drift detection: a remote whose `physicalTime` exceeds the local wall clock by more than the configured tolerance throws `HLCDriftException` so the system can surface the misconfiguration rather than silently jumping forward.

## Outbox details

- Backed by `OutboxQueue` (in-memory by default; the Drift-backed variant ships in `DriftSyncStore`).
- Each `OutboxEntry` carries the full record, an operation tag (`upsert` / `delete`), a status (`pending`, `inflight`, `synced`, `failed`), retry bookkeeping, and an idempotency key.
- `ExponentialBackoffRetryStrategy` computes `min(baseDelay * 2^attempts + jitter, maxDelay)` between attempts.
- After `maxAttempts` (default 20), the entry is dead-lettered and surfaced via the `onFailure` callback so the application can decide what to do.

## Scheduler details

- `ForegroundSync` is a simple `Timer.periodic` driver that triggers a single processor pass each tick, with reentrancy guards so two ticks never overlap.
- `BackgroundSync` is platform-specific (Android `workmanager`, iOS `background_fetch`, etc.) and runs even when the app is in the background.
- `ConnectivityObserver` debounces `connectivity_plus` events so flaky transitions do not trigger storms of sync attempts.
- `BandwidthMonitor` keeps a rolling window of measured throughput per network state and recommends a batch size that fits the target push duration.

## Isolates

- Argon2id key derivation runs in `Isolate.run` so the UI thread stays responsive while the CPU-intensive derivation runs.
- Future versions will move large delta computations (>1000 records) into an isolate; today the computation runs on the calling isolate because it is dominated by I/O.

## Public-API stability

`lib/flutter_sync.dart` is the single source of truth for what is public. Anything under `lib/src/` that the barrel does not re-export may change between minor releases without notice. Adapters that ship as separate packages would import the barrel; in-tree adapters import their nearest public symbols (`SyncRecord`, `SyncBatch`, etc.) directly.
