# Changelog

## 0.1.2

### Updated

- Bumped dependencies to latest versions

## 0.1.1

### Updated

- Bumped `permission_handler` dependency.
- Minor README and code formatting adjustments (no functional changes).

## 0.1.0

### Added

- Support for configurable tracking for user sessions.
- Support for immediate confirmation of notification receipt in background instead of only caching it.

### Fixed

- Resolved potential duplicate message processing in FirebaseMessagingService.
- Resolved an issue where awaiting getInitialMessage would deadlock SuperFCM initialization when opening the app via notification tap.

### Updated

- Removed color formatting from logger output (not compatible with all platforms).
- Improved readme with details about session tracking functionality and corrected default session threshold values.

## 0.0.3

### Updated

- Replaced `internet_connection_checker` with `internet_connection_checker_plus` for improved connectivity management.

## 0.0.2

### Fixed

- Bug where database operation would be attempted via the `onConnected` callback in `RequestManager` before `CacheManager` initialization was complete.

## 0.0.1

Initial version
