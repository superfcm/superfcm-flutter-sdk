import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:superfcm_flutter/src/utils/logger.dart';
import 'package:superfcm_flutter/superfcm_flutter.dart';

/// Type definition for callback functions handling notification events
typedef NotificationCallback = Future<void> Function(RemoteMessage message);

/// A service class that encapsulates all interactions with Firebase Cloud Messaging.
///
/// This service handles:
/// - Setting up Firebase messaging listeners
/// - Processing foreground, background, and terminated app messages
/// - Managing notification permissions
/// - Managing FCM token refreshes
///
/// By centralizing all Firebase-specific code in this service, we maintain a cleaner
/// separation of concerns and make the codebase more maintainable and testable.
class FirebaseMessagingService {
  // Singleton instance
  static final FirebaseMessagingService _instance =
      FirebaseMessagingService._internal();

  bool initialized = false;

  /// Factory constructor that returns the singleton instance
  factory FirebaseMessagingService() {
    return _instance;
  }

  /// Internal constructor for the singleton pattern
  FirebaseMessagingService._internal();

  /// Provides access to the singleton instance
  static FirebaseMessagingService get instance => _instance;

  // Subscriptions for message streams
  StreamSubscription<RemoteMessage>? _foregroundMessageSubscription;
  StreamSubscription<RemoteMessage>? _openedAppSubscription;
  StreamSubscription<String?>? _tokenSubscription;

  // Callback functions for message events
  NotificationCallback? _onOpenedCallback;
  NotificationCallback? _onForegroundCallback;
  NotificationCallback? _onBackgroundCallback;
  Function(String)? _onTokenRefreshCallback;

  /// Initializes the Firebase Messaging service with callback handlers.
  ///
  /// This method sets up all necessary Firebase message handlers and listeners.
  ///
  /// [onOpened] - Callback for messages that caused the app to open
  /// [onForeground] - Callback for messages received while app is in foreground
  /// [onBackground] - Callback for messages received while app is in background or terminated
  /// [onTokenRefresh] - Callback for FCM token refresh events
  Future<void> initialize({
    NotificationCallback? onOpened,
    NotificationCallback? onForeground,
    NotificationCallback? onBackground,
    Function(String)? onTokenRefresh,
  }) async {
    if (initialized) {
      return;
    }
    _onOpenedCallback = onOpened;
    _onForegroundCallback = onForeground;
    _onBackgroundCallback = onBackground;
    _onTokenRefreshCallback = onTokenRefresh;

    await _setupMessageHandlers();

    // If we have a token refresh callback, set up token monitoring
    if (_onTokenRefreshCallback != null) {
      await setupTokenMonitoring();
    }

    logger.d('Firebase Messaging Service initialized');
    initialized = true;
  }

  /// Sets up all the message handlers for different app states.
  ///
  /// This includes handlers for:
  /// - Foreground messages
  /// - Background messages
  /// - Messages that open the app from a terminated state
  Future<void> _setupMessageHandlers() async {
    // Listen to messages while the app is in the foreground
    _foregroundMessageSubscription =
        FirebaseMessaging.onMessage.listen(_onForegroundCallback);

    // Listen to messages when the app is opened from a terminated state
    await FirebaseMessaging.instance.getInitialMessage().then((message) async {
      if (message != null && _onOpenedCallback != null) {
        await _onOpenedCallback!(message);
      }
    });

    // Listen to messages when the app is in the background but not terminated
    _openedAppSubscription =
        FirebaseMessaging.onMessageOpenedApp.listen(_onOpenedCallback);

    // Register background message handler
    if (_onBackgroundCallback != null) {
      FirebaseMessaging.onBackgroundMessage(_onBackgroundCallback!);
    }
  }

  /// Registers a callback function to handle incoming Firebase Cloud Messaging (FCM)
  /// messages when the app is in the background or terminated.
  ///
  /// The [callback] function will be invoked when a message is received while the
  /// application is not in the foreground or terminated. This method should be
  /// used to handle background notifications and perform any necessary processing.
  ///
  /// The callback function should be a top-level function or a static method.
  ///
  /// [callback] - The function to be called when a background message is received
  void onBackgroundMessage(NotificationCallback callback) =>
      FirebaseMessaging.onBackgroundMessage(callback);

  /// Sets up monitoring for FCM token changes.
  ///
  /// When the token changes, the registered callback is invoked with the new token.
  Future<void> setupTokenMonitoring() async {
    // Cancel any existing subscription first
    await _tokenSubscription?.cancel();

    // Listen for token refreshes
    _tokenSubscription =
        FirebaseMessaging.instance.onTokenRefresh.listen((String? token) {
      if (token != null && _onTokenRefreshCallback != null) {
        logger.d('FCM token refreshed');
        _onTokenRefreshCallback!(token);
      }
    });
  }

  /// Requests the current FCM token.
  ///
  /// Returns the token string if available, null otherwise.
  Future<String?> getToken() async {
    return await FirebaseMessaging.instance.getToken();
  }

  /// Requests push notification permissions from the user.
  ///
  /// This method prompts the user to allow push notifications and returns the result.
  ///
  /// Parameters:
  /// - [alert]: Request permission to display alerts
  /// - [badge]: Request permission to update the app badge
  /// - [sound]: Request permission to play sounds
  /// - [announcement]: Request permission to play announcements
  /// - [carPlay]: Request permission to display notifications in CarPlay
  /// - [criticalAlert]: Request permission for critical alerts
  /// - [provisional]: Request provisional permission (iOS 12+ only)
  ///
  /// Returns the resulting [PermissionStatus].
  Future<PermissionStatus> requestPermission({
    bool alert = true,
    bool announcement = false,
    bool badge = true,
    bool carPlay = false,
    bool criticalAlert = false,
    bool provisional = false,
    bool sound = true,
  }) async {
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: alert,
      announcement: announcement,
      badge: badge,
      carPlay: carPlay,
      criticalAlert: criticalAlert,
      provisional: provisional,
      sound: sound,
    );

    return switch (settings.authorizationStatus) {
      AuthorizationStatus.authorized => PermissionStatus.granted,
      AuthorizationStatus.denied => PermissionStatus.denied,
      AuthorizationStatus.notDetermined => PermissionStatus.undetermined,
      AuthorizationStatus.provisional => PermissionStatus.granted,
    };
  }

  /// Cleans up resources used by the service.
  ///
  /// Cancels all active subscriptions and clears callback references.
  Future<void> dispose() async {
    await _foregroundMessageSubscription?.cancel();
    await _openedAppSubscription?.cancel();
    await _tokenSubscription?.cancel();

    _foregroundMessageSubscription = null;
    _openedAppSubscription = null;
    _tokenSubscription = null;

    _onForegroundCallback = null;
    _onOpenedCallback = null;
    _onTokenRefreshCallback = null;

    logger.d('Firebase Messaging Service disposed');
  }
}
