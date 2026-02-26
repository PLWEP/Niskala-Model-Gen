import 'package:dart_style/dart_style.dart';
import 'package:niskala_model_gen/src/models/builders/niskala_model.dart';
import 'package:niskala_model_gen/src/models/openapi/schema_model.dart';
import 'package:niskala_model_gen/src/util/generator/generation_context.dart';
import 'package:niskala_model_gen/src/util/generator/naming_utils.dart';
import 'package:niskala_model_gen/src/util/generator/schema_resolver.dart';
import 'package:pub_semver/pub_semver.dart';

/// Generates unit tests for the generated model classes.
class TestGenerator {
  /// Creates a [TestGenerator] instance.
  TestGenerator({
    required this.config,
    required this.context,
    DartFormatter? formatter,
  }) : _formatter =
           formatter ?? DartFormatter(languageVersion: Version(3, 0, 0));

  final NiskalaModel config;
  final GenerationContext context;
  final DartFormatter _formatter;

  /// Generates the test code for a given model.
  static const _emptyJsonConst = 'const <String, dynamic>{}';
  static const _emptyJsonNested = '<String, dynamic>{}';
  static const _emptyListConst = 'const <dynamic>[]';
  static const _emptyListNested = '<dynamic>[]';

  String generateTest(String className, SchemaModel schema) {
    final buffer = StringBuffer();

    // Collect all referenced models to import them
    final referencedModels = <String>{};
    _collectReferencedModels(
      schema,
      referencedModels,
      currentClassName: className,
      visitedClasses: {className},
    );

    // Also collect from expansions
    final baseEntityName = className.replaceAll('Model', '');
    if (config.genConfig?.classExpansions.containsKey(baseEntityName) ??
        false) {
      final expansions = config.genConfig!.classExpansions[baseEntityName]!;
      for (final exp in expansions) {
        referencedModels.add('${NamingUtils.toPascalCase(exp)}Model');
      }
    }

    final modelImports =
        referencedModels
            .where((m) => m != className)
            .map(
              (m) =>
                  "import 'package:${context.packageName}/models/${_getCategory(m)}/${NamingUtils.toSnakeCase(m)}.dart';",
            )
            .toSet()
            .toList()
          ..sort();

    final headerDirectives = [
      if (context.isFlutter)
        "import 'package:flutter_test/flutter_test.dart';"
      else
        "import 'package:test/test.dart';",
      "import 'package:${context.packageName}/models/${_getCategory(className)}/${NamingUtils.toSnakeCase(className)}.dart';",
      ...modelImports,
    ]..sort();

    // Header
    buffer
      ..writeAll(headerDirectives.map((dir) => '$dir\n'))
      ..writeln()
      ..writeln('void _recursiveRemoveNulls(Map<String, dynamic> map) {')
      ..writeln('  map.removeWhere((key, value) {')
      ..writeln('    if (value == null) return true;')
      ..writeln(
        '    if (value is Map<String, dynamic>) _recursiveRemoveNulls(value);',
      )
      ..writeln('    if (value is List) {')
      ..writeln('      for (final e in value) {')
      ..writeln(
        '        if (e is Map<String, dynamic>) _recursiveRemoveNulls(e);',
      )
      ..writeln('      }')
      ..writeln('    }')
      ..writeln('    return false;')
      ..writeln('  });')
      ..writeln('}')
      ..writeln()
      ..writeln('void main() {')
      ..writeln("  group('$className Tests', () {");

    _generateSerializationTest(buffer, className, schema);
    _generateCopyWithTest(buffer, className, schema);
    _generateEqualityTest(buffer, className, schema);

    buffer
      ..writeln('  });')
      ..writeln('}');

    try {
      return _formatter.format(buffer.toString());
    } catch (e) {
      buffer.toString();
      rethrow;
    }
  }

