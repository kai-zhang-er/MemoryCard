import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_cards/models/photo_asset.dart';
import 'package:memory_cards/screens/memory_card_screen.dart';
import 'package:memory_cards/services/memory_repository.dart';
import 'package:memory_cards/services/photo_library_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  late Directory tempDir;
  late MemoryRepository repository;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tempDir = await Directory.systemTemp.createTemp('memory_cards_card_test_');
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

  testWidgets('shows permission denied state', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    final service = _FakePhotoLibraryService(
      permission: PhotoPermissionResult.denied,
    );

    await _pumpCard(tester, service, repository);

    expect(find.text('需要相册权限'), findsOneWidget);
    expect(find.text('重新请求'), findsOneWidget);
    expect(find.text('打开设置'), findsOneWidget);
  });

  testWidgets('shows empty library state', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    final service = _FakePhotoLibraryService(
      permission: PhotoPermissionResult.authorized,
      assets: const [],
    );

    await _pumpCard(tester, service, repository);

    expect(find.text('没有可用照片'), findsOneWidget);
  });

  testWidgets('shows a local photo thumbnail', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    final service = _FakePhotoLibraryService(
      permission: PhotoPermissionResult.authorized,
      assets: [_asset('photo_001')],
      thumbnails: {'photo_001': _onePixelPng},
    );

    await _pumpCard(tester, service, repository);

    expect(find.byType(Image), findsOneWidget);
    expect(find.text('这张照片你还记得吗？'), findsOneWidget);
    expect(find.text('拍摄时间：2025-07-03'), findsOneWidget);
    expect(find.text('重要'), findsOneWidget);
    expect(find.text('待删除'), findsOneWidget);
    expect(find.text('跳过'), findsOneWidget);
  });

  testWidgets('talk opens placeholder without saving a record', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    final service = _FakePhotoLibraryService(
      permission: PhotoPermissionResult.authorized,
      assets: [_asset('photo_001')],
      thumbnails: {'photo_001': _onePixelPng},
    );

    await _pumpCard(tester, service, repository);
    await tester.tap(find.text('讲讲'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('录音功能将在 Task 4 接入'), findsOneWidget);
  });
}

Future<void> _pumpCard(
  WidgetTester tester,
  _FakePhotoLibraryService service,
  MemoryRepository repository, {
  Random? random,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: MemoryCardScreen(
        photoLibraryService: service,
        memoryRepository: repository,
        random: random ?? Random(1),
      ),
    ),
  );
  await tester.pumpAndSettle();
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

final Uint8List _onePixelPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAFgwJ/lK3Q2wAAAABJRU5ErkJggg==',
);
