import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:memory_cards/models/photo_asset.dart';
import 'package:memory_cards/services/memory_action_service.dart';
import 'package:memory_cards/services/memory_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  late Directory tempDir;
  late MemoryRepository repository;
  late MemoryActionService service;

  setUp(() async {
    tempDir =
        await Directory.systemTemp.createTemp('memory_cards_action_test_');
    repository = MemoryRepository(
      databaseFactory: databaseFactoryFfi,
      databasePath: '${tempDir.path}/memory_cards_test.db',
    );
    service = MemoryActionService(repository);
  });

  tearDown(() async {
    await repository.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('important action creates an important memory record with prompt',
      () async {
    final record = await service.saveAction(
      _asset('photo_001'),
      MemoryRecordAction.important,
      promptQuestion: '杩欐槸鍦ㄥ摢閲岋紵',
      now: DateTime.utc(2026, 7, 3),
    );

    final saved = await repository.getByAssetId('photo_001');

    expect(saved, isNotNull);
    expect(saved!.memoryId, record.memoryId);
    expect(saved.important, isTrue);
    expect(saved.deleteCandidate, isFalse);
    expect(saved.skipped, isFalse);
    expect(saved.promptQuestion, '杩欐槸鍦ㄥ摢閲岋紵');
  });

  test('delete candidate action creates a delete candidate record', () async {
    await service.saveAction(
      _asset('photo_001'),
      MemoryRecordAction.deleteCandidate,
      now: DateTime.utc(2026, 7, 3),
    );

    final saved = await repository.getByAssetId('photo_001');

    expect(saved, isNotNull);
    expect(saved!.deleteCandidate, isTrue);
    expect(saved.important, isFalse);
    expect(saved.skipped, isFalse);
  });

  test('skip action creates skipped record with skipped review status',
      () async {
    await service.saveAction(
      _asset('photo_001'),
      MemoryRecordAction.skipped,
      now: DateTime.utc(2026, 7, 3),
    );

    final saved = await repository.getByAssetId('photo_001');

    expect(saved, isNotNull);
    expect(saved!.skipped, isTrue);
    expect(saved.reviewStatus, 'skipped');
  });

  test('repeated actions update one record and preserve previous flags',
      () async {
    final asset = _asset('photo_001');
    final first = await service.saveAction(
      asset,
      MemoryRecordAction.important,
      now: DateTime.utc(2026, 7, 3, 9),
    );
    final second = await service.saveAction(
      asset,
      MemoryRecordAction.deleteCandidate,
      now: DateTime.utc(2026, 7, 3, 10),
    );

    final all = await repository.getAll();
    final saved = await repository.getByAssetId(asset.assetId);

    expect(all, hasLength(1));
    expect(second.memoryId, first.memoryId);
    expect(saved!.important, isTrue);
    expect(saved.deleteCandidate, isTrue);
    expect(saved.updatedAt, DateTime.utc(2026, 7, 3, 10));
  });

  test('attaches audio path to a new record with prompt', () async {
    await service.attachAudio(
      _asset('photo_001'),
      'audio/2026/memory_photo_001.m4a',
      promptQuestion: '杩欎竴澶╁悗鏉ュ彂鐢熶簡浠€涔堬紵',
      now: DateTime.utc(2026, 7, 3),
    );

    final saved = await repository.getByAssetId('photo_001');

    expect(saved, isNotNull);
    expect(saved!.audioPath, 'audio/2026/memory_photo_001.m4a');
    expect(saved.promptQuestion, '杩欎竴澶╁悗鏉ュ彂鐢熶簡浠€涔堬紵');
    expect(saved.transcript, '');
    expect(saved.memoryText, '');
    expect(saved.reviewStatus, 'raw');
  });

  test('attaching audio saves supplied manual note separately from transcript',
      () async {
    await service.attachAudio(
      _asset('photo_001'),
      'audio/2026/memory_photo_001.m4a',
      memoryText:
          '\u8fd9\u662f\u672c\u79d1\u6bd5\u4e1a\u65c5\u884c\uff0c\u5728\u53a6\u95e8\u3002',
      now: DateTime.utc(2026, 7, 3),
    );

    final saved = await repository.getByAssetId('photo_001');

    expect(saved, isNotNull);
    expect(saved!.memoryText,
        '\u8fd9\u662f\u672c\u79d1\u6bd5\u4e1a\u65c5\u884c\uff0c\u5728\u53a6\u95e8\u3002');
    expect(saved.transcript, '');
  });

  test('attaching audio preserves existing manual note when none is supplied',
      () async {
    final asset = _asset('photo_001');
    await service.attachAudio(
      asset,
      'audio/2026/first.m4a',
      memoryText: '\u65e7\u5907\u6ce8',
      now: DateTime.utc(2026, 7, 3, 9),
    );
    await service.attachAudio(
      asset,
      'audio/2026/second.m4a',
      now: DateTime.utc(2026, 7, 3, 10),
    );

    final saved = await repository.getByAssetId('photo_001');

    expect(saved, isNotNull);
    expect(saved!.audioPath, 'audio/2026/second.m4a');
    expect(saved.memoryText, '\u65e7\u5907\u6ce8');
  });
  test('attaching audio preserves existing flags', () async {
    final asset = _asset('photo_001');
    await service.saveAction(
      asset,
      MemoryRecordAction.important,
      now: DateTime.utc(2026, 7, 3, 9),
    );
    await service.attachAudio(
      asset,
      'audio/2026/memory_photo_001.m4a',
      now: DateTime.utc(2026, 7, 3, 10),
    );

    final saved = await repository.getByAssetId('photo_001');

    expect(saved, isNotNull);
    expect(saved!.important, isTrue);
    expect(saved.audioPath, 'audio/2026/memory_photo_001.m4a');
    expect(saved.updatedAt, DateTime.utc(2026, 7, 3, 10));
  });

  test('saving tags creates a record with merged user tags and prompt',
      () async {
    final asset = _asset('photo_001');
    await service.saveTags(
      asset,
      ['鏃呰', '瀹朵汉'],
      promptQuestion: '杩欐槸鍦ㄥ摢閲岋紵',
      now: DateTime.utc(2026, 7, 3, 9),
    );
    await service.saveTags(
      asset,
      ['瀹朵汉', '缇庨'],
      promptQuestion: '杩欐槸鍦ㄥ摢閲岋紵',
      now: DateTime.utc(2026, 7, 3, 10),
    );

    final saved = await repository.getByAssetId('photo_001');

    expect(saved, isNotNull);
    expect(saved!.userTags, ['鏃呰', '瀹朵汉', '缇庨']);
    expect(saved.promptQuestion, '杩欐槸鍦ㄥ摢閲岋紵');
    expect(saved.updatedAt, DateTime.utc(2026, 7, 3, 10));
  });

  test('saving tags preserves existing flags and audio', () async {
    final asset = _asset('photo_001');
    await service.saveAction(
      asset,
      MemoryRecordAction.important,
      now: DateTime.utc(2026, 7, 3, 9),
    );
    await service.attachAudio(
      asset,
      'audio/2026/memory_photo_001.m4a',
      now: DateTime.utc(2026, 7, 3, 10),
    );
    await service.saveTags(
      asset,
      ['鏈嬪弸'],
      now: DateTime.utc(2026, 7, 3, 11),
    );

    final saved = await repository.getByAssetId('photo_001');

    expect(saved, isNotNull);
    expect(saved!.important, isTrue);
    expect(saved.audioPath, 'audio/2026/memory_photo_001.m4a');
    expect(saved.userTags, ['鏈嬪弸']);
  });
}

PhotoAsset _asset(String id) {
  return PhotoAsset(
    assetId: id,
    createdAt: DateTime.utc(2025, 7, 3),
    width: 1200,
    height: 1600,
    title: 'Fake photo $id',
  );
}
