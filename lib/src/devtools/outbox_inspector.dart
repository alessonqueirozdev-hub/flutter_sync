// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 The FlutterSync Authors. All rights reserved.

import 'package:flutter/material.dart';

import '../core/flutter_sync.dart';
import '../models/sync_debug_info.dart';

/// DevTools tab displaying the engine's outbox state: pending counts,
/// dead-lettered entries, and quick actions.
class OutboxInspector extends StatefulWidget {
  /// Creates an outbox inspector bound to [flutterSync].
  const OutboxInspector({required this.flutterSync, super.key});

  /// FlutterSync instance to query.
  final FlutterSync flutterSync;

  @override
  State<OutboxInspector> createState() => _OutboxInspectorState();
}

class _OutboxInspectorState extends State<OutboxInspector> {
  late Future<SyncDebugInfo> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.flutterSync.debugInfo;
  }

  void _reload() {
    setState(() {
      _future = widget.flutterSync.debugInfo;
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<SyncDebugInfo>(
      future: _future,
      builder: (BuildContext context, AsyncSnapshot<SyncDebugInfo> snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final SyncDebugInfo info = snapshot.data!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      'Pending: ${info.outboxPendingTotal} '
                      '· Failed: ${info.outboxFailedTotal}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: () async {
                      await widget.flutterSync.syncNow();
                      _reload();
                    },
                    icon: const Icon(Icons.sync, size: 16),
                    label: const Text('Flush now'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: _reload,
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Reload'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: info.collections.isEmpty
                  ? const Center(
                      child: Text(
                        'No collections registered yet.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView(
                      children: <Widget>[
                        for (final SyncCollectionStats stats
                            in info.collections.values)
                          ListTile(
                            leading: const Icon(Icons.folder_outlined),
                            title: Text(stats.collection),
                            subtitle: Text(
                              '${stats.records} records · '
                              '${stats.pending} pending · '
                              '${stats.failed} failed',
                            ),
                            trailing: Text(
                              stats.lastSyncedAt == null
                                  ? 'never synced'
                                  : 'HLC ${stats.lastSyncedAt!}',
                              style: const TextStyle(fontFamily: 'monospace'),
                            ),
                          ),
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }
}
