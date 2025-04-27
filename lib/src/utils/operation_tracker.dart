import 'dart:async';

import 'package:superfcm_flutter/src/utils/logger.dart';

/// A utility class that tracks pending asynchronous operations.
///
/// The [OperationTracker] allows managing concurrent operations and provides
/// a mechanism to wait for all operations to complete before proceeding with
/// cleanup or disposal.
///
/// Features:
/// - Track number of pending operations
/// - Wait for all operations to complete
/// - Built-in timeout for waiting
/// - Logging of operation status
class OperationTracker {
  /// Tracks the number of pending async operations
  int _pendingOperations = 0;

  /// Completer that resolves when all operations are done
  Completer<void>? _noOperationsPending;

  /// Tag for identifying the source of operations in logs
  final String _tag;

  /// Creates a new operation tracker with an optional tag for logging.
  ///
  /// [tag] - A string identifier used in log messages to identify the source
  OperationTracker({String? tag}) : _tag = tag ?? 'OperationTracker';

  /// Gets the current count of pending operations
  int get pendingOperationsCount => _pendingOperations;

  /// Returns true if there are any pending operations
  bool get hasOperations => _pendingOperations > 0;

  /// Executes an operation and tracks its completion status.
  ///
  /// [operation] - The asynchronous operation to track
  ///
  /// Creates and completes a Completer when the last operation finishes.
  Future<T> trackOperation<T>(Future<T> Function() operation) async {
    _pendingOperations++;

    // If this is the first operation after having 0 operations,
    // create a new Completer to track when we return to 0
    if (_pendingOperations == 1) {
      _noOperationsPending = Completer<void>();
      logger.v('[$_tag] Started tracking operations');
    }

    try {
      return await operation();
    } finally {
      _pendingOperations--;

      // If this was the last operation, complete the Completer
      if (_pendingOperations == 0 &&
          _noOperationsPending != null &&
          !_noOperationsPending!.isCompleted) {
        logger.v('[$_tag] All operations completed');
        _noOperationsPending!.complete();
        _noOperationsPending = null;
      }
    }
  }

  /// Waits for all pending operations to complete.
  ///
  /// [timeout] - Optional timeout duration, defaults to 10 seconds
  ///
  /// Returns a Future that completes when all operations are done,
  /// or when the timeout is reached.
  Future<void> waitForOperations({Duration? timeout}) async {
    timeout ??= Duration(seconds: 10);

    if (!hasOperations) {
      logger.v('[$_tag] No pending operations to wait for');
      return;
    }

    logger.d(
        '[$_tag] Waiting for $_pendingOperations pending operations to complete...');

    // Create a completer if it doesn't exist yet
    _noOperationsPending ??= Completer<void>();

    // Wait for operations to complete with a timeout
    try {
      await _noOperationsPending!.future.timeout(timeout);
      logger.d('[$_tag] All pending operations completed successfully');
    } on TimeoutException {
      logger.w(
          '[$_tag] Timeout reached while waiting for $_pendingOperations operations to complete');
    }
  }
}
