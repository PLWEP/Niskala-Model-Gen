import 'package:niskala_model_gen/src/models/openapi/operation_model.dart';
import 'package:niskala_model_gen/src/models/openapi/parameter_model.dart';

/// Describes the operations available on a single path.
class PathItemModel {
  /// Creates a [PathItemModel] instance.
  PathItemModel({
    this.get,
    this.put,
    this.post,
    this.delete,
    this.options,
    this.head,
    this.patch,
    this.trace,
    this.parameters = const [],
  });

  /// Creates a [PathItemModel] instance from a JSON map.
  factory PathItemModel.fromJson(Map<String, dynamic> json) {
    return PathItemModel(
      get: json['get'] != null
          ? OperationModel.fromJson(json['get'] as Map<String, dynamic>)
          : null,
      put: json['put'] != null
          ? OperationModel.fromJson(json['put'] as Map<String, dynamic>)
          : null,
      post: json['post'] != null
          ? OperationModel.fromJson(json['post'] as Map<String, dynamic>)
          : null,
      delete: json['delete'] != null
          ? OperationModel.fromJson(json['delete'] as Map<String, dynamic>)
          : null,
      options: json['options'] != null
          ? OperationModel.fromJson(json['options'] as Map<String, dynamic>)
          : null,
      head: json['head'] != null
          ? OperationModel.fromJson(json['head'] as Map<String, dynamic>)
          : null,
      patch: json['patch'] != null
          ? OperationModel.fromJson(json['patch'] as Map<String, dynamic>)
          : null,
      trace: json['trace'] != null
          ? OperationModel.fromJson(json['trace'] as Map<String, dynamic>)
          : null,
      parameters:
          (json['parameters'] as List<dynamic>?)
              ?.map((e) => ParameterModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  /// A definition of a GET operation on this path.
  final OperationModel? get;

  /// A definition of a PUT operation on this path.
  final OperationModel? put;

  /// A definition of a POST operation on this path.
  final OperationModel? post;

  /// A definition of a DELETE operation on this path.
  final OperationModel? delete;

  /// A definition of an OPTIONS operation on this path.
  final OperationModel? options;

  /// A definition of a HEAD operation on this path.
  final OperationModel? head;

  /// A definition of a PATCH operation on this path.
  final OperationModel? patch;

  /// A definition of a TRACE operation on this path.
  final OperationModel? trace;

  /// A list of parameters that are applicable for all the operations described under this path.
  final List<ParameterModel> parameters;
}
