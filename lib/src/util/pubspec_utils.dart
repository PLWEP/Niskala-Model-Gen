import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

/// Utility class for interacting with the project's pubspec.yaml file.
class PubspecUtils {
  /// Resolves the project name and Flutter status from the pubspec.yaml file
  /// located in the project root (where niskala.yaml is usually located).
  static Future<PubspecInfo> resolveInfo(String projectRoot) async {
    final pubspecFile = File(p.join(projectRoot, 'pubspec.yaml'));
    if (!pubspecFile.existsSync()) {
      return const PubspecInfo(isFlutter: false);
    }

    try {
      final content = await pubspecFile.readAsString();
      final yaml = loadYaml(content);
      if (yaml is! YamlMap) {
        return const PubspecInfo(isFlutter: false);
      }

      final name = yaml['name']?.toString();
      final dependencies = yaml['dependencies'];
      final devDependencies = yaml['dev_dependencies'];

      var isFlutter = false;
      if (dependencies is YamlMap && dependencies.containsKey('flutter')) {
        isFlutter = true;
      } else if (devDependencies is YamlMap &&
          devDependencies.containsKey('flutter_test')) {
        isFlutter = true;
      }

      return PubspecInfo(name: name, isFlutter: isFlutter);
    } catch (_) {
      return const PubspecInfo(isFlutter: false);
    }
  }
}

/// Holds information extracted from a pubspec.yaml file.
class PubspecInfo {
  /// Creates a [PubspecInfo] instance.
  const PubspecInfo({required this.isFlutter, this.name});

  /// The project name.
  final String? name;

  /// Whether the project is a Flutter project.
  final bool isFlutter;
}
