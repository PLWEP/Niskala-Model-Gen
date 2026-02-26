import 'package:niskala_model_gen/src/models/builders/endpoint_model.dart';
import 'package:niskala_model_gen/src/models/builders/niskala_model.dart';
import 'package:niskala_model_gen/src/models/openapi/openapi_model.dart';
import 'package:niskala_model_gen/src/util/openapi_generator.dart';
import 'package:test/test.dart';

void main() {
  group('Generator Integration Tests', () {
    test('full flow with expansions and request bodies', () {
      final openApi = OpenApiModel.fromJson({
        'openapi': '3.0.0',
        'info': {'title': 'ComplexProj', 'version': '1.0'},
        'paths': {
          '/Orders': {
            'get': {
              'operationId': 'GetOrders',
              'parameters': [
                {
                  'name': r'$expand',
                  'in': 'query',
                  'schema': {
                    'type': 'array',
                    'items': {
                      'type': 'string',
                      'enum': ['Customer', 'Items'],
                    },
                  },
                },
              ],
              'responses': {
                '200': {
                  'content': {
                    'application/json': {
                      'schema': {
                        'type': 'object',
                        'properties': {
                          'value': {
                            'type': 'array',
                            'items': {
                              'type': 'object',
                              'properties': {
                                'OrderId': {'type': 'string'},
                                'Amount': {'type': 'number'},
                                'Customer': {
                                  'type': 'object',
                                  'properties': {
                                    'Id': {'type': 'string'},
                                  },
                                },
                                'Items': {
                                  'type': 'array',
                                  'items': {
                                    'type': 'object',
                                    'properties': {
                                      'ItemId': {'type': 'string'},
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
                },
              },
            },
            'post': {
              'operationId': 'CreateOrder',
              'requestBody': {
                'content': {
                  'application/json': {
                    'schema': {
                      'type': 'object',
                      'required': ['CustomerName'],
                      'properties': {
                        'CustomerName': {'type': 'string'},
                        'Note': {'type': 'string'},
                      },
                    },
                  },
                },
              },
              'responses': {
                '201': {'description': 'Created'},
              },
            },
          },
          '/Customers': {
            'get': {
              'operationId': 'GetCustomers',
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

      final config = NiskalaModel(
        endpoints: [
          EndpointModel(projection: 'ComplexProj', name: 'Orders'),
          EndpointModel(
            projection: 'ComplexProj',
            name: 'Orders',
            method: 'POST',
          ),
          EndpointModel(projection: 'ComplexProj', name: 'Customers'),
        ],
        openApiModels: [openApi],
        genConfig: GenSectionConfig(resourcePath: 'resources', output: 'lib'),
      );

      final generator = OpenApiGenerator(config);
      final files = generator.generate();

      // 1. Verify expansions were discovered and files generated
      expect(
        files.any(
          (f) => f.fileName.contains('expansions/customer_model.niskala.dart'),
        ),
        isTrue,
      );

      // 2. Verify request body (Insert model) was generated in requests/
      final insertFile = files.firstWhere(
        (f) => f.fileName.contains('requests/create_order_model.niskala.dart'),
      );
      expect(
        insertFile.content,
        contains(r'abstract class _$CreateOrderModel'),
      );

      // 3. Verify entity models
      expect(
        files.any(
          (f) => f.fileName.contains('responses/orders_model.niskala.dart'),
        ),
        isTrue,
      );
    });

    test('handles path matching with OData parentheses', () {
      final openApi = OpenApiModel.fromJson({
        'openapi': '3.0.0',
        'info': {'title': 'ODataProj', 'version': '1.0'},
        'paths': {
          '/Entities(Id={Id})': {
            'get': {
              'operationId': 'GetSingleEntity',
              'responses': {
                '200': {
                  'content': {
                    'application/json': {
                      'schema': {
                        'type': 'object',
                        'properties': {
                          'A': {'type': 'string'},
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
        endpoints: [EndpointModel(projection: 'ODataProj', name: 'Entities')],
        openApiModels: [openApi],
      );

      final generator = OpenApiGenerator(config);
      final files = generator.generate();

      expect(
        files.any(
          (f) => f.fileName.contains('responses/single_entity_model.dart'),
        ),
        isTrue,
      );
    });

    test('edge cases for coverage: 201, refs, and fallbacks', () {
      final openApi = OpenApiModel.fromJson({
        'openapi': '3.0.0',
        'info': {'title': 'EdgeCase API', 'version': '1.0'},
        'paths': {
          '/CreatedEntities': {
            'post': {
              'operationId': 'CreateEntity',
              'responses': {
                '201': {
                  'description': 'Created',
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
          '/RefEntities': {
            'get': {
              'operationId': 'GetRefEntity',
              'responses': {
                '200': {r'$ref': '#/components/responses/SuccessResponse'},
              },
            },
          },
        },
        'components': {
          'responses': {
            'SuccessResponse': {
              'description': 'Success',
              'content': {
                'application/json': {
                  'schema': {
                    'type': 'object',
                    'properties': {
                      'Status': {'type': 'string'},
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
          EndpointModel(
            projection: 'NonExistent',
            name: 'CreatedEntities',
            method: 'POST',
          ), // Fallback test
          EndpointModel(projection: 'EdgeCase', name: 'RefEntities'),
        ],
        openApiModels: [openApi],
      );

      final generator = OpenApiGenerator(config);
      final files = generator.generate();

      expect(
        files.any(
          (f) => f.fileName.contains('responses/create_entity_model.dart'),
        ),
        isTrue,
      );
      expect(
        files.any(
          (f) => f.fileName.contains('responses/ref_entity_model.dart'),
        ),
        isTrue,
      );
    });
  });
}
