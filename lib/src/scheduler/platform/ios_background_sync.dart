// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 The FlutterSync Authors. All rights reserved.

import 'dart:async';

import 'package:background_fetch/background_fetch.dart';

import '../background_sync.dart';

/// iOS implementation of [BackgroundSync] backed by `background_fetch`,
/// which wraps both `BGTaskScheduler` (iOS 13+) and the legacy
/// `performFetchWithCompletionHandler` API.
///
/// The host application's `Info.plist` must include:
///
/// ```xml
/// <key>UIBackgroundModes</key>
/// <array>
///   <string>fetch</string>
///   <string>processing</string>
/// </array>
/// <key>BGTaskSchedulerPermittedIdentifiers</key>
/// <array>
///   <string>com.transistorsoft.fetch</string>
/// </array>
/// ```
///
/// The minimum permitted interval is 15 minutes — values below that are
/// silently clamped up by iOS.
class IOSBackgroundSync implements BackgroundSync {
  /// Creates an iOS background-sync wrapper.
  IOSBackgroundSync();

  bool _registered = false;

  @override
  bool get isSupported => true;

  @override
  Future<void> register({
    required BackgroundSyncConfig config,
    required BackgroundSyncCallback onSync,
  }) async {
    final int minutes = config.interval.inMinutes < 15
        ? 15
        : config.interval.inMinutes;
    final int status = await BackgroundFetch.configure(
      BackgroundFetchConfig(
        minimumFetchInterval: minutes,
        stopOnTerminate: false,
        startOnBoot: true,
        enableHeadless: true,
        requiredNetworkType: config.requiresNetwork
            ? NetworkType.ANY
            : NetworkType.NONE,
        requiresBatteryNotLow: config.requiresBatteryNotLow,
        requiresCharging: config.requiresCharging,
        requiresDeviceIdle: config.requiresIdle,
        requiresStorageNotLow: false,
      ),
      (String taskId) async {
        try {
          await onSync();
        } catch (_) {
          // Swallow; the platform finishes the task regardless of
          // success because we always call `finish` below. The engine
          // itself logs sync failures through `SyncLogger`.
        }
        await BackgroundFetch.finish(taskId);
      },
      (String taskId) async {
        await BackgroundFetch.finish(taskId);
      },
    );
    _registered = status == BackgroundFetch.STATUS_AVAILABLE;
  }

  @override
  Future<void> cancel() async {
    if (!_registered) {
      return;
    }
    await BackgroundFetch.stop();
    _registered = false;
  }
}
