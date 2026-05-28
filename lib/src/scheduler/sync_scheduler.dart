// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 The FlutterSync Authors. All rights reserved.

import 'dart:async';

import 'package:meta/meta.dart';

import '../bandwidth/bandwidth_monitor.dart';
import '../models/network_state.dart';
import '../outbox/outbox_processor.dart';
import 'background_sync.dart';
import 'connectivity_observer.dart';
import 'foreground_sync.dart';

/// Configuration controlling when and how [SyncScheduler] runs sync passes.
@immutable
class SyncSchedulerConfig {
  /// Creates an immutable scheduler configuration.
  const SyncSchedulerConfig({
    this.foregroundInterval = const Duration(seconds: 30),
    this.backgroundInterval = const Duration(minutes: 15),
    this.wifiOnly = false,
    this.pauseWhenBatteryLow = true,
    this.backgroundTaskName = 'flutter_sync_background',
  });

  /// Interval between foreground sync passes.
  final Duration foregroundInterval;

  /// Interval between background sync passes (OS-scheduled).
  final Duration backgroundInterval;

  /// When `true`, sync is skipped on metered networks (mobile data).
  final bool wifiOnly;

  /// When `true`, sync is paused when the OS reports a low-battery state.
  final bool pauseWhenBatteryLow;

  /// Stable identifier registered with the OS background scheduler.
  final String backgroundTaskName;
}

/// Orchestrates foreground + background sync, respecting connectivity and
/// the user's pause/resume controls.
///
/// The scheduler does not perform the actual push/pull work — that lives
/// in [OutboxProcessor] and (later) the engine's pull path. It owns the
/// timing, the network gating, and the bandwidth-aware batch sizing.
class SyncScheduler {
  /// Creates a scheduler wired to the supplied collaborators.
  SyncScheduler({
    required this.config,
    required this.outboxProcessor,
    required this.connectivityObserver,
    required this.bandwidthMonitor,
    BackgroundSync? backgroundSync,
    ForegroundSync? foregroundSync,
  })  : _backgroundSync = backgroundSync ?? createBackgroundSync(),
        _foregroundSync = foregroundSync ??
            ForegroundSync(
              interval: config.foregroundInterval,
              onTick: () async {},
            );

  /// Effective scheduler configuration.
  final SyncSchedulerConfig config;

  /// Outbox processor invoked on every tick.
  final OutboxProcessor outboxProcessor;

  /// Observer used to gate sync on connectivity transitions.
  final ConnectivityObserver connectivityObserver;

  /// Bandwidth monitor consulted for batch-size adaptation.
  final BandwidthMonitor bandwidthMonitor;

  final BackgroundSync _backgroundSync;
  late ForegroundSync _foregroundSync;
  StreamSubscription<NetworkState>? _connectivitySub;
  bool _paused = false;
  bool _started = false;

  /// `true` when the scheduler is currently paused.
  bool get isPaused => _paused;

  /// Starts foreground sync and registers the background task.
  Future<void> start() async {
    if (_started) {
      return;
    }
    _started = true;
    await connectivityObserver.start();
    _connectivitySub =
        connectivityObserver.changes.listen(_onConnectivityChange);

    _foregroundSync = ForegroundSync(
      interval: config.foregroundInterval,
      onTick: _foregroundTick,
    );
    _foregroundSync.start();

    if (_backgroundSync.isSupported) {
      try {
        await _backgroundSync.register(
          config: BackgroundSyncConfig(
            taskName: config.backgroundTaskName,
            interval: config.backgroundInterval,
            requiresNetwork: true,
            requiresBatteryNotLow: config.pauseWhenBatteryLow,
          ),
          onSync: () => _runOnce(source: 'background'),
        );
      } on UnsupportedError {
        // Concrete platform impls are imported explicitly by host apps;
        // the dispatcher proxy throws this when no concrete implementation
        // is wired in. The engine still works through foreground sync.
      }
    }
  }

  /// Forces a sync attempt outside the schedule.
  Future<void> syncNow() => _runOnce(source: 'manual');

  /// Pauses scheduling. The current in-flight pass (if any) continues.
  void pause() {
    _paused = true;
    _foregroundSync.stop();
  }

  /// Resumes scheduling.
  void resume() {
    _paused = false;
    _foregroundSync.start();
  }

  Future<void> _foregroundTick() => _runOnce(source: 'foreground');

  Future<bool> _runOnce({required String source}) async {
    if (_paused) {
      return false;
    }
    final NetworkState state = connectivityObserver.current;
    if (state is NetworkStateNone) {
      return false;
    }
    if (config.wifiOnly && state is NetworkStateMobile) {
      return false;
    }
    final OutboxProcessResult result = await outboxProcessor.processOnce();
    return result.deadLettered == 0;
  }

  void _onConnectivityChange(NetworkState state) {
    bandwidthMonitor.reset(state);
    if (state is! NetworkStateNone && !_paused) {
      unawaited(_runOnce(source: 'connectivity'));
    }
  }

  /// Releases the scheduler's resources.
  Future<void> dispose() async {
    await _connectivitySub?.cancel();
    _connectivitySub = null;
    await _foregroundSync.dispose();
    await _backgroundSync.cancel();
    await connectivityObserver.dispose();
  }
}