  void _generateSerializationTest(
    StringBuffer buffer,
    String className,
    SchemaModel schema,
  ) {
    // json symmetry
    buffer
      ..writeln("    test('fromJson and toJson should be symmetrical', () {")
      ..writeln(
        '      const json = ${_generateMockJson(schema, className: className, isNested: true, visitedClasses: {className})};',
      )
      ..writeln('      final model = $className.fromJson(json);')
      ..writeln('      final resultJson = model.toJson();')
      ..writeln('      _recursiveRemoveNulls(resultJson);')
      ..writeln()
      ..writeln('      expect(resultJson, equals(json));')
      ..writeln('    });')
      ..writeln()
      ..writeln(
        "    test('fromJson should handle null values for optional fields', () {",
      )
      ..writeln(
        '      const json = ${_generateMockJson(schema, onlyRequired: true, isNested: true, visitedClasses: {className})};',
      )
      ..writeln('      final model = $className.fromJson(json);')
      ..writeln('      expect(model, isNotNull);')
      ..writeln('      final resultJson = model.toJson();')
      ..writeln('      _recursiveRemoveNulls(resultJson);')
      ..writeln('      expect(resultJson, equals(json));')
      ..writeln('    });');
  }

  void _generateCopyWithTest(
    StringBuffer buffer,
    String className,
    SchemaModel schema,
  ) {
    if (schema.properties.isEmpty) return;

    // copyWith
    buffer
      ..writeln(
        "    test('copyWith should create a new instance with updated values', () {",
      )
      ..writeln(
        '      final model = $className.fromJson(const ${_generateMockJson(schema, onlyRequired: true, className: className, isNested: true, visitedClasses: {className})});',
      );

    final properties = schema.properties.entries.toList();
    final firstProp = properties.first;
    final firstPropName = NamingUtils.toCamelCase(firstProp.key);
    final firstMockValue = _generateMockValue(
      firstProp.value,
      firstProp.key,
      seed: 1,
      asJson: false,
    );

    buffer
      ..writeln(
        '      final updatedModel = model.copyWith($firstPropName: $firstMockValue);',
      )
      ..writeln()
      ..writeln(
        '      expect(updatedModel.$firstPropName, equals($firstMockValue));',
      );

    if (properties.length > 1) {
      final secondProp = properties[1];
      final secondPropName = NamingUtils.toCamelCase(secondProp.key);
      buffer.writeln(
        '      expect(updatedModel.$secondPropName, equals(model.$secondPropName));',
      );
    }

    buffer
      ..writeln('      expect(identical(model, updatedModel), isFalse);')
      ..writeln('    });');
  }

  void _generateEqualityTest(
    StringBuffer buffer,
    String className,
    SchemaModel schema,
  ) {
    buffer
      ..writeln("    test('equality and hashCode should work correctly', () {")
      ..writeln(
        '      const json = ${_generateMockJson(schema, className: className, isNested: true, visitedClasses: {className})};',
      )
      ..writeln('      final model1 = $className.fromJson(json);')
      ..writeln('      final model2 = $className.fromJson(json);')
      ..writeln()
      ..writeln('      expect(model1, equals(model2));')
      ..writeln('      expect(model1.hashCode, equals(model2.hashCode));');

    if (schema.properties.isNotEmpty) {
      final firstProp = schema.properties.entries.first;
      final propName = NamingUtils.toCamelCase(firstProp.key);
      final newValue = _generateMockValue(
        firstProp.value,
        firstProp.key,
        seed: 1,
        asJson: false,
      );

      buffer
        ..writeln('      final model3 = model1.copyWith($propName: $newValue);')
        ..writeln('      expect(model1, isNot(equals(model3)));');
    }

    buffer.writeln('    });');
  }

