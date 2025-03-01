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

  // ANSI escape codes for colors
  static const String _gray = '\x1B[90m';
  static const String _purple = '\x1B[35m';
  static const String _blue = '\x1B[34m';
  static const String _yellow = '\x1B[33m';
  static const String _red = '\x1B[31m';
  static const String _reset = '\x1B[0m';

  Logger({
    this.minLevel = kDefaultLogLevel,
  });

  /// Sets the minimum log level.
  /// Messages below this level will not be logged.
  void setLevel(LogLevel level) {
    minLevel = level;
  }

  /// Get the color code for a specific log level
  String _getColorForLevel(LogLevel level) {
    switch (level) {
      case LogLevel.verbose:
        return _gray;
      case LogLevel.debug:
        return _purple;
      case LogLevel.info:
        return _blue;
      case LogLevel.warning:
        return _yellow;
      case LogLevel.error:
        return _red;
    }
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
      final color = _getColorForLevel(level);
      final now = DateTime.now();
      final isoTimestamp =
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}.${now.millisecond.toString().padLeft(3, '0')}';
      final logLevel = level.name.substring(0, 1).toUpperCase();
      final coloredMessage = color.isNotEmpty
          ? '$color[$logLevel]: $message$_reset'
          : '[$logLevel]: $message';
      debugPrint('[SuperFCM] [$isoTimestamp] $coloredMessage');
    }
  }
}
