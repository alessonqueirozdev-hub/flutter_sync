// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 The FlutterSync Authors. All rights reserved.

import 'package:flutter_sync/flutter_sync.dart';
import 'package:meta/meta.dart';

/// Demo Note model synced as a FlutterSync record.
@immutable
class Note implements SyncModel {
  /// Creates an immutable Note.
  const Note({
    required this.id,
    required this.title,
    required this.body,
    required this.updatedAt,
  });

  /// Reconstructs a Note from JSON.
  factory Note.fromJson(Map<String, dynamic> json) => Note(
        id: json['id']! as String,
        title: json['title']! as String,
        body: json['body']! as String,
        updatedAt: DateTime.parse(json['updated_at']! as String),
      );

  @override
  final String id;

  /// Short heading shown in the list.
  final String title;

  /// Free-form Markdown body.
  final String body;

  /// Wall-clock instant of the user's most recent local edit.
  final DateTime updatedAt;

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'title': title,
        'body': body,
        'updated_at': updatedAt.toUtc().toIso8601String(),
      };
}
