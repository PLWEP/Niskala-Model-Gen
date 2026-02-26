import 'package:niskala_model_gen/src/models/builders/endpoint_model.dart';
import 'package:niskala_model_gen/src/models/builders/niskala_model.dart';
import 'package:niskala_model_gen/src/models/openapi/openapi_model.dart';
import 'package:niskala_model_gen/src/util/code_merger.dart';
import 'package:niskala_model_gen/src/util/openapi_generator.dart';
import 'package:test/test.dart';

void main() {
  group('Smart Merge Integration Tests', () {
    test('preserves custom code when schema updates', () {
      // 1. Initial Generation
      final openApiV1 = OpenApiModel.fromJson({
        'openapi': '3.0.0',
        'info': {'title': 'Test', 'version': '1.0'},
        'paths': {
          '/Entities': {
            'get': {
              'operationId': 'GetEntity',
              'responses': {
                '200': {
                  'content': {
                    'application/json': {
                      'schema': {
                        'type': 'object',
                        'properties': {
                          'Id': {'type': 'string'},
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

      final configV1 = NiskalaModel(
        endpoints: [EndpointModel(projection: 'Test', name: 'Entities')],
        openApiModels: [openApiV1],
      );

      final genV1 = OpenApiGenerator(configV1);
      final filesV1 = genV1.generate();

      final custFileV1 = filesV1.firstWhere(
        (f) => f.fileName == 'models/responses/entity_model.dart',
      );

      // 2. Add custom logic to custFileV1
      const customCode = r'''
  @override
  String toString() => 'CustomEntity(id: $id)';
}
''';
      // Inject custom code before the last closing brace
      final existingContent = custFileV1.content;
      final lastBrace = existingContent.lastIndexOf('}');
      final modifiedContent =
          existingContent.substring(0, lastBrace) + customCode;

      // 3. Schema Update: Add 'Name' property
      final openApiV2 = OpenApiModel.fromJson({
        'openapi': '3.0.0',
        'info': {'title': 'Test', 'version': '2.0'},
        'paths': {
          '/Entities': {
            'get': {
              'operationId': 'GetEntity',
              'responses': {
                '200': {
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

      final configV2 = NiskalaModel(
        endpoints: [EndpointModel(projection: 'Test', name: 'Entities')],
        openApiModels: [openApiV2],
      );

      final genV2 = OpenApiGenerator(configV2);
      final filesV2 = genV2.generate();
      final newGeneratedContent = filesV2
          .firstWhere((f) => f.fileName == 'models/responses/entity_model.dart')
          .content;

      // 4. Perform the Merge (simulated CLI action)
      final mergedContent = CodeMerger.merge(
        modifiedContent,
        newGeneratedContent,
      );

      // 5. Assertions
      expect(mergedContent, contains('super.id')); // Constructor updated
      expect(mergedContent, contains('super.name')); // Constructor updated
      expect(
        mergedContent,
        contains(r'CustomEntity(id: $id)'),
      ); // Custom code preserved
      expect(mergedContent, contains('// Custom logic here'));

      // Ensure only one part directive exists
      final partMatches = RegExp(
        "part 'entity_model.niskala.dart';",
      ).allMatches(mergedContent);
      expect(partMatches.length, equals(1));
    });
  });
}
