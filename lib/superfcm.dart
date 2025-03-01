import 'dart:async';
import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:superfcm_flutter/src/managers/cache_manager.dart';
import 'package:superfcm_flutter/src/managers/connection_manager.dart';
import 'package:superfcm_flutter/src/managers/request_manager.dart';
import 'package:superfcm_flutter/src/models/api_response.dart';
import 'package:superfcm_flutter/src/models/subscription.dart';
import 'package:superfcm_flutter/src/services/firebase_messaging_service.dart';
import 'package:superfcm_flutter/src/utils/constants.dart';
import 'package:superfcm_flutter/src/utils/http_status.dart';
import 'package:superfcm_flutter/src/utils/logger.dart';
import 'package:superfcm_flutter/src/utils/request_types.dart';
import 'package:superfcm_flutter/src/utils/subscription_metadata.dart';
import 'package:superfcm_flutter/superfcm_config.dart';

/// Represents a pending operation that requires a subscription
class _PendingOperation {
  final Function() operation;

  _PendingOperation(this.operation);

  Future<void> execute() async {
    await operation();
  }
}

/// A class that manages push notification handling and device subscription management
/// for the SuperFCM service.
///
/// This class follows the singleton pattern and provides methods to:
/// - Initialize the SDK and register device for push notifications
/// - Link external user IDs to device subscriptions
/// - Manage subscription properties
/// - Track and handle notification delivery statuses
/// - Track custom events
/// - Handle notification permissions
///
/// Example:
/// ```dart
/// await SuperFCM.instance.initialize(config);
/// await SuperFCM.instance.linkExternalId('user123');
/// await SuperFCM.instance.setProperty('userType', 'premium');
/// ```
class SuperFCM {
  //
  // STATIC/INSTANCE VARIABLES
  //

  static final SuperFCM _instance = SuperFCM._internal();
  static SuperFCM get instance => _instance;

  //
  // CONFIGURATION VARIABLES
  //

  SuperFCMConfig? _config;
  bool initialized = false;

  //
  // STATE VARIABLES
  //

  Subscription? subscription;
  final List<_PendingOperation> _pendingOperations = [];

  //
  // CALLBACKS
  //

  NotificationCallback? _onOpenedCallback;
  NotificationCallback? _onForegroundCallback;

  //
  // SUPPORTING OBJECTS
  //

  final _prefs = SharedPreferences.getInstance();

  //
  // CONSTRUCTOR/INITIALIZATION METHODS
  //

  SuperFCM._internal();
  factory SuperFCM() => _instance;

  /// Initializes the SuperFCM SDK with the provided configuration.
  ///
  /// This method must be called before using any other SuperFCM functionality.
  /// It performs the following setup:
  /// - Configures logging
  /// - Initializes Firebase Messaging
  /// - Sets up notification handlers
  /// - Loads or creates device subscription
  /// - Processes any pending operations
  ///
  /// Parameters:
  /// - [config]: Configuration settings for SuperFCM
  /// - [onOpened]: Optional callback for notifications that open the app
  /// - [onForeground]: Optional callback for foreground notifications
  /// - [onBackground]: Optional callback for background notifications - must be a top level function
  ///
  /// Returns true if initialization was successful.
  ///
  /// Example:
  /// ```dart
  /// final config = SuperFCMConfig(
  ///   appId: 'your-app-id',
  /// );
  /// await SuperFCM.instance.initialize(
  ///   config,
  ///   onOpened: (message) => print('Opened: ${message.messageId}'),
  ///   onForeground: (message) => print('Received: ${message.messageId}'),
  /// );
  /// ```
  Future<bool> initialize(
    SuperFCMConfig config, {
    NotificationCallback? onOpened,
    NotificationCallback? onForeground,
    NotificationCallback? onBackground,
  }) async {
    logger.i('Initializing SuperFCM');
    if (initialized) {
      logger.d('SuperFCM already initialized');
      return true;
    }

    _config = config;
    _onForegroundCallback = onForeground;
    _onOpenedCallback = onOpened;

    logger.setLevel(config.logLevel);

    await CacheManager.instance.initialize(config);
    await RequestManager.instance.initialize(config);
    await FirebaseMessagingService.instance.initialize(
      onForeground: _handleForegroundMessage,
      onOpened: _handleMessageOpenedApp,
      onBackground: onBackground ?? _superFCMBackgroundHandler,
      onTokenRefresh:
          config.shouldMonitorTokenChange ? _handleTokenChange : null,
    );

    initialized = true;

    logger.d('SuperFCM initialization complete');

    await _getSubscriptionFromCache();

    if (subscription == null) {
      logger.d('No subscription found locally, registering new subscription');
    }

    await _getSubscriptionFromServer();

    if (subscription == null) {
      logger.w('Unable to retrieve subscription from server');
      ConnectionManager.instance.onConnected(_getSubscriptionFromServer);
    }

    if (subscription != null) {
      await _processPendingOperations();
    }

    return initialized;
  }

