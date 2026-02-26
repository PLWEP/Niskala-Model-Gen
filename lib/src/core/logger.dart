import 'dart:async';
import 'dart:io';
import 'package:logging/logging.dart';

/// Global logger instance for the Niskala Model Gen package.
final Logger logger = Logger('NiskalaModelGen');

StreamSubscription<LogRecord>? _loggerSubscription;

/// Configures the global logging behavior for the application.
///
/// If [verbose] is true, the logging level is set to [Level.ALL], capturing
/// detailed debug information. Otherwise, it defaults to [Level.INFO].
///
/// Log records are streamed to [stdout] for information and [stderr] for
/// severe errors and stack traces.
void setupLogger({bool verbose = false}) {
  Logger.root.level = verbose ? Level.ALL : Level.INFO;

  // Cancel previous subscription if it exists to avoid multiple listeners
  _loggerSubscription?.cancel();

  _loggerSubscription = Logger.root.onRecord.listen((record) {
    if (record.level >= Level.SEVERE) {
      stderr.writeln('✖ [${record.level.name}] ${record.message}');
      if (record.error != null) stderr.writeln('  Error: ${record.error}');
      if (record.stackTrace != null) stderr.writeln(record.stackTrace);
    } else if (record.level >= Level.WARNING) {
      stdout.writeln('⚠ [${record.level.name}] ${record.message}');
    } else if (record.level >= Level.INFO) {
      // Info logs are "to the point"
      stdout.writeln('• ${record.message}');
    } else if (verbose) {
      // Fine/Finer/Finest logs
      stdout.writeln(
        '  [${record.level.name.toLowerCase()}] ${record.message}',
      );
    }
  });
}
