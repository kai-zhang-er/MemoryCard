import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_cards/models/photo_asset.dart';
import 'package:memory_cards/screens/home_screen.dart';
import 'package:memory_cards/services/memory_repository.dart';
import 'package:memory_cards/services/photo_library_service.dart';

void main() {
  testWidgets('home screen shows product actions and privacy copy',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          repository: MemoryRepository(),
          photoLibraryServiceFactory: () => _DeniedPhotoLibraryService(),
        ),
      ),
    );

    expect(find.text('开始一局'), findsOneWidget);
    expect(find.text('今日 5 张'), findsWidgets);
    expect(find.text('记忆列表'), findsOneWidget);
    expect(find.text('重要照片'), findsOneWidget);
    expect(find.text('待删除'), findsOneWidget);
    expect(find.text('导出 JSON'), findsOneWidget);
    expect(find.textContaining('假'), findsNothing);
    expect(find.textContaining('不录音'), findsNothing);
    expect(find.text('照片只读显示；录音和记忆数据只保存在本机，不上传。'), findsOneWidget);
  });

  testWidgets('start game uses injected photo service factory', (tester) async {
    var factoryCalls = 0;
    final service = _DeniedPhotoLibraryService();

    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          repository: MemoryRepository(),
          photoLibraryServiceFactory: () {
            factoryCalls += 1;
            return service;
          },
        ),
      ),
    );

    await tester.tap(find.text('开始一局'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(factoryCalls, 1);
    expect(find.text('需要相册权限'), findsOneWidget);
  });

  testWidgets('today five opens a limited session', (tester) async {
    var factoryCalls = 0;
    final service = _DeniedPhotoLibraryService();

    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          repository: MemoryRepository(),
          photoLibraryServiceFactory: () {
            factoryCalls += 1;
            return service;
          },
        ),
      ),
    );

    await tester.tap(find.text('今日 5 张'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(factoryCalls, 1);
    expect(find.text('今日 5 张'), findsWidgets);
  });
}

class _DeniedPhotoLibraryService implements PhotoLibraryService {
  @override
  Future<List<PhotoAsset>> getPhotoAssets({int limit = 80}) async => const [];

  @override
  Future<DateTime?> getPhotoTime(String assetId) async => null;

  @override
  Future<Uint8List?> getThumbnail(String assetId, {int size = 900}) async =>
      null;

  @override
  Future<void> openSettings() async {}

  @override
  Future<PhotoPermissionResult> requestPermission() async =>
      PhotoPermissionResult.denied;
}
