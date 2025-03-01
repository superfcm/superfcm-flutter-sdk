import 'package:superfcm_flutter/src/utils/logger.dart';

/// Configuration class for SuperFCM
class SuperFCMConfig {
  /// The unique application identifier for SuperFCM.
  ///
  /// This ID is associated with your SuperFCM account and is used to identify
  /// your application when sending push notifications. It can be found in your
  /// SuperFCM dashboard.
  final String appId;

  /// Whether to monitor FCM token changes.
  ///
  /// If set to false any changed token must be passed manually to refreshToken().
  /// Note that any token change identified while offline will not be retried and
  /// that monitoring for token changes will only start after identify() has been
  /// called.
  final bool shouldMonitorTokenChange;

  /// Whether to cache requests that were made offline.
  ///
  /// If set to false SuperFCM will not retry any requests.
  final bool cacheOnOffline;

  /// Duration for how long to retain attempts for retry.
  ///
  /// If set to null, requests will be retried indefinitely.
  final Duration? maxCacheDuration;

  /// The minimum log level to display.
  ///
  /// Logs with a level lower than this will not be shown.
  /// Defaults to Level.info.
  final LogLevel logLevel;

  const SuperFCMConfig({
    required this.appId,
    this.shouldMonitorTokenChange = true,
    this.cacheOnOffline = true,
    this.maxCacheDuration,
    this.logLevel = LogLevel.info,
  });
}
