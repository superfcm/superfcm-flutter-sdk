import 'package:json_annotation/json_annotation.dart';

part 'subscription.g.dart';

/// Represents the status of push notification permissions.
///
/// - [denied] - The user has explicitly denied notification permissions
/// - [granted] - The user has granted notification permissions
/// - [undetermined] - The permission status has not been determined yet
enum PermissionStatus { denied, granted, undetermined }

/// Represents the platform type of the device.
///
/// - [android] - Android mobile platform
/// - [ios] - iOS mobile platform
/// - [web] - Web browser platform
enum PlatformType { android, ios, web }

/// Represents a push notification subscription for a device.
///
/// This class contains all metadata associated with a device subscription,
/// including device information, user identification, and notification settings.
@JsonSerializable(explicitToJson: true)
class Subscription {
  /// Unique identifier for the subscription on the SuperFCM platform.
  final String? id;

  /// The date when this device was first registered with SuperFCM.
  final DateTime? dateFirstSeen;

  /// The most recent date when this device connected to SuperFCM.
  final DateTime? dateLastSeen;

  /// The build number of the app installed on the device.
  final int? buildNumber;

  /// The version number of the app installed on the device.
  final String? version;

  /// The country code where the device is located.
  final String? country;

  /// The manufacturer of the device (e.g., "Apple", "Samsung").
  final String? deviceManufacturer;

  /// The model name of the device (e.g., "iPhone 13", "Pixel 6").
  final String? deviceName;

  /// A custom identifier that can be used to link this device to a user account.
  final String? externalId;

  /// The Firebase Cloud Messaging token for this device.
  final String? fcmToken;

  /// The language code set on the device.
  final String? language;

  /// The current notification permission status granted by the user.
  final PermissionStatus? permission;

  /// The platform type of the device.
  final PlatformType? platform;

  /// Custom properties associated with this subscription.
  final Map<String, dynamic>? properties;

  /// Indicates whether this is a test subscription.
  final bool? test;

  /// The timezone where the device is located.
  final String? timezone;

  /// The SuperFCM app ID that owns this subscription.
  final String? appId;

  /// Creates a new Subscription instance.
  ///
  /// Most fields are optional and will be populated by the SuperFCM backend
  /// during registration and updates.
  Subscription({
    this.id,
    this.dateFirstSeen,
    this.dateLastSeen,
    this.buildNumber,
    this.version,
    this.country,
    this.deviceManufacturer,
    this.deviceName,
    this.externalId,
    this.fcmToken,
    this.language,
    this.permission,
    this.platform,
    this.properties,
    this.test,
    this.timezone,
    this.appId,
  });

  /// Creates a Subscription instance from a JSON map.
  ///
  /// This factory constructor is used to deserialize JSON data received from
  /// the SuperFCM API into a Subscription object.
  factory Subscription.fromJson(Map<String, dynamic> json) =>
      _$SubscriptionFromJson(json);

  /// Converts this Subscription instance to a JSON map.
  ///
  /// This method is used to serialize the Subscription object for storage
  /// or transmission to the SuperFCM API.
  Map<String, dynamic> toJson() => _$SubscriptionToJson(this);

  /// Creates a copy of this Subscription instance with the given fields replaced with new values.
  Subscription copyWith({
    String? id,
    DateTime? dateFirstSeen,
    DateTime? dateLastSeen,
    int? buildNumber,
    String? version,
    String? country,
    String? deviceManufacturer,
    String? deviceName,
    String? externalId,
    String? fcmToken,
    String? language,
    PermissionStatus? permission,
    PlatformType? platform,
    Map<String, dynamic>? properties,
    bool? test,
    String? timezone,
    String? appId,
  }) {
    return Subscription(
      id: id ?? this.id,
      dateFirstSeen: dateFirstSeen ?? this.dateFirstSeen,
      dateLastSeen: dateLastSeen ?? this.dateLastSeen,
      buildNumber: buildNumber ?? this.buildNumber,
      version: version ?? this.version,
      country: country ?? this.country,
      deviceManufacturer: deviceManufacturer ?? this.deviceManufacturer,
      deviceName: deviceName ?? this.deviceName,
      externalId: externalId ?? this.externalId,
      fcmToken: fcmToken ?? this.fcmToken,
      language: language ?? this.language,
      permission: permission ?? this.permission,
      platform: platform ?? this.platform,
      properties: properties ?? this.properties,
      test: test ?? this.test,
      timezone: timezone ?? this.timezone,
      appId: appId ?? this.appId,
    );
  }
}
