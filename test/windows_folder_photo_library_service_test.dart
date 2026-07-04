import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:memory_cards/services/photo_library_service.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir =
        await Directory.systemTemp.createTemp('memory_cards_windows_photo_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('returns folderNotSelected when picker is canceled', () async {
    final service = WindowsFolderPhotoLibraryService(
      directoryPicker: () async => null,
    );

    final result = await service.requestPermission();

    expect(result, PhotoPermissionResult.folderNotSelected);
    expect(result.canAccessPhotos, isFalse);
    expect(result.requiresFolderSelection, isTrue);
  });

  test('discovers supported images and ignores unsupported files', () async {
    await File('${tempDir.path}/photo.jpg').writeAsBytes(_onePixelPng);
    await File('${tempDir.path}/notes.txt').writeAsString('not a photo');
    await Directory('${tempDir.path}/nested').create();
    await File('${tempDir.path}/nested/other.PNG').writeAsBytes(_onePixelPng);

    final service = WindowsFolderPhotoLibraryService(
      directoryPicker: () async => tempDir.path,
    );

    expect(await service.requestPermission(), PhotoPermissionResult.authorized);
    final assets = await service.getPhotoAssets();

    expect(assets.map((asset) => asset.title),
        containsAll(['photo.jpg', 'other.PNG']));
    expect(assets.any((asset) => asset.title == 'notes.txt'), isFalse);
  });

  test('uses file modified time as capture time fallback', () async {
    final file = File('${tempDir.path}/photo.webp');
    await file.writeAsBytes(_onePixelPng);
    final modified = DateTime(2022, 4, 5, 6, 7, 8);
    await file.setLastModified(modified);

    final service = WindowsFolderPhotoLibraryService(
      directoryPicker: () async => tempDir.path,
    );

    await service.requestPermission();
    final assets = await service.getPhotoAssets();
    final time = await service.getPhotoTime(file.path);

    expect(assets.single.createdAt, modified);
    expect(time, modified);
  });

  test('loads image bytes by file path asset id', () async {
    final file = File('${tempDir.path}/photo.bmp');
    await file.writeAsBytes(_onePixelPng);

    final service = WindowsFolderPhotoLibraryService(
      directoryPicker: () async => tempDir.path,
    );

    await service.requestPermission();
    final thumbnail = await service.getThumbnail(file.path);

    expect(thumbnail, _onePixelPng);
  });
}

final Uint8List _onePixelPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAFgwJ/lK3Q2wAAAABJRU5ErkJggg==',
);
