import 'dart:io';

void main() {
  final file = File('coverage/lcov.info');
  if (!file.existsSync()) {
    print('No coverage file found');
    return;
  }

  final lines = file.readAsLinesSync();
  int totalLines = 0;
  int coveredLines = 0;

  for (final line in lines) {
    if (line.startsWith('DA:')) {
      totalLines++;
      final parts = line.split(',');
      if (parts.length > 1) {
        final hits = int.tryParse(parts[1]) ?? 0;
        if (hits > 0) {
          coveredLines++;
        }
      }
    }
  }

  if (totalLines == 0) {
    print('No executable lines found');
  } else {
    final percent = (coveredLines / totalLines) * 100;
    print(
      'Coverage: \${percent.toStringAsFixed(2)}% ($coveredLines / $totalLines lines)',
    );
  }
}
