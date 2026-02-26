/// An object representing a Server.
class ServerModel {
  /// Creates a [ServerModel] instance.
  ServerModel({required this.url, this.description = ''});

  /// Creates a [ServerModel] instance from a JSON map.
  factory ServerModel.fromJson(Map<String, dynamic> json) {
    return ServerModel(
      url: json['url'] as String? ?? '',
      description: json['description'] as String? ?? '',
    );
  }

  /// A URL to the target host.
  final String url;

  /// An optional string describing the host designated by the URL.
  final String description;
}
