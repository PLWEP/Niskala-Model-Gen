import 'package:logging/logging.dart';
import 'package:niskala_model_gen/src/models/builders/pending_model.dart';
import 'package:niskala_model_gen/src/models/openapi/schema_model.dart';

/// Encapsulates the state of the generation process.
class GenerationContext {
  GenerationContext({
    required this.usedEnums,
    required this.pendingModels,
    required this.classNameToFolder,
    required this.signatureToClassName,
    required this.classToSchema,
    required this.logger,
    required this.subFolderResolver,
    this.components,
    this.isFlutter = false,
    this.packageName = 'YOUR_PROJECT_NAME',
  });

  /// The components (schemas) from the OpenAPI document.
  final Map<String, SchemaModel>? components;

  /// Whether the project is a Flutter project.
  final bool isFlutter;

  /// The project name for imports.
  final String packageName;

  /// Map of enum names to their schemas.
  final Map<String, SchemaModel> usedEnums;

  /// List of models that need to be generated.
  final List<PendingModel> pendingModels;

  /// Map of class names to their target folders.
  final Map<String, String> classNameToFolder;

  /// Map of schema signatures to class names (for deduplication).
  final Map<String, String> signatureToClassName;

  /// Map of class names to their source schemas.
  final Map<String, SchemaModel> classToSchema;

  /// Logger for reporting progress and warnings.
  final Logger logger;

  /// Callback to determine the sub-folder for a class.
  final String Function(String className) subFolderResolver;
}
