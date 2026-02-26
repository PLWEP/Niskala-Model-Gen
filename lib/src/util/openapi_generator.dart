import 'package:dart_style/dart_style.dart';
import 'package:logging/logging.dart';
import 'package:niskala_model_gen/src/models/builders/endpoint_model.dart';
import 'package:niskala_model_gen/src/models/builders/generated_file_model.dart';
import 'package:niskala_model_gen/src/models/builders/niskala_model.dart';
import 'package:niskala_model_gen/src/models/builders/pending_model.dart';
import 'package:niskala_model_gen/src/models/openapi/openapi_model.dart';
import 'package:niskala_model_gen/src/models/openapi/operation_model.dart';
import 'package:niskala_model_gen/src/models/openapi/path_item_model.dart';
import 'package:niskala_model_gen/src/models/openapi/schema_model.dart';
import 'package:niskala_model_gen/src/util/generator/class_generator.dart';
import 'package:niskala_model_gen/src/util/generator/enum_generator.dart';
import 'package:niskala_model_gen/src/util/generator/generation_context.dart';
import 'package:niskala_model_gen/src/util/generator/naming_utils.dart';
import 'package:niskala_model_gen/src/util/generator/schema_resolver.dart';
import 'package:niskala_model_gen/src/util/generator/test_generator.dart';
import 'package:pub_semver/pub_semver.dart';

/// A generator that translates OpenAPI specifications into Dart model files.
///
/// This orchestrator coordinates specialized modules to map OpenAPI paths,
/// operations, and schemas to Dart classes and enums.
class OpenApiGenerator {
  /// Creates an [OpenApiGenerator] with the given [config].
  OpenApiGenerator(this.config) {
    _formatter = DartFormatter(languageVersion: Version(3, 0, 0));
    _enumGenerator = EnumGenerator(formatter: _formatter);
    _classGenerator = ClassGenerator(
      config: config,
      context: _context,
      formatter: _formatter,
    );
  }

  /// The configuration containing project information and endpoints.
  final NiskalaModel config;

  /// Logger instance for this class.
  static final Logger _logger = Logger('OpenApiGenerator');

  late final DartFormatter _formatter;
  late final EnumGenerator _enumGenerator;
  late final ClassGenerator _classGenerator;

  // Internal state maintained via GenerationContext
  final Map<String, SchemaModel> _usedEnums = {};
  final List<PendingModel> _pendingModels = [];
  final Map<String, String> _classNameToFolder = {};
  final Map<String, String> _signatureToClassName = {};
  final Map<String, SchemaModel> _classToSchema = {};

  late final GenerationContext _context = GenerationContext(
    usedEnums: _usedEnums,
    pendingModels: _pendingModels,
    classNameToFolder: _classNameToFolder,
    signatureToClassName: _signatureToClassName,
    classToSchema: _classToSchema,
    logger: _logger,
    subFolderResolver: _getSubFolder,
    components: config.openApiModels.isNotEmpty
        ? config.openApiModels.first.components?.schemas
        : null, // Simplification
    isFlutter: config.isFlutter,
    packageName: config.effectiveProjectName,
  );

