# Changelog

## 0.0.3

### Updated

- Replaced `internet_connection_checker` with `internet_connection_checker_plus` for improved connectivity management.

## 0.0.2

### Fixed

- Bug where database operation would be attempted via the `onConnected` callback in `RequestManager` before `CacheManager` initialization was complete.

## 0.0.1

Initial version