  /// Cleans up resources used by SuperFCM.
  ///
  /// This should be called when the SuperFCM instance is no longer needed.
  /// Performs the following cleanup:
  /// - Disposes managers and services
  /// - Clears callbacks
  /// - Clears pending operations
  Future<void> dispose() async {
    logger.d('Disposing SuperFCM');
    await RequestManager.instance.dispose();
    await CacheManager.instance.dispose();
    await FirebaseMessagingService.instance.dispose();

    // Clear references
    _onForegroundCallback = null;
    _onOpenedCallback = null;
    _pendingOperations.clear();

    logger.d('SuperFCM disposed');
  }

  //
  // CORE SUBSCRIPTION MANAGEMENT
  //

  /// Attempts to load a saved subscription from local storage.
  ///
  /// Checks SharedPreferences for a cached subscription and deserializes it
  /// if found. Updates the [subscription] property if successful.
  Future<void> _getSubscriptionFromCache() async {
    logger.v('Attempting to load subscription from cache');
    final prefs = await _prefs;
    final storedData = prefs.getString(kSubscriptionKey);
    if (storedData != null && storedData.isNotEmpty) {
      try {
        Map<String, dynamic> data = json.decode(storedData);
        if (data.isNotEmpty) {
          subscription = Subscription.fromJson(data);
          logger.d('Successfully loaded subscription from cache');
          return;
        }
      } catch (e) {
        logger.e('Error loading subscription from cache: $e');
      }
    }
    logger.v('No subscription found in cache');
  }

  /// Saves the current subscription to local storage.
  ///
  /// Serializes and stores the [subscription] in SharedPreferences if it exists.
  /// Does nothing if [subscription] is null.
  Future<void> _storeSubscription() async {
    logger.v('Storing subscription to cache');
    if (subscription != null) {
      await (await _prefs).setString(
        kSubscriptionKey,
        json.encode(subscription?.toJson()),
      );
      logger.v('Successfully stored subscription to cache');
    }
  }

  /// Registers the current device to receive push notifications.
  ///
  /// Creates or updates a subscription for the current device.
  ///
  /// Throws an exception if FCM token cannot be obtained or if the registration fails.
  Future<void> _getSubscriptionFromServer() async {
    try {
      logger.d('Getting subscription from server');
      final fcmToken = await FirebaseMessagingService.instance.getToken();

      if (fcmToken == null) {
        logger.e('Failed to get FCM token');
        throw Exception('Failed to get FCM token');
      }

      logger.v('FCM token obtained: ${fcmToken.substring(0, 8)}...');

      final data = {...await SubscriptionMetadata.get(), 'fcmToken': fcmToken};

      // Request caching is disabled for linking since working with the response is required
      ApiResponse response = await _patch(
        'subscriptions/$fcmToken',
        data,
        false,
      );
      if (response.httpStatus == HttpStatus.notFound) {
        logger.d('Subscription not found, creating new subscription');
        response = await _post('subscriptions', data, false);
      }

      if (response.success) {
        subscription = Subscription.fromJson(response.data);
        await _storeSubscription();
        ConnectionManager.instance.removeConnectedCallback(
          _getSubscriptionFromServer,
        );
        logger.d('Successfully retrieved subscription from server');
        return;
      }

      logger.e("Unable to register subscription");
    } catch (e) {
      logger.e("Error registering subscription: $e");
    }
  }

