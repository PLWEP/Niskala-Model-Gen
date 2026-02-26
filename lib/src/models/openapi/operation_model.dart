import 'package:niskala_model_gen/src/models/openapi/parameter_model.dart';
import 'package:niskala_model_gen/src/models/openapi/request_body_model.dart';
import 'package:niskala_model_gen/src/models/openapi/response_model.dart';

/// Describes a single API operation on a path.
class OperationModel {
  /// Creates an [OperationModel] instance.
  OperationModel({
    this.tags = const [],
    this.summary = '',
    this.description = '',
    this.operationId = '',
    this.parameters = const [],
    this.requestBody,
    this.responses = const {},
  });

  /// Creates an [OperationModel] instance from a JSON map.
  factory OperationModel.fromJson(Map<String, dynamic> json) {
    return OperationModel(
      tags:
          (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList() ??
          [],
      summary: json['summary'] as String? ?? '',
      description: json['description'] as String? ?? '',
      operationId: json['operationId'] as String? ?? '',
      parameters:
          (json['parameters'] as List<dynamic>?)
              ?.map((e) => ParameterModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      requestBody: json['requestBody'] != null
          ? RequestBodyModel.fromJson(
              json['requestBody'] as Map<String, dynamic>,
            )
          : null,
      responses:
          (json['responses'] as Map<String, dynamic>?)?.map(
            (key, value) => MapEntry(
              key,
              ResponseModel.fromJson(value as Map<String, dynamic>),
            ),
          ) ??
          {},
    );
  }

  /// A list of tags for API documentation control.
  final List<String> tags;

  /// A short summary of what the operation does.
  final String summary;

  /// A verbose explanation of the operation behavior.
  final String description;

  /// Unique string used to identify the operation.
  final String operationId;

  /// A list of parameters that are applicable for this operation.
  final List<ParameterModel> parameters;

  /// The request body applicable for this operation.
  final RequestBodyModel? requestBody;

  /// The list of possible responses as they are returned from executing this operation.
  final Map<String, ResponseModel> responses;
}
