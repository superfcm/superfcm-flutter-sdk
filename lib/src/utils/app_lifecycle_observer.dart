import 'package:flutter/widgets.dart';

/// A helper class to observe app lifecycle changes.
///
/// This observer enables tracking when the app goes to background
/// and when it comes back to foreground, which is essential for session tracking.
class AppLifecycleObserver extends WidgetsBindingObserver {
  final VoidCallback onResume;
  final VoidCallback onPause;

  AppLifecycleObserver({
    required this.onResume,
    required this.onPause,
  });

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        onResume();
        break;
      case AppLifecycleState.paused:
        onPause();
        break;
      default:
        // No action needed for other states
        break;
    }
  }
}
