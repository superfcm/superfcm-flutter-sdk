// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'subscription.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Subscription _$SubscriptionFromJson(Map<String, dynamic> json) => Subscription(
      id: json['id'] as String?,
      dateFirstSeen: json['dateFirstSeen'] == null
          ? null
          : DateTime.parse(json['dateFirstSeen'] as String),
      dateLastSeen: json['dateLastSeen'] == null
          ? null
          : DateTime.parse(json['dateLastSeen'] as String),
      buildNumber: (json['buildNumber'] as num?)?.toInt(),
      version: json['version'] as String?,
      country: json['country'] as String?,
      deviceManufacturer: json['deviceManufacturer'] as String?,
      deviceName: json['deviceName'] as String?,
      externalId: json['externalId'] as String?,
      fcmToken: json['fcmToken'] as String?,
      language: json['language'] as String?,
      permission:
          $enumDecodeNullable(_$PermissionStatusEnumMap, json['permission']),
      platform: $enumDecodeNullable(_$PlatformTypeEnumMap, json['platform']),
      properties: json['properties'] as Map<String, dynamic>?,
      test: json['test'] as bool?,
      timezone: json['timezone'] as String?,
      appId: json['appId'] as String?,
    );

Map<String, dynamic> _$SubscriptionToJson(Subscription instance) =>
    <String, dynamic>{
      'id': instance.id,
      'dateFirstSeen': instance.dateFirstSeen?.toIso8601String(),
      'dateLastSeen': instance.dateLastSeen?.toIso8601String(),
      'buildNumber': instance.buildNumber,
      'version': instance.version,
      'country': instance.country,
      'deviceManufacturer': instance.deviceManufacturer,
      'deviceName': instance.deviceName,
      'externalId': instance.externalId,
      'fcmToken': instance.fcmToken,
      'language': instance.language,
      'permission': _$PermissionStatusEnumMap[instance.permission],
      'platform': _$PlatformTypeEnumMap[instance.platform],
      'properties': instance.properties,
      'test': instance.test,
      'timezone': instance.timezone,
      'appId': instance.appId,
    };

const _$PermissionStatusEnumMap = {
  PermissionStatus.denied: 'denied',
  PermissionStatus.granted: 'granted',
  PermissionStatus.undetermined: 'undetermined',
};

const _$PlatformTypeEnumMap = {
  PlatformType.android: 'android',
  PlatformType.ios: 'ios',
  PlatformType.web: 'web',
};
