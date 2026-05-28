// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 The FlutterSync Authors. All rights reserved.

import 'dart:collection';
import 'dart:math' as math;

import '../models/network_state.dart';

/// Single completed push measurement consumed by [BandwidthMonitor].
class BandwidthSample {
  /// Creates a measurement sample.
  const BandwidthSample({
    required this.byteSize,
    required this.duration,
    required this.networkState,
    required this.recordedAt,
  });

  /// Number of bytes transferred.
  final int byteSize;

  /// Wall-clock time the transfer took.
  final Duration duration;

  /// Network state during the transfer.
  final NetworkState networkState;

  /// Instant the measurement was taken.
  final DateTime recordedAt;

  /// Effective throughput in bytes per second; `null` when [duration] is
  /// zero.
  double? get bytesPerSecond => duration.inMicroseconds == 0
      ? null
      : byteSize * 1e6 / duration.inMicroseconds;
}

/// Computes an adaptive batch size from observed transfer throughput and
/// the current [NetworkState].
///
/// The monitor keeps a small rolling window of [BandwidthSample]s per
/// network state. The first three samples after a network change act as
/// calibration probes; afterwards the batch size is computed so each push
/// is expected to complete within [targetDuration]. Hard caps from
/// [SyncSchedulerConfig]-style defaults are also applied so a wildly
/// optimistic measurement cannot blow up the batch size beyond reason.
class BandwidthMonitor {
  /// Creates a monitor with the supplied bounds and target duration.
  BandwidthMonitor({
    this.minBatchSize = 5,
    this.maxBatchSizeWifi = 200,
    this.maxBatchSizeMobile = 25,
    this.maxBatchSizeEthernet = 500,
    this.targetDuration = const Duration(seconds: 2),
    this.windowSize = 8,
    this.averageBytesPerRecord = 1024,
  });

  /// Smallest batch the monitor will ever recommend.
  final int minBatchSize;

  /// Hard cap on the Wi-Fi recommendation.
  final int maxBatchSizeWifi;

  /// Hard cap on the cellular/mobile recommendation.
  final int maxBatchSizeMobile;

  /// Hard cap on the wired/Ethernet recommendation.
  final int maxBatchSizeEthernet;

  /// Target duration for a single push.
  final Duration targetDuration;

  /// Number of samples kept per network state.
  final int windowSize;

  /// Assumed payload size per record when no calibration data is available.
  final int averageBytesPerRecord;

  final Map<String, Queue<BandwidthSample>> _samples =
      <String, Queue<BandwidthSample>>{};

  /// Records [sample] and returns the new recommended batch size for that
  /// network state.
  int recordSample(BandwidthSample sample) {
    final String key = sample.networkState.runtimeType.toString();
    final Queue<BandwidthSample> window =
        _samples.putIfAbsent(key, Queue<BandwidthSample>.new);
    window.addLast(sample);
    while (window.length > windowSize) {
      window.removeFirst();
    }
    return batchSizeFor(sample.networkState);
  }

  /// Discards every sample taken before [networkState] changed.
  void reset(NetworkState networkState) {
    _samples.remove(networkState.runtimeType.toString());
  }

  /// Returns the recommended batch size for [networkState].
  int batchSizeFor(NetworkState networkState) {
    final int hardCap = switch (networkState) {
      NetworkStateNone() => minBatchSize,
      NetworkStateMobile() => maxBatchSizeMobile,
      NetworkStateWifi() => maxBatchSizeWifi,
      NetworkStateEthernet() => maxBatchSizeEthernet,
      NetworkStateVpn() => maxBatchSizeWifi,
      NetworkStateOther() => maxBatchSizeMobile,
    };
    if (networkState is NetworkStateNone) {
      return minBatchSize;
    }
    final Queue<BandwidthSample>? window =
        _samples[networkState.runtimeType.toString()];
    if (window == null || window.isEmpty) {
      return math.max(minBatchSize, math.min(hardCap, 25));
    }
    final double avgThroughput = window
            .map((BandwidthSample s) => s.bytesPerSecond ?? 0)
            .where((double v) => v > 0)
            .fold<double>(0, (double a, double b) => a + b) /
        math.max(1, window.length);
    if (avgThroughput <= 0) {
      return math.max(minBatchSize, math.min(hardCap, 25));
    }
    final double targetBytes =
        avgThroughput * targetDuration.inMilliseconds / 1000.0;
    final int proposed = (targetBytes / averageBytesPerRecord).floor();
    return math.max(minBatchSize, math.min(hardCap, proposed));
  }
}
