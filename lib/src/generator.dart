import 'package:niskala_model_gen/src/core/logger.dart';
import 'package:niskala_model_gen/src/models/builders/generated_file_model.dart';
import 'package:niskala_model_gen/src/models/builders/niskala_model.dart';
import 'package:niskala_model_gen/src/util/openapi_generator.dart';
import 'package:niskala_model_gen/src/util/openapi_loader.dart';

/// Main class for generating Dart models from IFS OpenAPI definitions.
///
/// This class orchestrates the loading of OpenAPI specifications and the
/// subsequent generation of Dart model files based on those specifications.
class ModelGenerator {
  /// Creates a new [ModelGenerator] instance with the provided [config].
  ModelGenerator(this.config);

  /// The configuration object containing project details and API definitions.
  final NiskalaModel config;

  /// Orchestrates the generation process.
  ///
  /// This method:
  /// 1. Loads all OpenAPI definitions specified in the config.
  /// 2. Initializes the [OpenApiGenerator].
  /// 3. Generates the Dart model files.
  /// 4. Returns a list of [GeneratedFileModel] containing the file paths and contents.
  Future<List<GeneratedFileModel>> generate() async {
    // 1. Load OpenAPI Definitions
    final openApiModels = await OpenApiLoader.loadAll(config);
    config.openApiModels = openApiModels;
    logger.info('Loaded ${openApiModels.length} OpenAPI documents.');

    final generatedFiles = <GeneratedFileModel>[];

    // 2. Generate OpenAPI Models
    final openApiGenerator = OpenApiGenerator(config);
    final openApiFiles = openApiGenerator.generate();
    generatedFiles.addAll(openApiFiles);

    return generatedFiles;
  }
}
