import 'dart:async';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:ipapi/ipapi.dart';
import 'package:ipapi/models/geo_data.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:superfcm_flutter/src/utils/logger.dart';

/// String constant for web platform identifier.
const String kPlatformWeb = 'web';

/// String constant for Android platform identifier.
const String kPlatformAndroid = 'android';

/// String constant for iOS platform identifier.
const String kPlatformIOS = 'ios';

/// String constant for denied permission status.
const String kStatusDenied = 'denied';

/// String constant for granted permission status.
const String kStatusGranted = 'granted';

/// String constant for undetermined permission status.
const String kStatusUndetermined = 'undetermined';

/// Utility class for gathering device metadata for push notification subscriptions.
///
/// This class provides methods to collect various pieces of device information
/// that are required when registering for push notifications with SuperFCM.
class SubscriptionMetadata {
  /// Collects geographic and timezone information about the device.
  ///
  /// Attempts to determine:
  /// - The country code based on IP address
  /// - The device's local timezone
  ///
  /// Returns a map containing the available location data.
  /// If any errors occur during data collection, they are logged and
  /// the method returns whatever data was successfully collected.
  static Future<Map<String, dynamic>> _getLocationData() async {
    try {
      final GeoData? geoData = await IpApi.getData(fields: ['countryCode']);
      String timezone = (await FlutterTimezone.getLocalTimezone()).identifier;
      return {
        'timezone': timezone,
        if (geoData?.countryCode != null) 'country': geoData!.countryCode,
      };
    } catch (e) {
      logger.e('Error getting location data: $e');
      return {};
    }
  }

  /// Collects language information from the device.
  ///
  /// Determines the device's configured language code using platform-specific methods.
  /// For web platforms, uses the PlatformDispatcher locale.
  /// For mobile platforms, parses the Platform.localeName.
  ///
  /// Returns a map containing the language code.
  /// If any errors occur during data collection, they are logged and
  /// the method returns an empty map.
  static Future<Map<String, dynamic>> _getLanguageData() async {
    try {
      if (kIsWeb) {
        return {'language': PlatformDispatcher.instance.locale.languageCode};
      }
      final List<String> localeParts = Platform.localeName.split('_');
      return {'language': localeParts[0]};
    } catch (e) {
      logger.e('Error getting language data: $e');
      return {};
    }
  }

  /// Collects platform and device information.
  ///
  /// Gathers details specific to the current platform:
  /// - For Android: platform identifier, device model, and manufacturer
  /// - For iOS: platform identifier, device model, and "Apple" as manufacturer
  /// - For Web: platform identifier and user agent information
  ///
  /// Returns a map containing platform-specific device information.
  /// If any errors occur during data collection, they are logged and
  /// the method returns an empty map.
  static Future<Map<String, dynamic>> _getPlatformData() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        AndroidDeviceInfo info = await deviceInfo.androidInfo;
        return {
          'platform': kPlatformAndroid,
          'deviceName': info.model,
          'deviceManufacturer': info.manufacturer,
        };
      }
      if (Platform.isIOS) {
        IosDeviceInfo info = await deviceInfo.iosInfo;
        return {
          'platform': kPlatformIOS,
          'deviceName': info.model,
          'deviceManufacturer': 'Apple',
        };
      }

      if (kIsWeb) {
        WebBrowserInfo info = await deviceInfo.webBrowserInfo;
        return {
          'platform': kPlatformWeb,
          'name': info.userAgent,
          'manufacturer': info.userAgent,
        };
      }

      return {};
    } catch (e) {
      logger.e('Error getting platform data: $e');
      return {};
    }
  }

  /// Collects information about the application version.
  ///
  /// Retrieves:
  /// - App version (e.g., "1.2.3")
  /// - Build number (e.g., 123)
  ///
  /// Returns a map containing the app version information.
  /// If any errors occur during data collection, they are logged and
  /// the method returns an empty map.
  static Future<Map<String, dynamic>> _getAppData() async {
    try {
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      return {
        'version': packageInfo.version,
        'buildNumber': int.tryParse(packageInfo.buildNumber),
      };
    } catch (e) {
      logger.e('Error getting app data: $e');
      return {};
    }
  }

  /// Checks the current notification permission status.
  ///
  /// Maps the platform-specific permission status to SuperFCM's
  /// standardized permission status values:
  /// - denied: User has denied notifications
  /// - granted: User has allowed notifications
  /// - undetermined: Permission status has not been determined yet
  ///
  /// Returns a map containing the permission status.
  /// If any errors occur during data collection, they are logged and
  /// the method returns an empty map.
  static Future<Map<String, dynamic>> _getPermissionStatus() async {
    try {
      return Permission.notification.status.then((status) => {
            'permission': switch (status) {
              PermissionStatus.denied => kStatusDenied,
              PermissionStatus.granted => kStatusGranted,
              PermissionStatus.permanentlyDenied => kStatusDenied,
              _ => kStatusUndetermined,
            }
          });
    } catch (e) {
      logger.e('Error getting permission status: $e');
      return {};
    }
  }

  /// Collects metadata required for push notification subscription registration.
  ///
  /// Gathers information about:
  /// * Geographic location (country)
  /// * Language preferences
  /// * Platform details
  /// * App version information
  /// * Notification permission status
  ///
  /// Returns a [Map] containing all available metadata.
  /// If any error occurs during data collection, that specific data will be omitted
  /// but the method will still return the successfully collected data.
  static Future<Map<String, dynamic>> get() async {
    final data = <String, dynamic>{};

    data.addAll(await _getLocationData());
    data.addAll(await _getLanguageData());
    data.addAll(await _getPlatformData());
    data.addAll(await _getAppData());
    data.addAll(await _getPermissionStatus());

    return data;
  }
}
