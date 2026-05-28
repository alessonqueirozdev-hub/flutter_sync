// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 The FlutterSync Authors. All rights reserved.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../audit/audit_entry.dart';
import '../audit/audit_query.dart';
import '../audit/audit_trail.dart';

/// DevTools tab listing recent conflict resolutions and permanent
/// failures with an "export to clipboard" action.
class ConflictLogViewer extends StatefulWidget {
  /// Creates a viewer reading from [auditTrail].
  const ConflictLogViewer({required this.auditTrail, super.key});

  /// Audit trail providing the entries.
  final AuditTrail auditTrail;

  @override
  State<ConflictLogViewer> createState() => _ConflictLogViewerState();
}

class _ConflictLogViewerState extends State<ConflictLogViewer> {
  late Future<List<AuditEntry>> _future;
  // The subscription is created in `initState` and cancelled in `dispose`
  // — the standard StatefulWidget lifecycle. The lint cannot trace the
  // creation/cancellation across method boundaries, so we suppress it
  // explicitly here.
  // ignore: cancel_subscriptions
  StreamSubscription<AuditEntry>? _streamSub;

  @override
  void initState() {
    super.initState();
    _future = _load();
    _streamSub = widget.auditTrail.stream.listen((_) {
      if (mounted) {
        setState(() {
          _future = _load();
        });
      }
    });
  }

  Future<List<AuditEntry>> _load() => widget.auditTrail.find(
        const AuditQuery().whereOperation(AuditOperation.conflictResolved),
      );

  @override
  void dispose() {
    final StreamSubscription<AuditEntry>? sub = _streamSub;
    if (sub != null) {
      unawaited(sub.cancel());
    }
    super.dispose();
  }

  Future<void> _copyJson(List<AuditEntry> entries) async {
    final String text =
        const JsonEncoder.withIndent('  ').convert(
      <Map<String, Object?>>[for (final AuditEntry e in entries) e.toJson()],
    );
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Conflict log copied to clipboard.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<AuditEntry>>(
      future: _future,
      builder: (BuildContext context, AsyncSnapshot<List<AuditEntry>> snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final List<AuditEntry> entries = snap.data!;
        return Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      '${entries.length} conflict resolution(s)',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  FilledButton.tonalIcon(
                    onPressed:
                        entries.isEmpty ? null : () => _copyJson(entries),
                    icon: const Icon(Icons.copy_outlined, size: 16),
                    label: const Text('Export log'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: entries.isEmpty
                  ? const Center(
                      child: Text(
                        'No conflicts recorded yet.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.separated(
                      itemCount: entries.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (BuildContext context, int i) {
                        final AuditEntry entry = entries[i];
                        return ListTile(
                          leading: const Icon(Icons.merge_type),
                          title: Text(
                            '${entry.collection}/${entry.recordId}',
                            style: const TextStyle(fontFamily: 'monospace'),
                          ),
                          subtitle: Text(
                            'strategy: ${entry.detail?['strategy'] ?? 'unknown'} · '
                            'actor: ${entry.actorNodeId.substring(0, 8)}',
                          ),
                          trailing: Text(
                            entry.occurredAt.toIso8601String().substring(11, 19),
                            style: const TextStyle(fontFamily: 'monospace'),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}