  String _getCategory(String className) {
    if (context.classNameToFolder.containsKey(className)) {
      return context.classNameToFolder[className]!;
    }
    // Check if it's an enum
    if (context.usedEnums.keys.any(
      (k) => NamingUtils.getEnumClassName(k) == className,
    )) {
      return 'enums';
    }
    // Fallback based on name patterns
    if (className.contains('RefModel')) return 'expansions';
    if (className.contains('ResponseModel') || className == 'ErrorModel') {
      return 'responses';
    }
    if (className.contains('State') ||
        className.contains('Type') ||
        className.contains('Category')) {
      if (!className.endsWith('Model')) return 'enums';
    }
    return 'entities';
  }

  void _collectReferencedModels(
    SchemaModel schema,
    Set<String> models, {
    String? currentClassName,
    Set<SchemaModel>? visited,
    Set<String>? visitedClasses,
    int depth = 0,
  }) {
    if (depth > 20) return;

    final effectiveVisited = visited ?? Set<SchemaModel>.identity();
    if (effectiveVisited.contains(schema)) return;
    effectiveVisited.add(schema);

    final effectiveVisitedClasses = visitedClasses ?? <String>{};

    if (schema.ref != null) {
      final refName = schema.ref!.split('/').last.replaceAll('.json', '');
      final rawClassName = NamingUtils.toPascalCase(refName);

      String? className;
      // Heuristic for enums first
      if (refName.contains('Enumeration') ||
          refName.endsWith('Enum') ||
          context.usedEnums.containsKey(refName) ||
          context.usedEnums.containsKey(rawClassName)) {
        className = NamingUtils.getEnumClassName(refName);
      } else if (context.classNameToFolder.containsKey(rawClassName)) {
        className = rawClassName;
      } else {
        className = rawClassName;
        if (!className.endsWith('Model')) className = '${className}Model';
      }

      if (effectiveVisitedClasses.contains(className)) return;
      effectiveVisitedClasses.add(className);

      models.add(className);

      if (context.classToSchema.containsKey(className)) {
        _collectReferencedModels(
          context.classToSchema[className]!,
          models,
          currentClassName: className,
          visited: effectiveVisited,
          visitedClasses: effectiveVisitedClasses,
          depth: depth + 1,
        );
      }
    }

    // Always check properties
    for (final entry in schema.properties.entries) {
      final propName = entry.key;
      final propSchema = entry.value;

      // Handle inline objects that generate models
      if (propSchema.ref == null && propSchema.properties.isNotEmpty) {
        final parentName = currentClassName ?? '';
        var inlineClassName =
            '${NamingUtils.toPascalCase(parentName)}${NamingUtils.toPascalCase(propName)}Model';

        if (parentName == 'ErrorModel') {
          inlineClassName = '${NamingUtils.toPascalCase(propName)}DetailModel';
        } else if (inlineClassName.contains('ModelModel')) {
          inlineClassName = inlineClassName.replaceAll('ModelModel', 'Model');
        }

        if (!models.contains(inlineClassName)) {
          models.add(inlineClassName);
        }

        // Also collect from this inline model
        _collectReferencedModels(
          propSchema,
          models,
          currentClassName: inlineClassName,
          visited: effectiveVisited,
          visitedClasses: effectiveVisitedClasses,
          depth: depth + 1,
        );
        continue;
      }

      _collectReferencedModels(
        propSchema,
        models,
        currentClassName: currentClassName,
        visited: effectiveVisited,
        visitedClasses: effectiveVisitedClasses,
        depth: depth + 1,
      );
    }

    // Always check items
    if (schema.items != null) {
      _collectReferencedModels(
        schema.items!,
        models,
        visited: effectiveVisited,
        visitedClasses: effectiveVisitedClasses,
        depth: depth + 1,
      );
    }
  }

