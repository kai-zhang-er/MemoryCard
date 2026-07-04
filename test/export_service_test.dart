import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:memory_cards/models/memory_record.dart';
import 'package:memory_cards/services/export_service.dart';
import 'package:memory_cards/services/memory_repository.dart';
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
    await repository.upsert(_record('memory_002', deleteCandidate: true));
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
  });
}

MemoryRecord _record(
  String id, {
  bool important = false,
  bool deleteCandidate = false,
}) {
  final now = DateTime.utc(2026, 7, 3, 9);
  return MemoryRecord(
    memoryId: id,
    assetId: 'asset_$id',
    photoTime: now.subtract(const Duration(days: 400)),
    createdAt: now,
    updatedAt: now,
    important: important,
    deleteCandidate: deleteCandidate,
    userTags: const ['test'],
    aiLightTags: const ['old_photo'],
  );
}
