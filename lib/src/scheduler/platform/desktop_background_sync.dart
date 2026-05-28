// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 The FlutterSync Authors. All rights reserved.

import 'dart:async';

import '../background_sync.dart';

/// Desktop (macOS / Windows / Linux) implementation of [BackgroundSync].
///
/// Desktop platforms do not expose a system-level periodic-task scheduler
/// that survives app termination the way mobile does. The implementation
/// instead drives a `Timer.periodic` while the host process is alive,
/// effectively merging foreground and background scheduling into a single
/// in-process timer with a longer cadence than the foreground driver.
///
/// To run sync while the app is closed, the host application should
/// register a platform-specific task with the user's scheduler — for
/// example a Windows Task Scheduler job or a launchd plist on macOS — and
/// document that in `doc/background_sync.md`.
class DesktopBackgroundSync implements BackgroundSync {
  /// Creates a desktop background-sync driver.
  DesktopBackgroundSync();

  Timer? _timer;

  @override
  bool get isSupported => true;

  @override
  Future<void> register({
    required BackgroundSyncConfig config,
    required BackgroundSyncCallback onSync,
  }) async {
    await cancel();
    _timer = Timer.periodic(config.interval, (_) async {
      try {
        await onSync();
      } catch (_) {
        // Swallowed intentionally — desktop background sync does not have a
        // platform finalizer to report errors to. The engine itself logs.
      }
    });
  }

  @override
  Future<void> cancel() async {
    _timer?.cancel();
    _timer = null;
  }
}
