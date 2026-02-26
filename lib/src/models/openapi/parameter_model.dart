import 'package:niskala_model_gen/src/models/openapi/schema_model.dart';

/// Describes a single operation parameter.
class ParameterModel {
  /// Creates a [ParameterModel] instance.
  ParameterModel({
    this.name = '',
    this.inLocation = '',
    this.description = '',
    this.required = false,
    this.schema,
    this.ref,
  });

  /// Creates a [ParameterModel] instance from a JSON map.
  factory ParameterModel.fromJson(Map<String, dynamic> json) {
    return ParameterModel(
      name: json['name'] as String? ?? '',
      inLocation: json['in'] as String? ?? '',
      description: json['description'] as String? ?? '',
      required: json['required'] as bool? ?? false,
      schema: json['schema'] != null
          ? SchemaModel.fromJson(json['schema'] as Map<String, dynamic>)
          : null,
      ref: json[r'$ref'] as String?,
    );
  }

  /// The name of the parameter. Parameter names are case sensitive.
  final String name;

  /// The location of the parameter. Possible values are "query", "header", "path" or "cookie".
  final String inLocation;

  /// A brief description of the parameter.
  final String description;

  /// Determines whether this parameter is mandatory.
  final bool required;

  /// The schema defining the type used for the parameter.
  final SchemaModel? schema;

  /// A reference to the parameter definition.
  final String? ref;
}
