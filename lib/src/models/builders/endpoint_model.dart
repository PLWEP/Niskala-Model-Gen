import 'package:yaml/yaml.dart';

/// Represents an API endpoint definition from the configuration.
class EndpointModel {
  /// Creates an [EndpointModel] instance.
  EndpointModel({
    required this.projection,
    required this.name,
    this.method = 'GET',
  });

  /// Factory constructor to create an [EndpointModel] from a YAML API definition.
  factory EndpointModel.fromApiDefinition(YamlMap map) {
    final endpoint = map['endpoint']?.toString() ?? '';
    // Remove leading slash if present for internal consistency
    final cleanName = endpoint.startsWith('/')
        ? endpoint.substring(1)
        : endpoint;

    return EndpointModel(
      projection: map['projection']?.toString() ?? '',
      name: cleanName,
      method: map['method']?.toString().toUpperCase() ?? 'GET',
    );
  }

  /// The projection name (e.g., 'PurchaseRequisitionHandling').
  final String projection;

  /// The endpoint name or path (e.g., 'PurchaseRequisitionSet').
  final String name;

  /// The HTTP method for the endpoint (default is 'GET').
  final String method;

  /// Creates a copy of this [EndpointModel] with some fields replaced.
  EndpointModel copyWith({String? projection, String? name, String? method}) {
    return EndpointModel(
      projection: projection ?? this.projection,
      name: name ?? this.name,
      method: method ?? this.method,
    );
  }
}
