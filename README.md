# SuperFCM Flutter SDK

[SuperFCM](https://superfcm.com) is a modern, lightweight push notification platform for mobile apps, built on top of Firebase Cloud Messaging (FCM).

It provides a powerful yet intuitive interface to manage subscribers, segment audiences, and send notifications beyond the basics — whether instant, scheduled, event-triggered, or recurring at flexible intervals.

This SDK simplifies the integration of SuperFCM with your Flutter application. While this SDK is entirely optional, it streamlines the integration process compared to using the SuperFCM REST API directly.

## Prerequisites

Before implementing the SDK, please:

1. Register an account at [SuperFCM](https://superfcm.com) and create a new app
2. Complete the setup instructions for [Firebase Cloud Messaging](https://firebase.google.com/docs/cloud-messaging/flutter/client)

**Important:** The SuperFCM Flutter SDK includes Firebase Messaging functionality, so adding the `firebase_messaging` dependency separately to your project is not required.

### Initialization

It's recommended to initialize SuperFCM as early as possible in your app's lifecycle, typically in your `main.dart` file. Always call `initialize()` before making any other requests to SuperFCM:

```dart
import 'package:superfcm_flutter/superfcm_flutter.dart';
import 'package:firebase_core/firebase_core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp();

  // Configure and initialize SuperFCM
  await SuperFCM.instance.initialize(
    SuperFCMConfig(
      // replace with your App ID
      appId: 'your-superfcm-app-id',
    ),
    onOpened: (message) {
      // Handle when app is opened from notification
      print('App opened from message: ${message.data}');
    },
    onForeground: (message) {
      // Handle foreground messages
      print('Received message: ${message.data}');
    },
  );

  runApp(MyApp());
}
```

While awaiting initialization completion is not strictly necessary, there are important behaviors to understand:

- **Requests made before initialization** will be queued and executed once initialization completes
- Queued requests may not be processed in their original order
- If the SDK remains uninitialized throughout the app's lifecycle, queued requests will be discarded when the app terminates

The SDK can initialize offline using previously cached subscription data. Any requests made will be associated with that subscription.

**Note:** First-time users of your app will require a network connection to fully initialize the SDK at least once.

## Core Functionality

### Session Tracking

SuperFCM automatically tracks app sessions to help you understand user engagement patterns. Sessions are monitored based on app lifecycle events and configurable thresholds:

```dart
// Configure session behavior during initialization
final config = SuperFCMConfig(
  appId: 'your-superfcm-app-id',
  // Enable automatic session tracking (default: true)
  autoTrackSessions: true,
  // Set inactivity threshold to consider a new session (default: 30 minutes)
  sessionInactivityThreshold: Duration(minutes: 30),
  // Set background threshold for a new session (default: 30 seconds)
  sessionBackgroundThreshold: Duration(seconds: 30),
);
```

You can also manually override the session count:

```dart
// Set the session count to a specific value
await SuperFCM.instance.setSessionCount(5);
```

Session count is a valuable metric for segmenting your audience and targeting notifications based on user engagement levels.

### Event Tracking

Events can be used to trigger notifications that you've configured in the [SuperFCM Dashboard](https://dashboard.superfcm.com).

Track events for each subscription with a simple call:

```dart
SuperFCM.instance.trackEvent('begin_checkout');
```

**Important considerations:**

- In SuperFCM, events consist of only the event name without additional properties
- SuperFCM does not automatically track any events
- Events are cached locally and transmitted in batches or when connectivity is restored
- You can manually trigger event transmission:

```dart
SuperFCM.instance.flushEvents();
```

Events cached after SDK initialization will persist even if the app terminates and follow the same offline handling rules as other requests. See [Offline Capabilities](#offline-capabilities-caching) for more details.

### Managing Custom Properties

Custom properties enable precise audience segmentation through the [SuperFCM Dashboard](https://dashboard.superfcm.com).

```dart
// Update multiple properties
SuperFCM.instance.updateProperties({
  'hasSubscription': true,
  'totalSpent': 19.99,
  'sessionCount': 25,
  'favoriteCategory': 'electronics',
});

// Update a single property
SuperFCM.instance.setProperty('favoriteCategory', 'electronics');

// Delete multiple properties
SuperFCM.instance.deleteProperties([
  'temporary-flag',
  'old-setting'
]);

// Delete a single property
SuperFCM.instance.deleteProperty('temporary-flag');
```

SuperFCM supports the following value types for custom properties:

- Boolean values
- String values
- Numeric values (integers and doubles)

### Linking External User IDs (Cross-Device Tracking)

To associate a user's identity with their device and link FCM tokens/subscriptions with user accounts:

```dart
SuperFCM.instance.linkExternalId('your-user-id');
```

Best practice is to call `linkExternalId` whenever a user signs into your app. This enables tracking the same user across multiple devices.

Note that linking a user ID doesn't automatically update any custom properties. To update properties, see [Managing Custom Properties](#managing-custom-properties).

### Permission Handling

SuperFCM tracks notification permission status automatically but doesn't request permissions without your explicit command. You can request permissions using:

```dart
SuperFCM.instance.requestPermission(
  alert: true,
  announcement: false,
  badge: true,
  carPlay: false,
  criticalAlert: false,
  provisional: false,
  sound: true,
)
```

The `requestPermission()` method awaits the system permission dialog response and updates the permission status in SuperFCM automatically.

If you handle permissions separately, you can manually update SuperFCM's record of the permission status:

```dart
SuperFCM.instance.updatePermissionStatus(PermissionStatus.authorized);
```

### Test Subscriptions

To designate a device for receiving test notifications:

```dart
SuperFCM.instance.setTest(true);
```

To revert back to normal notification behavior:

```dart
SuperFCM.instance.setTest(false);
```

You can also manage test status directly through the [SuperFCM Dashboard](https://dashboard.superfcm.com).

## Notification Handling

SuperFCM exposes the `RemoteMessage` object from the Firebase Cloud Messaging SDK and uses the same callback pattern.

### Foreground Messages & App Open via Message

Handle both notification scenarios during initialization:

```dart
SuperFCM.instance.initialize(
  config,
  onOpened: (RemoteMessage message) {
    // Handle notification tap and use payload [message.data]
    Navigator.pushNamed(context, message.data['routeName']);
  },
  onForeground: (RemoteMessage message) {
    // Handle foreground message
    if (message.notification != null) {
      print('Received notification: ${message.notification?.title}');
    }
  },
);
```

Or set callbacks after initialization:

```dart
SuperFCM.instance.setOnOpenedCallback((RemoteMessage message) {
  // Handle notification tap and use payload [message.data]
  Navigator.pushNamed(context, message.data['routeName']);
});

SuperFCM.instance.setOnForegroundCallback((RemoteMessage message) {
  // Handle foreground message
  if (message.notification != null) {
    print('Received notification: ${message.notification?.title}');
  }
});
```

### Background Message Handling

Background messages are automatically processed by SuperFCM. The SDK caches received messages and updates their delivery status in the SuperFCM Dashboard when the app next comes online.

For custom background handling:

```dart
SuperFCM.instance.initialize(
  // ...
  onBackground: backgroundHandler,
);
```

Or set the handler after initialization:

```dart
SuperFCM.instance.setOnBackgroundCallback(backgroundHandler);
```

**Important:** When using Flutter 3.3.0 or higher, ensure your background handler is preserved during release mode compilation by adding the `@pragma('vm:entry-point')` annotation:

```dart
@pragma('vm:entry-point')
Future<void> backgroundHandler(RemoteMessage message) async {
  print('New notification received: ${message.notification?.title}');

  // Critical: Call SuperFCM's background handler to ensure
  // delivery tracking works properly
  await SuperFCM.backgroundHandler(message);
}
```

## Technical Details

### Firebase Cloud Messaging Integration

SuperFCM utilizes Firebase Cloud Messaging and operates on a subscription basis using FCM tokens. By default, each device creates a separate subscription in SuperFCM.

When the FCM token changes, SuperFCM automatically updates the subscription with the new token.

While it is technically possible to use Firebase Cloud Messaging alongside SuperFCM, this combination has not been tested.

### Automatic Metadata Collection

SuperFCM collects the following subscription metadata during initialization:

- Location information (timezone and country based on IP address)
- Device language
- Device name and manufacturer details
- Platform type (iOS, Android, or Web)
- App version (string) and build number (integer)
- Notification permission status

### Offline Capabilities & Caching

Once initialized, SuperFCM caches API requests made while offline and retries them when network connectivity returns. By default, requests are cached indefinitely, but you can customize this behavior:

```dart
final config = SuperFCMConfig(
  // Drop any cached requests older than 24 hrs
  maxCacheDuration: Duration(hours: 24),
  // Do not retry any request
  cacheOnOffline: false,
);
SuperFCM.instance.initialize(config);
```

## Support and Resources

> **Note:** Additional resources are currently under construction. In the meantime, please refer to:

- [GitHub Issues](https://github.com/superfcm/superfcm-flutter-sdk/issues)
- [SuperFCM Docs](https://docs.superfcm.com)
- Contact us at [info@superfcm.com](mailto:info@superfcm.com)
