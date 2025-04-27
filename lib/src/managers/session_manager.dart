import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:superfcm_flutter/src/utils/app_lifecycle_observer.dart';
import 'package:superfcm_flutter/src/utils/constants.dart';
import 'package:superfcm_flutter/src/utils/logger.dart';
import 'package:superfcm_flutter/superfcm_config.dart';

/// A class that manages app session tracking.
///
/// This class is responsible for tracking app sessions, including:
/// - Monitoring app lifecycle to detect session boundaries
/// - Determining when to increment the session count
/// - Notifying when sessions change
class SessionManager {
  // Singleton instance
  static final SessionManager _instance = SessionManager._internal();
  static SessionManager get instance => _instance;

  // Private constructor
  SessionManager._internal();

  // Session tracking variables
  DateTime? _lastActiveTimestamp;
  bool _isInBackground = false;
  bool _isInitialized = false;

  // App lifecycle observer
  AppLifecycleObserver? _lifecycleObserver;

  // Config reference
  SuperFCMConfig? _config;

  // Callback for server updates
  Function()? _onSessionCountChanged;

  /// Initializes the session manager.
  ///
  /// Sets up session tracking based on the provided configuration.
  ///
  /// Parameters:
  /// - [config]: The SuperFCM configuration
  /// - [onSessionCountChanged]: Callback to notify when session count changes
  Future<void> initialize(
    SuperFCMConfig config, {
    Function()? onSessionCountChanged,
  }) async {
    if (_isInitialized) {
      logger.d('SessionManager already initialized');
      return;
    }

    _config = config;
    _onSessionCountChanged = onSessionCountChanged;

    // Load the last active timestamp
    final lastTimestamp = await _loadLastActiveTimestamp();

    if (config.autoTrackSessions) {
      if (lastTimestamp != null) {
        final now = DateTime.now();
        // When initializing, we assume the app was fully terminated (not just backgrounded)
        // We only check the inactivity threshold, not the background threshold
        await _checkSessionThresholds(lastTimestamp, now,
            wasInBackground: false);
      } else {
        // If we don't have a lastTimestamp (e.g., first launch or cache was purged)
        // We should still count this as a new session
        logger.d('No previous timestamp found, treating as a new session');
        _notifySessionIncrement();
      }
    }

    // Set up app lifecycle monitoring if enabled
    if (config.autoTrackSessions) {
      _setupLifecycleMonitoring();
    }

    // Update last active timestamp and store it
    _lastActiveTimestamp = DateTime.now();
    await _saveLastActiveTimestamp();

    _isInitialized = true;
    logger.d('SessionManager initialized');
  }

  /// Checks if the time between sessions exceeds either threshold.
  ///
  /// This method is used both during initialization and when the app
  /// is resumed from background to determine if a new session should be started.
  ///
  /// Parameters:
  /// - [lastActiveTime]: The last time the app was active
  /// - [currentTime]: The current time
  /// - [wasInBackground]: Whether the app was in background (vs just inactive)
  Future<void> _checkSessionThresholds(
      DateTime lastActiveTime, DateTime currentTime,
      {bool wasInBackground = false}) async {
    if (_config == null) return;

    final timeSinceLastActive = currentTime.difference(lastActiveTime);
    bool shouldStartNewSession = false;

    // Only check background threshold if the app was actually in background
    if (wasInBackground &&
        timeSinceLastActive >= _config!.sessionBackgroundThreshold) {
      logger.d(
          'App was in background for ${timeSinceLastActive.inSeconds}s, exceeding background threshold of ${_config!.sessionBackgroundThreshold.inSeconds}s');
      shouldStartNewSession = true;
    }

    // Always check inactivity threshold regardless of background state
    if (timeSinceLastActive >= _config!.sessionInactivityThreshold) {
      logger.d(
          'App was inactive for ${timeSinceLastActive.inSeconds}s, exceeding inactivity threshold of ${_config!.sessionInactivityThreshold.inSeconds}s');
      shouldStartNewSession = true;
    }

    if (shouldStartNewSession) {
      logger.d('Starting new session due to threshold(s) exceeded');
      _notifySessionIncrement();
    } else {
      logger.v(
          'Continuing existing session, inactive for ${timeSinceLastActive.inSeconds}s');
    }
  }

