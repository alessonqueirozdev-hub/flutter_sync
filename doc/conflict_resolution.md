# Conflict resolution

When a pull observes a record whose local counterpart was also modified since the last sync, the engine routes the pair through a `ConflictResolver`. Five built-ins ship with FlutterSync; you can also write your own.

## When does a conflict actually fire?

Only when both sides changed *the same record* since the last successful sync. If only one side touched the record, the merger applies the newer version directly without invoking the resolver.

## Built-in strategies

### `LWWResolver`

Last-Write-Wins by HLC timestamp. The record with the strictly greater HLC wins; ties break by the HLC's `nodeId` field, which is stable across runs. This is the default and the right choice for most "single-writer dominant" workflows.

```dart
conflictResolver: const LWWResolver(),
```

### `ServerWinsResolver`

The remote record always wins. Use when the server is authoritative (curated reference data, policy data, etc.).

### `ClientWinsResolver`

The local record always wins. Use when the device is authoritative (rare — but useful for single-user write-only flows).

### `CRDTResolver`

Merges payload fields that carry CRDT data through user-supplied `CRDTFieldMerger`s. Fields not listed in `mergers` fall back to LWW.

```dart
conflictResolver: CRDTResolver(
  mergers: {
    'tags': (local, remote) {
      final merged = <Object?>{
        if (local is List) ...local,
        if (remote is List) ...remote,
      };
      return merged.toList();
    },
  },
),
```

### `FieldLevelResolver`

Each field gets its own resolution strategy:

```dart
conflictResolver: FieldLevelResolver(
  strategies: {
    'title': FieldStrategyConfig(strategy: FieldStrategy.serverWins),
    'tags': FieldStrategyConfig(
      strategy: FieldStrategy.merge,
      merger: (local, remote) => /* merge */,
    ),
    'description': FieldStrategyConfig(strategy: FieldStrategy.lww),
  },
),
```

## Per-collection overrides

Pass `conflictResolver:` to a specific repository to override the engine-wide default:

```dart
final settings = flutterSync.repository<Settings>(
  'settings',
  serializer: ...,
  conflictResolver: const ServerWinsResolver(),
);
```

## Writing your own

Implement `ConflictResolver`:

```dart
class MyResolver implements ConflictResolver {
  @override
  ConflictResolutionStrategy get strategy =>
      ConflictResolutionStrategy.custom;

  @override
  String get name => 'my-resolver';

  @override
  Future<SyncRecord> resolve(SyncConflict conflict) async {
    // Domain-specific merge logic here.
  }
}
```

Resolvers must be deterministic — given the same inputs, every replica must return the same record — otherwise the system stops converging.
