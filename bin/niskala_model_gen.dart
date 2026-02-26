import 'dart:async';
import 'dart:io';

import 'package:args/args.dart';
import 'package:niskala_model_gen/src/core/exceptions.dart';
import 'package:niskala_model_gen/src/core/logger.dart';
import 'package:niskala_model_gen/src/generator.dart';
import 'package:niskala_model_gen/src/models/builders/generated_file_model.dart';
import 'package:niskala_model_gen/src/util/code_merger.dart';
import 'package:niskala_model_gen/src/util/config_loader.dart';
import 'package:path/path.dart' as p;
import 'package:watcher/watcher.dart';

/// Command-line entry point for the Niskala Model Generator.
void main(List<String> arguments) async {
  final parser = ArgParser()
    ..addCommand('init')
    ..addOption(
      'config',
      abbr: 'c',
      help: 'Path to the YAML configuration file.',
    )
    ..addOption('output', abbr: 'o', help: 'Output directory path.')
    ..addFlag(
      'verbose',
      abbr: 'v',
      help: 'Enable verbose logging output.',
      negatable: false,
    )
    ..addFlag(
      'dry-run',
      help: 'Show what files would be generated without writing them.',
      negatable: false,
    )
    ..addFlag(
      'watch',
      abbr: 'w',
      help: 'Watch for configuration or metadata changes and regenerate.',
      negatable: false,
    )
    ..addFlag(
      'help',
      abbr: 'h',
      help: 'Show this help message.',
      negatable: false,
    );

  setupLogger();

  try {
    final results = parser.parse(arguments);

    if (results['help'] as bool) {
      _showHelp(parser);
      return;
    }

    if (results['verbose'] as bool) {
      setupLogger(verbose: true);
    }

    if (results.command?.name == 'init') {
      await _handleInit();
      return;
    }

    final configPath = results.wasParsed('config')
        ? results['config'] as String
        : ConfigLoader.defaultConfigName;

    final dryRun = results['dry-run'] as bool;
    final watch = results['watch'] as bool;

    if (watch) {
      await _handleWatch(configPath, dryRun);
    } else {
      await _runGeneration(configPath, dryRun);
    }
  } catch (e, stack) {
    if (e is ConfigException) {
      logger.severe(e.message);
    } else {
      logger.severe('Fatal error during generation', e, stack);
    }
    exit(1);
  }
}

void _showHelp(ArgParser parser) {
  stdout
    ..writeln('Niskala Model Generator')
    ..writeln('Usage: niskala_model_gen [command] [options]')
    ..writeln('\nCommands:')
    ..writeln('  init        Scaffold a default niskala.yaml')
    ..writeln('\nOptions:')
    ..writeln(parser.usage);
}

Future<void> _handleInit() async {
  final file = File(ConfigLoader.defaultConfigName);
  if (file.existsSync()) {
    logger.warning('${ConfigLoader.defaultConfigName} already exists.');
    return;
  }

  const template = '''
# Optional: Project name for imports (defaults to name in pubspec.yaml)
project_name: MyProject

niskala_model_gen:
  # Mandatory: Path to directory containing .json metadata files
  resource_path: metadata_files
  # Optional: Default output directory
  output: lib

odataEnvironments:
  - name: Development
    baseUrl: https://ifsdev.your-company.co.id
    username: your_user
    password: your_password

apiDefinitions:
  - projection: PurchaseRequisitionHandling
    endpoint: PurchaseReqLineNopartSet
''';

  await file.writeAsString(template);
  logger.info('Created default ${ConfigLoader.defaultConfigName}');
}

Future<void> _runGeneration(String configPath, bool dryRun) async {
  logger.info('Loading configuration from $configPath...');
  final config = await ConfigLoader.loadConfig(cliConfigPath: configPath);
  final generator = ModelGenerator(config);

  logger.info('Generating models...');
  final files = await generator.generate();

  if (files.isEmpty) {
    logger.warning(
      'No files were generated. Check your configuration and metadata files.',
    );
    return;
  }

  for (final file in files) {
    final baseDir = file.type == FileType.test
        ? (config.configDir ?? '.')
        : config.baseDirectory;
    final filePath = p.join(baseDir, file.fileName);
    final fileObj = File(filePath);

    var contentToWrite = file.content;
    if (file.isCustom && fileObj.existsSync()) {
      final existingContent = await fileObj.readAsString();
      contentToWrite = CodeMerger.merge(existingContent, file.content);
    }

    if (dryRun) {
      logger.info('[DRY-RUN] Would write: $filePath');
      continue;
    }

    final dir = fileObj.parent;
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }

    await fileObj.writeAsString(contentToWrite);
    logger.fine('Generated: ${file.fileName}');
  }

  logger.info(
    'Successfully ${dryRun ? "analyzed" : "generated"} ${files.length} files.',
  );
}

Future<void> _handleWatch(String configPath, bool dryRun) async {
  logger.info('Starting watch mode on $configPath...');
  await _runGeneration(configPath, dryRun);

  final watcher = FileWatcher(configPath);
  logger.info('Watching for changes in $configPath...');

  await for (final event in watcher.events) {
    logger.info('Change detected in ${event.path}. Regenerating...');
    try {
      await _runGeneration(configPath, dryRun);
    } catch (e) {
      logger.severe('Generation failed: $e');
    }
  }
}
