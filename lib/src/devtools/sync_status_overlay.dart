// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 The FlutterSync Authors. All rights reserved.

import 'package:flutter/material.dart';

import '../core/flutter_sync.dart';
import '../models/sync_status.dart';

/// Compact pill widget that renders the engine's current [SyncStatus] for
/// the Status tab of `FlutterSyncDevTools`.
class SyncStatusOverlay extends StatelessWidget {
  /// Creates a status overlay bound to [flutterSync].
  const SyncStatusOverlay({required this.flutterSync, super.key});

  /// FlutterSync instance to observe.
  final FlutterSync flutterSync;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<SyncStatus>(
      stream: flutterSync.status,
      initialData: const SyncStatus.idle(),
      builder: (BuildContext context, AsyncSnapshot<SyncStatus> snapshot) {
        final SyncStatus status = snapshot.data ?? const SyncStatus.idle();
        return _StatusPill(status: status);
      },
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final SyncStatus status;

  @override
  Widget build(BuildContext context) {
    final (Color color, IconData icon, String label) = switch (status) {
      SyncStatusIdle() => (Colors.grey, Icons.cloud_outlined, 'Idle'),
      SyncStatusSyncing(:final int completed, :final int total) => (
          Colors.blue,
          Icons.sync,
          'Syncing $completed/$total',
        ),
      SyncStatusSynced(:final DateTime at) => (
          Colors.green,
          Icons.cloud_done_outlined,
          'Synced ${_formatRelative(at)}',
        ),
      SyncStatusOffline() => (
          Colors.orange,
          Icons.cloud_off_outlined,
          'Offline',
        ),
      SyncStatusPaused() => (
          Colors.amber,
          Icons.pause_circle_outline,
          'Paused',
        ),
      SyncStatusError(:final String message) => (
          Colors.red,
          Icons.error_outline,
          'Error: $message',
        ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  String _formatRelative(DateTime instant) {
    final Duration delta = DateTime.now().toUtc().difference(instant);
    if (delta.inSeconds < 60) {
      return 'just now';
    }
    if (delta.inMinutes < 60) {
      return '${delta.inMinutes} min ago';
    }
    if (delta.inHours < 24) {
      return '${delta.inHours} h ago';
    }
    return '${delta.inDays} d ago';
  }
}
