import 'dart:convert';
import 'dart:io';
import 'package:niskala_model_gen/src/core/exceptions.dart';
import 'package:niskala_model_gen/src/models/builders/endpoint_model.dart';
import 'package:niskala_model_gen/src/models/builders/niskala_model.dart';
import 'package:niskala_model_gen/src/models/openapi/openapi_model.dart';
import 'package:niskala_model_gen/src/util/openapi_loader.dart';
import 'package:test/test.dart';

class MockFile implements File {
  MockFile(this._path, {String content = ''}) : _content = content;

  final String _path;
  final String _content;

  @override
  String get path => _path;

  @override
  bool existsSync() => true;

  @override
  Future<String> readAsString({dynamic encoding}) async => _content;

  @override
  File get absolute => this;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockDirectory implements Directory {
  MockDirectory(
    this._path, {
    List<FileSystemEntity>? entities,
    bool exists = true,
  }) : _entities = entities ?? [],
       _exists = exists;

  final String _path;
  final List<FileSystemEntity> _entities;
  final bool _exists;

  @override
  String get path => _path;

  @override
  Directory get absolute => this;

  @override
  bool existsSync() => _exists;

  @override
  Stream<FileSystemEntity> list({
    bool recursive = false,
    bool followLinks = true,
  }) {
    return Stream.fromIterable(_entities);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('OpenApiLoader Tests', () {
    test('returns empty if resourcePath is missing', () async {
      final config = NiskalaModel(endpoints: []);
      final models = await OpenApiLoader.loadAll(config);
      expect(models, isEmpty);
    });

    test('returns empty if directory does not exist', () async {
      final config = NiskalaModel(
        endpoints: [],
        genConfig: GenSectionConfig(resourcePath: 'missing'),
      );
      await IOOverrides.runZoned(() async {
        final models = await OpenApiLoader.loadAll(config);
        expect(models, isEmpty);
      }, createDirectory: (path) => MockDirectory(path, exists: false));
    });

    test('loads matching OpenAPI files with strict matching', () async {
      final config = NiskalaModel(
        endpoints: [EndpointModel(projection: 'TestProj', name: 'Set1')],
        genConfig: GenSectionConfig(resourcePath: 'resources'),
      );

      final openApiJson = jsonEncode({
        'openapi': '3.0.0',
        'info': {'title': 'TestProj API', 'version': '1.0'},
        'paths': <String, dynamic>{},
      });

      final entities = [
        MockFile('resources/TestProj.json', content: openApiJson),
        MockFile(
          'resources/TestProj.svc.json',
          content: openApiJson,
        ), // Should also match
        MockFile(
          'resources/OtherTestProj.json',
          content: openApiJson,
        ), // Should NOT match (strict)
        MockFile('resources/Other.json', content: '{}'),
      ];

      await IOOverrides.runZoned(() async {
        final models = await OpenApiLoader.loadAll(config);
        expect(models, isA<List<OpenApiModel>>());
        expect(models.length, equals(2));
        expect(models.first.info.title, equals('TestProj API'));
      }, createDirectory: (path) => MockDirectory(path, entities: entities));
    });

    test('throws MetadataException on JSON decode errors', () async {
      final config = NiskalaModel(
        endpoints: [EndpointModel(projection: 'TestProj', name: 'Set1')],
        genConfig: GenSectionConfig(resourcePath: 'resources'),
      );

      final entities = [
        MockFile('resources/TestProj.json', content: 'invalid-json'),
      ];

      await IOOverrides.runZoned(() async {
        expect(
          () => OpenApiLoader.loadAll(config),
          throwsA(isA<MetadataException>()),
        );
      }, createDirectory: (path) => MockDirectory(path, entities: entities));
    });
  });
}
