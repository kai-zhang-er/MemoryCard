import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_cards/models/memory_record.dart';
import 'package:memory_cards/models/photo_asset.dart';
import 'package:memory_cards/screens/memory_card_screen.dart';
import 'package:memory_cards/screens/record_memory_screen.dart';
import 'package:memory_cards/services/memory_repository.dart';
import 'package:memory_cards/services/photo_library_service.dart';
import 'package:memory_cards/services/prompt_question_service.dart';
import 'package:memory_cards/services/recording_service.dart';
import 'package:memory_cards/services/weighted_random_service.dart';

void main() {
  testWidgets('shows permission denied state', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    final service = _FakePhotoLibraryService(
      permission: PhotoPermissionResult.denied,
    );

    await _pumpCard(tester, service, _FakeMemoryRepository());

    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    expect(find.text('需要相册权限'), findsOneWidget);
  });

  testWidgets('shows empty library state', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    final service = _FakePhotoLibraryService(
      permission: PhotoPermissionResult.authorized,
      assets: const [],
    );

    await _pumpCard(tester, service, _FakeMemoryRepository());

    expect(find.byIcon(Icons.image_not_supported_outlined), findsOneWidget);
  });

  testWidgets('shows a local photo thumbnail and prompt', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    final service = _FakePhotoLibraryService(
      permission: PhotoPermissionResult.authorized,
      assets: [_asset('photo_001')],
      thumbnails: {'photo_001': _onePixelPng},
    );

    await _pumpCard(tester, service, _FakeMemoryRepository());

    expect(find.byType(Image), findsOneWidget);
    expect(find.text('测试问题？'), findsOneWidget);
    expect(find.byIcon(Icons.star_outline), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    expect(find.byIcon(Icons.skip_next), findsOneWidget);
  });

  testWidgets('quick tag chips toggle and save without advancing',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    final repository = _FakeMemoryRepository();
    final service = _FakePhotoLibraryService(
      permission: PhotoPermissionResult.authorized,
      assets: [_asset('photo_001'), _asset('photo_002')],
      thumbnails: {
        'photo_001': _onePixelPng,
        'photo_002': _onePixelPng,
      },
    );

    await _pumpCard(tester, service, repository);
    final firstShown = service.thumbnailRequests.single;

    await tester.tap(find.text('旅行'));
    await tester.pump();
    await tester.tap(find.text('家人'));
    await tester.pump();
    await _pumpSeveral(tester);

    final saved = await repository.getByAssetId(firstShown);
    expect(saved, isNotNull);
    expect(saved!.userTags, ['旅行', '家人']);
    expect(saved.promptQuestion, '测试问题？');
    expect(service.thumbnailRequests, [firstShown]);
  });

  testWidgets('important action saves the displayed prompt', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    final repository = _FakeMemoryRepository();
    final service = _FakePhotoLibraryService(
      permission: PhotoPermissionResult.authorized,
      assets: [_asset('photo_001')],
      thumbnails: {'photo_001': _onePixelPng},
    );

    await _pumpCard(tester, service, repository);
    await _tapVisible(tester, find.byIcon(Icons.star_outline));
    await _pumpSeveral(tester);

    final saved = await repository.getByAssetId('photo_001');
    expect(saved, isNotNull);
    expect(saved!.important, isTrue);
    expect(saved.promptQuestion, '测试问题？');
  });

  testWidgets(
      'talk opens recording screen with the current prompt and thumbnail',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    final service = _FakePhotoLibraryService(
      permission: PhotoPermissionResult.authorized,
      assets: [_asset('photo_001')],
      thumbnails: {'photo_001': _onePixelPng},
    );

    await _pumpCard(tester, service, _FakeMemoryRepository());
    await _tapVisible(tester, find.byIcon(Icons.mic_none));
    await _pumpSeveral(tester);

    expect(find.byType(RecordMemoryScreen), findsOneWidget);
    expect(find.text('测试问题？'), findsOneWidget);
    expect(find.byType(Image), findsWidgets);
  });

  testWidgets('does not repeat a shown photo while another candidate exists',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    final repository = _FakeMemoryRepository();
    final service = _FakePhotoLibraryService(
      permission: PhotoPermissionResult.authorized,
      assets: [_asset('photo_001'), _asset('photo_002')],
      thumbnails: {
        'photo_001': _onePixelPng,
        'photo_002': _onePixelPng,
      },
    );

    await _pumpCard(tester, service, repository);
    final firstShown = service.thumbnailRequests.single;

    await _tapVisible(tester, find.byIcon(Icons.skip_next));
    await _pumpSeveral(tester);

    expect(service.thumbnailRequests, hasLength(2));
    expect(service.thumbnailRequests.last, isNot(firstShown));
  });

  testWidgets('historically processed photos are excluded before fallback',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    final now = DateTime.utc(2026, 7, 3);
    final repository = _FakeMemoryRepository([
      MemoryRecord(
        memoryId: 'memory_photo_001',
        assetId: 'photo_001',
        createdAt: now,
        updatedAt: now,
      ),
    ]);
    final service = _FakePhotoLibraryService(
      permission: PhotoPermissionResult.authorized,
      assets: [_asset('photo_001'), _asset('photo_002')],
      thumbnails: {
        'photo_001': _onePixelPng,
        'photo_002': _onePixelPng,
      },
    );

    await _pumpCard(
      tester,
      service,
      repository,
      useRepositoryProcessedIds: true,
    );

    expect(service.thumbnailRequests, ['photo_002']);
  });

  testWidgets('today five completion shows session counters', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    final repository = _FakeMemoryRepository();
    final assets = List.generate(6, (index) => _asset('photo_$index'));
    final service = _FakePhotoLibraryService(
      permission: PhotoPermissionResult.authorized,
      assets: assets,
      thumbnails: {
        for (final asset in assets) asset.assetId: _onePixelPng,
      },
    );

    await _pumpCard(
      tester,
      service,
      repository,
      sessionLimit: 5,
    );
    await tester.tap(find.text('旅行'));
    await tester.pump();
    await _pumpSeveral(tester);
    await _tapVisible(tester, find.byIcon(Icons.star_outline));
    await _pumpSeveral(tester);
    await _tapVisible(tester, find.byIcon(Icons.delete_outline));
    await _pumpSeveral(tester);
    await _tapVisible(tester, find.byIcon(Icons.skip_next));
    await _pumpSeveral(tester);
    await _tapVisible(tester, find.byIcon(Icons.skip_next));
    await _pumpSeveral(tester);
    await _tapVisible(tester, find.byIcon(Icons.skip_next));
    await _pumpSeveral(tester);

    expect(service.thumbnailRequests.toSet(), hasLength(5));
    expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
    expect(find.text('看过 5 张'), findsOneWidget);
    expect(find.text('录音 0 段'), findsOneWidget);
    expect(find.text('重要 1 张'), findsOneWidget);
    expect(find.text('待删除 1 张'), findsOneWidget);
    expect(find.text('跳过 3 张'), findsOneWidget);
    expect(find.text('标签 1 张'), findsOneWidget);
  });
}

