import 'package:flutter/foundation.dart';
import 'package:superfcm_flutter/src/utils/constants.dart';

final Logger logger = Logger();

enum LogLevel {
  verbose,
  debug,
  info,
  warning,
  error,
}

class Logger {
  LogLevel minLevel;

  Logger({
    this.minLevel = kDefaultLogLevel,
  });

  /// Sets the minimum log level.
  /// Messages below this level will not be logged.
  void setLevel(LogLevel level) {
    minLevel = level;
  }

  /// Log a message at level [LogLevel.verbose].
  /// For highly detailed tracing information that would be too noisy at debug level.
  void v(dynamic message) {
    log(LogLevel.verbose, message);
  }

  /// Log a message at level [LogLevel.debug].
  /// For debugging information useful during development.
  void d(dynamic message) {
    log(LogLevel.debug, message);
  }

  /// Log a message at level [LogLevel.info].
  /// For informational messages about normal application behavior.
  void i(dynamic message) {
    log(LogLevel.info, message);
  }

  /// Log a message at level [LogLevel.warning].
  /// For potentially harmful situations that might lead to problems.
  void w(dynamic message) {
    log(LogLevel.warning, message);
  }

  /// Log a message at level [LogLevel.error].
  /// For errors that prevent normal operation.
  void e(dynamic message) {
    log(LogLevel.error, message);
  }

  /// Log a message with [level].
  void log(LogLevel level, dynamic message) {
    if (level.index >= minLevel.index) {
      final now = DateTime.now();
      final isoTimestamp =
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}.${now.millisecond.toString().padLeft(3, '0')}';
      final logLevel = level.name.substring(0, 1).toUpperCase();
      debugPrint('[SuperFCM] [$isoTimestamp] [$logLevel]: $message');
    }
  }
}
