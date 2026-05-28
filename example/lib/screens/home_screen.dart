// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 The FlutterSync Authors. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter_sync/flutter_sync.dart';

import 'todo_screen.dart';

/// Home screen displaying the current sync status banner plus quick links
/// into the example collections.
class HomeScreen extends StatelessWidget {
  /// Creates a home screen for [flutterSync].
  const HomeScreen({required this.flutterSync, super.key});

  /// FlutterSync instance to observe.
  final FlutterSync flutterSync;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('FlutterSync Example')),
      body: Column(
        children: <Widget>[
          _StatusBanner(flutterSync: flutterSync),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              children: <Widget>[
                ListTile(
                  leading: const Icon(Icons.check_circle_outline),
                  title: const Text('Todos'),
                  subtitle: const Text('Offline-first task list'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          TodoScreen(flutterSync: flutterSync),
                    ),
                  ),
                ),
                const ListTile(
                  leading: Icon(Icons.note_outlined),
                  title: Text('Notes'),
                  subtitle: Text('Coming soon in this example'),
                  enabled: false,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: FilledButton.icon(
                    onPressed: flutterSync.syncNow,
                    icon: const Icon(Icons.sync),
                    label: const Text('Sync now'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final SyncDebugInfo info = await flutterSync.debugInfo;
                      if (!context.mounted) {
                        return;
                      }
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(info.toString())),
                      );
                    },
                    icon: const Icon(Icons.info_outline),
                    label: const Text('Debug'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.flutterSync});

  final FlutterSync flutterSync;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<SyncStatus>(
      stream: flutterSync.status,
      initialData: const SyncStatus.idle(),
      builder: (BuildContext context, AsyncSnapshot<SyncStatus> snapshot) {
        final SyncStatus status = snapshot.data ?? const SyncStatus.idle();
        final (Color color, String label) = switch (status) {
          SyncStatusIdle() => (Colors.grey, 'Idle'),
          SyncStatusSyncing() => (Colors.blue, 'Syncing'),
          SyncStatusSynced() => (Colors.green, 'Synced'),
          SyncStatusOffline() => (Colors.orange, 'Offline'),
          SyncStatusPaused() => (Colors.amber, 'Paused'),
          SyncStatusError(:final String message) => (Colors.red, message),
        };
        return Container(
          width: double.infinity,
          color: color.withValues(alpha: 0.12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.w600),
          ),
        );
      },
    );
  }
}
