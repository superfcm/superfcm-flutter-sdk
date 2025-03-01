import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/retry.dart';
import 'package:superfcm_flutter/src/managers/cache_manager.dart';
import 'package:superfcm_flutter/src/managers/connection_manager.dart';
import 'package:superfcm_flutter/src/models/api_response.dart';
import 'package:superfcm_flutter/src/utils/constants.dart';
import 'package:superfcm_flutter/src/utils/http_status.dart';
import 'package:superfcm_flutter/src/utils/logger.dart';
import 'package:superfcm_flutter/src/utils/request_types.dart';
import 'package:superfcm_flutter/superfcm_config.dart';

/// A singleton class that handles API requests to the SuperFCM backend.
///
/// The RequestManager is responsible for:
/// - Making HTTP requests to the SuperFCM API
/// - Handling offline scenarios by caching requests
/// - Managing retries for failed requests based on configuration
/// - Providing a uniform interface for all API interactions
/// - Periodically flushing cached requests when back online
/// - Retrying cached requests when connectivity is restored
class RequestManager {
  static final RequestManager _instance = RequestManager._internal();
  SuperFCMConfig? _config;
  late final http.Client _client;
  bool initialized = false;

  /// Timer for periodic flushing of cached requests
  Timer? _flushTimer;

  /// Internal constructor for the singleton pattern.
  RequestManager._internal();

  /// Provides access to the singleton instance of RequestManager.
  static RequestManager get instance => _instance;

  /// Initializes the RequestManager with the provided configuration.
  ///
  /// Sets up the HTTP client with retry functionality based on the configuration.
  ///
  /// [config] - The SuperFCM configuration object.
  Future<void> initialize(SuperFCMConfig config) async {
    if (initialized) {
      return;
    }
    _config = config;
    _client = RetryClient(
      http.Client(),
      retries: 5,
      when: (response) =>
          _config?.cacheOnOffline == true &&
          (response.statusCode >= 500 ||
              response.statusCode == HttpStatus.tooManyAttempts.code),
      onRetry: (request, response, retryCount) {
        if (response != null) {
          final HttpStatus status = HttpStatus.fromCode(response.statusCode) ??
              HttpStatus.internalServerError;
          final String message =
              response.statusCode == HttpStatus.tooManyAttempts.code
                  ? 'Rate limited'
                  : 'Request failed';
          logger.w(
              '$message on attempt $retryCount (Status: ${response.statusCode} - ${status.name})');
        } else {
          logger.w('Request failed on attempt $retryCount (Status: unknown)');
        }
      },
    );

    // Register callbacks for connection status changes
    ConnectionManager.instance.onConnected(_startPeriodicFlush);
    ConnectionManager.instance.onDisconnected(_stopPeriodicFlush);

    ConnectionManager.instance.onConnected(_retryCachedRequests);
    ConnectionManager.instance.onResume(_retryCachedRequests);
    ConnectionManager.instance.onConnected(flushCachedEvents);

    logger.d('Request Manager initialized');
    initialized = true;
  }

  /// Start a timer to periodically flush cached requests
  void _startPeriodicFlush() {
    _flushTimer?.cancel();
    _flushTimer = Timer.periodic(Duration(minutes: kEventFlushIntervalMinutes),
        (_) async {
      logger.v('Attempting periodic flush of cached requests');
      if (await ConnectionManager.instance.hasConnection()) {
        await _retryCachedRequests();
        await flushCachedEvents();
      }
    });
    logger.d(
        'Started periodic flush timer (interval: $kEventFlushIntervalMinutes mins)');
  }

  /// Stop timer to periodically flush cached requests
  void _stopPeriodicFlush() {
    _flushTimer?.cancel();
    _flushTimer = null;
  }