  /// Generates Dart model files for all endpoints defined in the configuration.
  List<GeneratedFileModel> generate() {
    final generatedFiles = <GeneratedFileModel>[];
    final generatedNames = <String>{};
    _usedEnums.clear();
    _signatureToClassName.clear();
    _pendingModels.clear();
    _classNameToFolder.clear();

    // --- PHASE 1: PRE-PASS (Discovery) ---
    for (final endpoint in config.endpoints) {
      if (endpoint.projection.isEmpty || endpoint.name.isEmpty) continue;

      final targetApi = _getTargetApi(endpoint);
      if (targetApi == null) continue;

      final pathKey = '/${endpoint.name}';
      final matchedKey = _findMatchedPath(targetApi, pathKey, endpoint.name);
      final pathItem = matchedKey.isNotEmpty
          ? targetApi.paths[matchedKey]
          : null;

      if (pathItem == null) continue;

      final methods = ['get', 'post', 'put', 'patch', 'delete'];
      for (final method in methods) {
        final operation = _getOperation(pathItem, method);
        if (operation == null) continue;

        _discoverExpansions(endpoint, operation, targetApi, pathKey);
      }
    }

    // --- PHASE 2: GENERATION ---
    final testGenerator = TestGenerator(
      config: config,
      context: _context,
      formatter: _formatter,
    );

    for (final endpoint in config.endpoints) {
      if (endpoint.projection.isEmpty || endpoint.name.isEmpty) continue;

      final targetApi = _getTargetApi(endpoint);
      if (targetApi == null) continue;

      final pathItem = _getPathItem(targetApi, endpoint);
      if (pathItem == null) continue;

      final methodKey = endpoint.method.toLowerCase();
      final operation = _getOperation(pathItem, methodKey);
      if (operation == null) continue;

      // Request Body
      _handleRequestBody(
        endpoint,
        operation,
        targetApi,
        methodKey,
        generatedFiles,
        generatedNames,
      );

      // Responses
      _handleResponses(
        endpoint,
        operation,
        targetApi,
        methodKey,
        generatedFiles,
        generatedNames,
      );

      // Expansions
      _handleExpansions(
        endpoint,
        operation,
        targetApi,
        generatedFiles,
        generatedNames,
      );
    }

    // Process Pending Models
    while (_pendingModels.isNotEmpty) {
      final pending = _pendingModels.removeAt(0);
      if (!generatedNames.contains(pending.className)) {
        _classGenerator
            .generate(
              pending.className,
              pending.schema,
              pending.components,
              pending.subFolder,
            )
            .forEach((path, content) {
              generatedFiles.add(
                GeneratedFileModel(
                  fileName: '${config.modelsSubDir}/${pending.subFolder}/$path',
                  content: content,
                  type: pending.subFolder == 'entities'
                      ? FileType.entityModel
                      : FileType.other,
                  isCustom: !path.contains('.niskala.'),
                ),
              );
            });
        generatedNames.add(pending.className);
      }
    }

    // Enums
    _usedEnums.forEach((name, schema) {
      if (!generatedNames.contains(name)) {
        final content = _enumGenerator.generate(name, schema);
        generatedFiles.add(
          GeneratedFileModel(
            fileName:
                '${config.modelsSubDir}/enums/${NamingUtils.toSnakeCase(name)}.dart',
            content: content,
            type: FileType.enumType,
          ),
        );
        generatedNames.add(name);
      }
    });

    // --- PHASE 3: TEST GENERATION ---
    for (final entry in _classToSchema.entries) {
      final className = entry.key;
      final schema = entry.value;
      final subFolder = _classNameToFolder[className] ?? 'entities';

      final testContent = testGenerator.generateTest(className, schema);
      final fileName = NamingUtils.toSnakeCase(className);

      generatedFiles.add(
        GeneratedFileModel(
          fileName: 'test/models/$subFolder/${fileName}_test.dart',
          content: testContent,
          type: FileType.test,
        ),
      );
    }

    return generatedFiles;
  }

  // --- Helper Methods ---

  OpenApiModel? _getTargetApi(EndpointModel endpoint) {
    try {
      final projName = endpoint.projection.replaceAll('.svc', '');
      return config.openApiModels.firstWhere(
        (api) =>
            api.info.title.contains(projName) ||
            api.info.description.contains(projName),
        orElse: () => config.openApiModels.first,
      );
    } catch (e) {
      return config.openApiModels.isNotEmpty
          ? config.openApiModels.first
          : null;
    }
  }

  String _findMatchedPath(
    OpenApiModel api,
    String pathKey,
    String endpointName,
  ) {
    final paths = api.paths.keys.cast<String>();
    if (paths.contains(pathKey)) return pathKey;
    return paths.firstWhere((key) {
      if (key.startsWith('$pathKey(')) return true;
      if (key.endsWith('/$endpointName')) return true;
      return false;
    }, orElse: () => '');
  }

  PathItemModel? _getPathItem(OpenApiModel api, EndpointModel endpoint) {
    final pathKey = '/${endpoint.name}';
    final matchedKey = _findMatchedPath(api, pathKey, endpoint.name);
    return matchedKey.isNotEmpty ? api.paths[matchedKey] : null;
  }

