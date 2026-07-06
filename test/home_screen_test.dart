import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_cards/models/photo_asset.dart';
import 'package:memory_cards/screens/home_screen.dart';
import 'package:memory_cards/services/export_service.dart';
import 'package:memory_cards/services/memory_repository.dart';
import 'package:memory_cards/services/photo_library_service.dart';

const _startText = '\u5f00\u59cb\u4e00\u5c40';
const _todayFiveText = '\u4eca\u65e5 5 \u5f20';
const _memoryListText = '\u8bb0\u5fc6\u5217\u8868';
const _importantText = '\u91cd\u8981\u7167\u7247';
const _deleteCandidateText = '\u5f85\u5220\u9664';
const _exportText = '\u5bfc\u51fa\u8d44\u6599';
const _privacyText =
    '\u7167\u7247\u53ea\u8bfb\u663e\u793a\uff1b\u5f55\u97f3\u548c\u8bb0\u5fc6\u6570\u636e\u53ea\u4fdd\u5b58\u5728\u672c\u673a\uff0c\u4e0d\u4e0a\u4f20\u3002';
const _permissionText = '\u9700\u8981\u76f8\u518c\u6743\u9650';

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

    expect(find.text(_startText), findsOneWidget);
    expect(find.text(_todayFiveText), findsWidgets);
    expect(find.text(_memoryListText), findsOneWidget);
    expect(find.text(_importantText), findsOneWidget);
    expect(find.text(_deleteCandidateText), findsOneWidget);
    expect(find.text(_exportText), findsOneWidget);
    expect(find.textContaining('\u5047'), findsNothing);
    expect(find.textContaining('\u4e0d\u5f55\u97f3'), findsNothing);
    expect(find.text(_privacyText), findsOneWidget);
  });

  testWidgets('export action writes json and markdown bundle', (tester) async {
    final exportDirectory = Directory('C:/tmp/home_export_test');
    final exportService = _FakeExportService(exportDirectory);

    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          repository: MemoryRepository(),
          photoLibraryServiceFactory: () => _DeniedPhotoLibraryService(),
          exportServiceFactory: (_) => exportService,
        ),
      ),
    );

    await tester.tap(find.text(_exportText));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(exportService.exportCalls, 1);
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

    await tester.tap(find.text(_startText));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(factoryCalls, 1);
    expect(find.text(_permissionText), findsOneWidget);
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

    await tester.tap(find.text(_todayFiveText));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(factoryCalls, 1);
    expect(find.text(_todayFiveText), findsWidgets);
  });
}

class _FakeExportService extends ExportService {
  _FakeExportService(this.directory) : super(MemoryRepository());

  final Directory directory;
  var exportCalls = 0;

  @override
  Future<ExportResult> exportMemories({DateTime? exportedAt}) async {
    exportCalls += 1;
    final jsonFile = File('${directory.path}/memories.json');
    final markdownDirectory = Directory('${directory.path}/markdown');
    await markdownDirectory.create(recursive: true);
    await jsonFile.writeAsString('{}');
    return ExportResult(
      exportDirectory: directory,
      jsonFile: jsonFile,
      markdownDirectory: markdownDirectory,
      markdownCount: 0,
    );
  }
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
