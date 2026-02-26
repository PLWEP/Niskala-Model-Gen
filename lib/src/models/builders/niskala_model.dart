import 'package:niskala_model_gen/src/models/builders/endpoint_model.dart';
import 'package:niskala_model_gen/src/models/openapi/openapi_model.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

/// Represents the section `niskala_gen` in the YAML configuration.
class GenSectionConfig {
  /// Creates a [GenSectionConfig] instance.
  GenSectionConfig({
    this.resourcePath,
    this.output,
    Map<String, List<String>>? classExpansions,
  }) : classExpansions = classExpansions ?? {};

  /// Factory constructor to create a [GenSectionConfig] from a YAML map.
  factory GenSectionConfig.fromYaml(YamlMap map) {
    return GenSectionConfig(
      resourcePath: map['resource_path']?.toString(),
      output: map['output']?.toString(),
    );
  }

  /// The path to the directory containing OpenAPI JSON metadata files.
  final String? resourcePath;

  /// The root directory where generated code will be written (typically 'lib').
  final String? output;

  /// Map of class names to their expansion properties
  final Map<String, List<String>> classExpansions;
}

/// Represents the simplified configuration model for Niskala Model Gen.
class NiskalaModel {
  /// Creates a [NiskalaModel] with the required [endpoints].
  NiskalaModel({
    required this.endpoints,
    this.projectName,
    this.configDir,
    this.genConfig,
    this.openApiModels = const [],
    this.isFlutter = false,
    this.resolvedProjectName,
  });

  /// Factory constructor to create a [NiskalaModel] from a YAML map.
  factory NiskalaModel.fromYaml(
    YamlMap map, {
    String? configDir,
    bool isFlutter = false,
    String? resolvedProjectName,
  }) {
    // 1. Endpoints (apiDefinitions)
    final endpointsList = <EndpointModel>[];
    if (map.containsKey('apiDefinitions') &&
        map['apiDefinitions'] is YamlList) {
      final definitions = map['apiDefinitions'] as YamlList;
      for (final def in definitions) {
        if (def is YamlMap) {
          endpointsList.add(EndpointModel.fromApiDefinition(def));
        }
      }
    }

    // 2. Niskala Gen Config (unified)
    GenSectionConfig? genConfig;
    if (map.containsKey('niskala_gen') && map['niskala_gen'] is YamlMap) {
      genConfig = GenSectionConfig.fromYaml(map['niskala_gen'] as YamlMap);
    } else if (map.containsKey('niskala_model_gen') &&
        map['niskala_model_gen'] is YamlMap) {
      // Fallback for backward compatibility
      genConfig = GenSectionConfig.fromYaml(
        map['niskala_model_gen'] as YamlMap,
      );
    }

    return NiskalaModel(
      endpoints: endpointsList,
      projectName: map['project_name']?.toString(),
      configDir: configDir,
      genConfig: genConfig,
      isFlutter: isFlutter,
      resolvedProjectName: resolvedProjectName,
    );
  }

  /// The name of the project (used for imports in tests).
  final String? projectName;

  /// The directory containing the configuration file.
  final String? configDir;

  /// A list of API endpoints defined in the configuration.
  final List<EndpointModel> endpoints;

  /// The generator-specific configuration section.
  final GenSectionConfig? genConfig;

  /// Operational state: The list of loaded OpenAPI specs.
  List<OpenApiModel> openApiModels;

  /// Whether the project is a Flutter project.
  final bool isFlutter;

  /// The project name resolved from pubspec.yaml.
  final String? resolvedProjectName;

  /// The project name to use for imports (custom config wins over pubspec).
  String get effectiveProjectName =>
      projectName ?? resolvedProjectName ?? 'YOUR_PROJECT_NAME';

  /// The base directory for all outputs (defaults to 'lib').
  String get baseDirectory {
    final output = genConfig?.output ?? 'lib';
    if (configDir != null && !p.isAbsolute(output)) {
      return p.normalize(p.join(configDir!, output));
    }
    return output;
  }

  /// The target directory for generated models (relative to baseDirectory).
  /// We want this to always be 'models'.
  String get modelsSubDir => 'models';

  /// The root directory for tests (typically 'test').
  String get testBaseDirectory => 'test';

  /// The target directory for generated models (absolute/full path).
  String get outputDirectory => p.join(baseDirectory, modelsSubDir);

  /// The target directory for generated enums.
  String get enumsDirectory => p.join(outputDirectory, 'enums');

  /// Convenience getter for the resource path.
  String? get resourcePath {
    final resPath = genConfig?.resourcePath;
    if (resPath != null && configDir != null && !p.isAbsolute(resPath)) {
      return p.normalize(p.join(configDir!, resPath));
    }
    return resPath;
  }
}
