import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:niskala_model_gen/src/core/exceptions.dart';
import 'package:niskala_model_gen/src/models/builders/niskala_model.dart';
import 'package:niskala_model_gen/src/models/openapi/openapi_model.dart';
import 'package:path/path.dart' as p;

/// A utility class for loading and parsing OpenAPI specifications
/// from the filesystem.
class OpenApiLoader {
  static final Logger _logger = Logger('OpenApiLoader');

  /// Loads all OpenAPI JSON files that match the configured [config].
  static Future<List<OpenApiModel>> loadAll(NiskalaModel config) async {
    final resourcePath = config.resourcePath;
    if (resourcePath == null || resourcePath.isEmpty) {
      return [];
    }

    final directory = Directory(resourcePath);
    if (!directory.existsSync()) {
      _logger.warning('Directory does not exist at ${directory.absolute.path}');
      return [];
    }

    final models = <OpenApiModel>[];
    final requiredProjections = config.endpoints
        .map((e) => e.projection.toLowerCase())
        .toSet();

    await for (final entity in directory.list(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.json')) continue;

      final fileName = p.basename(entity.path).toLowerCase();
      _logger.info('Found JSON file: $fileName');

      // Strict match: fileName must match projection.json or projection.svc.json
      final isRequired = requiredProjections.any((proj) {
        final lowerProj = proj.toLowerCase();
        final match =
            fileName == '$lowerProj.json' ||
            fileName == '$lowerProj.svc.json' ||
            fileName == lowerProj;

        if (match) {
          _logger.info('File $fileName matches required projection: $proj');
        }
        return match;
      });

      if (!isRequired) continue;

      try {
        _logger.info('Loading potential OpenAPI file: ${entity.path}');
        final content = await entity.readAsString();
        final jsonMap = jsonDecode(content) as Map<String, dynamic>;

        _logger.fine('JSON root keys: ${jsonMap.keys.take(5).join(', ')}');

        if (jsonMap.containsKey('openapi') || jsonMap.containsKey('swagger')) {
          _logger.info(
            'Successfully identified valid OpenAPI/Swagger specification: $fileName',
          );
          models.add(OpenApiModel.fromJson(jsonMap));
        } else {
          _logger.warning(
            'Skipping $fileName: Missing "openapi" or "swagger" root key (OData Edmx detected?)',
          );
        }
      } catch (e) {
        throw MetadataException(
          'Failed to load OpenAPI file ${entity.path}: $e',
          e,
        );
      }
    }

    return models;
  }
}