Future<void> _pumpCard(
  WidgetTester tester,
  _FakePhotoLibraryService service,
  MemoryRepository repository, {
  Random? random,
  WeightedRandomService weightedRandomService = const WeightedRandomService(),
  PromptQuestionService promptQuestionService =
      const PromptQuestionService(questions: ['测试问题？']),
  bool useRepositoryProcessedIds = false,
  int? sessionLimit,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: MemoryCardScreen(
        photoLibraryService: service,
        memoryRepository: repository,
        sessionLimit: sessionLimit,
        recordingServiceFactory: () => _FakeRecordingService(),
        processedAssetIdsLoader:
            useRepositoryProcessedIds ? null : () async => <String>{},
        weightedRandomService: weightedRandomService,
        promptQuestionService: promptQuestionService,
        random: random ?? Random(1),
      ),
    ),
  );
  await _pumpSeveral(tester);
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
}

Future<void> _pumpSeveral(WidgetTester tester) async {
  for (var i = 0; i < 10; i += 1) {
    await tester.pump(const Duration(milliseconds: 100));
  }
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

class _FakeMemoryRepository extends MemoryRepository {
  _FakeMemoryRepository([List<MemoryRecord> records = const []])
      : records = [...records];

  final List<MemoryRecord> records;

  @override
  Future<void> upsert(MemoryRecord record) async {
    records.removeWhere((existing) => existing.memoryId == record.memoryId);
    records.add(record);
  }

  @override
  Future<List<MemoryRecord>> getAll() async => [...records];

  @override
  Future<MemoryRecord?> getByAssetId(String assetId) async {
    final matches = records.where((record) => record.assetId == assetId);
    return matches.isEmpty ? null : matches.last;
  }
}

class _FakePhotoLibraryService implements PhotoLibraryService {
  _FakePhotoLibraryService({
    required this.permission,
    this.assets = const [],
    this.thumbnails = const {},
  });

  final PhotoPermissionResult permission;
  final List<PhotoAsset> assets;
  final Map<String, Uint8List> thumbnails;
  final List<String> thumbnailRequests = [];

  @override
  Future<PhotoDeleteResult> deleteOriginalPhoto(String assetId) async =>
      const PhotoDeleteResult.unsupported();

  @override
  Future<List<PhotoAsset>> getPhotoAssets({int limit = 80}) async {
    return assets.take(limit).toList(growable: false);
  }

  @override
  Future<DateTime?> getPhotoTime(String assetId) async {
    return assets
        .where((asset) => asset.assetId == assetId)
        .firstOrNull
        ?.createdAt;
  }

  @override
  Future<Uint8List?> getThumbnail(String assetId, {int size = 900}) async {
    thumbnailRequests.add(assetId);
    return thumbnails[assetId];
  }

  @override
  Future<void> openSettings() async {}

  @override
  Future<PhotoPermissionResult> requestPermission() async {
    return permission;
  }
}

class _FakeRecordingService implements RecordingService {
  @override
  Future<void> cancel() async {}

  @override
  Future<void> dispose() async {}

  @override
  Future<bool> hasPermission() async => true;

  @override
  Future<RecordingStartResult> start(String assetId, {DateTime? now}) async {
    return RecordingStartResult(
      absolutePath: 'C:/tmp/$assetId.m4a',
      relativePath: 'audio/2026/$assetId.m4a',
    );
  }

  @override
  Future<String?> stop() async => 'audio/2026/fake.m4a';
}

final Uint8List _onePixelPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAFgwJ/lK3Q2wAAAABJRU5ErkJggg==',
);
