import 'package:niskala_model_gen/src/models/openapi/parameter_model.dart';
import 'package:niskala_model_gen/src/models/openapi/request_body_model.dart';
import 'package:niskala_model_gen/src/models/openapi/response_model.dart';
import 'package:niskala_model_gen/src/models/openapi/schema_model.dart';

/// Holds a set of reusable objects for different aspects of the OAS.
class ComponentsModel {
  /// Creates a [ComponentsModel] instance.
  ComponentsModel({
    this.schemas = const {},
    this.responses = const {},
    this.parameters = const {},
    this.requestBodies = const {},
  });

  /// Creates a [ComponentsModel] instance from a JSON map.
  factory ComponentsModel.fromJson(Map<String, dynamic> json) {
    final schemasMap = <String, SchemaModel>{};
    if (json['schemas'] != null) {
      (json['schemas'] as Map<String, dynamic>).forEach((key, value) {
        schemasMap[key] = SchemaModel.fromJson(value as Map<String, dynamic>);
      });
    }

    final parametersMap = <String, ParameterModel>{};
    if (json['parameters'] != null) {
      (json['parameters'] as Map<String, dynamic>).forEach((key, value) {
        parametersMap[key] = ParameterModel.fromJson(
          value as Map<String, dynamic>,
        );
      });
    }

    final responsesMap = <String, ResponseModel>{};
    if (json['responses'] != null) {
      (json['responses'] as Map<String, dynamic>).forEach((key, value) {
        responsesMap[key] = ResponseModel.fromJson(
          value as Map<String, dynamic>,
        );
      });
    }

    final requestBodiesMap = <String, RequestBodyModel>{};
    if (json['requestBodies'] != null) {
      (json['requestBodies'] as Map<String, dynamic>).forEach((key, value) {
        requestBodiesMap[key] = RequestBodyModel.fromJson(
          value as Map<String, dynamic>,
        );
      });
    }

    return ComponentsModel(
      schemas: schemasMap,
      responses: responsesMap,
      parameters: parametersMap,
      requestBodies: requestBodiesMap,
    );
  }

  /// An object to hold reusable Schema Objects.
  final Map<String, SchemaModel> schemas;

  /// An object to hold reusable Response Objects.
  final Map<String, ResponseModel> responses;

  /// An object to hold reusable Parameter Objects.
  final Map<String, ParameterModel> parameters;

  /// An object to hold reusable Request Body Objects.
  final Map<String, RequestBodyModel> requestBodies;
}
