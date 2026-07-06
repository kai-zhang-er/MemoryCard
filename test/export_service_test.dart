import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:memory_cards/models/memory_record.dart';
import 'package:memory_cards/services/export_service.dart';
import 'package:memory_cards/services/memory_repository.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  late Directory tempDir;
  late Directory documentsDir;
  late MemoryRepository repository;

  setUp(() async {
    tempDir =
        await Directory.systemTemp.createTemp('memory_cards_export_test_');
    documentsDir = Directory('${tempDir.path}/documents');
    await documentsDir.create(recursive: true);
    repository = MemoryRepository(
      databaseFactory: databaseFactoryFfi,
      databasePath: '${tempDir.path}/memory_cards_test.db',
    );
  });

  tearDown(() async {
    await repository.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('exports all records to memories json', () async {
    await repository.upsert(_record('memory_001', important: true));
    await repository.upsert(
        _record('memory_002', deleteCandidate: true, photoDeleted: true));
    final service = ExportService(
      repository,
      directoryProvider: () async => documentsDir,
    );

    final file = await service.exportMemoriesJson(
      exportedAt: DateTime.utc(2026, 7, 3, 10),
    );
    final json = jsonDecode(await file.readAsString()) as Map<String, Object?>;
    final records = json['records'] as List<Object?>;

    expect(file.path.endsWith('exports${Platform.pathSeparator}memories.json'),
        isTrue);
    expect(json['app'], 'Memory Cards');
    expect(json['version'], '0.1.0');
    expect(json['exported_at'], '2026-07-03T10:00:00.000Z');
    expect(records, hasLength(2));
    expect(
        records
            .whereType<Map<String, Object?>>()
            .map((record) => record['memory_id']),
        containsAll(['memory_001', 'memory_002']));
    final deletedRecord = records
        .whereType<Map<String, Object?>>()
        .firstWhere((record) => record['memory_id'] == 'memory_002');
    expect(deletedRecord['photo_deleted'], isTrue);
    expect(deletedRecord['photo_deleted_at'], isNotNull);
  });

  test('exports json and human-readable markdown files', () async {
    await repository.upsert(
      _record(
        'memory:001',
        important: true,
        photoDeleted: true,
        audioPath: 'audio/2026/memory.m4a',
        memoryText:
            '\u8fd9\u662f\u672c\u79d1\u6bd5\u4e1a\u65c5\u884c\uff0c\u5728\u53a6\u95e8\u3002',
        promptQuestion: '\u8fd9\u662f\u5728\u54ea\u91cc\uff1f',
      ),
    );
    await repository
        .upsert(_record('memory/without/date', hasPhotoTime: false));
    final service = ExportService(
      repository,
      directoryProvider: () async => documentsDir,
    );

    final result = await service.exportMemories(
      exportedAt: DateTime.utc(2026, 7, 3, 10),
    );
    final files = result.markdownDirectory
        .listSync()
        .whereType<File>()
        .map((file) => p.basename(file.path))
        .toList(growable: false);
    final markdownFile = File(
      p.join(result.markdownDirectory.path, '2025-06-03_memory_001.md'),
    );
    final markdown = await markdownFile.readAsString();

    expect(await result.jsonFile.exists(), isTrue);
    expect(result.markdownCount, 2);
    expect(files, contains('2025-06-03_memory_001.md'));
    expect(files, contains('unknown-date_memory_without_date.md'));
    expect(markdown, contains('# \u7167\u7247\u8bb0\u5fc6'));
    expect(markdown, contains('- \u6807\u7b7e\uff1atest'));
    expect(markdown, contains('\u539f\u59cb\u7167\u7247\u5df2\u5220\u9664'));
    expect(markdown, contains('- \u72b6\u6001\uff1a\u91cd\u8981'));
    expect(markdown,
        contains('- \u5f55\u97f3\u8def\u5f84\uff1aaudio/2026/memory.m4a'));
    expect(
        markdown,
        contains(
            '\u63d0\u793a\u95ee\u9898\uff1a\u8fd9\u662f\u5728\u54ea\u91cc\uff1f'));
    expect(markdown, contains('\u6587\u5b57\u5907\u6ce8'));
    expect(
        markdown,
        contains(
            '\u8fd9\u662f\u672c\u79d1\u6bd5\u4e1a\u65c5\u884c\uff0c\u5728\u53a6\u95e8\u3002'));
    expect(markdown, contains('\u5f85\u8f6c\u5199\u3002'));
    expect(markdown, contains('audio/'));
  });
}

MemoryRecord _record(
  String id, {
  bool important = false,
  bool deleteCandidate = false,
  bool hasPhotoTime = true,
  bool photoDeleted = false,
  String? audioPath,
  String memoryText = '',
  String transcript = '',
  String promptQuestion =
      '\u8fd9\u5f20\u7167\u7247\u4f60\u8fd8\u8bb0\u5f97\u5417\uff1f',
}) {
  final now = DateTime.utc(2026, 7, 3, 9);
  return MemoryRecord(
    memoryId: id,
    assetId: 'asset_$id',
    photoTime: hasPhotoTime ? DateTime.utc(2025, 6, 3) : null,
    createdAt: now,
    updatedAt: now,
    important: important,
    deleteCandidate: deleteCandidate,
    photoDeleted: photoDeleted,
    photoDeletedAt: photoDeleted ? DateTime.utc(2026, 7, 4) : null,
    userTags: const ['test'],
    aiLightTags: const ['old_photo'],
    audioPath: audioPath,
    memoryText: memoryText,
    transcript: transcript,
    promptQuestion: promptQuestion,
  );
}
