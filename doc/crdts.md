# CRDTs

FlutterSync ships six Conflict-free Replicated Data Types. Each type's `merge` operation is associative, commutative, and idempotent — independently verified by the property-based tests in `test/crdt/`.

## When to use which

| Type | Pick it when... |
|---|---|
| `GCounter` | The counter only ever goes up (views, likes, downloads). |
| `PNCounter` | The counter can both increase and decrease (votes, balances). |
| `TwoPhaseSet<T>` | A removed element must stay removed forever (audit lists). |
| `LWWSet<T>` | An element can be re-added after removal (tags, labels). |
| `LWWMap<K, V>` | A key/value store where the latest write per key wins. |
| `SyncText` | Multi-user collaborative text editing. |

## GCounter

```dart
final views = GCounter()
  .increment('node-a', 5)
  .increment('node-b', 3);
print(views.value); // 8
final mergedView = views.merge(otherViews);
```

## PNCounter

```dart
final balance = PNCounter()
  .increment('user-tx', 100)
  .decrement('user-tx', 30);
print(balance.value); // 70
```

## LWWSet

```dart
final tags = LWWSet<String>()
  .add('flutter', clock.tick())
  .add('dart', clock.tick());

// Later, on a different replica:
final removedFlutter = tags.remove('flutter', clock.tick());
final readded = removedFlutter.add('flutter', clock.tick());
print(readded.contains('flutter')); // true
```

## LWWMap

```dart
final settings = LWWMap<String, Object?>()
  .set('theme', 'dark', clock.tick())
  .set('notifications', true, clock.tick());
print(settings.get('theme')); // 'dark'
```

## SyncText (Logoot)

```dart
final doc = SyncText(siteId: clock.nodeId);
doc.insert(0, 'Hello');
doc.insert(5, ' world');

// Concurrent edit on another replica:
final other = SyncText(siteId: 'other-node');
other.insert(0, 'Hi');

final merged = doc.merge(other);
print(merged.value); // 'Hello world' interleaved with 'Hi' deterministically
```

## Persisting CRDTs in a SyncRecord

CRDTs round-trip through `toJson` / `fromJson` so they can be carried inside a `SyncRecord.payload`. Pair them with a `CRDTResolver` to ensure conflicts are resolved through the CRDT's `merge` rather than LWW.
