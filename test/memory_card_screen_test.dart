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

  testWidgets('shows a local photo thumbnail', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    final service = _FakePhotoLibraryService(
      permission: PhotoPermissionResult.authorized,
      assets: [_asset('photo_001')],
      thumbnails: {'photo_001': _onePixelPng},
    );

    await _pumpCard(tester, service, _FakeMemoryRepository());

    expect(find.byType(Image), findsOneWidget);
    expect(find.byIcon(Icons.star_outline), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    expect(find.byIcon(Icons.skip_next), findsOneWidget);
  });

  testWidgets('talk opens recording screen with the current thumbnail',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    final service = _FakePhotoLibraryService(
      permission: PhotoPermissionResult.authorized,
      assets: [_asset('photo_001')],
      thumbnails: {'photo_001': _onePixelPng},
    );

    await _pumpCard(tester, service, _FakeMemoryRepository());
    await tester.tap(find.byIcon(Icons.mic_none));
    await _pumpSeveral(tester);

    expect(find.byType(RecordMemoryScreen), findsOneWidget);
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

    await tester.tap(find.byIcon(Icons.skip_next));
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

  testWidgets('today five stops after five shown photos', (tester) async {
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
    for (var i = 0; i < 5; i += 1) {
      await tester.tap(find.byIcon(Icons.skip_next));
      await _pumpSeveral(tester);
    }

    expect(service.thumbnailRequests.toSet(), hasLength(5));
    expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
  });
}

Future<void> _pumpCard(
  WidgetTester tester,
  _FakePhotoLibraryService service,
  MemoryRepository repository, {
  Random? random,
  WeightedRandomService weightedRandomService = const WeightedRandomService(),
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
        random: random ?? Random(1),
      ),
    ),
  );
  await _pumpSeveral(tester);
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
