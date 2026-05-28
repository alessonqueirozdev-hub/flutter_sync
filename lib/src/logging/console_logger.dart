// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 The FlutterSync Authors. All rights reserved.

import 'dart:developer' as developer;

import 'sync_logger.dart';

/// Default [SyncLogger] implementation that forwards every record to
/// `dart:developer`'s `log()` so it shows up in Flutter DevTools, the
/// terminal, and the host's IDE consoles.
class ConsoleLogger implements SyncLogger {
  /// Creates a console logger that emits records at or above [minLevel].
  ConsoleLogger({this.minLevel = SyncLogLevel.info});

  /// Minimum severity that is forwarded. Records below this level are
  /// silently dropped.
  final SyncLogLevel minLevel;

  @override
  void log(SyncLogRecord record) {
    if (record.level.index < minLevel.index) {
      return;
    }
    developer.log(
      record.message,
      name: record.tag ?? 'flutter_sync',
      level: _developerLevel(record.level),
      error: record.error,
      stackTrace: record.stackTrace,
      time: record.at,
    );
  }

  int _developerLevel(SyncLogLevel level) {
    switch (level) {
      case SyncLogLevel.trace:
        return 300;
      case SyncLogLevel.debug:
        return 500;
      case SyncLogLevel.info:
        return 800;
      case SyncLogLevel.warning:
        return 900;
      case SyncLogLevel.error:
        return 1000;
    }
  }

  @override
  void trace(String message, {String? tag, Map<String, Object?> context = const <String, Object?>{}}) {
    log(SyncLogRecord(
      level: SyncLogLevel.trace,
      message: message,
      at: DateTime.now().toUtc(),
      tag: tag,
      context: context,
    ),);
  }

  @override
  void debug(String message, {String? tag, Map<String, Object?> context = const <String, Object?>{}}) {
    log(SyncLogRecord(
      level: SyncLogLevel.debug,
      message: message,
      at: DateTime.now().toUtc(),
      tag: tag,
      context: context,
    ),);
  }

  @override
  void info(String message, {String? tag, Map<String, Object?> context = const <String, Object?>{}}) {
    log(SyncLogRecord(
      level: SyncLogLevel.info,
      message: message,
      at: DateTime.now().toUtc(),
      tag: tag,
      context: context,
    ),);
  }

  @override
  void warning(
    String message, {
    String? tag,
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?> context = const <String, Object?>{},
  }) {
    log(SyncLogRecord(
      level: SyncLogLevel.warning,
      message: message,
      at: DateTime.now().toUtc(),
      tag: tag,
      error: error,
      stackTrace: stackTrace,
      context: context,
    ),);
  }

  @override
  void error(
    String message, {
    String? tag,
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?> context = const <String, Object?>{},
  }) {
    log(SyncLogRecord(
      level: SyncLogLevel.error,
      message: message,
      at: DateTime.now().toUtc(),
      tag: tag,
      error: error,
      stackTrace: stackTrace,
      context: context,
    ),);
  }
}
