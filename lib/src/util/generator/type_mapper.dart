import 'package:niskala_model_gen/src/models/builders/pending_model.dart';
import 'package:niskala_model_gen/src/models/openapi/schema_model.dart';
import 'package:niskala_model_gen/src/util/generator/generation_context.dart';
import 'package:niskala_model_gen/src/util/generator/naming_utils.dart';
import 'package:niskala_model_gen/src/util/generator/schema_resolver.dart';

/// Determines the appropriate Dart type for an OpenAPI schema and manages model discovery.
class TypeMapper {
  /// Maps an OpenAPI schema to a Dart type string.
  static String mapSchemaToDartType(
    SchemaModel schema,
    Map<String, SchemaModel>? components,
    String propName,
    String parentClassName,
    GenerationContext context,
  ) {
    if (schema.ref != null) {
      final refName = schema.ref!.split('/').last;
      final resolvedSchema = components?[refName];
      if (resolvedSchema != null && resolvedSchema.enumValues.isNotEmpty) {
        final enumName = NamingUtils.getEnumClassName(refName);
        context.usedEnums[enumName] = resolvedSchema;
        return enumName;
      }
      if (resolvedSchema != null && resolvedSchema.type == 'object') {
        var className = NamingUtils.toPascalCase(refName);
        if (!className.endsWith('Model')) className = '${className}Model';
        final folder = context.subFolderResolver(className);
        if (!context.classNameToFolder.containsKey(className)) {
          context.pendingModels.add(
            PendingModel(
              className: className,
              schema: resolvedSchema,
              components: components,
              subFolder: folder,
            ),
          );
          context.classNameToFolder[className] = folder;
        }
        return className;
      }
      var className = NamingUtils.toPascalCase(refName);
      if (!className.endsWith('Model')) className = '${className}Model';
      return className;
    }

    if (schema.enumValues.isNotEmpty) {
      final enumName = NamingUtils.getEnumClassName(
        '$parentClassName${NamingUtils.toPascalCase(propName)}',
      );
      context.usedEnums[enumName] = schema;
      return enumName;
    }

    switch (schema.type) {
      case 'string':
        if (schema.format == 'date-time' || schema.format == 'date') {
          return 'DateTime';
        }
        return 'String';
      case 'integer':
        return 'int';
      case 'number':
        return 'double';
      case 'boolean':
        return 'bool';
      case 'array':
        if (schema.items != null) {
          final itemType = mapSchemaToDartType(
            schema.items!,
            components,
            'items',
            parentClassName,
            context,
          );
          return 'List<$itemType>';
        }
        return 'List<dynamic>';
      case 'object':
        if (schema.properties.isNotEmpty) {
          final signature = SchemaResolver.getSchemaSignature(
            schema,
            components,
          );
          if (context.signatureToClassName.containsKey(signature)) {
            final existingName = context.signatureToClassName[signature]!;
            context.logger.info(
              'Reusing existing class $existingName for signature: ${signature.substring(0, signature.length > 50 ? 50 : signature.length)}...',
            );
            return existingName;
          }

          var className =
              '$parentClassName${NamingUtils.toPascalCase(propName)}Model';
          if (parentClassName == 'ErrorModel') {
            className = '${NamingUtils.toPascalCase(propName)}DetailModel';
          } else if (className.contains('ModelModel')) {
            className = className.replaceAll('ModelModel', 'Model');
          }

          if (className == 'ValueModel' &&
              parentClassName.endsWith('SetModel')) {
            // Inner value in OData collection
            className = parentClassName.replaceAll('SetModel', 'Model');
          }

          context.signatureToClassName[signature] = className;
          final folder = context.subFolderResolver(className);
          if (!context.classNameToFolder.containsKey(className)) {
            context.pendingModels.add(
              PendingModel(
                className: className,
                schema: schema,
                components: components,
                subFolder: folder,
              ),
            );
            context.classNameToFolder[className] = folder;
          }
          return className;
        }
        return 'Map<String, dynamic>';
      default:
        return 'dynamic';
    }
  }
}