  /// Links an external user ID to the current device subscription.
  ///
  /// This is useful for cross-platform identification of the same user.
  /// The external ID can be any string that uniquely identifies the user in your system.
  ///
  /// Parameters:
  /// - [externalId]: The external identifier to associate with this device
  ///
  /// Example:
  /// ```dart
  /// await SuperFCM.instance.linkExternalId('user_123');
  /// ```
  Future<bool> linkExternalId(String externalId) async {
    return _queueOrExecute(() async {
      logger.i('Linking external ID: $externalId');

      if (subscription?.externalId == externalId) {
        logger.v('External ID already linked');
        return true;
      }

      final response = await _patch('subscriptions/${subscription!.id}', {
        'externalId': externalId,
      });

      return _handleResponse(
        response,
        'link external ID',
        onSuccess: (response) {
          subscription = Subscription.fromJson(response.data);
          _storeSubscription();
        },
      );
    });
  }

  //
  // PROPERTY MANAGEMENT
  //

  /// Updates multiple subscription properties simultaneously.
  ///
  /// Properties are key-value pairs that can be used to segment users or
  /// customize notification content. This method allows batch updates to properties.
  ///
  /// Parameters:
  /// - [properties]: Map of property names to their values
  ///   - Set a value to null to remove the property
  ///
  /// Example:
  /// ```dart
  /// await SuperFCM.instance.updateProperties({
  ///   'userType': 'premium',
  ///   'lastLogin': DateTime.now().toIso8601String(),
  ///   'oldProperty': null, // This will remove the property
  /// });
  /// ```
  Future<bool> updateProperties(Map<String, dynamic> properties) async {
    return _queueOrExecute(() async {
      logger.d('Updating ${properties.length} properties');
      final response = await _patch(
          'subscriptions/${subscription?.id}',
          {
            'properties': properties,
          },
          _config!.cacheOnOffline);

      return _handleResponse(
        response,
        'update properties',
        onSuccess: (response) {
          if (subscription != null) {
            final Map<String, dynamic> updatedProps = Map<String, dynamic>.from(
              subscription!.properties ?? {},
            );

            // Update or remove properties based on the provided values
            properties.forEach((key, value) {
              if (value == null) {
                updatedProps.remove(key);
              } else {
                updatedProps[key] = value;
              }
            });

            subscription = subscription!.copyWith(properties: updatedProps);
            _storeSubscription();
          }
        },
      );
    });
  }

  /// Updates a single subscription property.
  ///
  /// A more convenient way to update a single property compared to [updateProperties].
  ///
  /// Parameters:
  /// - [key]: The name of the property to update
  /// - [value]: The new value for the property
  ///
  /// Example:
  /// ```dart
  /// await SuperFCM.instance.setProperty('isPremium', true);
  /// ```
  Future<bool> setProperty(String key, dynamic value) async {
    return _queueOrExecute(() async {
      logger.i('Setting property: $key -> $value');
      if (subscription?.properties?[key] == value) {
        logger.v('Property $key already set to $value');
        return true;
      }
      return await updateProperties({key: value});
    });
  }

  /// Deletes multiple properties from the current subscription.
  ///
  /// Parameters:
  /// - [properties]: List of property names to delete
  ///
  /// Example:
  /// ```dart
  /// await SuperFCM.instance.deleteProperties(['temporary', 'oldFeature']);
  /// ```
  Future<bool> deleteProperties(List<String> properties) async {
    return _queueOrExecute(() async {
      logger.d('Deleting properties: ${properties.join(', ')}');
      return await updateProperties(
        Map.fromEntries(properties.map((key) => MapEntry(key, null))),
      );
    });
  }

  /// Deletes a single property from the current subscription.
  ///
  /// A more convenient way to delete a single property compared to [deleteProperties].
  ///
  /// Parameters:
  /// - [property]: The name of the property to delete
  ///
  /// Example:
  /// ```dart
  /// await SuperFCM.instance.deleteProperty('temporary');
  /// ```
  Future<bool> deleteProperty(String property) async {
    return _queueOrExecute(() async {
      logger.d('Deleting property: $property');
      if (!(subscription?.properties?.containsKey(property) ?? false)) {
        logger.v('Property $property does not exist');
        return true;
      }
      return await deleteProperties([property]);
    });
  }

