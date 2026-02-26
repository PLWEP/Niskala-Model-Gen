import 'package:niskala_model_gen/src/models/builders/endpoint_model.dart';
import 'package:niskala_model_gen/src/models/builders/niskala_model.dart';
import 'package:niskala_model_gen/src/models/openapi/openapi_model.dart';
import 'package:niskala_model_gen/src/util/openapi_generator.dart';
import 'package:test/test.dart';

void main() {
  group('OpenApiGenerator Tests', () {
    test('generates gen/ and cust/ files for a simple entity', () {
      final openApi = OpenApiModel.fromJson({
        'openapi': '3.0.0',
        'info': {'title': 'TestProj', 'version': '1.0'},
        'paths': {
          '/TestEntitySet': {
            'get': {
              'operationId': 'GetTestEntity',
              'responses': {
                '200': {
                  'description': 'OK',
                  'content': {
                    'application/json': {
                      'schema': {
                        'type': 'object',
                        'properties': {
                          'Id': {'type': 'string'},
                          'Name': {'type': 'string'},
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
          EndpointModel(projection: 'TestProj', name: 'TestEntitySet'),
        ],
        openApiModels: [openApi],
      );

      final generator = OpenApiGenerator(config);
      final files = generator.generate();

      // Check for Base and Cust files
      // Class name will be TestEntityModel
      final genFile = files.firstWhere(
        (f) => f.fileName.contains('test_entity_model.niskala.dart'),
      );
      final custFile = files.firstWhere(
        (f) =>
            f.fileName.contains('test_entity_model.dart') &&
            !f.fileName.contains('.niskala.'),
      );

      expect(genFile.content, contains("part of 'test_entity_model.dart';"));
      expect(genFile.content, contains(r'abstract class _$TestEntityModel'));
      expect(genFile.isCustom, isFalse);

      expect(custFile.content, contains('// Custom logic here'));
      expect(
        custFile.content,
        contains("part 'test_entity_model.niskala.dart';"),
      );
      expect(
        custFile.content,
        contains(r'class TestEntityModel extends _$TestEntityModel'),
      );
      // Check for super. parameters individually to ignore whitespace
      expect(custFile.content, contains('super.id'));
      expect(custFile.content, contains('super.name'));
      expect(custFile.content, contains('super.name'));
      expect(custFile.isCustom, isTrue);
    });

    test('generates enums in correct directory', () {
      final openApi = OpenApiModel.fromJson({
        'openapi': '3.0.0',
        'info': {'title': 'TestProj', 'version': '1.0'},
        'paths': {
          '/TestEntitySet': {
            'get': {
              'operationId': 'ListItems',
              'responses': {
                '200': {
                  'content': {
                    'application/json': {
                      'schema': {
                        'type': 'object',
                        'properties': {
                          'Status': {
                            'type': 'string',
                            'enum': ['Active', 'Inactive'],
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
          EndpointModel(projection: 'TestProj', name: 'TestEntitySet'),
        ],
        openApiModels: [openApi],
      );

      final generator = OpenApiGenerator(config);
      final files = generator.generate();

      // Enum filename should be status_enum.dart or list_items_status_enum.dart
      // depending on context. For nested enums in requests/responses,
      // it might be operation-prefixed.
      final enumFiles = files
          .where((f) => f.fileName.contains('enums/'))
          .toList();

      expect(
        enumFiles,
        isNotEmpty,
        reason:
            'No enum files generated. Found: ${files.map((f) => f.fileName)}',
      );

      final statusEnum = enumFiles.firstWhere(
        (f) => f.fileName.contains('status.dart'),
      );
      expect(statusEnum.content, contains('enum '));
      expect(statusEnum.isCustom, isFalse);
    });
  });
}
