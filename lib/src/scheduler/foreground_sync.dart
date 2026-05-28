// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 The FlutterSync Authors. All rights reserved.

import 'dart:async';

/// Drives periodic sync attempts while the host app is running in the
/// foreground.
///
/// The class is intentionally minimal: it owns a single `Timer.periodic`,
/// invokes the supplied callback, and reports whether the previous
/// invocation is still in flight (preventing overlapping runs).
class ForegroundSync {
  /// Creates a foreground-sync driver.
  ForegroundSync({
    required this.interval,
    required this.onTick,
  });

  /// Interval between periodic ticks.
  final Duration interval;

  /// Callback executed on every tick. The returned future is awaited so
  /// overlapping invocations are avoided.
  final Future<void> Function() onTick;

  Timer? _timer;
  bool _running = false;
  bool _disposed = false;

  /// `true` when the driver is currently scheduled.
  bool get isActive => _timer != null;

  /// Starts the periodic timer. Safe to call multiple times — extra calls
  /// are no-ops while the driver is already active.
  void start() {
    if (_disposed) {
      throw StateError('ForegroundSync has been disposed.');
    }
    if (_timer != null) {
      return;
    }
    _timer = Timer.periodic(interval, (_) => _tick());
  }

  /// Stops the periodic timer.
  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Triggers a one-shot sync attempt outside the periodic schedule.
  ///
  /// Skipped (no-op) when a previous invocation is still in flight.
  Future<void> kick() => _tick();

  Future<void> _tick() async {
    if (_running) {
      return;
    }
    _running = true;
    try {
      await onTick();
    } finally {
      _running = false;
    }
  }

  /// Releases internal state. After calling [dispose] the driver may not
  /// be reused.
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    stop();
  }
}
