# Backend adapters

FlutterSync ships six adapters. Every adapter implements the same `SyncAdapter` interface, so swapping backends is a one-line change in `FlutterSync.configure`.

| Adapter | Source | Real-time |
|---|---|:---:|
| `SupabaseSyncAdapter` | `lib/src/adapters/supabase/` | Yes |
| `FirebaseSyncAdapter` | `lib/src/adapters/firebase/` | Yes |
| `RestSyncAdapter` | `lib/src/adapters/rest/` | Polled |
| `GraphQLSyncAdapter` | `lib/src/adapters/graphql/` | Yes (if `subscriptionEndpoint` set) |
| `GrpcSyncAdapter` | `lib/src/adapters/grpc/` | Yes |
| `MockSyncAdapter` | `lib/src/adapters/mock/` | Yes |

## Supabase

```dart
final adapter = SupabaseSyncAdapter(client: Supabase.instance.client);
```

The backend table must include `id TEXT PRIMARY KEY`, `hlc TEXT NOT NULL`, and a `updated_at TIMESTAMPTZ DEFAULT NOW()` column. Use `SupabaseRlsHelper.userScoped` to scope rows per user; the helper returns ready-to-paste SQL.

## Firebase (Firestore)

```dart
final adapter = FirebaseSyncAdapter(firestore: FirebaseFirestore.instance);
```

Each collection maps to a top-level Firestore collection of the same name. Documents must carry an `hlc` string field; security rules should require the writer's UID match a `userId` field if you need user scoping.

## REST

```dart
final adapter = RestSyncAdapter(
  config: RestSyncConfig(
    baseUrl: 'https://api.example.com',
    auth: BearerTokenAuth(token),
  ),
);
```

Contract:

- `GET /{collection}?since={hlc}&limit={n}&cursor={token}` → `{ "records": [...], "high_water_hlc": "...", "has_more": bool }`
- `POST /{collection}` body `{ "records": [...] }` → `{ "pushed": int, "rejected_ids": [...] }`

Custom contracts subclass `RestSyncAdapter` and override the request hooks.

## GraphQL

```dart
final adapter = GraphQLSyncAdapter(
  config: GraphQLSyncConfig(
    endpoint: 'https://api.example.com/graphql',
    subscriptionEndpoint: 'wss://api.example.com/graphql',
    headers: {'Authorization': 'Bearer $token'},
  ),
);
```

The adapter expects `sync_pull`, `sync_push`, and `sync_watch` operations matching the shapes in `GraphQLDocumentFactory`. Override `documentFactory` to point at custom operations on your own schema.

## gRPC

```dart
final adapter = GrpcSyncAdapter(transport: MyGeneratedGrpcTransport(channel));
```

The `flutter_sync.proto` service definition ships in `lib/src/adapters/grpc/`. Run `protoc` against it in your own project to generate the Dart stubs, then implement `GrpcSyncTransport` by delegating to those stubs.

## Mock

```dart
final adapter = MockSyncAdapter()
  ..latency = const Duration(milliseconds: 200)
  ..failNextPushes = 1;
```

Use the mock for tests, prototypes, and the example app. It supports injected latency, scripted failures, and direct inspection of the in-memory `stored` map.

## Writing your own

Any class implementing `SyncAdapter` works:

```dart
class MyAdapter implements SyncAdapter {
  @override
  Future<void> initialize() async { ... }
  @override
  Future<SyncPushResult> push(SyncBatch batch) async { ... }
  @override
  Future<SyncPullResult> pull(SyncPullRequest request) async { ... }
  @override
  Stream<SyncEvent> subscribe(SyncSubscription subscription) { ... }
  @override
  SyncAdapterCapabilities get capabilities => const SyncAdapterCapabilities(
    realtime: false, serverSideFilters: true, partialSync: true,
    idempotentPush: true, deltaPull: true, maxBatchSize: 100,
  );
  @override
  Future<void> dispose() async { ... }
}
```
