import 'package:niskala_model_gen/src/models/openapi/schema_model.dart';

/// Describes a single response from an API Operation.
class ResponseModel {
  /// Creates a [ResponseModel] instance.
  ResponseModel({this.description = '', this.content, this.schema, this.ref});

  /// Creates a [ResponseModel] instance from a JSON map.
  factory ResponseModel.fromJson(Map<String, dynamic> json) {
    SchemaModel? schemaObj;
    final content = json['content'] as Map<String, dynamic>?;

    if (content != null) {
      final jsonKey = content.keys.firstWhere(
        (k) => k.contains('json'),
        orElse: () => 'application/json',
      );
      if (content[jsonKey] != null) {
        final jsonContent = content[jsonKey] as Map<String, dynamic>;
        if (jsonContent['schema'] != null) {
          schemaObj = SchemaModel.fromJson(
            jsonContent['schema'] as Map<String, dynamic>,
          );
        }
      }
    }

    return ResponseModel(
      description: json['description'] as String? ?? '',
      content: content,
      schema: schemaObj,
      ref: json[r'$ref'] as String?,
    );
  }

  /// A short description of the response.
  final String description;

  /// A map containing descriptions of potential response payloads.
  final Map<String, dynamic>? content;

  /// The schema defining the structure of the response.
  final SchemaModel? schema;

  /// A reference to the response definition.
  final String? ref;
}
