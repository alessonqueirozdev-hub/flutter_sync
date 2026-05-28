// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 The FlutterSync Authors. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter_sync/flutter_sync.dart';
import 'package:uuid/uuid.dart';

import '../models/todo.dart';
import '../repositories/todo_repository.dart';

/// Screen showing the Todo list using a reactive `SyncRepository<Todo>`
/// watch stream.
class TodoScreen extends StatefulWidget {
  /// Creates the Todo screen bound to [flutterSync].
  const TodoScreen({required this.flutterSync, super.key});

  /// FlutterSync instance used to build the repository.
  final FlutterSync flutterSync;

  @override
  State<TodoScreen> createState() => _TodoScreenState();
}

class _TodoScreenState extends State<TodoScreen> {
  late final TodoRepository _repo;
  final TextEditingController _controller = TextEditingController();
  final Uuid _uuid = const Uuid();

  @override
  void initState() {
    super.initState();
    _repo = TodoRepository(widget.flutterSync);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final String text = _controller.text.trim();
    if (text.isEmpty) {
      return;
    }
    await _repo.save(Todo(id: _uuid.v4(), title: text));
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Todos')),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: 'New todo',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _add(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(onPressed: _add, child: const Text('Add')),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<List<Todo>>(
              stream: _repo.watchAll(),
              builder: (BuildContext context,
                  AsyncSnapshot<List<Todo>> snapshot,) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final List<Todo> todos = snapshot.data!;
                if (todos.isEmpty) {
                  return const Center(child: Text('No todos yet.'));
                }
                return ListView.builder(
                  itemCount: todos.length,
                  itemBuilder: (BuildContext context, int i) {
                    final Todo todo = todos[i];
                    return Dismissible(
                      key: ValueKey<String>(todo.id),
                      onDismissed: (_) => _repo.delete(todo.id),
                      background: Container(color: Colors.red),
                      child: CheckboxListTile(
                        title: Text(
                          todo.title,
                          style: TextStyle(
                            decoration: todo.completed
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                        value: todo.completed,
                        onChanged: (bool? value) => _repo.save(
                          todo.copyWith(completed: value ?? false),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
