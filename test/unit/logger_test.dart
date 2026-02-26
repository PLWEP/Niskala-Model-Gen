import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:logging/logging.dart';
import 'package:niskala_model_gen/src/core/logger.dart';
import 'package:test/test.dart';

class MockStdout implements Stdout {
  final List<String> lines = [];

  @override
  void writeln([Object? obj = '']) {
    lines.add(obj.toString());
  }

  @override
  void write(Object? obj) {
    if (obj != null) lines.add(obj.toString());
  }

  @override
  void writeAll(Iterable<dynamic> objects, [String separator = '']) {
    lines.add(objects.join(separator));
  }

  @override
  void writeCharCode(int charCode) {
    lines.add(String.fromCharCode(charCode));
  }

  @override
  void add(List<int> data) {}

  @override
  void addError(Object error, [StackTrace? stackTrace]) {}

  @override
  Future<void> addStream(Stream<List<int>> stream) => Future.value();

  @override
  Future<void> close() => Future.value();

  @override
  Future<void> get done => Future.value();

  @override
  Future<dynamic> flush() => Future.value();

  @override
  set encoding(Encoding encoding) {}

  @override
  Encoding get encoding => utf8;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    return null;
  }
}

void main() {
  group('Logger Tests', () {
    late MockStdout mockStdout;
    late MockStdout mockStderr;

    setUp(() {
      mockStdout = MockStdout();
      mockStderr = MockStdout();
    });

    test('setupLogger sets correct level for non-verbose', () {
      setupLogger();
      expect(Logger.root.level, equals(Level.INFO));
    });

    test('setupLogger sets correct level for verbose', () {
      setupLogger(verbose: true);
      expect(Logger.root.level, equals(Level.ALL));
    });

    test('INFO log formatting', () async {
      await IOOverrides.runZoned(() async {
        setupLogger();
        logger.info('Test Info Message');
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(mockStdout.lines, contains('• Test Info Message'));
      }, stdout: () => mockStdout);
    });

    test('WARNING log formatting', () async {
      await IOOverrides.runZoned(() async {
        setupLogger();
        logger.warning('Test Warning Message');
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(mockStdout.lines, contains('⚠ [WARNING] Test Warning Message'));
      }, stdout: () => mockStdout);
    });

    test('SEVERE log formatting', () async {
      await IOOverrides.runZoned(() async {
        setupLogger();
        logger.severe('Test Error Message');
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(mockStderr.lines, contains('✖ [SEVERE] Test Error Message'));
      }, stderr: () => mockStderr);
    });

    test('SEVERE log with error and stacktrace', () async {
      await IOOverrides.runZoned(() async {
        setupLogger();
        final stack = StackTrace.current;
        logger.severe('Test Error', 'Detailed Error', stack);
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(mockStderr.lines, contains('✖ [SEVERE] Test Error'));
        expect(mockStderr.lines, contains('  Error: Detailed Error'));
        expect(mockStderr.lines, contains(stack.toString()));
      }, stderr: () => mockStderr);
    });

    test('FINE log output in verbose mode', () async {
      await IOOverrides.runZoned(() async {
        setupLogger(verbose: true);
        logger.fine('Test Fine Message');
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(mockStdout.lines, contains('  [fine] Test Fine Message'));
      }, stdout: () => mockStdout);
    });

    test('FINE log suppressed in non-verbose mode', () async {
      await IOOverrides.runZoned(() async {
        setupLogger();
        logger.fine('Hidden Message');
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(
          mockStdout.lines.any((l) => l.contains('Hidden Message')),
          isFalse,
        );
      }, stdout: () => mockStdout);
    });
  });
}
