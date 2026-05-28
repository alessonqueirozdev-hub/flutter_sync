// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 The FlutterSync Authors. All rights reserved.

import 'package:flutter_sync/flutter_sync.dart';

import '../models/todo.dart';

/// Thin wrapper that builds a typed [SyncRepository] for the Todo
/// collection so the rest of the example app does not need to know the
/// FlutterSync serializer plumbing.
class TodoRepository {
  /// Creates a repository bound to [flutterSync].
  TodoRepository(FlutterSync flutterSync)
      : repository = flutterSync.repository<Todo>(
          'todos',
          serializer: SyncModelSerializer<Todo>(
            fromJson: Todo.fromJson,
            toJson: (Todo t) => t.toJson(),
          ),
        );

  /// Underlying [SyncRepository] — exposed so the UI layer can read
  /// streams and query directly.
  final SyncRepository<Todo> repository;

  /// Returns every non-deleted Todo.
  Future<List<Todo>> all() => repository.findAll();

  /// Returns a live, reactive stream of Todos.
  Stream<List<Todo>> watchAll() => repository.watch();

  /// Persists [todo] locally and queues a sync.
  Future<void> save(Todo todo) => repository.save(todo);

  /// Marks the Todo identified by [id] as deleted.
  Future<void> delete(String id) => repository.delete(id);
}
