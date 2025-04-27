import 'package:superfcm_flutter/superfcm_flutter.dart';

/// API base URL configuration
///
/// The domain for the SuperFCM API services in Google Cloud Functions
const String kApiAuthority = 'api.superfcm.com';

/// API version path segment
///
/// Used to construct the full API URL path with version information
const String kApiVersion = 'v1';

/// Default request timeout duration
///
/// Requests that take longer than this duration will be cancelled
const Duration kRequestTimeout = Duration(seconds: 5);

/// Subscription storage key
///
/// This key is used to persist subscription information across app restarts
const String kSubscriptionKey = 'superfcm_subscription';

/// Session count storage key
///
/// This key is used to persist the session count across app restarts
const String kSessionCountKey = 'superfcm_session_count';

/// Last active timestamp storage key
///
/// This key is used to persist the timestamp of when the app was last active
const String kLastActiveTimestampKey = 'superfcm_last_active_timestamp';

/// Cache database name
///
/// This database is used to store requests and events when offline
const String kCacheDatabaseName = 'superfcm_cache.db';

/// Cache database version
///
/// Increment this when making changes to the database schema
const int kCacheDatabaseVersion = 1;

/// Event flush interval
///
/// Defines the interval in minutes between automatic event flushes
const int kEventFlushIntervalMinutes = 5;

/// Maximum event batch size
///
/// When processing cached events, they will be sent to the server in batches
/// of this size to avoid overwhelming the network or server
const int kEventBatchSize = 50;

/// Message delivery identifier
///
/// This key is used in the data payload to identify SuperFCM messages
/// and to extract the delivery ID for status updates
const String kDeliveryKey = 'superfcm_delivery_id';

/// Message received status
///
/// Used when updating delivery status for a message that was received
/// while the app was in the foreground
const String kMessageStatusReceived = 'received';

/// Message opened status
///
/// Used when updating delivery status for a message that was tapped
/// by the user to open the app
const String kMessageStatusOpened = 'opened';

/// Endpoints that accept cache duration parameter
///
/// These endpoints will have the cacheDuration field added to the request data
/// when the request is processed after being cached
const List<String> kEndpointsAcceptingCacheDuration = [
  'deliveries',
  'events',
];

/// Default log level
///
/// Sets the minimum log level to display. Messages with levels below this
/// will be suppressed. Set to debug by default to show important information
/// while filtering out verbose messages.
const LogLevel kDefaultLogLevel = LogLevel.debug;