  /// Sets the test flag for the current subscription.
  ///
  /// This marks the subscription as a test subscription, making it available
  /// for segment filtering on the "test" parameter in the SuperFCM dashboard.
  ///
  /// Parameters:
  /// - [value]: Boolean indicating whether this subscription is a test subscription
  ///
  /// Example:
  /// ```dart
  /// // Mark this device as a test device
  /// await SuperFCM.instance.setTest(true);
  /// ```
  Future<bool> setTest(bool value) async {
    return _queueOrExecute(() async {
      logger.i('Setting test subscription status to: $value');
      if (subscription?.test == value) {
        logger.v('Test subscription status already set to $value');
        return true;
      }
      final response = await _patch(
          'subscriptions/${subscription?.id}',
          {
            'test': value,
          },
          _config!.cacheOnOffline);

      return _handleResponse(
        response,
        'set test subscription status',
        onSuccess: (response) {
          subscription = subscription!.copyWith(test: value);
          _storeSubscription();
        },
      );
    });
  }

  /// Updates the push notification permission status for the current subscription.
  ///
  /// Should be called whenever the permission status changes.
  ///
  /// Parameters:
  /// - [status]: Current permission status granted by the user
  ///
  /// Example:
  /// ```dart
  /// final status = await Permission.notification.request();
  /// await SuperFCM.instance.updatePermissionStatus(
  ///   status.isGranted ? PermissionStatus.authorized : PermissionStatus.denied
  /// );
  /// ```
  Future<bool> updatePermissionStatus(PermissionStatus status) async {
    return _queueOrExecute(() async {
      logger.d('Updating permission status to: $status');
      final response = await _patch(
          'subscriptions/${subscription?.id}',
          {
            'permission': status.toString(),
          },
          _config!.cacheOnOffline);
      return _handleResponse(response, 'update permission status');
    });
  }

  //
  // EVENT MANAGEMENT
  //

  /// Logs a custom event with the provided name.
  ///
  /// Events are cached locally and automatically flushed to the server:
  /// - Every [kEventFlushIntervalMinutes] minutes
  /// - When manually calling [flushEvents]
  /// - When the device comes back online after being offline
  /// - When the number of cached events reaches [kEventBatchSize]
  ///
  /// Parameters:
  /// - [name]: The name of the event to track
  ///
  /// Example:
  /// ```dart
  /// await SuperFCM.instance.trackEvent('begin_checkout');
  /// ```
  Future<void> trackEvent(String name) async {
    return _queueOrExecute(() async {
      logger.i('Tracking event: $name');
      await CacheManager.instance.addItem("events", {
        'name': name,
        'subscriptionId': subscription?.id,
      });

      final cachedEvents = await CacheManager.instance.getItems('events');
      if (cachedEvents.length >= kEventBatchSize) {
        logger.d('Event batch size reached, triggering flush');
        await flushEvents();
      }
      logger.v('Successfully tracked event: $name');
    });
  }

  /// Manually triggers a flush of cached events to the server.
  ///
  /// This method attempts to send all cached events to the SuperFCM backend.
  /// If the device is offline, the operation will fail silently and events will
  /// remain cached until the next flush attempt.
  ///
  /// Example:
  /// ```dart
  /// await SuperFCM.instance.flushEvents();
  /// ```
  Future<bool> flushEvents() async {
    return _queueOrExecute(() async {
      logger.d('Flushing cached events');
      bool result = await RequestManager.instance.flushCachedEvents();
      logger.d('Successfully flushed cached events');
      return result;
    });
  }

  //
  // NOTIFICATION HANDLING
  //

  /// Requests push notification permissions from the user.
  ///
  /// This method prompts the user to allow push notifications and returns the result.
  /// The permission status is automatically updated in the subscription.
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
  /// Returns the resulting [NotificationSettings].
  ///
  /// Example:
  /// ```dart
  /// final settings = await SuperFCM.instance.requestPermission(
  ///   alert: true,
  ///   badge: true,
  ///   sound: true,
  /// );
  /// ```
  Future<PermissionStatus> requestPermission({
    bool alert = true,
    bool announcement = false,
    bool badge = true,
    bool carPlay = false,
    bool criticalAlert = false,
    bool provisional = false,
    bool sound = true,
  }) async {
    final status = await FirebaseMessagingService.instance.requestPermission(
      alert: alert,
      announcement: announcement,
      badge: badge,
      carPlay: carPlay,
      criticalAlert: criticalAlert,
      provisional: provisional,
      sound: sound,
    );
    await updatePermissionStatus(status);

    return status;
  }

