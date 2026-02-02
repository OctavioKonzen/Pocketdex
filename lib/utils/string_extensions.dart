// lib/utils/string_extensions.dart

extension StringExtension on String {
  String capitalise() {
    if (isEmpty) {
      return "";
    }
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}