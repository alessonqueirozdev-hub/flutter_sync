# Getting started

This guide walks you from `flutter pub add flutter_sync` to a fully syncing collection.

## 1. Install

```bash
flutter pub add flutter_sync
```

If you plan to use SQLite for local storage, also add Drift and the platform-specific SQLite bundle:

```bash
flutter pub add drift sqlite3_flutter_libs
```

If you plan to use real-time push notifications via a hosted backend, install the adapter you want:

```bash
flutter pub add supabase_flutter      # for SupabaseSyncAdapter
flutter pub add cloud_firestore       # for FirebaseSyncAdapter
flutter pub add graphql               # for GraphQLSyncAdapter
flutter pub add grpc                  # for GrpcSyncAdapter
```

## 2. Configure the engine

```dart
final flutterSync = await FlutterSync.configure(
  adapter: MockSyncAdapter(),                // swap in a real backend later
  store: DriftSyncStore(database: ...),
  logger: ConsoleLogger(),
);
```

`FlutterSync.configure` is async because it bootstraps the HLC clock, runs pending migrations, and opens the backend connection. Await it once and keep the returned `FlutterSync` for the duration of the app.

## 3. Define a model

```dart
class Todo implements SyncModel {
  Todo({required this.id, required this.title, this.done = false});

  @override
  final String id;
  final String title;
  final bool done;

  factory Todo.fromJson(Map<String, dynamic> j) => Todo(
    id: j['id'] as String,
    title: j['title'] as String,
    done: (j['done'] as bool?) ?? false,
  );

  @override
  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'done': done};
}
```

Reserved field names (`id`, `collection`, `hlc`, `created_at`, `updated_at`, `is_deleted`, anything starting with `_sync_`) must never appear in `toJson()` — the engine attaches them itself.

## 4. Build a repository

```dart
final todos = flutterSync.repository<Todo>(
  'todos',
  serializer: SyncModelSerializer(
    fromJson: Todo.fromJson,
    toJson: (t) => t.toJson(),
  ),
);
```

## 5. Save, read, and watch

```dart
await todos.save(Todo(id: uuid.v4(), title: 'Buy milk'));
final all = await todos.findAll();
todos.watch().listen((list) => print('${list.length} todos'));
```

Writes return as soon as the local store accepts them — the engine takes care of pushing them to the backend in the background.

## 6. Observe sync status

```dart
flutterSync.status.listen((status) {
  // SyncStatusIdle / Syncing / Synced / Offline / Paused / Error
});
```

## 7. Tear down

```dart
await flutterSync.dispose();
```

That's it. Read [Adapters](adapters.md) to plug in your real backend, then [Conflict resolution](conflict_resolution.md) to choose a merge strategy.