  String _generateMockJson(
    SchemaModel schema, {
    int seed = 0,
    int depth = 0,
    bool asJson = true,
    String? className,
    bool onlyRequired = false,
    bool isNested = false,
    Set<String>? visitedClasses,
    bool isExpansion = false,
  }) {
    const maxDepth = 5;
    final effectiveVisited = visitedClasses ?? <String>{};
    if (depth > maxDepth) {
      return isNested ? _emptyJsonNested : _emptyJsonConst;
    }

    final props = <String>[];
    for (final entry in schema.properties.entries) {
      final isRequired = schema.requiredFields.contains(entry.key);
      if (onlyRequired && !isRequired) continue;

      final value = _generateMockValue(
        entry.value,
        entry.key,
        seed: seed,
        depth: depth + 1,
        onlyRequired: onlyRequired,
        isNested: true,
        visitedClasses: effectiveVisited,
      );
      if (value == 'null') continue;
      props.add("'${entry.key}': $value");
    }

    // Special case for OData expansion wrappers: ensure they have a 'value' property if they are empty
    // and we know they should be a collection wrapper (convention).
    if (isExpansion &&
        !schema.properties.containsKey('value') &&
        !onlyRequired) {
      final mockVal = _generateMockValue(
        SchemaModel(
          type: 'array',
          items: SchemaModel(type: 'object'),
        ),
        'value',
        seed: seed,
        depth: depth + 1,
        onlyRequired: onlyRequired,
        isNested: true,
        visitedClasses: effectiveVisited,
      );
      props.add("'value': $mockVal");
    }

    // Include expansions if className is provided
    if (className != null && config.genConfig != null) {
      final baseEntityName = className.replaceAll('Model', '');
      if (config.genConfig!.classExpansions.containsKey(baseEntityName)) {
        final expansions = config.genConfig!.classExpansions[baseEntityName]!;
        for (final exp in expansions) {
          if (depth == 0) {
            final expClassName = '${NamingUtils.toPascalCase(exp)}Model';
            if (context.classToSchema.containsKey(expClassName)) {
              if (effectiveVisited.contains(expClassName)) {
                props.add("'$exp': $_emptyJsonNested");
                continue;
              }
              final expSchema = context.classToSchema[expClassName]!;
              final expValue = _generateMockJson(
                expSchema,
                seed: seed,
                depth: depth + 1,
                onlyRequired: onlyRequired,
                isNested: true,
                visitedClasses: {...effectiveVisited, expClassName},
                isExpansion: true,
              );
              props.add("'$exp': $expValue");
            }
          } else {
            // expansions are skipped at nested levels to prevent explosion
          }
        }
      }
    }

    if (props.isEmpty && schema.ref != null) {
      final refName = schema.ref!.split('/').last.replaceAll('.json', '');
      // Check if it's an enum
      if (context.usedEnums.containsKey(refName)) {
        final enumSchema = context.usedEnums[refName]!;
        if (enumSchema.enumValues.isNotEmpty) {
          final val =
              enumSchema.enumValues[seed % enumSchema.enumValues.length];
          return "'$val'";
        }
      }

      final refClassName = '${NamingUtils.toPascalCase(refName)}Model';
      if (context.classToSchema.containsKey(refClassName)) {
        final refSchema = context.classToSchema[refClassName]!;
        final mockJson = _generateMockJson(
          refSchema,
          seed: seed + 1,
          depth: depth + 1,
          className: refClassName,
          onlyRequired: onlyRequired,
          isNested: true, // Internal models are always nested
          visitedClasses: {...effectiveVisited, refClassName},
        );
        return asJson ? mockJson : '$refClassName.fromJson(const $mockJson)';
      }
    }

    const type = '<String, dynamic>';
    return "$type{${props.join(', ')}}";
  }

