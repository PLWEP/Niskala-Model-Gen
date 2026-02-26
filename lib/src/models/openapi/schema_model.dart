/// The Schema Object allows the definition of input and output data types.
///
/// These types can be objects, but also primitives and arrays.
class SchemaModel {
  /// Creates a [SchemaModel] instance.
  SchemaModel({
    this.type,
    this.ref,
    this.format,
    this.nullable = false,
    this.properties = const {},
    this.items,
    this.requiredFields = const [],
    this.enumValues = const [],
    this.maxLength,
    this.minimum,
    this.maximum,
    this.pattern,
  });

  /// Creates a [SchemaModel] instance from a JSON map.
  factory SchemaModel.fromJson(Map<String, dynamic> json) {
    final props = <String, SchemaModel>{};
    if (json['properties'] != null) {
      (json['properties'] as Map<String, dynamic>).forEach((key, value) {
        props[key] = SchemaModel.fromJson(value as Map<String, dynamic>);
      });
    }

    SchemaModel? itemsObj;
    if (json['items'] != null) {
      itemsObj = SchemaModel.fromJson(json['items'] as Map<String, dynamic>);
    }

    return SchemaModel(
      type: json['type'] as String?,
      ref: json[r'$ref'] as String?,
      format: json['format'] as String?,
      nullable: json['nullable'] as bool? ?? false,
      properties: props,
      items: itemsObj,
      requiredFields:
          (json['required'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      enumValues: json['enum'] as List<dynamic>? ?? [],
      maxLength: json['maxLength'] as int?,
      minimum: json['minimum'] as num?,
      maximum: json['maximum'] as num?,
      pattern: json['pattern'] as String?,
    );
  }

  /// The type of the schema (e.g., 'object', 'array', 'string').
  final String? type;

  /// A reference to another schema definition.
  final String? ref;

  /// The format of the schema (e.g., 'int32', 'double', 'date-time').
  final String? format;

  /// Whether the schema can be null.
  final bool nullable;

  /// A map of property names to their corresponding schemas.
  final Map<String, SchemaModel> properties;

  /// The schema for array items, if the type is 'array'.
  final SchemaModel? items;

  /// A list of property names that are required.
  final List<String> requiredFields;

  /// A list of allowed values for this schema (for enums).
  final List<dynamic> enumValues;

  /// The maximum length of the string, if the type is 'string'.
  final int? maxLength;

  /// The minimum value of a numeric type.
  final num? minimum;

  /// The maximum value of a numeric type.
  final num? maximum;

  /// The regex pattern of a string type.
  final String? pattern;
}
