// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 The FlutterSync Authors. All rights reserved.

import 'package:flutter_sync/flutter_sync.dart';
import 'package:meta/meta.dart';

/// Demo Todo model synced as a FlutterSync record.
@immutable
class Todo implements SyncModel {
  /// Creates an immutable Todo.
  const Todo({
    required this.id,
    required this.title,
    this.completed = false,
    this.priority = 0,
  });

  @override
  final String id;

  /// Human-readable title displayed in the list.
  final String title;

  /// `true` once the user has marked the Todo done.
  final bool completed;

  /// Sort key; higher values surface first.
  final int priority;

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'title': title,
        'completed': completed,
        'priority': priority,
      };

  /// Reconstructs a Todo from JSON.
  factory Todo.fromJson(Map<String, dynamic> json) => Todo(
        id: json['id']! as String,
        title: json['title']! as String,
        completed: (json['completed'] as bool?) ?? false,
        priority: (json['priority'] as int?) ?? 0,
      );

  /// Returns a copy with the supplied fields replaced.
  Todo copyWith({String? title, bool? completed, int? priority}) => Todo(
        id: id,
        title: title ?? this.title,
        completed: completed ?? this.completed,
        priority: priority ?? this.priority,
      );
}
