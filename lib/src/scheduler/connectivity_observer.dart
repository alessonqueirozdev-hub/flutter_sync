// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 The FlutterSync Authors. All rights reserved.

import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

import '../models/network_state.dart';

/// Wraps the `connectivity_plus` plugin and exposes a debounced
/// [NetworkState] stream.
///
/// Real-world connectivity events arrive in bursts (e.g. waking from
/// suspend, switching SSIDs) and would otherwise cause the scheduler to
/// react to transient states. The observer waits for a quiet period of
/// [debounce] before forwarding a state change downstream.
class ConnectivityObserver {
  /// Creates a connectivity observer.
  ConnectivityObserver({
    Connectivity? connectivity,
    Duration debounce = const Duration(seconds: 2),
  })  : _connectivity = connectivity ?? Connectivity(),
        _debounce = debounce,
        _controller = StreamController<NetworkState>.broadcast();

  final Connectivity _connectivity;
  final Duration _debounce;
  final StreamController<NetworkState> _controller;

  NetworkState _current = const NetworkStateNone();
  StreamSubscription<List<ConnectivityResult>>? _upstream;
  Timer? _debounceTimer;
  bool _disposed = false;

  /// Broadcast stream of debounced [NetworkState] transitions, including
  /// the initial state.
  Stream<NetworkState> get changes => _controller.stream;

  /// The most recent observed [NetworkState].
  NetworkState get current => _current;

  /// Starts observing connectivity. Safe to call multiple times — extra
  /// calls are no-ops.
  Future<void> start() async {
    if (_disposed) {
      throw StateError('ConnectivityObserver has been disposed.');
    }
    if (_upstream != null) {
      return;
    }
    final List<ConnectivityResult> initial =
        await _connectivity.checkConnectivity();
    _current = _translate(initial);
    _controller.add(_current);
    _upstream =
        _connectivity.onConnectivityChanged.listen(_onConnectivityChange);
  }

  void _onConnectivityChange(List<ConnectivityResult> results) {
    final NetworkState candidate = _translate(results);
    if (candidate == _current) {
      _debounceTimer?.cancel();
      _debounceTimer = null;
      return;
    }
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounce, () {
      _current = candidate;
      _debounceTimer = null;
      if (!_controller.isClosed) {
        _controller.add(_current);
      }
    });
  }

  NetworkState _translate(List<ConnectivityResult> results) {
    if (results.isEmpty || results.every((ConnectivityResult r) => r == ConnectivityResult.none)) {
      return const NetworkStateNone();
    }
    // Highest-fidelity link wins when several are reported simultaneously.
    if (results.contains(ConnectivityResult.ethernet)) {
      return const NetworkStateEthernet();
    }
    if (results.contains(ConnectivityResult.wifi)) {
      return const NetworkStateWifi();
    }
    if (results.contains(ConnectivityResult.vpn)) {
      return const NetworkStateVpn();
    }
    if (results.contains(ConnectivityResult.mobile)) {
      return const NetworkStateMobile();
    }
    return const NetworkStateOther();
  }

  /// Stops the observer and releases its resources.
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _debounceTimer?.cancel();
    await _upstream?.cancel();
    _upstream = null;
    await _controller.close();
  }
}
