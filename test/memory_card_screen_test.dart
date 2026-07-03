import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_cards/models/photo_asset.dart';
import 'package:memory_cards/screens/memory_card_screen.dart';
import 'package:memory_cards/services/photo_library_service.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  testWidgets('shows permission denied state', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    final service = _FakePhotoLibraryService(
      permission: PhotoPermissionResult.denied,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MemoryCardScreen(
          photoLibraryService: service,
          random: Random(1),
        ),
      ),
    );
    await tester.pumpAndSettle();

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

    await tester.pumpWidget(
      MaterialApp(
        home: MemoryCardScreen(
          photoLibraryService: service,
          random: Random(1),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('没有可用照片'), findsOneWidget);
  });

  testWidgets('shows a local photo thumbnail', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    final service = _FakePhotoLibraryService(
      permission: PhotoPermissionResult.authorized,
      assets: [
        PhotoAsset(
          assetId: 'photo_001',
          createdAt: DateTime.utc(2025, 7, 3),
          width: 1200,
          height: 1600,
          title: 'Fake photo',
        ),
      ],
      thumbnails: {'photo_001': _onePixelPng},
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MemoryCardScreen(
          photoLibraryService: service,
          random: Random(1),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Image), findsOneWidget);
    expect(find.text('这张照片你还记得吗？'), findsOneWidget);
    expect(find.text('拍摄时间：2025-07-03'), findsOneWidget);
    expect(find.text('换一张'), findsOneWidget);
  });
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
