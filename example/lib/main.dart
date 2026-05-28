// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 The FlutterSync Authors. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter_sync/flutter_sync.dart';

import 'screens/home_screen.dart';

/// Entry point of the FlutterSync example application.
///
/// The app is configured with a [MockSyncAdapter] by default so it can be
/// run end-to-end without provisioning a backend. Swap in
/// `SupabaseSyncAdapter`, `FirebaseSyncAdapter`, or any other adapter to
/// see the engine push to a real server.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final FlutterSync flutterSync = await FlutterSync.configure(
    adapter: MockSyncAdapter(),
    store: _DemoStore(),
    logger: ConsoleLogger(),
  );
  runApp(_App(flutterSync: flutterSync));
}

class _App extends StatelessWidget {
  const _App({required this.flutterSync});

  final FlutterSync flutterSync;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FlutterSync Example',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: HomeScreen(flutterSync: flutterSync),
    );
  }
}

/// Tiny in-memory [SyncStore] used by the example so the app can be
/// launched without provisioning SQLite or Hive boxes. Real applications
/// would use `DriftSyncStore` or `HiveSyncStore`.
class _DemoStore implements SyncStore {
  final Map<String, Map<String, SyncRecord>> _records =
      <String, Map<String, SyncRecord>>{};
  final Map<String, SyncMetadata> _meta = <String, SyncMetadata>{};
  String _nodeId = '';

  @override
  Future<void> initialize(SyncStoreConfig config) async {
    _nodeId = config.nodeId;
  }

  @override
  Future<SyncRecord?> findById(String collection, String id) async =>
      _records[collection]?[id];

  @override
  Future<List<SyncRecord>> findAll(
    String collection, {
    SyncQuery? query,
  }) async =>
      (_records[collection]?.values ?? const <SyncRecord>[])
          .where((SyncRecord r) => !r.isDeleted)
          .toList();

  @override
  Future<void> upsert(SyncRecord record) async {
    _records.putIfAbsent(record.collection, () => <String, SyncRecord>{})[
        record.id] = record;
  }

  @override
  Future<void> delete(String collection, String id) async {
    final SyncRecord? prev = _records[collection]?[id];
    if (prev != null) {
      _records[collection]![id] = prev.copyWith(
        isDeleted: true,
        updatedAt: DateTime.now().toUtc(),
      );
    }
  }

  @override
  Stream<SyncStoreEvent> watch(String collection, {SyncQuery? query}) =>
      const Stream<SyncStoreEvent>.empty();

  @override
  Future<SyncMetadata> getMetadata(String collection) async =>
      _meta[collection] ??
      SyncMetadata.empty(collection: collection, nodeId: _nodeId);

  @override
  Future<void> setMetadata(String collection, SyncMetadata metadata) async {
    _meta[collection] = metadata;
  }

  @override
  Future<void> runMigration(SyncStoreMigration migration) async {
    await migration.up(this);
  }

  @override
  Future<void> dispose() async {
    _records.clear();
  }
}
