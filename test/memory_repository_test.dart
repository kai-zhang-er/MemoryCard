import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:memory_cards/models/memory_record.dart';
import 'package:memory_cards/services/memory_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  late Directory tempDir;
  late MemoryRepository repository;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('memory_cards_test_');
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

  test('upserts and reads records', () async {
    final record = _record('memory_001', important: true);

    await repository.upsert(record);
    final saved = await repository.getById(record.memoryId);

    expect(saved, isNotNull);
    expect(saved!.assetId, 'asset_memory_001');
    expect(saved.important, isTrue);
  });

  test('filters important and delete candidate records', () async {
    await repository.upsert(_record('memory_001', important: true));
    await repository.upsert(_record('memory_002', deleteCandidate: true));
    await repository.upsert(_record('memory_003', skipped: true));

    final important = await repository.getImportant();
    final deleteCandidates = await repository.getDeleteCandidates();
    final all = await repository.getAll();

    expect(all, hasLength(3));
    expect(important.map((record) => record.memoryId), contains('memory_001'));
    expect(deleteCandidates.map((record) => record.memoryId),
        contains('memory_002'));
  });

  test('finds latest record by asset id', () async {
    final first = _record('memory_001');
    final second = _record('memory_002').copyWith(
      assetId: first.assetId,
      updatedAt: first.updatedAt.add(const Duration(minutes: 5)),
    );

    await repository.upsert(first);
    await repository.upsert(second);

    final saved = await repository.getByAssetId(first.assetId);

    expect(saved, isNotNull);
    expect(saved!.memoryId, second.memoryId);
  });
  test('updates and deletes records', () async {
    final record = _record('memory_001');
    await repository.upsert(record);

    final updated = record.copyWith(
      important: true,
      updatedAt: record.updatedAt.add(const Duration(minutes: 1)),
    );
    final updatedCount = await repository.update(updated);
    final saved = await repository.getById(record.memoryId);
    final deletedCount = await repository.deleteById(record.memoryId);
    final deleted = await repository.getById(record.memoryId);

    expect(updatedCount, 1);
    expect(saved!.important, isTrue);
    expect(deletedCount, 1);
    expect(deleted, isNull);
  });
}

MemoryRecord _record(
  String id, {
  bool important = false,
  bool deleteCandidate = false,
  bool skipped = false,
}) {
  final now = DateTime.utc(2026, 7, 3, 9, id.hashCode % 60);
  return MemoryRecord(
    memoryId: id,
    assetId: 'asset_$id',
    photoTime: now.subtract(const Duration(days: 400)),
    createdAt: now,
    updatedAt: now,
    important: important,
    deleteCandidate: deleteCandidate,
    skipped: skipped,
    userTags: const ['test'],
    aiLightTags: const ['old_photo'],
  );
}
