import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'memory_repository.dart';

class ExportService {
  ExportService(this.repository, {DirectoryProvider? directoryProvider})
      : _directoryProvider = directoryProvider ?? _defaultDirectoryProvider;

  static const String appName = 'Memory Cards';
  static const String version = '0.1.0';

  final MemoryRepository repository;
  final DirectoryProvider _directoryProvider;

  Future<File> exportMemoriesJson({DateTime? exportedAt}) async {
    final records = await repository.getAll();
    final directory = await _directoryProvider();
    final exportDirectory = Directory(p.join(directory.path, 'exports'));
    await exportDirectory.create(recursive: true);

    final file = File(p.join(exportDirectory.path, 'memories.json'));
    final payload = {
      'app': appName,
      'exported_at': (exportedAt ?? DateTime.now()).toIso8601String(),
      'version': version,
      'records': records.map((record) => record.toJson()).toList(),
    };

    const encoder = JsonEncoder.withIndent('  ');
    return file.writeAsString(encoder.convert(payload), flush: true);
  }

  static Future<Directory> _defaultDirectoryProvider() {
    return getApplicationDocumentsDirectory();
  }
}

typedef DirectoryProvider = Future<Directory> Function();
