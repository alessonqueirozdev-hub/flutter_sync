// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 The FlutterSync Authors. All rights reserved.

import 'package:meta/meta.dart';

/// Severity classification used throughout FlutterSync.
enum SyncLogLevel {
  /// Verbose tracing — disabled by default.
  trace,

  /// Diagnostic information useful while developing.
  debug,

  /// Routine engine activity.
  info,

  /// Recoverable abnormal condition.
  warning,

  /// Unrecoverable failure surfaced to the caller.
  error,
}

/// Single log record emitted by `SyncLogger`.
@immutable
class SyncLogRecord {
  /// Creates a log record.
  const SyncLogRecord({
    required this.level,
    required this.message,
    required this.at,
    this.tag,
    this.error,
    this.stackTrace,
    this.context = const <String, Object?>{},
  });

  /// Severity of the record.
  final SyncLogLevel level;

  /// Human-readable message.
  final String message;

  /// Wall-clock instant the record was emitted.
  final DateTime at;

  /// Optional tag (e.g. component name) for filtering.
  final String? tag;

  /// Optional underlying error object.
  final Object? error;

  /// Optional stack trace.
  final StackTrace? stackTrace;

  /// Optional structured context.
  final Map<String, Object?> context;

  @override
  String toString() {
    final StringBuffer buffer = StringBuffer('[${level.name.toUpperCase()}]');
    if (tag != null) {
      buffer.write(' [$tag]');
    }
    buffer.write(' $message');
    if (error != null) {
      buffer.write(' (error: $error)');
    }
    return buffer.toString();
  }
}

/// Contract every FlutterSync logger must implement.
///
/// The library never calls `print` directly; it always routes through a
/// `SyncLogger`. Hosts configure one in `FlutterSync.configure`. The
/// default implementation is `ConsoleLogger`; production apps typically
/// plug in their own implementation (Crashlytics, Datadog, etc.).
abstract interface class SyncLogger {
  /// Emits [record].
  void log(SyncLogRecord record);

  /// Convenience helper for an [SyncLogLevel.trace] message.
  void trace(String message, {String? tag, Map<String, Object?> context});

  /// Convenience helper for an [SyncLogLevel.debug] message.
  void debug(String message, {String? tag, Map<String, Object?> context});

  /// Convenience helper for an [SyncLogLevel.info] message.
  void info(String message, {String? tag, Map<String, Object?> context});

  /// Convenience helper for an [SyncLogLevel.warning] message.
  void warning(
    String message, {
    String? tag,
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?> context,
  });

  /// Convenience helper for an [SyncLogLevel.error] message.
  void error(
    String message, {
    String? tag,
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?> context,
  });
}
