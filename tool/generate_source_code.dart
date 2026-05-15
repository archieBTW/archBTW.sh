import 'dart:convert';
import 'dart:io';

void main() {
  final libDir = Directory('lib');
  if (!libDir.existsSync()) {
    print('lib directory not found. Please run this script from the project root.');
    return;
  }

  final files = libDir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'));

  final sourceCodeMap = <String, String>{};

  for (final file in files) {
    // Skip the generated file itself if it exists
    if (file.path.contains('generated/source_code.dart')) {
      continue;
    }

    // Normalize path to use forward slashes
    final normalizedPath = file.path.replaceAll('\\', '/');
    final content = file.readAsStringSync();
    sourceCodeMap[normalizedPath] = content;
  }

  final generatedDir = Directory('lib/generated');
  if (!generatedDir.existsSync()) {
    generatedDir.createSync(recursive: true);
  }

  final outputFile = File('lib/generated/source_code.dart');

  final buffer = StringBuffer();
  buffer.writeln('// GENERATED CODE - DO NOT MODIFY BY HAND');
  buffer.writeln('// ignore_for_file: constant_identifier_names');
  buffer.writeln('');
  buffer.writeln('const Map<String, String> sourceCodeFiles = {');

  for (final entry in sourceCodeMap.entries) {
    // Use jsonEncode to safely encode string to a valid literal format
    // Replace \$ with \\\$ to escape Dart string interpolation
    final encodedKey = jsonEncode(entry.key);
    final encodedValue = jsonEncode(entry.value).replaceAll(r'$', r'\$');
    buffer.writeln('  $encodedKey: $encodedValue,');
  }

  buffer.writeln('};');

  outputFile.writeAsStringSync(buffer.toString());
  print('Successfully generated source code map with ${sourceCodeMap.length} files.');
}
