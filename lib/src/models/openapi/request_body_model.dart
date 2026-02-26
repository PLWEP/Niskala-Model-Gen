import 'package:niskala_model_gen/src/models/openapi/schema_model.dart';

/// Describes a single request body.
class RequestBodyModel {
  /// Creates a [RequestBodyModel] instance.
  RequestBodyModel({this.description, this.ref, this.content = const {}});

  /// Creates a [RequestBodyModel] instance from a JSON map.
  factory RequestBodyModel.fromJson(Map<String, dynamic> json) {
    final ref = json[r'$ref'] as String?;
    final description = json['description'] as String?;

    final contentMap = <String, SchemaModel>{};
    if (json['content'] != null) {
      (json['content'] as Map<String, dynamic>).forEach((
        mediaType,
        mediaTypeObj,
      ) {
        if (mediaTypeObj is Map<String, dynamic> &&
            mediaTypeObj['schema'] != null) {
          contentMap[mediaType] = SchemaModel.fromJson(
            mediaTypeObj['schema'] as Map<String, dynamic>,
          );
        }
      });
    }

    return RequestBodyModel(
      description: description,
      ref: ref,
      content: contentMap,
    );
  }

  /// A brief description of the request body.
  final String? description;

  /// A reference to the request body definition.
  final String? ref;

  /// The content of the request body. The key is the media type.
  final Map<String, SchemaModel> content;

  /// Convenience getter for the primary schema (usually application/json).
  SchemaModel? get schema {
    if (content.isEmpty) return null;
    // Prefer application/json, then the first one found
    return content['application/json'] ?? content.values.first;
  }
}
