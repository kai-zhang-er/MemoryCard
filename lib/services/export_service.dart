import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/memory_record.dart';
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
    final exportDirectory = await _ensureExportDirectory(directory);
    return _writeJsonFile(exportDirectory, records, exportedAt: exportedAt);
  }

  Future<ExportResult> exportMemories({DateTime? exportedAt}) async {
    final records = await repository.getAll();
    final directory = await _directoryProvider();
    final exportDirectory = await _ensureExportDirectory(directory);
    final jsonFile = await _writeJsonFile(
      exportDirectory,
      records,
      exportedAt: exportedAt,
    );
    final markdownDirectory =
        Directory(p.join(exportDirectory.path, 'markdown'));
    await markdownDirectory.create(recursive: true);

    for (final staleFile in markdownDirectory.listSync().whereType<File>()) {
      if (p.extension(staleFile.path).toLowerCase() == '.md') {
        await staleFile.delete();
      }
    }

    for (final record in records) {
      final file = File(
        p.join(markdownDirectory.path, _markdownFileName(record)),
      );
      await file.writeAsString(_markdownForRecord(record), flush: true);
    }

    return ExportResult(
      exportDirectory: exportDirectory,
      jsonFile: jsonFile,
      markdownDirectory: markdownDirectory,
      markdownCount: records.length,
    );
  }

  Future<Directory> _ensureExportDirectory(Directory documentsDirectory) async {
    final exportDirectory =
        Directory(p.join(documentsDirectory.path, 'exports'));
    await exportDirectory.create(recursive: true);
    return exportDirectory;
  }

  Future<File> _writeJsonFile(
    Directory exportDirectory,
    List<MemoryRecord> records, {
    DateTime? exportedAt,
  }) async {
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

  String _markdownFileName(MemoryRecord record) {
    final date = record.photoTime == null
        ? 'unknown-date'
        : _dateSlug(record.photoTime!.toLocal());
    return '${date}_${_safeFilePart(record.memoryId)}.md';
  }

  String _markdownForRecord(MemoryRecord record) {
    final tags = record.userTags.isEmpty ? '无' : record.userTags.join('、');
    final statuses = _statusLabels(record);
    final audioPath = record.audioPath?.trim();
    final audioText = audioPath == null || audioPath.isEmpty ? '无' : audioPath;
    final memoryText =
        record.memoryText.trim().isEmpty ? '无。' : record.memoryText.trim();
    final transcript =
        record.transcript.trim().isEmpty ? '待转写。' : record.transcript.trim();

    return [
      '# 照片记忆',
      '',
      '- 拍摄时间：${record.photoTime?.toLocal().toIso8601String() ?? '未知'}',
      '- 标签：$tags',
      '- 状态：${statuses.isEmpty ? '普通' : statuses.join('、')}',
      '- 录音路径：$audioText',
      '- 提示问题：${record.promptQuestion}',
      '',
      '> 录音路径是相对于 App Documents 目录的本地路径；如需长期备份，请同时备份 audio/ 文件夹。',
      '',
      '## 文字备注',
      '',
      memoryText,
      '',
      '## 转写',
      '',
      transcript,
      '',
    ].join('\n');
  }

  List<String> _statusLabels(MemoryRecord record) {
    return [
      if (record.important) '重要',
      if (record.deleteCandidate) '待删除',
      if (record.skipped) '已跳过',
    ];
  }

  String _dateSlug(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  String _safeFilePart(String value) {
    final safe = value.trim().replaceAll(RegExp(r'[^a-zA-Z0-9_-]+'), '_');
    return safe.isEmpty ? 'memory' : safe;
  }

  static Future<Directory> _defaultDirectoryProvider() {
    return getApplicationDocumentsDirectory();
  }
}

class ExportResult {
  const ExportResult({
    required this.exportDirectory,
    required this.jsonFile,
    required this.markdownDirectory,
    required this.markdownCount,
  });

  final Directory exportDirectory;
  final File jsonFile;
  final Directory markdownDirectory;
  final int markdownCount;
}

typedef DirectoryProvider = Future<Directory> Function();