  OperationModel? _getOperation(PathItemModel pathItem, String method) {
    switch (method.toLowerCase()) {
      case 'get':
        return pathItem.get;
      case 'post':
        return pathItem.post;
      case 'put':
        return pathItem.put;
      case 'patch':
        return pathItem.patch;
      case 'delete':
        return pathItem.delete;
      default:
        return null;
    }
  }

  void _discoverExpansions(
    EndpointModel endpoint,
    OperationModel operation,
    OpenApiModel targetApi,
    String pathKey,
  ) {
    final expandNames = <String>{};
    for (final param in operation.parameters) {
      if (param.name == r'$expand') {
        final enumValues = param.schema?.items?.enumValues;
        if (enumValues != null) {
          expandNames.addAll(enumValues.map((e) => e.toString()));
        }
      }
    }

    for (final expandName in expandNames) {
      var baseSchema =
          operation.responses['200']?.schema ??
          operation.responses['201']?.schema;
      if (baseSchema == null && operation.responses['200']?.ref != null) {
        final resolved = SchemaResolver.resolveResponse(
          operation.responses['200']!.ref!,
          targetApi,
        );
        baseSchema = resolved?.schema;
      }

      if (baseSchema != null) {
        var entitySchema = baseSchema;
        if (entitySchema.type == 'object' &&
            entitySchema.properties.containsKey('value')) {
          entitySchema =
              entitySchema.properties['value']!.items ??
              entitySchema.properties['value']!;
        }
        if (entitySchema.type == 'array' && entitySchema.items != null) {
          entitySchema = entitySchema.items!;
        }

        if (entitySchema.ref != null) {
          entitySchema =
              SchemaResolver.resolveSchema(
                entitySchema.ref!,
                targetApi.components?.schemas,
              ) ??
              entitySchema;
        }

        final entityName = endpoint.name.replaceAll('Set', '');
        SchemaModel? expandSchema;
        if (entitySchema.properties.containsKey(expandName)) {
          expandSchema = entitySchema.properties[expandName];
        } else {
          final expandPathKey = '$pathKey(';
          final matchedExpandKey = targetApi.paths.keys.firstWhere(
            (k) => k.startsWith(expandPathKey) && k.endsWith('/$expandName'),
            orElse: () => '',
          );
          if (matchedExpandKey.isNotEmpty) {
            expandSchema = targetApi
                .paths[matchedExpandKey]
                ?.get
                ?.responses['200']
                ?.schema;
            if (expandSchema == null &&
                targetApi.paths[matchedExpandKey]?.get?.responses['200']?.ref !=
                    null) {
              expandSchema = SchemaResolver.resolveResponse(
                targetApi.paths[matchedExpandKey]!.get!.responses['200']!.ref!,
                targetApi,
              )?.schema;
            }
          }
        }

        if (expandSchema != null) {
          final className = '${NamingUtils.toPascalCase(expandName)}Model';
          final currentExpansions = config.genConfig!.classExpansions
              .putIfAbsent(entityName, () => []);
          if (!currentExpansions.contains(expandName)) {
            _logger.fine('Discovered expansion: $expandName for $entityName');
            currentExpansions.add(expandName);
          }
          if (!_classNameToFolder.containsKey(className)) {
            _classNameToFolder[className] = 'expansions';
          }
        }
      }
    }
  }

  void _handleRequestBody(
    EndpointModel endpoint,
    OperationModel operation,
    OpenApiModel targetApi,
    String methodKey,
    List<GeneratedFileModel> generatedFiles,
    Set<String> generatedNames,
  ) {
    var resolvedRequestBody = operation.requestBody;
    if (resolvedRequestBody?.ref != null) {
      final resolved = SchemaResolver.resolveRequestBody(
        resolvedRequestBody!.ref!,
        targetApi,
      );
      if (resolved != null) resolvedRequestBody = resolved;
    }

    if (resolvedRequestBody != null && resolvedRequestBody.schema != null) {
      final className = _getClassName(
        endpoint,
        operation,
        method: methodKey,
        schema: resolvedRequestBody.schema,
      );
      _classNameToFolder[className] = 'requests';
      const folder = 'requests';
      if (!generatedNames.contains(className)) {
        _classGenerator
            .generate(
              className,
              resolvedRequestBody.schema!,
              targetApi.components?.schemas,
              folder,
            )
            .forEach((path, content) {
              generatedFiles.add(
                GeneratedFileModel(
                  fileName: '${config.modelsSubDir}/$folder/$path',
                  content: content,
                  type: folder == 'entities'
                      ? FileType.entityModel
                      : FileType.requestModel,
                  isCustom: !path.contains('.niskala.'),
                ),
              );
            });
        generatedNames.add(className);
      }
    }
  }

