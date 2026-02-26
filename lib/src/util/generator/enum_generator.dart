import 'package:code_builder/code_builder.dart';
import 'package:dart_style/dart_style.dart';
import 'package:niskala_model_gen/src/models/openapi/schema_model.dart';
import 'package:niskala_model_gen/src/util/generator/naming_utils.dart';
import 'package:pub_semver/pub_semver.dart';

/// Generates the source code for enhanced Dart enums.
class EnumGenerator {
  EnumGenerator({DartFormatter? formatter})
    : _formatter =
          formatter ?? DartFormatter(languageVersion: Version(3, 0, 0));

  final DartFormatter _formatter;

  /// Generates the source code for an enhanced Dart enum from an OpenAPI [SchemaModel].
  String generate(String name, SchemaModel schema) {
    var valueType = 'String';
    if (schema.type == 'integer' || schema.type == 'number') {
      valueType = 'int';
    }

    final enumBuilder = Enum((b) {
      b
        ..name = name
        ..fields.add(
          Field(
            (fb) => fb
              ..name = 'value'
              ..modifier = FieldModifier.final$
              ..type = refer(valueType),
          ),
        );

      // Constructor
      b.constructors.add(
        Constructor(
          (cb) => cb
            ..constant = true
            ..requiredParameters.add(
              Parameter(
                (pb) => pb
                  ..name = 'value'
                  ..toThis = true,
              ),
            ),
        ),
      );

      // Values
      for (final val in schema.enumValues) {
        final valStr = val.toString();
        final enumMemberName = NamingUtils.toCamelCase(valStr);
        b.values.add(
          EnumValue(
            (evb) => evb
              ..name = NamingUtils.isReservedKeyword(enumMemberName)
                  ? '${enumMemberName}Value'
                  : enumMemberName
              ..arguments.add(
                valueType == 'String'
                    ? literalString(valStr)
                    : literalNum(int.tryParse(valStr) ?? 0),
              ),
          ),
        );
      }

      // fromJson
      b.constructors.add(
        Constructor((cb) {
          cb
            ..name = 'fromJson'
            ..factory = true
            ..requiredParameters.add(
              Parameter(
                (pb) => pb
                  ..name = 'json'
                  ..type = refer('dynamic'),
              ),
            )
            ..body = Block((bb) {
              bb.addExpression(
                refer('values')
                    .property('firstWhere')
                    .call(
                      [
                        Method(
                          (m) => m
                            ..lambda = true
                            ..requiredParameters.add(
                              Parameter((p) => p..name = 'e'),
                            )
                            ..body = refer('e')
                                .property('value')
                                .equalTo(
                                  refer('json').property('toString').call([]),
                                )
                                .code,
                        ).closure,
                      ],
                      {
                        'orElse': Method(
                          (m) => m
                            ..lambda = true
                            ..body = refer('values').property('first').code,
                        ).closure,
                      },
                    )
                    .returned,
              );
            });
        }),
      );

      // toJson
      b.methods.add(
        Method(
          (mb) => mb
            ..name = 'toJson'
            ..returns = refer(valueType)
            ..lambda = true
            ..body = refer('value').code,
        ),
      );
    });

    final library = Library((lb) => lb.body.add(enumBuilder));
    final emitter = DartEmitter();
    final source = library.accept(emitter).toString();
    return _formatter.format(source);
  }
}
