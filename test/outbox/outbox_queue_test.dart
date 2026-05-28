// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 The FlutterSync Authors. All rights reserved.

import 'package:flutter_sync/flutter_sync.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_fixtures.dart';

void main() {
  group('InMemoryOutboxQueue', () {
    test('enqueue assigns an id and emits an event', () async {
      final InMemoryOutboxQueue q = InMemoryOutboxQueue();
      final List<OutboxQueueEvent> seen = <OutboxQueueEvent>[];
      final sub = q.events.listen(seen.add);
      final OutboxEntry entry = await q.enqueue(
        TestFixtures.record(),
        OutboxOperation.upsert,
      );
      await Future<void>.delayed(Duration.zero);
      expect(entry.id, isNotEmpty);
      expect(entry.status, OutboxStatus.pending);
      expect(seen.single, isA<OutboxQueueEventEnqueued>());
      await sub.cancel();
      await q.dispose();
    });

    test('dueEntries respects nextRetryAt', () async {
      final InMemoryOutboxQueue q = InMemoryOutboxQueue();
      final OutboxEntry pending = await q.enqueue(
        TestFixtures.record(id: 'a'),
        OutboxOperation.upsert,
      );
      final OutboxEntry future = await q.enqueue(
        TestFixtures.record(id: 'b'),
        OutboxOperation.upsert,
      );
      await q.update(future.copyWith(
        nextRetryAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
      ),);
      final List<OutboxEntry> due = await q.dueEntries();
      expect(due.length, 1);
      expect(due.single.id, pending.id);
      await q.dispose();
    });

    test('idempotency key is deterministic per (collection, id, hlc)', () {
      final SyncRecord r = TestFixtures.record();
      expect(
        OutboxEntry.computeIdempotencyKey(r),
        OutboxEntry.computeIdempotencyKey(r),
      );
    });
  });

  group('ExponentialBackoffRetryStrategy', () {
    test('produces increasing delays capped at maxDelay', () {
      final ExponentialBackoffRetryStrategy strategy =
          ExponentialBackoffRetryStrategy(
        baseDelay: const Duration(milliseconds: 100),
        maxDelay: const Duration(seconds: 1),
        maxAttempts: 10,
      );
      final Duration d1 = strategy.nextDelay(1);
      final Duration d3 = strategy.nextDelay(3);
      expect(d1 < d3 || d3 == const Duration(seconds: 1), isTrue);
      expect(strategy.nextDelay(50), const Duration(seconds: 1));
    });

    test('nextDelay returns zero for non-positive attempts', () {
      final ExponentialBackoffRetryStrategy strategy =
          ExponentialBackoffRetryStrategy();
      expect(strategy.nextDelay(0), Duration.zero);
      expect(strategy.nextDelay(-1), Duration.zero);
    });
  });
}