  /// Loads the timestamp of the last time the app was active.
  ///
  /// Returns null if there's no saved timestamp.
  Future<DateTime?> _loadLastActiveTimestamp() async {
    logger.v('Loading last active timestamp from storage');
    final prefs = await SharedPreferences.getInstance();
    final timestamp = prefs.getInt(kLastActiveTimestampKey);

    if (timestamp != null) {
      return DateTime.fromMillisecondsSinceEpoch(timestamp);
    }

    return null;
  }

  /// Saves the current active timestamp to SharedPreferences.
  ///
  /// This is called when the app is initialized and when it goes to background
  /// to track when the app was last active.
  Future<void> _saveLastActiveTimestamp() async {
    if (_lastActiveTimestamp != null) {
      logger.v('Saving last active timestamp to storage');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(kLastActiveTimestampKey,
          _lastActiveTimestamp!.millisecondsSinceEpoch);
    }
  }

  /// Sets up app lifecycle monitoring to track sessions.
  ///
  /// Registers callbacks for app lifecycle events to detect when the app
  /// goes to background and returns to foreground, which are used to
  /// determine when to increment the session count.
  void _setupLifecycleMonitoring() {
    logger.d('Setting up app lifecycle monitoring for session tracking');

    // Clean up any existing observer first
    _removeLifecycleObserver();

    // Create and add a new observer
    _lifecycleObserver = AppLifecycleObserver(
      onResume: _handleAppResume,
      onPause: _handleAppPause,
    );

    WidgetsBinding.instance.addObserver(_lifecycleObserver!);
  }

  /// Removes the app lifecycle observer.
  void _removeLifecycleObserver() {
    if (_lifecycleObserver != null) {
      try {
        WidgetsBinding.instance.removeObserver(_lifecycleObserver!);
        _lifecycleObserver = null;
      } catch (e) {
        logger.e('Error removing lifecycle observer: $e');
      }
    }
  }

  /// Handles app resume events.
  ///
  /// When the app is resumed from background, this method checks if it has been
  /// in the background long enough to qualify as a new session, and if so,
  /// notifies about the session increment.
  void _handleAppResume() {
    logger.v('App resumed from background');
    final now = DateTime.now();

    // Check if the app has been inactive long enough to qualify as a new session
    if (_lastActiveTimestamp != null) {
      _checkSessionThresholds(_lastActiveTimestamp!, now,
          wasInBackground: _isInBackground);
    }

    _isInBackground = false;

    // Always update the active timestamp when resuming
    _lastActiveTimestamp = now;
    _saveLastActiveTimestamp(); // Save without waiting
  }

  /// Handles app pause events.
  ///
  /// When the app goes to background, this method records the timestamp
  /// to later determine if a new session should be started when the app resumes.
  void _handleAppPause() {
    logger.v('App paused (going to background)');
    _isInBackground = true;

    // Update last active timestamp when app goes to background
    _lastActiveTimestamp = DateTime.now();
    _saveLastActiveTimestamp(); // Save without waiting
  }

  /// Notifies about the session increment.
  ///
  /// This is called when the conditions for a new session are met.
  void _notifySessionIncrement() {
    logger.i('Session incremented by 1');

    // Notify about the change
    if (_onSessionCountChanged != null) {
      _onSessionCountChanged!();
    }
  }

  /// Cleans up resources used by the session manager.
  ///
  /// This should be called when the session manager is no longer needed.
  Future<void> dispose() async {
    logger.d('Disposing SessionManager');
    _removeLifecycleObserver();
    _onSessionCountChanged = null;
    _isInitialized = false;
  }
}