  /// Sets the callback for notifications that open the app.
  ///
  /// This callback will be called when a notification causes the app to open from
  /// a background or terminated state.
  /// This method allows changing the callback after initialization.
  ///
  /// Parameters:
  /// - [callback]: Function that receives a [RemoteMessage] containing the notification data
  ///
  /// Example:
  /// ```dart
  /// SuperFCM.instance.setOnOpenedCallback((message) {
  ///   print('App opened from notification: ${message.notification?.title}');
  ///   // Navigate to appropriate screen based on notification data
  /// });
  /// ```
  void setOnOpenedCallback(NotificationCallback? callback) {
    logger.d('Setting new onOpened callback');
    _onOpenedCallback = callback;
  }

  /// Sets the callback for foreground notifications.
  ///
  /// This callback will be called when a notification is received while the app is in foreground.
  /// This method allows changing the callback after initialization.
  ///
  /// Parameters:
  /// - [callback]: Function that receives a [RemoteMessage] containing the notification data
  ///
  /// Example:
  /// ```dart
  /// SuperFCM.instance.setOnForegroundCallback((message) {
  ///   print('New notification received: ${message.notification?.title}');
  /// });
  /// ```
  void setOnForegroundCallback(NotificationCallback? callback) {
    logger.d('Setting new onForeground callback');
    _onForegroundCallback = callback;
  }

  /// Sets the callback for background notifications.
  ///
  /// This callback will be called when a notification is received while the app is in the background or terminated.
  /// This method allows changing the callback after initialization.
  ///
  /// Parameters:
  /// - [callback]: Function that receives a [RemoteMessage] containing the notification data
  ///
  /// Example:
  /// ```dart
  /// SuperFCM.instance.setOnBackgroundCallback(backgroundHandler);
  ///
  /// // ...
  ///
  /// // When using Flutter version 3.3.0 or higher, the message handler must be
  /// // annotated with @pragma('vm:entry-point') right above the function declaration
  /// // (otherwise it may be removed during tree shaking for release mode)
  /// @pragma('vm:entry-point')
  /// Future<void> backgroundHandler(RemoteMessage message) async {
  ///   print('New notification received: ${message.notification?.title}');
  /// }
  ///
  /// ```
  void setOnBackgroundCallback(NotificationCallback? callback) {
    logger.d('Setting new onBackground callback');
    FirebaseMessagingService.instance
        .onBackgroundMessage(callback ?? _superFCMBackgroundHandler);
  }

  /// Handles messages received while the app is in the foreground.
  ///
  /// Updates delivery status on the SuperFCM backend and forwards the message
  /// to the registered [_onForegroundCallback] if set.
  ///
  /// Parameters:
  /// - [message]: The received Firebase RemoteMessage
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    logger.d('Received foreground message: ${message.messageId}');

    // Check if this is a SuperFCM message
    final deliveryId = _getDeliveryId(message);
    if (deliveryId != null) {
      // Update delivery status on the server
      await _updateDeliveryStatus(deliveryId, kMessageStatusReceived);
    }

    // Forward to callback if registered
    if (_onForegroundCallback != null) {
      await _onForegroundCallback!(message);
    }

