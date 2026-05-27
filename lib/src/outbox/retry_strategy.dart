// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 The FlutterSync Authors. All rights reserved.

import 'dart:math' as math;

import 'package:meta/meta.dart';

/// Strategy that computes the next retry delay given the current attempt
/// count.
///
/// Implementations are intentionally tiny and side-effect-free so they can
/// be unit-tested with deterministic inputs.
abstract interface class RetryStrategy {
  /// Returns the delay until the next retry of an entry whose previous
  /// [attemptCount] attempts have failed.
  ///
  /// `attemptCount` is `1` immediately after the first failure.
  Duration nextDelay(int attemptCount);

  /// The maximum number of attempts allowed before an entry is
  /// dead-lettered.
  int get maxAttempts;
}

/// Exponential-backoff retry with jitter.
///
/// Formula:
///
/// ```
/// delay = min(baseDelay * 2^attemptCount + jitter, maxDelay)
/// jitter = random(0, baseDelay.inMilliseconds)
/// ```
///
/// Defaults match the FlutterSync spec: `baseDelay = 1s`, `maxDelay = 300s`,
/// `maxAttempts = 20`.
@immutable
class ExponentialBackoffRetryStrategy implements RetryStrategy {
  /// Creates an immutable exponential-backoff strategy.
  ExponentialBackoffRetryStrategy({
    this.baseDelay = const Duration(seconds: 1),
    this.maxDelay = const Duration(seconds: 300),
    this.maxAttempts = 20,
    math.Random? random,
  }) : _random = random ?? math.Random();

  /// Initial delay multiplier.
  final Duration baseDelay;

  /// Cap on the computed delay.
  final Duration maxDelay;

  @override
  final int maxAttempts;

  final math.Random _random;

  @override
  Duration nextDelay(int attemptCount) {
    if (attemptCount <= 0) {
      return Duration.zero;
    }
    final int safeAttempt = attemptCount > 30 ? 30 : attemptCount;
    final int multiplier = 1 << safeAttempt;
    final int rawMs = baseDelay.inMilliseconds * multiplier;
    final int jitterMs = _random.nextInt(baseDelay.inMilliseconds + 1);
    final int total = rawMs + jitterMs;
    final int capped = math.min(total, maxDelay.inMilliseconds);
    return Duration(milliseconds: capped);
  }
}

/// Deterministic strategy useful in tests: every retry uses the same
/// fixed [delay], up to [maxAttempts].
@immutable
class ConstantRetryStrategy implements RetryStrategy {
  /// Creates a constant-delay retry strategy.
  const ConstantRetryStrategy({
    required this.delay,
    required this.maxAttempts,
  });

  /// Fixed delay applied between every attempt.
  final Duration delay;

  @override
  final int maxAttempts;

  @override
  Duration nextDelay(int attemptCount) => attemptCount <= 0 ? Duration.zero : delay;
}
