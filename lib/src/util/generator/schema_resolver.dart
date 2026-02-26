import 'package:niskala_model_gen/src/models/openapi/openapi_model.dart';
import 'package:niskala_model_gen/src/models/openapi/request_body_model.dart';
import 'package:niskala_model_gen/src/models/openapi/response_model.dart';
import 'package:niskala_model_gen/src/models/openapi/schema_model.dart';

/// Handles resolution of OpenAPI references and computing schema signatures.
class SchemaResolver {
  /// Resolves a schema reference from the OpenAPI components.
  static SchemaModel? resolveSchema(
    String ref,
    Map<String, SchemaModel>? components,
  ) {
    final refName = ref.split('/').last;
    return components?[refName];
  }

  /// Resolves a response reference from the OpenAPI components.
  static ResponseModel? resolveResponse(String ref, OpenApiModel api) {
    final refName = ref.split('/').last;
    return api.components?.responses[refName];
  }

  /// Resolves a request body reference from the OpenAPI components.
  static RequestBodyModel? resolveRequestBody(String ref, OpenApiModel api) {
    final refName = ref.split('/').last;
    return api.components?.requestBodies[refName];
  }

  /// Computes a structural signature for a schema to identify duplicate structures.
  static String getSchemaSignature(
    SchemaModel schema,
    Map<String, SchemaModel>? components,
  ) {
    final buffer = StringBuffer()..write('t:${schema.type};');
    if (schema.ref != null) {
      buffer.write('r:${schema.ref};');
    }

    if (schema.properties.isNotEmpty) {
      buffer.write(';');
      final sortedKeys = schema.properties.keys.toList()..sort();
      for (final key in sortedKeys) {
        final prop = schema.properties[key]!;
        buffer.write('$key:${getSchemaSignature(prop, components)};');
      }
    }

    if (schema.items != null) {
      buffer.write('i:${getSchemaSignature(schema.items!, components)};');
    }

    if (schema.enumValues.isNotEmpty) {
      final sortedEnums = schema.enumValues.map((e) => e.toString()).toList()
        ..sort();
      buffer.write('e:[${sortedEnums.join(',')}];');
    }

    return buffer.toString();
  }
}
