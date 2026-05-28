// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 The FlutterSync Authors. All rights reserved.

import 'dart:async';

/// Configuration carried into a background-sync registration.
class BackgroundSyncConfig {
  /// Creates an immutable background-sync configuration.
  const BackgroundSyncConfig({
    required this.taskName,
    required this.interval,
    this.requiresCharging = false,
    this.requiresBatteryNotLow = true,
    this.requiresNetwork = true,
    this.requiresIdle = false,
  });

  /// Stable identifier used by the OS to track the registered task.
  final String taskName;

  /// Desired interval between background sync attempts. Operating systems
  /// may delay execution to align with system maintenance windows; this
  /// value is best-effort.
  final Duration interval;

  /// `true` when the OS should only trigger the task while the device is
  /// charging.
  final bool requiresCharging;

  /// `true` when the OS should only trigger the task while the battery
  /// level is not low.
  final bool requiresBatteryNotLow;

  /// `true` when the OS should only trigger the task when network
  /// connectivity is available.
  final bool requiresNetwork;

  /// `true` when the OS should only trigger the task when the device is
  /// idle.
  final bool requiresIdle;
}

/// Callback invoked by the platform when a scheduled background sync
/// should run.
///
/// Returning `true` signals to the OS that the work completed
/// successfully; `false` lets the OS know it can retry on the next
/// available opportunity.
typedef BackgroundSyncCallback = Future<bool> Function();

/// Common contract every platform-specific background-sync implementation
/// must satisfy.
///
/// Concrete implementations live in `lib/src/scheduler/platform/`:
///
/// - `AndroidBackgroundSync` — `workmanager` `PeriodicWorkRequest`.
/// - `IOSBackgroundSync` — `background_fetch` + `BGTaskScheduler`.
/// - `DesktopBackgroundSync` — in-process `Timer.periodic` driver.
/// - `WebBackgroundSync` — `ServiceWorker` bridge.
///
/// Host applications instantiate the appropriate class directly in their
/// `main()` after detecting the platform (or via a constant chosen at
/// build time). [NoBackgroundSync] is provided as a safe default for
/// builds that do not (yet) wire up a platform-specific implementation.
abstract interface class BackgroundSync {
  /// Registers (or replaces) the background task with the OS scheduler.
  Future<void> register({
    required BackgroundSyncConfig config,
    required BackgroundSyncCallback onSync,
  });

  /// Cancels the registered background task.
  Future<void> cancel();

  /// `true` when the host platform supports background sync.
  bool get isSupported;
}

/// No-op [BackgroundSync] used when the host has not (yet) wired up a
/// platform-specific implementation. Registration is a no-op and
/// [isSupported] returns `false` so callers can degrade gracefully to
/// foreground-only operation.
class NoBackgroundSync implements BackgroundSync {
  /// Const constructor for the singleton-like noop.
  const NoBackgroundSync();

  @override
  bool get isSupported => false;

  @override
  Future<void> register({
    required BackgroundSyncConfig config,
    required BackgroundSyncCallback onSync,
  }) async {}

  @override
  Future<void> cancel() async {}
}

/// Convenience factory that returns the safe [NoBackgroundSync] default.
///
/// Host applications override this by instantiating the concrete
/// platform class directly (e.g. `AndroidBackgroundSync()`) — this avoids
/// pulling unsupported platform plugins into web/desktop builds via
/// runtime checks that would otherwise fail tree shaking.
BackgroundSync createBackgroundSync() => const NoBackgroundSync();
