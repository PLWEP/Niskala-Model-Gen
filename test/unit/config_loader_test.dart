import 'dart:io';
import 'package:niskala_model_gen/src/core/exceptions.dart';
import 'package:niskala_model_gen/src/util/config_loader.dart';
import 'package:test/test.dart';

class MockFile implements File {
  MockFile(this._path, {String content = '', bool exists = true})
    : _content = content,
      _exists = exists;

  final String _path;
  final String _content;
  final bool _exists;

  @override
  String get path => _path;

  @override
  bool existsSync() => _exists;

  @override
  Future<bool> exists() async => _exists;

  @override
  Future<String> readAsString({dynamic encoding}) async => _content;

  @override
  File get absolute => this;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('ConfigLoader Tests', () {
    test('throws ConfigException when file does not exist', () async {
      await IOOverrides.runZoned(() async {
        expect(
          () => ConfigLoader.loadConfig(cliConfigPath: 'missing.yaml'),
          throwsA(isA<ConfigException>()),
        );
      }, createFile: (path) => MockFile(path, exists: false));
    });

    test('loads valid config successfully', () async {
      const yamlContent = '''
niskala_model_gen:
  resource_path: ./metadata
apiDefinitions:
  - projection: Proj1
    endpoint: End1
''';
      await IOOverrides.runZoned(() async {
        final config = await ConfigLoader.loadConfig(
          cliConfigPath: 'niskala.yaml',
        );
        expect(config.resourcePath, equals('metadata'));
        expect(config.endpoints.length, equals(1));
        expect(config.endpoints.first.projection, equals('Proj1'));
      }, createFile: (path) => MockFile(path, content: yamlContent));
    });

    test('loads default config when no path provided', () async {
      const defaultYaml = '''
niskala_model_gen:
  resource_path: .
apiDefinitions: []
''';
      await IOOverrides.runZoned(
        () async {
          final config = await ConfigLoader.loadConfig();
          expect(config.resourcePath, equals('.'));
        },
        createFile: (path) {
          if (path == 'niskala.yaml') {
            return MockFile(path, content: defaultYaml);
          }
          return MockFile(path, exists: false);
        },
      );
    });
  });
}
