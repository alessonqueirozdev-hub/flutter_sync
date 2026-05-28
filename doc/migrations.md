# Schema migrations

Local-store schema changes (renamed columns, new indexes, denormalized fields) flow through versioned `SchemaMigration` objects that the engine applies in order at startup.

## Defining a migration

```dart
final migration = SchemaMigration(
  version: 2,
  description: 'Add denormalized author_name column for offline display',
  up: (store) async {
    // Issue DDL through the store-specific raw-SQL API.
    // For DriftSyncStore:
    final driftStore = store as DriftSyncStore;
    await driftStore.database.executor.runCustom(
      'ALTER TABLE sync_records '
      'ADD COLUMN author_name TEXT',
    );
  },
  down: (store) async {
    // Optional reverse. Many production sites do not implement down().
  },
);
```

The `down` callback is optional. Migrations without a `down` throw `UnsupportedError` if the runner is asked to roll back — strict release-train sites should always provide one.

## Registering migrations

Pass the full ordered list to `FlutterSync.configure`:

```dart
await FlutterSync.configure(
  adapter: ...,
  store: ...,
  migrations: <SchemaMigration>[
    SchemaMigration(version: 1, up: createInitialSchema),
    SchemaMigration(version: 2, up: addAuthorNameColumn),
    SchemaMigration(version: 3, up: backfillAuthorNames),
  ],
);
```

The `MigrationRunner` enforces:

- Versions are unique (duplicates throw `StateError`).
- Versions are applied in ascending order.
- Migrations at or below the recorded current version are skipped.
- The whole upgrade runs inside one transaction so a partial schema is never observable by readers.

## Reading the result

```dart
final runner = MigrationRunner(store: store);
final result = await runner.run(
  migrations: migrations,
  currentVersion: 1,
);
print('Applied ${result.applied.length}, ended at v${result.endVersion}');
```

## Bootstrapping the initial schema

The Drift store already creates its own internal tables on first `initialize()`. Your migration v1 typically adds *application-specific* metadata or denormalization tables on top of that.

For Hive-backed apps, migrations are usually no-ops because Hive is schemaless; use migrations to data-transform existing records when your model evolves.
