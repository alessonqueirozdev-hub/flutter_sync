// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 The FlutterSync Authors. All rights reserved.

import 'package:meta/meta.dart';

/// High-level network connectivity classification.
///
/// [NetworkState] is a sealed hierarchy emitted by `ConnectivityObserver`
/// and consumed by `SyncScheduler` and `BandwidthMonitor` to drive
/// network-aware behavior (e.g. smaller batches over mobile, no push when
/// offline). Callers must exhaustively pattern match every variant.
@immutable
sealed class NetworkState {
  /// Internal const constructor for subclasses.
  const NetworkState();

  /// Constructs the [NetworkStateNone] singleton (no connectivity).
  const factory NetworkState.none() = NetworkStateNone;

  /// Constructs the [NetworkStateWifi] singleton.
  const factory NetworkState.wifi() = NetworkStateWifi;

  /// Constructs the [NetworkStateMobile] singleton.
  const factory NetworkState.mobile() = NetworkStateMobile;

  /// Constructs the [NetworkStateEthernet] singleton.
  const factory NetworkState.ethernet() = NetworkStateEthernet;

  /// Constructs the [NetworkStateVpn] singleton.
  const factory NetworkState.vpn() = NetworkStateVpn;

  /// Constructs the [NetworkStateOther] singleton.
  const factory NetworkState.other() = NetworkStateOther;

  /// `true` when this network state implies the device has internet access.
  bool get isOnline => this is! NetworkStateNone;

  /// `true` when this network state is considered "metered" — that is, when
  /// the user typically pays per byte and the engine should reduce its data
  /// usage.
  bool get isMetered => this is NetworkStateMobile;
}

/// No-connectivity variant of [NetworkState].
final class NetworkStateNone extends NetworkState {
  /// Const constructor for the singleton-like none state.
  const NetworkStateNone();

  @override
  bool operator ==(Object other) => other is NetworkStateNone;

  @override
  int get hashCode => 100;

  @override
  String toString() => 'NetworkState.none';
}

/// Wi-Fi variant of [NetworkState].
final class NetworkStateWifi extends NetworkState {
  /// Const constructor for the singleton-like Wi-Fi state.
  const NetworkStateWifi();

  @override
  bool operator ==(Object other) => other is NetworkStateWifi;

  @override
  int get hashCode => 101;

  @override
  String toString() => 'NetworkState.wifi';
}

/// Cellular/mobile variant of [NetworkState].
final class NetworkStateMobile extends NetworkState {
  /// Const constructor for the singleton-like mobile state.
  const NetworkStateMobile();

  @override
  bool operator ==(Object other) => other is NetworkStateMobile;

  @override
  int get hashCode => 102;

  @override
  String toString() => 'NetworkState.mobile';
}

/// Wired Ethernet variant of [NetworkState].
final class NetworkStateEthernet extends NetworkState {
  /// Const constructor for the singleton-like Ethernet state.
  const NetworkStateEthernet();

  @override
  bool operator ==(Object other) => other is NetworkStateEthernet;

  @override
  int get hashCode => 103;

  @override
  String toString() => 'NetworkState.ethernet';
}

/// VPN tunnel variant of [NetworkState].
final class NetworkStateVpn extends NetworkState {
  /// Const constructor for the singleton-like VPN state.
  const NetworkStateVpn();

  @override
  bool operator ==(Object other) => other is NetworkStateVpn;

  @override
  int get hashCode => 104;

  @override
  String toString() => 'NetworkState.vpn';
}

/// Catch-all variant for connectivity types the engine does not classify
/// specifically (e.g. Bluetooth tethering).
final class NetworkStateOther extends NetworkState {
  /// Const constructor for the singleton-like other state.
  const NetworkStateOther();

  @override
  bool operator ==(Object other) => other is NetworkStateOther;

  @override
  int get hashCode => 105;

  @override
  String toString() => 'NetworkState.other';
}