  void _handleResponses(
    EndpointModel endpoint,
    OperationModel operation,
    OpenApiModel targetApi,
    String methodKey,
    List<GeneratedFileModel> generatedFiles,
    Set<String> generatedNames,
  ) {
    for (final responseEntry in operation.responses.entries) {
      final code = responseEntry.key;
      var resolvedResponse = responseEntry.value;
      if (resolvedResponse.ref != null) {
        final resolved = SchemaResolver.resolveResponse(
          resolvedResponse.ref!,
          targetApi,
        );
        if (resolved != null) resolvedResponse = resolved;
      }

      if (resolvedResponse.schema == null) continue;

      final className = _getClassName(
        endpoint,
        operation,
        code: code,
        method: methodKey,
        schema: resolvedResponse.schema,
      );

      if (className == 'ErrorModel') {
        const folder = 'responses';
        if (!generatedNames.contains('ErrorModel')) {
          _classGenerator
              .generate(
                'ErrorModel',
                resolvedResponse.schema!,
                targetApi.components?.schemas,
                folder,
              )
              .forEach((path, content) {
                generatedFiles.add(
                  GeneratedFileModel(
                    fileName: '${config.modelsSubDir}/$folder/$path',
                    content: content,
                    type: FileType.responseModel,
                    isCustom: !path.contains('.niskala.'),
                  ),
                );
              });
          generatedNames.add('ErrorModel');
        }
        continue;
      }

      if (!generatedNames.contains(className)) {
        _classNameToFolder[className] = 'responses';
        const folder = 'responses';
        _classGenerator
            .generate(
              className,
              resolvedResponse.schema!,
              targetApi.components?.schemas,
              folder,
            )
            .forEach((path, content) {
              generatedFiles.add(
                GeneratedFileModel(
                  fileName: '${config.modelsSubDir}/$folder/$path',
                  content: content,
                  type: folder == 'entities'
                      ? FileType.entityModel
                      : FileType.responseModel,
                  isCustom: !path.contains('.niskala.'),
                ),
              );
            });
        generatedNames.add(className);
      }
    }
  }

