import 'package:code_builder/code_builder.dart';
import 'package:dart_style/dart_style.dart';
import 'package:niskala_model_gen/src/models/builders/niskala_model.dart';
import 'package:niskala_model_gen/src/models/openapi/schema_model.dart';
import 'package:niskala_model_gen/src/util/generator/generation_context.dart';
import 'package:niskala_model_gen/src/util/generator/naming_utils.dart';
import 'package:niskala_model_gen/src/util/generator/type_mapper.dart';
import 'package:pub_semver/pub_semver.dart';

/// Generates the source code for Dart classes (Base and Extension).
class ClassGenerator {
  ClassGenerator({
    required this.config,
    required this.context,
    DartFormatter? formatter,
  }) : _formatter =
           formatter ?? DartFormatter(languageVersion: Version(3, 0, 0));

  final NiskalaModel config;
  final GenerationContext context;
  final DartFormatter _formatter;

  /// Generates the source code for Dart classes (Base and Extension) from an OpenAPI [SchemaModel].
  Map<String, String> generate(
    String className,
    SchemaModel schema,
    Map<String, SchemaModel>? components,
    String subFolder, {
    List<String>? expansions,
  }) {
    var effectiveSchema = schema;
    if (effectiveSchema.ref != null && effectiveSchema.properties.isEmpty) {
      final refName = effectiveSchema.ref!.split('/').last;
      effectiveSchema = components?[refName] ?? effectiveSchema;
    }

    context.classNameToFolder[className] = subFolder;
    context.classToSchema[className] = effectiveSchema;

    final effectiveExpansions = expansions ?? [];
    final baseEntityName = className.replaceAll('Model', '');
    if (config.genConfig != null) {
      if (config.genConfig!.classExpansions.containsKey(baseEntityName)) {
        final discovered = config.genConfig!.classExpansions[baseEntityName]!;
        for (final exp in discovered) {
          if (!effectiveExpansions.contains(exp)) {
            effectiveExpansions.add(exp);
          }
        }
      }
    }

    final baseClassName = '_\$$className';

    // --- BASE CLASS GENERATION ---
    var usesDeepEquality = false;
    final baseClassBuilder = Class((b) {
      b
        ..name = baseClassName
        ..abstract = true
        ..annotations.add(refer('immutable'))
        ..fields.addAll([
          for (final entry in effectiveSchema.properties.entries)
            Field((fb) {
              final propName = entry.key;
              final propSchema = entry.value;
              final propertyType = TypeMapper.mapSchemaToDartType(
                propSchema,
                components,
                propName,
                className,
                context,
              );
              final isRequired = effectiveSchema.requiredFields.contains(
                propName,
              );
              fb
                ..name = NamingUtils.toCamelCase(propName)
                ..modifier = FieldModifier.final$
                ..type = refer('$propertyType${isRequired ? '' : '?'}');
            }),
          for (final exp in effectiveExpansions)
            Field((fb) {
              final expClassName = '${NamingUtils.toPascalCase(exp)}Model';
              fb
                ..name = NamingUtils.toCamelCase(exp)
                ..modifier = FieldModifier.final$
                ..type = refer('$expClassName?');
            }),
        ])
        ..constructors.add(
          Constructor((cb) {
            cb.constant = true;
            final requiredParams = <Parameter>[];
            final optionalParams = <Parameter>[];

            for (final entry in effectiveSchema.properties.entries) {
              final isRequired = effectiveSchema.requiredFields.contains(
                entry.key,
              );
              final param = Parameter((pb) {
                pb
                  ..name = NamingUtils.toCamelCase(entry.key)
                  ..toThis = true
                  ..named = true
                  ..required = isRequired;
              });
              if (isRequired) {
                requiredParams.add(param);
              } else {
                optionalParams.add(param);
              }
            }
            for (final exp in effectiveExpansions) {
              optionalParams.add(
                Parameter((pb) {
                  pb
                    ..name = NamingUtils.toCamelCase(exp)
                    ..toThis = true
                    ..named = true;
                }),
              );
            }
            cb.optionalParameters.addAll([
              ...requiredParams,
              ...optionalParams,
            ]);
          }),
        );

      // toJson logic
      b.methods.add(
        Method(
          (mb) => mb
            ..name = 'toJson'
            ..returns = refer('Map<String, dynamic>')
            ..body = Block((bb) {
              final map = <Expression, Expression>{};
              effectiveSchema.properties.forEach((propName, propSchema) {
                final camelProp = NamingUtils.toCamelCase(propName);
                final jsonProp = propName == 'odataEtag'
                    ? '@odata.etag'
                    : propName;
                final propertyType = TypeMapper.mapSchemaToDartType(
                  propSchema,
                  components,
                  propName,
                  className,
                  context,
                );

                Expression valExpr = refer(camelProp);
                if (propertyType.startsWith('List<')) {
                  final itemType = propertyType
                      .replaceAll('List<', '')
                      .replaceAll('>', '');
                  final isModel =
                      context.classNameToFolder.containsKey(itemType) ||
                      context.usedEnums.containsKey(itemType);

                  if (isModel) {
                    valExpr = valExpr
                        .nullSafeProperty('map')
                        .call([
                          Method(
                            (m) => m
                              ..lambda = true
                              ..requiredParameters.add(
                                Parameter((p) => p..name = 'e'),
                              )
                              ..body = refer(
                                'e',
                              ).property('toJson').call([]).code,
                          ).closure,
                        ])
                        .property('toList')
                        .call([]);
                  } else if (itemType == 'DateTime') {
                    valExpr = valExpr
                        .nullSafeProperty('map')
                        .call([
                          Method(
                            (m) => m
                              ..lambda = true
                              ..requiredParameters.add(
                                Parameter((p) => p..name = 'e'),
                              )
                              ..body = refer(
                                'e',
                              ).property('toIso8601String').call([]).code,
                          ).closure,
                        ])
                        .property('toList')
                        .call([]);
                  }
                } else if (context.classNameToFolder.containsKey(
                      propertyType,
                    ) ||
                    context.usedEnums.containsKey(propertyType)) {
                  valExpr = valExpr.nullSafeProperty('toJson').call([]);
                } else if (propertyType == 'DateTime') {
                  if (effectiveSchema.requiredFields.contains(propName)) {
                    valExpr = valExpr.property('toIso8601String').call([]);
                  } else {
                    valExpr = valExpr
                        .nullSafeProperty('toIso8601String')
                        .call([]);
                  }
                }
                map[literalString(jsonProp)] = valExpr;
              });

              for (final exp in effectiveExpansions) {
                map[literalString(exp)] = refer(
                  NamingUtils.toCamelCase(exp),
                ).nullSafeProperty('toJson').call([]);
              }

              bb.addExpression(literalMap(map).returned);
            }),
        ),
      );

      // toPartialJson
      b.methods.add(
        Method(
          (mb) => mb
            ..name = 'toPartialJson'
            ..returns = refer('Map<String, dynamic>')
            ..lambda = true
            ..body = const Code(
              'toJson()..removeWhere((key, value) => value == null)',
            ),
        ),
      );

      // validate
      b.methods.add(
        Method(
          (mb) => mb
            ..name = 'validate'
            ..returns = refer('Map<String, String>')
            ..body = Block((bb) {
              bb.statements.add(
                const Code('final errors = <String, String>{};'),
              );

              for (final entry in effectiveSchema.properties.entries) {
                final propName = entry.key;
                final propSchema = entry.value;
                final camelProp = NamingUtils.toCamelCase(propName);

                final isRequired = effectiveSchema.requiredFields.contains(
                  propName,
                );
                final isNullable = !isRequired;

                final hasStructuralConstraints =
                    propSchema.maxLength != null ||
                    propSchema.minimum != null ||
                    propSchema.maximum != null;

                final hasPatternConstraint = propSchema.pattern != null;
                final hasRequiredConstraint = isRequired && isNullable;

                if (!hasStructuralConstraints &&
                    !hasRequiredConstraint &&
                    !hasPatternConstraint) {
                  continue;
                }

                // Local variable for null-safety promotion
                bb.statements.add(Code('final $camelProp = this.$camelProp;'));

                if (hasRequiredConstraint) {
                  bb.statements.add(
                    Code('''
if ($camelProp == null) {
  errors['$propName'] = 'Field is required';
}'''),
                  );
                }

                if (hasStructuralConstraints || hasPatternConstraint) {
                  if (isNullable) {
                    bb.statements.add(Code('if ($camelProp != null) {'));
                  }

                  if (propSchema.maxLength != null) {
                    bb.statements.add(
                      Code('''
if ($camelProp.length > ${propSchema.maxLength}) {
  errors['$propName'] = 'Maximum length is ${propSchema.maxLength}';
}'''),
                    );
                  }

                  if (propSchema.minimum != null) {
                    bb.statements.add(
                      Code('''
if ($camelProp < ${propSchema.minimum}) {
  errors['$propName'] = 'Minimum value is ${propSchema.minimum}';
}'''),
                    );
                  }

                  if (propSchema.maximum != null) {
                    bb.statements.add(
                      Code('''
if ($camelProp > ${propSchema.maximum}) {
  errors['$propName'] = 'Maximum value is ${propSchema.maximum}';
}'''),
                    );
                  }

                  if (propSchema.pattern != null) {
                    bb.statements.add(
                      Code('''
if (!RegExp(r'${propSchema.pattern}').hasMatch($camelProp.toString())) {
  errors['$propName'] = 'Invalid format';
}'''),
                    );
                  }

                  if (isNullable) {
                    bb.statements.add(const Code('}'));
                  }
                }
              }

              bb.statements.add(const Code('return errors;'));
            }),
        ),
      );

      // --- New Functional Methods ---

      // operator ==
      b.methods.add(
        Method(
          (mb) => mb
            ..name = 'operator =='
            ..returns = refer('bool')
            ..requiredParameters.add(
              Parameter(
                (pb) => pb
                  ..name = 'other'
                  ..type = refer('Object'),
              ),
            )
            ..annotations.add(refer('override'))
            ..body = Block((bb) {
              bb.statements.add(
                const Code('''
if (identical(this, other)) {
  return true;
}'''),
              );
              bb.statements.add(
                Code('''
if (other is! $className) {
  return false;
}'''),
              );

              final allFields = [
                ...effectiveSchema.properties.keys.map(NamingUtils.toCamelCase),
                ...effectiveExpansions.map(NamingUtils.toCamelCase),
              ];

              final eqExpr = StringBuffer(
                allFields.isEmpty ? 'true' : 'other.runtimeType == runtimeType',
              );
              for (final field in allFields) {
                var isList = false;
                final propEntry = effectiveSchema.properties.entries.firstWhere(
                  (e) => NamingUtils.toCamelCase(e.key) == field,
                  orElse: () => MapEntry('', SchemaModel(type: 'string')),
                );
                if (propEntry.key != '') {
                  isList = propEntry.value.type == 'array';
                }

                if (isList) {
                  usesDeepEquality = true;
                  eqExpr.write(
                    ' && const DeepCollectionEquality().equals(other.$field, $field)',
                  );
                } else {
                  eqExpr.write(' && other.$field == $field');
                }
              }
              bb.statements.add(Code('return $eqExpr;'));
            }),
        ),
      );

      // hashCode
      b.methods.add(
        Method(
          (mb) => mb
            ..name = 'hashCode'
            ..returns = refer('int')
            ..type = MethodType.getter
            ..annotations.add(refer('override'))
            ..body = Block((bb) {
              final allFields = [
                ...effectiveSchema.properties.keys.map(NamingUtils.toCamelCase),
                ...effectiveExpansions.map(NamingUtils.toCamelCase),
              ];

              if (allFields.isEmpty) {
                bb.addExpression(
                  refer('runtimeType').property('hashCode').returned,
                );
              } else {
                final hashBuffer = StringBuffer();
                for (var i = 0; i < allFields.length; i++) {
                  final field = allFields[i];
                  var isList = false;
                  final propEntry = effectiveSchema.properties.entries
                      .firstWhere(
                        (e) => NamingUtils.toCamelCase(e.key) == field,
                        orElse: () => MapEntry('', SchemaModel(type: 'string')),
                      );
                  if (propEntry.key != '') {
                    isList = propEntry.value.type == 'array';
                  }

                  if (isList) {
                    usesDeepEquality = true;
                    hashBuffer.write(
                      'const DeepCollectionEquality().hash($field)',
                    );
                  } else {
                    hashBuffer.write('$field.hashCode');
                  }

                  if (i < allFields.length - 1) {
                    hashBuffer.write(' ^ ');
                  }
                }
                bb.statements.add(Code('return $hashBuffer;'));
              }
            }),
        ),
      );

      // toString
      b.methods.add(
        Method(
          (mb) => mb
            ..name = 'toString'
            ..returns = refer('String')
            ..annotations.add(refer('override'))
            ..body = Block((bb) {
              final entries = [
                ...effectiveSchema.properties.keys.map(NamingUtils.toCamelCase),
                ...effectiveExpansions.map(NamingUtils.toCamelCase),
              ];

              if (entries.isEmpty) {
                bb.addExpression(literalString('$className()').returned);
                return;
              }

              final buffer = StringBuffer()..writeln('$className(');
              for (var i = 0; i < entries.length; i++) {
                buffer.write('${entries[i]}: \$${entries[i]}');
                if (i < entries.length - 1) {
                  buffer.writeln(',');
                } else {
                  buffer.writeln();
                }
              }
              buffer.write(')');
              // Use multiline string to avoid long lines
              bb.addExpression(
                CodeExpression(Code("'''\n$buffer'''")).returned,
              );
            }),
        ),
      );
    });

    final fromJsonFunc = Method(
      (m) => m
        ..name = '_\$${className}FromJson'
        ..returns = refer(className)
        ..requiredParameters.add(
          Parameter(
            (pb) => pb
              ..name = 'json'
              ..type = refer('Map<String, dynamic>'),
          ),
        )
        ..body = Block((bb) {
          final args = <String, Expression>{};
          effectiveSchema.properties.forEach((propName, propSchema) {
            final propertyType = TypeMapper.mapSchemaToDartType(
              propSchema,
              components,
              propName,
              className,
              context,
            );
            final camelProp = NamingUtils.toCamelCase(propName);
            final jsonProp = propName == 'odataEtag' ? '@odata.etag' : propName;
            final isRequired = effectiveSchema.requiredFields.contains(
              propName,
            );

            Expression expr;
            if (propertyType.startsWith('List<')) {
              final itemType = propertyType
                  .replaceAll('List<', '')
                  .replaceAll('>', '');
              final mapExpr = context.usedEnums.containsKey(itemType)
                  ? refer(itemType).property('fromJson').call([refer('e')])
                  : refer(itemType).property('fromJson').call([
                      const CodeExpression(Code('e as Map<String, dynamic>')),
                    ]);

              expr = refer('json')
                  .index(literalString(jsonProp))
                  .asA(refer('List<dynamic>?'))
                  .nullSafeProperty('map')
                  .call([
                    Method(
                      (m) => m
                        ..lambda = true
                        ..requiredParameters.add(
                          Parameter((p) => p..name = 'e'),
                        )
                        ..body = mapExpr.code,
                    ).closure,
                  ])
                  .property('toList')
                  .call([]);
              if (isRequired) expr = expr.ifNullThen(literalList([]));
            } else if (context.usedEnums.containsKey(propertyType)) {
              if (isRequired) {
                expr = refer(propertyType).property('fromJson').call([
                  refer('json').index(literalString(jsonProp)),
                ]);
              } else {
                expr = refer('json')
                    .index(literalString(jsonProp))
                    .notEqualTo(literalNull)
                    .conditional(
                      refer(propertyType).property('fromJson').call([
                        refer('json').index(literalString(jsonProp)),
                      ]),
                      literalNull,
                    );
              }
            } else if (propertyType == 'DateTime') {
              if (isRequired) {
                expr = refer('DateTime').property('parse').call([
                  CodeExpression(Code("json['$jsonProp'] as String")),
                ]);
              } else {
                expr = refer('json')
                    .index(literalString(jsonProp))
                    .notEqualTo(literalNull)
                    .conditional(
                      refer('DateTime').property('parse').call([
                        CodeExpression(Code("json['$jsonProp'] as String")),
                      ]),
                      literalNull,
                    );
              }
            } else if (propertyType == 'double') {
              // Safe numeric conversion: API may return int for double fields
              if (isRequired) {
                expr = refer('json')
                    .index(literalString(jsonProp))
                    .asA(refer('num'))
                    .property('toDouble')
                    .call([]);
              } else {
                expr = refer('json')
                    .index(literalString(jsonProp))
                    .asA(refer('num?'))
                    .nullSafeProperty('toDouble')
                    .call([]);
              }
            } else if (propertyType == 'int') {
              // Safe numeric conversion: API may return double for int fields
              if (isRequired) {
                expr = refer('json')
                    .index(literalString(jsonProp))
                    .asA(refer('num'))
                    .property('toInt')
                    .call([]);
              } else {
                expr = refer('json')
                    .index(literalString(jsonProp))
                    .asA(refer('num?'))
                    .nullSafeProperty('toInt')
                    .call([]);
              }
            } else if ([
              'String',
              'bool',
              'num',
              'dynamic',
            ].contains(propertyType)) {
              expr = CodeExpression(
                Code(
                  "json['$jsonProp'] as $propertyType${isRequired ? '' : '?'}",
                ),
              );
            } else {
              if (isRequired) {
                expr = refer(propertyType).property('fromJson').call([
                  CodeExpression(
                    Code("json['$jsonProp'] as Map<String, dynamic>"),
                  ),
                ]);
              } else {
                expr = refer('json')
                    .index(literalString(jsonProp))
                    .notEqualTo(literalNull)
                    .conditional(
                      refer(propertyType).property('fromJson').call([
                        CodeExpression(
                          Code("json['$jsonProp'] as Map<String, dynamic>"),
                        ),
                      ]),
                      literalNull,
                    );
              }
            }
            args[camelProp] = expr;
          });

          for (final exp in effectiveExpansions) {
            final expClassName = '${NamingUtils.toPascalCase(exp)}Model';
            final camelExp = NamingUtils.toCamelCase(exp);
            final expr = refer('json')
                .index(literalString(exp))
                .notEqualTo(literalNull)
                .conditional(
                  refer(expClassName).property('fromJson').call([
                    CodeExpression(
                      Code("json['$exp'] as Map<String, dynamic>"),
                    ),
                  ]),
                  literalNull,
                );
            args[camelExp] = expr;
          }

          bb.addExpression(refer(className).call([], args).returned);
        }),
    );

    final baseLibrary = Library((lb) {
      lb.directives.addAll([
        Directive.partOf('${NamingUtils.toSnakeCase(className)}.dart'),
      ]);
      lb.body.addAll([baseClassBuilder, fromJsonFunc]);
    });

    final baseEmitter = DartEmitter();
    final baseContent =
        '// GENERATED CODE - DO NOT MODIFY BY HAND\n\n${baseLibrary.accept(baseEmitter)}';

    // --- CUSTOM CLASS GENERATION ---
    final custClassBuilder = Class((b) {
      b
        ..name = className
        ..extend = refer(baseClassName)
        ..implements.addAll([if (className == 'ErrorModel') refer('Exception')])
        ..constructors.addAll([
          Constructor((cb) {
            cb.constant = true;
            final requiredParams = <Parameter>[];
            final optionalParams = <Parameter>[];

            for (final entry in effectiveSchema.properties.entries) {
              final isRequired = effectiveSchema.requiredFields.contains(
                entry.key,
              );
              final param = Parameter((pb) {
                pb
                  ..name = 'super.${NamingUtils.toCamelCase(entry.key)}'
                  ..named = true
                  ..toThis = false
                  ..required = isRequired;
              });
              if (isRequired) {
                requiredParams.add(param);
              } else {
                optionalParams.add(param);
              }
            }
            for (final exp in effectiveExpansions) {
              optionalParams.add(
                Parameter((pb) {
                  pb
                    ..name = 'super.${NamingUtils.toCamelCase(exp)}'
                    ..named = true
                    ..toThis = false;
                }),
              );
            }
            cb.optionalParameters.addAll([
              ...requiredParams,
              ...optionalParams,
            ]);
          }),
          Constructor((cb) {
            cb
              ..name = 'fromJson'
              ..factory = true
              ..requiredParameters.add(
                Parameter(
                  (pb) => pb
                    ..name = 'json'
                    ..type = refer('Map<String, dynamic>'),
                ),
              )
              ..body = refer(
                '_\$${className}FromJson',
              ).call([refer('json')]).code;
          }),
        ]);

      // copyWith implementation
      b.methods.add(
        Method(
          (mb) => mb
            ..name = 'copyWith'
            ..returns = refer(className)
            ..optionalParameters.addAll([
              for (final entry in effectiveSchema.properties.entries)
                Parameter(
                  (pb) => pb
                    ..name = NamingUtils.toCamelCase(entry.key)
                    ..named = true
                    ..type = refer(
                      '${TypeMapper.mapSchemaToDartType(entry.value, components, entry.key, className, context)}?',
                    ),
                ),
              for (final exp in effectiveExpansions)
                Parameter(
                  (pb) => pb
                    ..name = NamingUtils.toCamelCase(exp)
                    ..named = true
                    ..type = refer('${NamingUtils.toPascalCase(exp)}Model?'),
                ),
            ])
            ..body = Block((bb) {
              final args = <String, Expression>{};
              for (final entry in effectiveSchema.properties.entries) {
                final camel = NamingUtils.toCamelCase(entry.key);
                args[camel] = refer(
                  camel,
                ).ifNullThen(refer('this').property(camel));
              }
              for (final exp in effectiveExpansions) {
                final camel = NamingUtils.toCamelCase(exp);
                args[camel] = refer(
                  camel,
                ).ifNullThen(refer('this').property(camel));
              }
              bb.addExpression(refer(className).call([], args).returned);
            }),
        ),
      );
    });

    final custLibrary = Library((lb) {
      final hasList = usesDeepEquality;
      final imports = <String>{
        if (hasList) 'package:collection/collection.dart',
      };

      effectiveSchema.properties.forEach((propName, propSchema) {
        final dartType = TypeMapper.mapSchemaToDartType(
          propSchema,
          components,
          propName,
          className,
          context,
        );
        final baseType = dartType.replaceAll('List<', '').replaceAll('>', '');
        if (baseType == className) return;

        if (context.classNameToFolder.containsKey(baseType)) {
          final targetFolder = context.classNameToFolder[baseType]!;
          final fileName = NamingUtils.toSnakeCase(baseType);
          final path =
              'package:${context.packageName}/models/$targetFolder/$fileName.dart';
          imports.add(path);
        } else if (context.usedEnums.containsKey(baseType)) {
          final fileName = NamingUtils.toSnakeCase(baseType);
          imports.add(
            'package:${context.packageName}/models/enums/$fileName.dart',
          );
        }
      });

      for (final exp in effectiveExpansions) {
        final expClassName = '${NamingUtils.toPascalCase(exp)}Model';
        if (context.classNameToFolder.containsKey(expClassName)) {
          final targetFolder = context.classNameToFolder[expClassName]!;
          final fileName = NamingUtils.toSnakeCase(expClassName);
          final path =
              'package:${context.packageName}/models/$targetFolder/$fileName.dart';
          imports.add(path);
        }
      }

      final directiveList =
          [
            Directive.import('package:meta/meta.dart'),
            Directive.part(
              '${NamingUtils.toSnakeCase(className)}.niskala.dart',
            ),
            for (final path in imports) Directive.import(path),
          ]..sort((a, b) {
            if (a.type != b.type) {
              return a.type == DirectiveType.import ? -1 : 1;
            }
            return a.url.compareTo(b.url);
          });

      lb
        ..directives.addAll(directiveList)
        ..body.add(custClassBuilder);
    });

    final custEmitter = DartEmitter();
    var custContent = custLibrary.accept(custEmitter).toString();

    custContent = _formatCustomClassContent(
      className,
      custContent,
      effectiveSchema,
      effectiveExpansions,
    );

    return {
      '${NamingUtils.toSnakeCase(className)}.niskala.dart': _formatter.format(
        baseContent,
      ),
      '${NamingUtils.toSnakeCase(className)}.dart': _formatter.format(
        custContent,
      ),
    };
  }

  String _formatCustomClassContent(
    String className,
    String content,
    SchemaModel schema,
    List<String> expansions,
  ) {
    var result = content;

    // 1. Transform super. parameters to proper formatting
    // (code_builder might output super.field: null which we want to avoid)

    // 2. Wrap in markers
    final lastBraceIndex = result.lastIndexOf('}');
    if (lastBraceIndex != -1) {
      result =
          '${result.substring(0, lastBraceIndex)}\n  // Custom logic here\n${result.substring(lastBraceIndex)}';
    }
    return result;
  }
}
