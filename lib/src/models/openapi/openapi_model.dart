import 'package:niskala_model_gen/src/models/openapi/components_model.dart';
import 'package:niskala_model_gen/src/models/openapi/info_model.dart';
import 'package:niskala_model_gen/src/models/openapi/path_item_model.dart';
import 'package:niskala_model_gen/src/models/openapi/server_model.dart';
import 'package:niskala_model_gen/src/models/openapi/tag_model.dart';

/// Represents the root of an OpenAPI 3.0.x document.
class OpenApiModel {
  /// Creates an [OpenApiModel] instance.
  OpenApiModel({
    required this.openapi,
    required this.info,
    this.servers = const [],
    this.security = const [],
    this.tags = const [],
    this.paths = const {},
    this.components,
  });

  /// Creates an [OpenApiModel] instance from a JSON map.
  factory OpenApiModel.fromJson(Map<String, dynamic> json) {
    return OpenApiModel(
      openapi: json['openapi'] as String? ?? '3.0.1',
      info: InfoModel.fromJson(json['info'] as Map<String, dynamic>? ?? {}),
      servers:
          (json['servers'] as List<dynamic>?)
              ?.map((e) => ServerModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      security:
          (json['security'] as List<dynamic>?)
              ?.map((e) => e as Map<String, dynamic>)
              .toList() ??
          [],
      tags:
          (json['tags'] as List<dynamic>?)
              ?.map((e) => TagModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      paths:
          (json['paths'] as Map<String, dynamic>?)?.map(
            (key, value) => MapEntry(
              key,
              PathItemModel.fromJson(value as Map<String, dynamic>),
            ),
          ) ??
          {},
      components: json['components'] != null
          ? ComponentsModel.fromJson(json['components'] as Map<String, dynamic>)
          : null,
    );
  }

  /// The OpenAPI version string (e.g., '3.0.1').
  final String openapi;

  /// Metadata about the API.
  final InfoModel info;

  /// An array of Server Objects, which provide connectivity information to a target server.
  final List<ServerModel> servers;

  /// A declaration of which security mechanisms can be used across the API.
  final List<Map<String, dynamic>> security;

  /// A list of tags used by the specification for logical grouping.
  final List<TagModel> tags;

  /// The available paths and operations for the API.
  final Map<String, PathItemModel> paths;

  /// An element to hold various schemas for the specification.
  final ComponentsModel? components;
}
