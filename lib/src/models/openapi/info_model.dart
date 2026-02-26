/// Metadata about the API.
class InfoModel {
  /// Creates an [InfoModel] instance.
  InfoModel({
    required this.title,
    required this.version,
    this.description = '',
  });

  /// Creates an [InfoModel] instance from a JSON map.
  factory InfoModel.fromJson(Map<String, dynamic> json) {
    return InfoModel(
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      version: json['version'] as String? ?? '',
    );
  }

  /// The title of the API.
  final String title;

  /// A short description of the API.
  final String description;

  /// The version of the OpenAPI document.
  final String version;
}
