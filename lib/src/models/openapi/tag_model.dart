/// Adds metadata to a single tag that is used by the Operation Object.
class TagModel {
  /// Creates a [TagModel] instance.
  TagModel({required this.name, this.description = ''});

  /// Creates a [TagModel] instance from a JSON map.
  factory TagModel.fromJson(Map<String, dynamic> json) {
    return TagModel(
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
    );
  }

  /// The name of the tag.
  final String name;

  /// A brief description for the tag.
  final String description;
}