  Future<bool> _retryCachedRequests() async {
    final List<Map<String, dynamic>> cachedRequests =
        await CacheManager.instance.getItems('requests');

    if (cachedRequests.isEmpty) {
      logger.v('No cached requests to process');
      return true;
    }

    logger.d('Processing ${cachedRequests.length} cached requests');
    for (final Map<String, dynamic> req in cachedRequests) {
      final int id = req['id'];
      final RequestType type =
          RequestType.values.firstWhere((e) => e.toString() == req['type']);
      final String endpoint = req['endpoint'];
      final Map<String, dynamic> data = json.decode(req['data']);

      final int currentTime = DateTime.now().millisecondsSinceEpoch;
      final int timestamp = req['timestamp'];
      data['cacheDuration'] = currentTime - timestamp;

      logger.v('Processing cached request: ${type.toString()} $endpoint');

      await request(type, endpoint, data, false);

      logger.v('Request processed successfully, removing from queue');
      await CacheManager.instance.removeItem('requests', id);
    }
    return true;
  }

  /// Attempts to flush all cached events to the server
  ///
  /// Events are flushed under the following conditions:
  /// - Automatically every [kEventFlushIntervalMinutes] minutes
  /// - When manually called via [SuperFCM.flushEvents()]
  /// - When the device comes back online after being offline
  /// - When the number of cached events reaches [kEventBatchSize]
  ///
  /// Returns true if all events were successfully flushed, false if any failed
  /// or if the device is offline.
  Future<bool> flushCachedEvents() async {
    final List<Map<String, dynamic>> cachedEvents =
        await CacheManager.instance.getItems('events');

    if (cachedEvents.isEmpty) {
      logger.v('No events to flush');
      return true;
    }

    // Check if we have internet connection before attempting to flush
    if (!await ConnectionManager.instance.hasConnection()) {
      logger.d('No internet connection, skipping flush');
      return false;
    }

    logger.d(
        'Flushing ${cachedEvents.length} cached events: ${cachedEvents.map((e) => e['name']).join(', ')}');

    final int currentTime = DateTime.now().millisecondsSinceEpoch;
    int processedCount = 0;

    while (processedCount < cachedEvents.length) {
      final List<Map<String, dynamic>> eventBatch = [];

      final int endIndex =
          (processedCount + kEventBatchSize < cachedEvents.length)
              ? processedCount + kEventBatchSize
              : cachedEvents.length;

      final List<Map<String, dynamic>> currentBatch =
          cachedEvents.sublist(processedCount, endIndex);

      for (final Map<String, dynamic> event in currentBatch) {
        final int timestamp = event['timestamp'];
        final int cacheDuration = currentTime - timestamp;
        eventBatch.add({
          ...event,
          'cacheDuration': cacheDuration,
        });
      }

      await request(
        RequestType.post,
        'events',
        {'events': eventBatch},
        false,
      );

      for (final Map<String, dynamic> event in currentBatch) {
        await CacheManager.instance.removeItem('events', event['id']);
      }
      processedCount += currentBatch.length;
    }

    logger.d('Finished flushing events');
    return true;
  }

  Future<void> dispose() async {
    _stopPeriodicFlush();
    _client.close();
    ConnectionManager.instance.dispose();
  }

  /// Sends an HTTP request to the SuperFCM API.
  ///
  /// Handles device connectivity checks and caching of requests when offline.
  ///
  /// [type] - The HTTP method to use (GET, POST, PATCH, DELETE)
  /// [endpoint] - The API endpoint to call
  /// [data] - The request body data (for POST, PATCH)
  /// [cacheOnOffline] - Whether to cache the request if the device is offline
  ///
  /// Returns an ApiResponse object with proper request status (success, cached, or error).
  Future<ApiResponse> request(
    RequestType type,
    String endpoint, [
    Map<String, dynamic> data = const {},
    bool cacheOnOffline = true,
  ]) async {
    logger.v('Making ${type.name.toUpperCase()} request to $endpoint');
    if (!await ConnectionManager.instance.hasConnection()) {
      logger.d("Device is offline");
      if (cacheOnOffline) {
        logger.d("Caching request");
        await _cacheRequest(type, endpoint, data);
        return ApiResponse.cached(data);
      } else {
        logger.v("Request not cached due to cacheOnOffline=false");
        return ApiResponse.networkError(
            message: "Device offline and caching disabled");
      }
    }
    try {
      final ApiResponse? result = await _executeRequest(type, endpoint, data);
      logger.v("Successfully executed request");
      return result ??
          ApiResponse.unknownError(
              message: "Unknown error during request execution");
    } catch (e) {
      logger.e('Request failed: $e');
      if (cacheOnOffline && _isNetworkError(e)) {
        logger.d("Caching request due to network error: ${e.toString()}");
        await _cacheRequest(type, endpoint, data);
        return ApiResponse.cached(data);
      }
      return ApiResponse.networkError(message: e.toString());
    }
  }

