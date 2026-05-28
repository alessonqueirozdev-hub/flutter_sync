// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 The FlutterSync Authors. All rights reserved.

import 'package:flutter_sync/flutter_sync.dart';

import '../models/note.dart';

/// Thin wrapper that builds a typed [SyncRepository] for the Note
/// collection.
class NoteRepository {
  /// Creates a repository bound to [flutterSync].
  NoteRepository(FlutterSync flutterSync)
      : repository = flutterSync.repository<Note>(
          'notes',
          serializer: SyncModelSerializer<Note>(
            fromJson: Note.fromJson,
            toJson: (Note n) => n.toJson(),
          ),
        );

  /// Underlying [SyncRepository].
  final SyncRepository<Note> repository;

  /// Returns every non-deleted Note.
  Future<List<Note>> all() => repository.findAll();

  /// Returns a live, reactive stream of Notes.
  Stream<List<Note>> watchAll() => repository.watch();

  /// Persists [note] locally and queues a sync.
  Future<void> save(Note note) => repository.save(note);

  /// Marks the Note identified by [id] as deleted.
  Future<void> delete(String id) => repository.delete(id);
}
