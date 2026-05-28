// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 The FlutterSync Authors. All rights reserved.

import 'dart:async';

import 'package:workmanager/workmanager.dart';

import '../background_sync.dart';

/// Android implementation of [BackgroundSync] backed by `workmanager`.
///
/// The plugin schedules a `PeriodicWorkRequest` whose isolate-friendly
/// callback is registered with [Workmanager.initialize] at app launch.
/// The host application is responsible for invoking [Workmanager.initialize]
/// once in `main()` with a top-level entry-point function annotated with
/// `@pragma('vm:entry-point')`.
///
/// Constraints exposed in [BackgroundSyncConfig] map to `WorkManager`'s
/// [Constraints]:
///
/// | FlutterSync flag         | WorkManager flag                  |
/// |--------------------------|-----------------------------------|
/// | `requiresNetwork`        | `NetworkType.connected`           |
/// | `requiresCharging`       | `requiresCharging`                |
/// | `requiresBatteryNotLow`  | `requiresBatteryNotLow`           |
/// | `requiresIdle`           | `requiresDeviceIdle`              |
class AndroidBackgroundSync implements BackgroundSync {
  /// Creates an Android background-sync wrapper around [workmanager].
  AndroidBackgroundSync({Workmanager? workmanager})
      : _workmanager = workmanager ?? Workmanager();

  final Workmanager _workmanager;
  String? _registeredTaskName;

  @override
  bool get isSupported => true;

  @override
  Future<void> register({
    required BackgroundSyncConfig config,
    required BackgroundSyncCallback onSync,
  }) async {
    await cancel();
    await _workmanager.registerPeriodicTask(
      config.taskName,
      config.taskName,
      frequency: config.interval < const Duration(minutes: 15)
          ? const Duration(minutes: 15)
          : config.interval,
      constraints: Constraints(
        networkType: config.requiresNetwork
            ? NetworkType.connected
            : NetworkType.not_required,
        requiresCharging: config.requiresCharging,
        requiresBatteryNotLow: config.requiresBatteryNotLow,
        requiresDeviceIdle: config.requiresIdle,
      ),
      existingWorkPolicy: ExistingWorkPolicy.replace,
    );
    _registeredTaskName = config.taskName;
  }

  @override
  Future<void> cancel() async {
    final String? taskName = _registeredTaskName;
    if (taskName != null) {
      await _workmanager.cancelByUniqueName(taskName);
      _registeredTaskName = null;
    }
  }
}
