import 'package:niskala_model_gen/src/core/logger.dart';

/// Utility to merge generated code with existing custom code using markers.
class CodeMerger {
  /// The marker used to identify the custom code section.
  static const customLogicMarker = '// Custom logic here';

  /// Merges [newContent] into [existingContent] by preserving code after the marker.
  static String merge(String existingContent, String newContent) {
    final existingNormalized = existingContent.replaceAll('\r\n', '\n');
    final newNormalized = newContent.replaceAll('\r\n', '\n');

    if (!existingNormalized.contains(customLogicMarker)) {
      logger.warning(
        'Marker "$customLogicMarker" not found in existing file. Performing baseline upgrade.',
      );
      return newContent;
    }

    final existingLines = existingNormalized.split('\n');
    final newLines = newNormalized.split('\n');

    final existingMarkerIndex = existingLines.indexWhere(
      (l) => l.contains(customLogicMarker),
    );
    final newMarkerIndex = newLines.indexWhere(
      (l) => l.contains(customLogicMarker),
    );

    if (newMarkerIndex == -1) {
      logger.severe('New content is missing the marker. Cannot merge safely.');
      return existingContent;
    }

    final customPartCode = existingLines
        .sublist(existingMarkerIndex + 1)
        .join('\n');

    // 1. Identify what's in the NEW content first
    final newImportsMatchedKeys = <String>{};
    for (final line in newLines) {
      final trimmed = line.trim();
      if (trimmed.startsWith('import ')) {
        final matchKey = _getMatchKey(trimmed);
        if (matchKey != null) {
          newImportsMatchedKeys.add(matchKey);
        }
      }
    }

    final normalizedToOriginal = <String, String>{};

    for (final line in [...newLines, ...existingLines]) {
      final trimmed = line.trim();
      if (trimmed.startsWith('import ')) {
        final matchKey = _getMatchKey(trimmed);
        if (matchKey == null) continue;

        // If this is from existing content but NOT in new content
        final isFromExisting = !newLines.any((l) => l.trim() == trimmed);
        if (isFromExisting && !newImportsMatchedKeys.contains(matchKey)) {
          // It's a candidate for removal.
          // Check if it's a Niskala model/expansion/enum import
          final isModelImport =
              matchKey.contains('entities/') ||
              matchKey.contains('responses/') ||
              matchKey.contains('expansions/') ||
              matchKey.contains('enums/');

          if (isModelImport) {
            // Only keep if it's used in the custom code part
            final fileName = matchKey.split('/').last.replaceAll('.dart', '');
            final className = fileName.split('_').map((s) {
              if (s.isEmpty) return '';
              return s[0].toUpperCase() + s.substring(1);
            }).join();

            if (!customPartCode.contains(className)) {
              continue; // Drop stale model import
            }
          }
        }

        if (!normalizedToOriginal.containsKey(matchKey)) {
          normalizedToOriginal[matchKey] = trimmed;
        } else {
          // Prioritize package: imports over relative ones
          if (trimmed.contains("'package:") || trimmed.contains('"package:')) {
            normalizedToOriginal[matchKey] = trimmed;
          }
        }
      }
    }

    final sortedImports = normalizedToOriginal.values.toList()
      ..sort((a, b) {
        final aTrim = a.trim();
        final bTrim = b.trim();

        final aIsDart =
            aTrim.startsWith("import 'dart:") ||
            aTrim.startsWith('import "dart:');
        final bIsDart =
            bTrim.startsWith("import 'dart:") ||
            bTrim.startsWith('import "dart:');

        if (aIsDart && !bIsDart) return -1;
        if (!aIsDart && bIsDart) return 1;

        final aIsPkg =
            aTrim.startsWith("import 'package:") ||
            aTrim.startsWith('import "package:');
        final bIsPkg =
            bTrim.startsWith("import 'package:") ||
            bTrim.startsWith('import "package:');

        if (aIsPkg && !bIsPkg) return -1;
        if (!aIsPkg && bIsPkg) return 1;

        return aTrim.compareTo(bTrim);
      });

    // 4. Assemble the result
    final result = <String>[
      ...sortedImports,
      if (sortedImports.isNotEmpty) '',
      ...newLines
          .sublist(0, newMarkerIndex + 1)
          .where((l) => !l.trim().startsWith('import ')),
      ...existingLines.sublist(existingMarkerIndex + 1),
    ];

    return result.join('\n');
  }

  static final _importRegExp = RegExp(r'''^import\s+['"]([^'"]+)['"];?\s*$''');

  static String? _getMatchKey(String importLine) {
    final match = _importRegExp.firstMatch(importLine.trim());
    if (match == null) return null;
    var path = match.group(1)!;

    // Remove leading relative markers
    if (path.startsWith('./')) path = path.substring(2);
    while (path.startsWith('../')) {
      path = path.substring(3);
    }

    if (path.contains('/')) {
      final parts = path.split('/');
      if (parts.length >= 2) {
        final fileName = parts.last;
        final folderName = parts[parts.length - 2];
        return '$folderName/$fileName';
      }
    }
    return path;
  }
}