    logger.v('Finished processing foreground message');
  }

  /// Handles messages that caused the app to open from a background/terminated state.
  ///
  /// Updates delivery status on the SuperFCM backend and forwards the message
  /// to the registered [_onOpenedCallback] if set.
  ///
  /// Parameters:
  /// - [message]: The RemoteMessage that opened the app
  Future<void> _handleMessageOpenedApp(RemoteMessage message) async {
    logger.d('App opened from message: ${message.messageId}');

    // Check if this is a SuperFCM message
    final deliveryId = _getDeliveryId(message);
    if (deliveryId != null) {
      // Update delivery status on the server
      await _updateDeliveryStatus(deliveryId, kMessageStatusOpened);
    }

    // Forward to callback if registered
    if (_onOpenedCallback != null) {
      await _onOpenedCallback!(message);
    }

    logger.v('Finished processing opened message');
  }

  /// Extracts the SuperFCM delivery ID from a Firebase RemoteMessage.
  ///
  /// Parameters:
  /// - [message]: The RemoteMessage to extract the delivery ID from
  ///
  /// Returns the delivery ID if present, otherwise null.
  String? _getDeliveryId(RemoteMessage message) {
    if (message.data.containsKey(kDeliveryKey)) {
      return message.data[kDeliveryKey];
    }

    return null;
  }

  /// Handles FCM token changes by updating the subscription on the server.
  ///
  /// Called automatically when the FCM token is refreshed. Updates the subscription
  /// with the new token and saves it to local storage if successful.
  ///
  /// Parameters:
  /// - [newToken]: The new FCM token to register
  Future<void> _handleTokenChange(String newToken) async {
    await _queueOrExecute(() async {
      if (subscription == null || subscription?.fcmToken == newToken) {
        logger.v('Token unchanged or no subscription exists');
        return;
      }

      logger.d('Updating FCM token: ${newToken.substring(0, 8)}...');

      final ApiResponse response = await _patch(
        'subscriptions/${subscription?.id}',
        {'fcmToken': newToken},
        _config!.cacheOnOffline,
      );

      subscription = Subscription.fromJson(response.data);
      await _storeSubscription();
      logger.d('Successfully updated FCM token');
    });
  }

  //
  // UTILITY METHODS
  //

  /// Queues an operation to be executed once a subscription is available.
  ///
  /// If a subscription is already available, executes the operation immediately.
  /// Otherwise, adds it to a queue to be executed when a subscription is established.
  ///
  /// Parameters:
  /// - [operation]: The async operation to execute
  ///
  /// Returns a [Future] that completes when the operation is executed.
  Future<T> _queueOrExecute<T>(Future<T> Function() operation) async {
    if (!initialized) {
      logger.w("SuperFCM not yet initialized, queuing operation");
    }

    if (initialized && subscription != null) {
      return await operation();
    }

    final completer = Completer<T>();

    _pendingOperations.add(
      _PendingOperation(() async {
        try {
          T result = await operation();
          completer.complete(result);
        } catch (e) {
          logger.e('Error executing pending operation: $e');
          completer.completeError(e);
        }
      }),
    );

    logger.v(
      'Operation queued (${_pendingOperations.length} pending operations)',
    );

    return completer.future;
  }

  /// Processes all pending operations that were waiting for a subscription.
  ///
  /// Called automatically when a subscription becomes available. Executes all
  /// queued operations and handles any errors that occur during execution.
  Future<void> _processPendingOperations() async {
    if (_pendingOperations.isEmpty) {
      return;
    }

    logger.d('Processing ${_pendingOperations.length} pending operations');

    final operations = List<_PendingOperation>.from(_pendingOperations);
    _pendingOperations.clear();

    for (final operation in operations) {
      try {
        await operation.execute();
      } catch (e) {
        logger.e('Error executing pending operation: $e');
      }
    }

    logger.d('Successfully processed pending operations');
  }

  /// Handles API responses and provides consistent logging based on the response type.
  ///
  /// This utility method centralizes response handling across all SuperFCM methods.
  /// It logs appropriate messages and returns a boolean indicating success.
  ///
  /// Parameters:
  /// - [response]: The ApiResponse to process
  /// - [actionName]: A descriptive name of the action being performed (for logging)
  /// - [onSuccess]: Optional callback function when response is successful
  ///
  /// Returns:
  /// - true if the request was successful or cached
  /// - false if there was an error
  bool _handleResponse(
    ApiResponse response,
    String actionName, {
    void Function(ApiResponse response)? onSuccess,
  }) {
    switch (response.requestStatus) {
      case RequestStatus.success:
        logger.d('Successfully $actionName');
        if (onSuccess != null) onSuccess(response);
        return true;

      case RequestStatus.cached:
        logger.d(
          '$actionName request cached for later execution (device offline)',
        );
        return true;

      case RequestStatus.clientError:
        logger.w(
          'Failed to $actionName: Client error (${response.httpStatus.code})',
        );
        return false;

      case RequestStatus.serverError:
        logger.w(
          'Failed to $actionName: Server error (${response.httpStatus.code})',
        );
        return false;

      case RequestStatus.networkError:
        logger.w('Failed to $actionName: Network error');
        return false;

      case RequestStatus.unknownError:
        logger.w('Failed to $actionName: Unknown error');
        return false;
    }
  }

  /// Updates the delivery status of a specific notification.
  ///
  /// Parameters:
  /// - [deliveryId]: The unique identifier of the delivery to update
  /// - [status]: The new status to set for the delivery
  Future<bool> _updateDeliveryStatus(String deliveryId, String status) async {
    return _queueOrExecute(() async {
      logger.d('Updating delivery status: $deliveryId -> $status');
      final response = await _patch(
          'deliveries/$deliveryId',
          {
            'status': status,
          },
          _config!.cacheOnOffline);
      return _handleResponse(
        response,
        'update delivery status for $deliveryId',
      );
    });
  }

  /// Sends a POST request to the SuperFCM API.
  ///
  /// Parameters:
  /// - [endpoint]: API endpoint without base URL or app ID prefix
  /// - [data]: Request body data
  /// - [shouldCache]: Whether to cache failed requests for retry (default: true)
  ///
  /// Returns an [ApiResponse] if successful, null otherwise.
  Future<ApiResponse> _post(
    String endpoint,
    Map<String, dynamic> data, [
    bool shouldCache = true,
  ]) =>
      RequestManager.instance.request(
        RequestType.post,
        endpoint,
        data,
        shouldCache,
      );

  /// Sends a PATCH request to the SuperFCM API.
  ///
  /// Parameters:
  /// - [endpoint]: API endpoint without base URL or app ID prefix
  /// - [data]: Request body data
  /// - [shouldCache]: Whether to cache failed requests for retry (default: true)
  ///
  /// Returns an [ApiResponse] if successful, null otherwise.
  Future<ApiResponse> _patch(
    String endpoint,
    Map<String, dynamic> data, [
    bool shouldCache = true,
  ]) =>
      RequestManager.instance.request(
        RequestType.patch,
        endpoint,
        data,
        shouldCache,
      );

  /// Background function processes messages when the app is in the background or terminated.
  /// Since it runs in a separate isolate, it cannot access the main SuperFCM instance.
  /// Instead, it directly caches delivery status updates to be processed when the app
  /// becomes active again.
  ///
  /// The function:
  /// 1. Checks if the message contains a SuperFCM delivery ID
  /// 2. Opens a direct connection to the cache database
  /// 3. Creates a temporary CacheManager instance
  /// 4. Caches the delivery status update for later processing
  /// 5. Closes the database connection
  ///
  /// Parameters:
  /// - [message]: The Firebase RemoteMessage containing the notification data
  static Future<void> backgroundHandler(RemoteMessage message) async {
    logger.d("Background message received: ${message.data}");

    // Check if this is a SuperFCM message
    if (message.data.containsKey(kDeliveryKey)) {
      final deliveryId = message.data[kDeliveryKey];
      Database? db;

      try {
        db = await openDatabase(
          kCacheDatabaseName,
          version: kCacheDatabaseVersion,
          singleInstance: false,
        );

        // Insert the request directly without using CacheManager
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        await db.insert('requests', {
          'type': RequestType.patch.toString(),
          'endpoint': 'deliveries/$deliveryId',
          'data': json.encode({'status': kMessageStatusReceived}),
          'timestamp': timestamp,
        });

        logger.d(
          'Background delivery status update cached for later processing: $deliveryId',
        );
      } catch (e) {
        logger.e('Error in background message handler: $e');
      } finally {
        // Always close this dedicated connection
        await db?.close();
        logger.v('Background handler completed, database closed');
      }
    }
  }
}

@pragma('vm:entry-point')
Future<void> _superFCMBackgroundHandler(RemoteMessage message) async {
  await SuperFCM.backgroundHandler(message);
}