  void _handleExpansions(
    EndpointModel endpoint,
    OperationModel operation,
    OpenApiModel targetApi,
    List<GeneratedFileModel> generatedFiles,
    Set<String> generatedNames,
  ) {
    final expandNames = <String>{};
    for (final param in operation.parameters) {
      if (param.name == r'$expand') {
        final enumValues = param.schema?.items?.enumValues;
        if (enumValues != null) {
          expandNames.addAll(enumValues.map((e) => e.toString()));
        }
      }
    }

    for (final expandName in expandNames) {
      var baseSchema =
          operation.responses['200']?.schema ??
          operation.responses['201']?.schema;
      if (baseSchema == null && operation.responses['200']?.ref != null) {
        final resolved = SchemaResolver.resolveResponse(
          operation.responses['200']!.ref!,
          targetApi,
        );
        baseSchema = resolved?.schema;
      }

      if (baseSchema != null) {
        var entitySchema = baseSchema;
        if (entitySchema.type == 'object' &&
            entitySchema.properties.containsKey('value')) {
          entitySchema =
              entitySchema.properties['value']!.items ??
              entitySchema.properties['value']!;
        }
        if (entitySchema.type == 'array' && entitySchema.items != null) {
          entitySchema = entitySchema.items!;
        }
        if (entitySchema.ref != null) {
          entitySchema =
              SchemaResolver.resolveSchema(
                entitySchema.ref!,
                targetApi.components?.schemas,
              ) ??
              entitySchema;
        }

        SchemaModel? expandSchema;
        if (entitySchema.properties.containsKey(expandName)) {
          expandSchema = entitySchema.properties[expandName];
        } else {
          final pathKey = '/${endpoint.name}';
          final expandPathKey = '$pathKey(';
          final matchedExpandKey = targetApi.paths.keys.firstWhere(
            (k) => k.startsWith(expandPathKey) && k.endsWith('/$expandName'),
            orElse: () => '',
          );
          if (matchedExpandKey.isNotEmpty) {
            expandSchema = targetApi
                .paths[matchedExpandKey]
                ?.get
                ?.responses['200']
                ?.schema;
            if (expandSchema == null &&
                targetApi.paths[matchedExpandKey]?.get?.responses['200']?.ref !=
                    null) {
              expandSchema = SchemaResolver.resolveResponse(
                targetApi.paths[matchedExpandKey]!.get!.responses['200']!.ref!,
                targetApi,
              )?.schema;
            }
          }
        }

        if (expandSchema != null) {
          final className = '${NamingUtils.toPascalCase(expandName)}Model';
          if (!generatedNames.contains(className)) {
            const folder = 'expansions';
            _classGenerator
                .generate(
                  className,
                  expandSchema,
                  targetApi.components?.schemas,
                  folder,
                )
                .forEach((path, content) {
                  generatedFiles.add(
                    GeneratedFileModel(
                      fileName: '${config.modelsSubDir}/$folder/$path',
                      content: content,
                      type: FileType.expandModel,
                      isCustom: !path.contains('.niskala.'),
                    ),
                  );
                });
            generatedNames.add(className);
          }
        }
      }
    }
  }

  String _getClassName(
    EndpointModel endpoint,
    OperationModel operation, {
    String? code,
    String? method,
    SchemaModel? schema,
  }) {
    if (code == 'default' ||
        (code != null &&
            int.tryParse(code) != null &&
            int.parse(code) >= 400)) {
      return 'ErrorModel';
    }

    if (schema != null && schema.ref != null) {
      final refName = schema.ref!.split('/').last;
      var className = NamingUtils.toPascalCase(refName);
      if (!className.endsWith('Model')) className = '${className}Model';
      return className;
    }

    if (operation.operationId.isNotEmpty) {
      var className = NamingUtils.toPascalCase(operation.operationId);
      // Strip 'Get' prefix if present for consistency
      if (className.startsWith('Get') && className.length > 3) {
        className = className.substring(3);
      }
      // Ensure suffix
      if (!className.endsWith('Model')) {
        className = '${className}Model';
      }
      return className;
    }

    // Standardize entity name by removing common suffixes
    var entityName = endpoint.name;
    // Strip leading slash if present
    if (entityName.startsWith('/')) {
      entityName = entityName.substring(1);
    }

    if (entityName.endsWith('Set') && entityName.length > 3) {
      entityName = entityName.substring(0, entityName.length - 3);
    } else if (entityName.endsWith('Entities')) {
      entityName = entityName.substring(0, entityName.length - 8);
      if (entityName.isEmpty || entityName.endsWith('/')) {
        entityName = '${entityName}Entity';
      }
    }

    var suffix = method != null ? NamingUtils.toPascalCase(method) : '';
    if (suffix == 'Post' &&
        (endpoint.name.endsWith('Set') || endpoint.name.endsWith('Entities'))) {
      suffix = 'Insert';
    }
    if (suffix == 'Patch' || suffix == 'Put') suffix = 'Update';

    var className = (suffix == 'Insert' || suffix == 'Update')
        ? '$entityName${suffix}Model'
        : '${entityName}Model';

    if (className.contains('ModelModel')) {
      className = className.replaceAll('ModelModel', 'Model');
    }
    return className;
  }

  String _getSubFolder(String className) {
    if (className == 'ErrorModel') return 'responses';
    if (className.endsWith('SetModel')) return 'responses';

    // Check if this class was explicitly mapped in orchestrator
    if (_classNameToFolder.containsKey(className)) {
      return _classNameToFolder[className]!;
    }

    if (className.endsWith('InsertModel') ||
        className.endsWith('UpdateModel')) {
      return 'requests';
    }

    return 'entities';
  }
}