  /// Executes the actual HTTP request.
  ///
  /// [type] - The HTTP method to use
  /// [endpoint] - The API endpoint to call, without the base URL or app ID prefix.
  /// [data] - The request body data
  ///
  /// Returns an ApiResponse if successful, null otherwise.
  Future<ApiResponse?> _executeRequest(
    RequestType type,
    String endpoint,
    Map<String, dynamic> data,
  ) async {
    final Uri uri = Uri.https(
      kApiAuthority,
      '$kApiVersion/apps/${_config?.appId}/$endpoint',
    );
    logger.v('Querying $uri with data: $data');
    try {
      final httpResponse = await _client
          .send(http.Request(type.name.toUpperCase(), uri)
            ..headers['Content-Type'] = 'application/json'
            ..body = json.encode(data))
          .timeout(kRequestTimeout)
          .then(http.Response.fromStream);
      final status =
          HttpStatus.fromCode(httpResponse.statusCode) ?? HttpStatus.unknown;
      // Log appropriate message based on status code range
      if (httpResponse.statusCode >= 200 && httpResponse.statusCode < 300) {
        logger
            .v('Request succeeded with status ${status.code} (${status.name})');
      } else if (httpResponse.statusCode >= 400 &&
          httpResponse.statusCode < 500) {
        logger.v(
            'Client error on request $uri and data $data with status ${status.code} (${status.name}): ${httpResponse.body}');
      } else if (httpResponse.statusCode >= 500) {
        logger.v(
            'Server error on request $uri and data $data with status ${status.code} (${status.name}): ${httpResponse.body}');
      }
      return _parseResponse(httpResponse);
    } catch (e) {
      final String errorContext =
          'Failed to execute ${type.name.toUpperCase()} request to $endpoint';
      logger.e('$errorContext: $e');
      rethrow; // Re-throw to handle in the request method
    }
  }

  /// Caches a request for later execution when the device comes back online.
  ///
  /// [type] - The HTTP method of the request
  /// [endpoint] - The API endpoint of the request
  /// [data] - The request body data
  Future<void> _cacheRequest(
    RequestType type,
    String endpoint,
    Map<String, dynamic> data,
  ) async {
    await CacheManager.instance.addItem('requests', {
      'type': type.toString(),
      'endpoint': endpoint,
      'data': json.encode(data),
    });
    logger.v('Request cached: ${type.name} $endpoint');
  }

  ApiResponse? _parseResponse(http.Response response) {
    final status =
        HttpStatus.fromCode(response.statusCode) ?? HttpStatus.unknown;

    if (response.body.isEmpty) {
      return ApiResponse(httpStatus: status, data: {});
    }

    try {
      final data = json.decode(response.body);
      return ApiResponse(httpStatus: status, data: data);
    } catch (e) {
      logger.e('Failed to parse response body: $e');
      return ApiResponse(httpStatus: status, data: {'raw': response.body});
    }
  }

  ///
  /// This function identifies various network-related exceptions that
  /// could occur during HTTP requests.
  ///
  /// [e] - The exception to check
  ///
  /// Returns true if the exception is network-related, false otherwise.
  bool _isNetworkError(dynamic e) =>
      e is SocketException ||
      e is TimeoutException ||
      e is HandshakeException ||
      e is http.ClientException ||
      e is WebSocketException;
}
