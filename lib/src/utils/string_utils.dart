extension StringExtensions on String {
  /// Capitalizes the first letter of a string.
  ///
  /// Returns the string with its first character converted to uppercase,
  /// keeping the rest of the string unchanged.
  /// If the string is empty, returns the empty string.
  ///
  /// Example:
  /// ```dart
  /// 'hello'.ucfirst() // returns 'Hello'
  /// ''.ucfirst() // returns ''
  /// ```
  String ucfirst() {
    if (isEmpty) return this;
    return this[0].toUpperCase() + substring(1);
  }
}
