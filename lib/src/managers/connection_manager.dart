import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';
import 'package:superfcm_flutter/src/utils/logger.dart';

/// A singleton class that manages and monitors internet connectivity status.
///
/// The [ConnectionManager] provides functionality to:
/// - Monitor device's internet connection status
/// - Notify listeners when connection status changes
/// - Provide current connection status
/// - Handle app lifecycle changes
class ConnectionManager with WidgetsBindingObserver {
  static final ConnectionManager _instance = ConnectionManager._internal();

  /// Subscription to the internet connection status stream
  StreamSubscription<bool>? _isConnected;

  /// Callbacks for connection status changes
  final List<void Function()> _onConnectedCallbacks = [];
  final List<void Function()> _onDisconnectedCallbacks = [];
  final List<void Function()> _onResumeCallbacks = [];

  /// Factory constructor that returns the singleton instance
  factory ConnectionManager() {
    return _instance;
  }

  ConnectionManager._internal() {
    WidgetsBinding.instance.addObserver(this);
    _isConnected = InternetConnectionChecker.instance.onStatusChange
        .map((c) => c == InternetConnectionStatus.connected)
        .listen((isConnected) async {
      if (isConnected) {
        logger.d('Device is online');
        _notifyConnected();
      } else {
        logger.d('Device is offline');
        _notifyDisconnected();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _notifyResume();
    }
  }

  /// Provides access to the singleton instance of [ConnectionManager]
  static ConnectionManager get instance => _instance;

  /// Register a callback function to be called when the device connects to the internet
  void onConnected(void Function() callback) {
    _onConnectedCallbacks.add(callback);
    logger
        .v('Added connected callback, total: ${_onConnectedCallbacks.length}');
  }

  /// Register a callback function to be called when the device disconnects from the internet
  void onDisconnected(void Function() callback) {
    _onDisconnectedCallbacks.add(callback);
    logger.v(
        'Added disconnected callback, total: ${_onDisconnectedCallbacks.length}');
  }

  /// Register a callback function to be called when the app is resumed
  void onResume(void Function() callback) {
    _onResumeCallbacks.add(callback);
    logger.v('Added resume callback, total: ${_onResumeCallbacks.length}');
  }

  /// Removes a previously registered connected callback
  void removeConnectedCallback(void Function() callback) {
    _onConnectedCallbacks.remove(callback);
    logger.v(
        'Removed connected callback, remaining: ${_onConnectedCallbacks.length}');
  }

  /// Removes a previously registered disconnected callback
  void removeDisconnectedCallback(void Function() callback) {
    _onDisconnectedCallbacks.remove(callback);
    logger.v(
        'Removed disconnected callback, remaining: ${_onDisconnectedCallbacks.length}');
  }

  /// Removes a previously registered resume callback
  void removeResumeCallback(void Function() callback) {
    _onResumeCallbacks.remove(callback);
    logger
        .v('Removed resume callback, remaining: ${_onResumeCallbacks.length}');
  }

  /// Notifies all registered callbacks when a connection is established
  void _notifyConnected() {
    logger.v('Notifying ${_onConnectedCallbacks.length} connected callbacks');
    for (final callback in _onConnectedCallbacks) {
      callback();
    }
  }

  /// Notifies all registered callbacks when a connection is lost
  void _notifyDisconnected() {
    logger.v(
        'Notifying ${_onDisconnectedCallbacks.length} disconnected callbacks');
    for (final callback in _onDisconnectedCallbacks) {
      callback();
    }
  }

  /// Notifies all registered callbacks when the app is resumed
  void _notifyResume() {
    logger.v('Notifying ${_onResumeCallbacks.length} resume callbacks');
    for (final callback in _onResumeCallbacks) {
      callback();
    }
  }

  /// Check if the device currently has internet connectivity
  Future<bool> hasConnection() async {
    return InternetConnectionChecker.instance.hasConnection;
  }

  Future<void> dispose() async {
    WidgetsBinding.instance.removeObserver(this);
    _isConnected?.cancel();
    _isConnected = null;
    _onConnectedCallbacks.clear();
    _onDisconnectedCallbacks.clear();
    _onResumeCallbacks.clear();
  }
}
