import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_cards/models/photo_asset.dart';
import 'package:memory_cards/screens/home_screen.dart';
import 'package:memory_cards/services/memory_repository.dart';
import 'package:memory_cards/services/photo_library_service.dart';

void main() {
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
