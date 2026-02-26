/// Represents the type of a generated file.
enum FileType {
  /// A general model file.
  model,

  /// A response model file.
  responseModel,

  /// A request model file.
  requestModel,

  /// An expansion model file.
  expandModel,

  /// An entity model file.
  entityModel,

  /// An enum file.
  enumType,

  /// A test file.
  test,

  /// Any other type of file.
  other,
}

/// Represents a file that has been generated but not yet written to disk.
class GeneratedFileModel {
  /// Creates a [GeneratedFileModel] instance.
  GeneratedFileModel({
    required this.fileName,
    required this.content,
    required this.type,
    this.isCustom = false,
  });

  /// The relative path and name of the file (e.g., 'entities/user_model.dart').
  final String fileName;

  /// The full source code content of the file.
  final String content;

  /// The type of the file (e.g., model or enum).
  final FileType type;

  /// Whether this is a custom extension file that should not be overwritten.
  final bool isCustom;
}
