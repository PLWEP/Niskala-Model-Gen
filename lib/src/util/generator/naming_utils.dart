/// Pure utility logic for string transformations and naming conventions.
class NamingUtils {
  /// Formats a string to PascalCase (e.g., 'user_name' -> 'UserName').
  static String toPascalCase(String text) {
    if (text.isEmpty) return text;
    return text
        .split(RegExp(r'(_|-|\.|@|/)'))
        .map((s) => s.isEmpty ? '' : s[0].toUpperCase() + s.substring(1))
        .join();
  }

  /// Formats a string to camelCase (e.g., 'UserName' -> 'userName').
  static String toCamelCase(String text) {
    if (text.isEmpty) return text;
    final pascal = toPascalCase(text);
    return pascal[0].toLowerCase() + pascal.substring(1);
  }

  /// Formats a string to snake_case (e.g., 'UserName' -> 'user_name').
  static String toSnakeCase(String text) {
    if (text.isEmpty) return text;
    final result = text.replaceAll('@', '');
    final r = RegExp('(?<=[a-z0-9])[A-Z]');
    return result
        .replaceAllMapped(r, (m) => '_${m.group(0)}')
        .toLowerCase()
        .replaceAll('-', '_')
        .replaceAll('.', '_');
  }

  /// Generates a standardized class name for an enum.
  static String getEnumClassName(String name) {
    var className = toPascalCase(name);
    // Strip redundant suffixes
    final redundantSuffixes = [
      'EnumerationEnum',
      'Enumeration',
      'StateEnum',
      'StatusEnum',
      'Enum',
    ];
    for (final suffix in redundantSuffixes) {
      if (className.endsWith(suffix)) {
        className = className.substring(0, className.length - suffix.length);
        break; // Only strip the first matched redundant suffix
      }
    }
    return className;
  }

  /// Checks if a word is a Dart reserved keyword.
  static bool isReservedKeyword(String word) {
    const keywords = {
      'continue',
      'break',
      'return',
      'if',
      'else',
      'for',
      'while',
      'do',
      'switch',
      'case',
      'default',
      'try',
      'catch',
      'finally',
      'throw',
      'rethrow',
      'async',
      'await',
      'yield',
      'void',
      'dynamic',
      'var',
      'final',
      'const',
      'static',
      'late',
      'class',
      'interface',
      'mixin',
      'extension',
      'enum',
      'typedef',
      'import',
      'export',
      'part',
      'library',
      'operator',
      'set',
      'get',
      'this',
      'super',
      'new',
      'true',
      'false',
      'null',
      'is',
      'as',
      'in',
    };
    return keywords.contains(word);
  }
}
