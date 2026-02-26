import 'package:niskala_model_gen/src/util/code_merger.dart';
import 'package:test/test.dart';

void main() {
  group('CodeMerger Tests', () {
    test('merges new content into existing content with marker', () {
      const existing = r'''
import 'package:other/other.dart';

part 'test.niskala.dart';
class TestModel extends _$TestModel {
  TestModel({super.id});
  factory TestModel.fromJson(Map<String, dynamic> json) => _$TestModelFromJson(json);
  Map<String, dynamic> toJson() => super.toJson();
  // Custom logic here

  void myCustomMethod() {
    print('hello');
  }
}
''';

      const updated = r'''
import 'package:other/other.dart';
import 'package:new/new.dart';

part 'test.niskala.dart';
class TestModel extends _$TestModel {
  TestModel({super.id, super.name});
  factory TestModel.fromJson(Map<String, dynamic> json) => _$TestModelFromJson(json);
  Map<String, dynamic> toJson() => super.toJson();
  // Custom logic here
  
  void otherMethod() {}
}
''';

      final merged = CodeMerger.merge(existing, updated);

      expect(merged, contains('super.id'));
      expect(merged, contains('super.name'));
      expect(merged, contains('void myCustomMethod()'));
      expect(merged, isNot(contains('void otherMethod()')));
      expect(merged, contains("import 'package:other/other.dart';"));
      expect(merged, contains("import 'package:new/new.dart';"));
    });

    test('cleans up stale model imports not used in custom logic', () {
      const existing = r'''
import 'package:other/other.dart';
import 'entities/user_model.dart';
import 'entities/unused_model.dart';

part 'test.niskala.dart';
class TestModel extends _$TestModel {
  TestModel({super.id});
  // Custom logic here

  void useUser(UserModel user) {}
}
''';

      // 'entities/user_model.dart' is used (UserModel)
      // 'entities/unused_model.dart' is NOT used

      const updated = r'''
import 'package:other/other.dart';

part 'test.niskala.dart';
class TestModel extends _$TestModel {
  TestModel({super.id});
  // Custom logic here
}
''';

      final merged = CodeMerger.merge(existing, updated);

      expect(merged, contains("import 'entities/user_model.dart';"));
      expect(merged, isNot(contains("import 'entities/unused_model.dart';")));
    });

    test('sorts imports correctly (dart -> package -> other)', () {
      const existing = r'''
import 'package:b/b.dart';
import 'dart:async';
import 'a/a.dart';
import 'package:a/a.dart';
import 'dart:io';

part 'test.niskala.dart';
class TestModel extends _$TestModel {
  // Custom logic here
}
''';

      const updated = r'''
import 'package:c/c.dart';

part 'test.niskala.dart';
class TestModel extends _$TestModel {
  // Custom logic here
}
''';

      final merged = CodeMerger.merge(existing, updated);
      final lines = merged.split('\n');

      final imports = lines.where((l) => l.startsWith('import ')).toList();

      expect(imports[0], contains('dart:async'));
      expect(imports[1], contains('dart:io'));
      expect(imports[2], contains('package:a/a.dart'));
      expect(imports[3], contains('package:b/b.dart'));
      expect(imports[4], contains('package:c/c.dart'));
      expect(imports[5], contains('a/a.dart'));
    });

    test('returns new content if markers are missing', () {
      const existing = 'class Old {}';
      const updated = '// NISKALA-BEGIN\nclass New {}\n// NISKALA-END';

      final merged = CodeMerger.merge(existing, updated);
      expect(merged, equals(updated));
    });
  });
}
