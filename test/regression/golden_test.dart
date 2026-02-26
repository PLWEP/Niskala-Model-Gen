import 'package:niskala_model_gen/src/models/builders/endpoint_model.dart';
import 'package:niskala_model_gen/src/models/builders/niskala_model.dart';
import 'package:niskala_model_gen/src/models/openapi/openapi_model.dart';
import 'package:niskala_model_gen/src/util/openapi_generator.dart';
import 'package:test/test.dart';

void main() {
  group('Golden Regression Tests', () {
    test('Simple Entity Golden', () {
      final openApi = OpenApiModel.fromJson({
        'openapi': '3.0.0',
        'info': {'title': 'GoldenProj', 'version': '1.0'},
        'paths': {
          '/SimpleEntities': {
            'get': {
              'operationId': 'GetSimple',
              'responses': {
                '200': {
                  'content': {
                    'application/json': {
                      'schema': {
                        'type': 'object',
                        'properties': {
                          'Id': {'type': 'string'},
                          'IsActive': {'type': 'boolean'},
                        },
                        'required': ['Id'],
                      },
                    },
                  },
                },
              },
            },
          },
        },
      });

      final config = NiskalaModel(
        endpoints: [
          EndpointModel(projection: 'GoldenProj', name: 'SimpleEntities'),
        ],
        openApiModels: [openApi],
      );

      final generator = OpenApiGenerator(config);
      final files = generator.generate();

      final genFile = files.firstWhere(
        (f) => f.fileName.contains('simple_model.niskala.dart'),
      );

      const expectedContent = r"""
// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'simple_model.dart';

@immutable
abstract class _$SimpleModel {
  const _$SimpleModel({
    required this.id,
    this.isActive,
  });

  final String id;

  final bool? isActive;

  Map<String, dynamic> toJson() {
    return {
      'Id': id,
      'IsActive': isActive,
    };
  }

  Map<String, dynamic> toPartialJson() =>
      toJson()..removeWhere((key, value) => value == null);

  Map<String, String> validate() {
    final errors = <String, String>{};
    return errors;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! SimpleModel) {
      return false;
    }
    return other.runtimeType == runtimeType &&
        other.id == id &&
        other.isActive == isActive;
  }

  @override
  int get hashCode {
    return id.hashCode ^ isActive.hashCode;
  }

  @override
  String toString() {
    return '''
SimpleModel(
id: $id,
isActive: $isActive
)''';
  }
}

SimpleModel _$SimpleModelFromJson(Map<String, dynamic> json) {
  return SimpleModel(
    id: json['Id'] as String,
    isActive: json['IsActive'] as bool?,
  );
}
""";

      String normalize(String s) => s.replaceAll('\r\n', '\n').trim();

      expect(normalize(genFile.content), equals(normalize(expectedContent)));
    });

    test('Enum Golden', () {
      final openApi = OpenApiModel.fromJson({
        'openapi': '3.0.0',
        'info': {'title': 'GoldenProj', 'version': '1.0'},
        'paths': {
          '/SimpleEntities': {
            'get': {
              'operationId': 'GetWithEnum',
              'responses': {
                '200': {
                  'content': {
                    'application/json': {
                      'schema': {
                        'type': 'object',
                        'properties': {
                          'Status': {
                            'type': 'string',
                            'enum': ['Active', 'Pending'],
                          },
                        },
                      },
                    },
                  },
                },
              },
            },
          },
        },
      });

      final config = NiskalaModel(
        endpoints: [
          EndpointModel(projection: 'GoldenProj', name: 'SimpleEntities'),
        ],
        openApiModels: [openApi],
      );

      final generator = OpenApiGenerator(config);
      final files = generator.generate();

      final enumFile = files.firstWhere(
        (f) => f.fileName.contains('enums/with_enum_model_status.dart'),
      );

      const expectedEnumContent = '''
enum WithEnumModelStatus {
  active('Active'),
  pending('Pending');

  const WithEnumModelStatus(this.value);

  factory WithEnumModelStatus.fromJson(dynamic json) {
    return values.firstWhere(
      (e) => e.value == json.toString(),
      orElse: () => values.first,
    );
  }

  final String value;

  String toJson() => value;
}
''';

      String normalize(String s) => s.replaceAll('\r\n', '\n').trim();
      expect(
        normalize(enumFile.content),
        equals(normalize(expectedEnumContent)),
      );
    });
  });
}
