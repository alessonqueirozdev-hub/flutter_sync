// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 The FlutterSync Authors. All rights reserved.

import 'package:flutter/material.dart';

import '../audit/audit_trail.dart';
import '../core/flutter_sync.dart';
import 'conflict_log_viewer.dart';
import 'outbox_inspector.dart';
import 'sync_status_overlay.dart';

/// Debug-only drawer-style overlay that exposes the FlutterSync engine
/// state to developers without leaving the host app.
///
/// Wrap your top-level widget at app startup (typically inside a
/// `kDebugMode` guard):
///
/// ```dart
/// runApp(FlutterSyncDevTools(
///   flutterSync: flutterSync,
///   auditTrail: auditTrail,
///   child: MyApp(),
/// ));
/// ```
///
/// Swipe from the right edge of the screen to open the drawer. The drawer
/// has tabs for Status, Outbox, Conflicts, HLC, and Network — each tab is
/// a thin Flutter widget that polls (or streams from) the engine.
class FlutterSyncDevTools extends StatelessWidget {
  /// Wraps [child] with the FlutterSync DevTools drawer.
  const FlutterSyncDevTools({
    required this.flutterSync,
    required this.auditTrail,
    required this.child,
    super.key,
  });

  /// FlutterSync instance to inspect.
  final FlutterSync flutterSync;

  /// Audit trail consulted by the Conflicts tab.
  final AuditTrail auditTrail;

  /// Application widget that the overlay sits on top of.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(
        children: <Widget>[
          child,
          Positioned(
            top: 8,
            right: 8,
            child: SafeArea(child: SyncStatusOverlay(flutterSync: flutterSync)),
          ),
          _DevToolsLauncher(
            flutterSync: flutterSync,
            auditTrail: auditTrail,
          ),
        ],
      ),
    );
  }
}

class _DevToolsLauncher extends StatelessWidget {
  const _DevToolsLauncher({
    required this.flutterSync,
    required this.auditTrail,
  });

  final FlutterSync flutterSync;
  final AuditTrail auditTrail;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 0,
      bottom: 96,
      child: SafeArea(
        child: FloatingActionButton.small(
          heroTag: 'flutter_sync_dev_tools',
          tooltip: 'FlutterSync DevTools',
          onPressed: () => _openPanel(context),
          child: const Icon(Icons.developer_board),
        ),
      ),
    );
  }

  Future<void> _openPanel(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return DefaultTabController(
          length: 3,
          child: FractionallySizedBox(
            heightFactor: 0.85,
            child: Scaffold(
              appBar: AppBar(
                title: const Text('FlutterSync DevTools'),
                automaticallyImplyLeading: false,
                actions: <Widget>[
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
                bottom: const TabBar(
                  tabs: <Widget>[
                    Tab(icon: Icon(Icons.cloud), text: 'Status'),
                    Tab(icon: Icon(Icons.outbox), text: 'Outbox'),
                    Tab(icon: Icon(Icons.merge_type), text: 'Conflicts'),
                  ],
                ),
              ),
              body: TabBarView(
                children: <Widget>[
                  Center(
                    child: SyncStatusOverlay(flutterSync: flutterSync),
                  ),
                  OutboxInspector(flutterSync: flutterSync),
                  ConflictLogViewer(auditTrail: auditTrail),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