  String _generateMockValue(
    SchemaModel schema,
    String name, {
    int seed = 0,
    int depth = 0,
    bool asJson = true,
    bool onlyRequired = false,
    bool isNested = false,
    Set<String>? visitedClasses,
  }) {
    const maxDepth = 5;
    final effectiveVisited = visitedClasses ?? <String>{};
    if (depth > maxDepth &&
        (schema.type == 'object' || schema.type == 'array')) {
      if (schema.type == 'array') {
        return (isNested || !asJson) ? _emptyListNested : _emptyListConst;
      }
      return asJson ? (isNested ? _emptyJsonNested : _emptyJsonConst) : 'null';
    }

    if (schema.ref != null) {
      final refName = schema.ref!.split('/').last.replaceAll('.json', '');

      // Check if it's an enum
      if (context.usedEnums.containsKey(refName)) {
        final enumSchema = context.usedEnums[refName]!;
        if (enumSchema.enumValues.isNotEmpty) {
          final val =
              enumSchema.enumValues[seed % enumSchema.enumValues.length];
          return "'$val'";
        }
      }

      // Check if it's a nested model
      var className = NamingUtils.toPascalCase(refName);
      if (!className.endsWith('Model')) className = '${className}Model';

      if (context.classToSchema.containsKey(className)) {
        final modelSchema = context.classToSchema[className]!;
        if (depth > 20) {
          return asJson
              ? (isNested ? _emptyJsonNested : _emptyJsonConst)
              : '$className.fromJson($_emptyJsonConst)';
        }
        final json = _generateMockJson(
          modelSchema,
          seed: seed,
          depth: depth + 1,
          className: className,
          onlyRequired: onlyRequired,
          isNested: true,
          visitedClasses: {...effectiveVisited, className},
        );
        if (asJson) {
          return json;
        } else {
          return '$className.fromJson(const $json)';
        }
      }

      return 'null';
    }

    if (schema.enumValues.isNotEmpty) {
      final val = schema.enumValues[seed % schema.enumValues.length];
      return "'$val'";
    }

    switch (schema.type) {
      case 'string':
        if (schema.format == 'date-time' || schema.format == 'date') {
          return seed == 0
              ? "'2024-01-01T00:00:00.000Z'"
              : "'2025-01-01T00:00:00.000Z'";
        }
        return seed == 0 ? "'test_$name'" : "'updated_$name'";
      case 'integer':
        return (1 + seed).toString();
      case 'number':
        return (1.0 + seed).toString();
      case 'boolean':
        return seed == 0 ? 'true' : 'false';
      case 'array':
        if (schema.items != null) {
          final val = _generateMockValue(
            schema.items!,
            name,
            seed: seed,
            depth: depth + 1,
            asJson:
                asJson, // Propagate! (if array is JSON, items are JSON; if array is Model, items are Model)
            onlyRequired: onlyRequired,
            isNested: true,
            visitedClasses: effectiveVisited,
          );
          final prefix = (asJson && !isNested) ? 'const ' : '';
          final type = asJson ? '<dynamic>' : '';
          return '$prefix$type[$val]';
        }
        return asJson ? _emptyListConst : _emptyListNested;
      case 'object':
        if (schema.properties.isNotEmpty) {
          final signature = SchemaResolver.getSchemaSignature(
            schema,
            context.components,
          );
          if (context.signatureToClassName.containsKey(signature)) {
            final className = context.signatureToClassName[signature]!;
            if (depth > 20) {
              return asJson
                  ? (isNested ? _emptyJsonNested : _emptyJsonConst)
                  : '$className.fromJson($_emptyJsonConst)';
            }
            final json = _generateMockJson(
              schema,
              seed: seed,
              depth: depth + 1,
              className: className,
              onlyRequired: onlyRequired,
              isNested: true,
              visitedClasses: {...effectiveVisited, className},
            );
            if (asJson) {
              return json;
            } else {
              return '$className.fromJson(const $json)';
            }
          }

          if (depth > 20) {
            return (isNested || !asJson) ? _emptyJsonNested : _emptyJsonConst;
          }
          final json = _generateMockJson(
            schema,
            seed: seed,
            depth: depth + 1,
            onlyRequired: onlyRequired,
            isNested: true,
            visitedClasses: effectiveVisited,
          );
          if (isNested || !asJson) return json;
          return 'const $json';
        }
        return (isNested || !asJson) ? _emptyJsonNested : _emptyJsonConst;
      default:
        return 'null';
    }
  }
}
