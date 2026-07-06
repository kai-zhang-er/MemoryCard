import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_cards/models/memory_record.dart';
import 'package:memory_cards/models/photo_asset.dart';
import 'package:memory_cards/screens/memory_detail_screen.dart';
import 'package:memory_cards/services/audio_playback_service.dart';
import 'package:memory_cards/services/memory_repository.dart';
import 'package:memory_cards/services/photo_library_service.dart';
import 'package:memory_cards/services/recording_file_service.dart';
import 'package:memory_cards/widgets/audio_player_tile.dart';

const _detailTitle = '\u8bb0\u5fc6\u8be6\u60c5';
const _travelTag = '\u65c5\u884c';
const _importantText = '\u91cd\u8981';
const _deleteCandidateText = '\u5f85\u5220\u9664';
const _skippedText = '\u5df2\u8df3\u8fc7';
const _deleteMemoryText = '\u5220\u9664\u8fd9\u6761\u8bb0\u5fc6\u8bb0\u5f55';
const _deleteDialogText =
    '\u8fd9\u53ea\u4f1a\u5220\u9664 App \u91cc\u7684\u8bb0\u5fc6\u8bb0\u5f55\uff0c\u4e0d\u4f1a\u5220\u9664\u6216\u4fee\u6539\u539f\u59cb\u7167\u7247\u3002';
const _confirmDeleteText = '\u5220\u9664\u8bb0\u5f55';
const _deleteOriginalPhotoText = '\u5220\u9664\u539f\u59cb\u7167\u7247';
const _deleteOriginalWarning =
    '\u8fd9\u4f1a\u5220\u9664\u624b\u673a\u76f8\u518c/\u672c\u5730\u6587\u4ef6\u4e2d\u7684\u539f\u59cb\u7167\u7247\uff0c\u4e0d\u53ea\u662f\u5220\u9664 Memory Cards \u91cc\u7684\u8bb0\u5f55\u3002\u6b64\u64cd\u4f5c\u53ef\u80fd\u65e0\u6cd5\u64a4\u9500\u3002';
const _noteHintText = '\u5199\u4e00\u53e5\u60f3\u8d77\u6765\u7684\u4e8b';

void main() {
  testWidgets('MemoryDetailScreen shows editable record details',
      (tester) async {
    final repository = _FakeMemoryRepository(
      _record(
        userTags: const [_travelTag],
        important: true,
        audioPath: 'audio/2026/memory.m4a',
      ),
    );
    final photoLibraryService = _FakePhotoLibraryService();

    await _pumpDetail(
      tester,
      repository: repository,
      photoLibraryService: photoLibraryService,
    );
    await tester.pump();

    expect(find.text(_detailTitle), findsOneWidget);
    expect(find.text(_travelTag), findsOneWidget);
    expect(find.text(_importantText), findsOneWidget);
    expect(find.byType(AudioPlayerTile), findsOneWidget);
    expect(photoLibraryService.thumbnailRequests, contains('asset_001'));
  });

  testWidgets('tags can be toggled and persisted', (tester) async {
    final repository = _FakeMemoryRepository(_record());

    await _pumpDetail(tester, repository: repository);
    await tester.pump();

    await tester.tap(find.text(_travelTag));
    await tester.pump();

    expect(repository.record.userTags, contains(_travelTag));

    await tester.tap(find.text(_travelTag));
    await tester.pump();

    expect(repository.record.userTags, isNot(contains(_travelTag)));
  });

  testWidgets('status switches can be toggled and persisted', (tester) async {
    final repository = _FakeMemoryRepository(_record());

    await _pumpDetail(tester, repository: repository);
    await tester.pump();

    await tester.tap(find.text(_importantText));
    await tester.pump();
    expect(repository.record.important, isTrue);

    await tester.tap(find.text(_deleteCandidateText));
    await tester.pump();
    expect(repository.record.deleteCandidate, isTrue);

    await tester.tap(find.text(_skippedText));
    await tester.pump();
    expect(repository.record.skipped, isTrue);
    expect(repository.record.reviewStatus, 'skipped');
  });

  testWidgets('manual note can be edited and persisted', (tester) async {
    final repository =
        _FakeMemoryRepository(_record(memoryText: '\u65e7\u5907\u6ce8'));

    await _pumpDetail(tester, repository: repository);
    await tester.pump();

    await tester.enterText(
      find.widgetWithText(TextField, _noteHintText),
      '\u8fd9\u662f\u672c\u79d1\u6bd5\u4e1a\u65c5\u884c\uff0c\u5728\u53a6\u95e8\u3002',
    );
    await tester.pump(const Duration(milliseconds: 800));

    expect(repository.record.memoryText,
        '\u8fd9\u662f\u672c\u79d1\u6bd5\u4e1a\u65c5\u884c\uff0c\u5728\u53a6\u95e8\u3002');
  });
  test('audio file deletion helper removes audio without deleting memory data',
      () async {
    final tempDir = Directory('.dart_tool/memory_detail_audio_test');
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
    await tempDir.create(recursive: true);
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final audioFile = File('${tempDir.path}/audio/2026/memory.m4a');
    await audioFile.parent.create(recursive: true);
    await audioFile.writeAsBytes([1, 2, 3]);
    final repository = _FakeMemoryRepository(
      _record(audioPath: 'audio/2026/memory.m4a'),
    );
    final recordingFileService = RecordingFileService(
      documentsDirectoryProvider: () async => tempDir,
    );

    await recordingFileService.deleteIfExists(repository.record.audioPath);
    await repository.upsert(repository.record.copyWith(clearAudioPath: true));

    expect(await audioFile.exists(), isFalse);
    expect(repository.deletedMemoryIds, isEmpty);
    expect(repository.record.audioPath, isNull);
  });

  testWidgets(
      'permanent original photo delete is gated to delete-candidate detail',
      (tester) async {
    final repository = _FakeMemoryRepository(_record(deleteCandidate: true));
    final photoLibraryService = _FakePhotoLibraryService(
      deleteResult: const PhotoDeleteResult.success(),
    );

    await _pumpDetail(
      tester,
      repository: repository,
      photoLibraryService: photoLibraryService,
      allowPermanentPhotoDelete: true,
    );
    await tester.pump();

    await tester.ensureVisible(find.text(_deleteOriginalPhotoText));
    await tester.tap(find.text(_deleteOriginalPhotoText));
    await tester.pump();

    expect(find.text(_deleteOriginalWarning), findsOneWidget);

    await tester.tap(find.text(_deleteOriginalPhotoText).last);
    await tester.pump();
    await tester.pump();

    expect(photoLibraryService.deletedAssetIds, ['asset_001']);
    expect(repository.record.photoDeleted, isTrue);
    expect(repository.record.photoDeletedAt, isNotNull);
  });

  testWidgets('permanent original photo delete is hidden outside delete flow',
      (tester) async {
    final repository = _FakeMemoryRepository(_record(deleteCandidate: true));

    await _pumpDetail(tester, repository: repository);
    await tester.pump();

    expect(find.text(_deleteOriginalPhotoText), findsNothing);
  });

  testWidgets('memory record can be deleted after confirmation',
      (tester) async {
    final repository = _FakeMemoryRepository(_record());

    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () {
                  Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (context) => MemoryDetailScreen(
                        initialRecord: repository.record,
                        repository: repository,
                        photoLibraryService: _FakePhotoLibraryService(),
                        audioPlaybackControllerFactory:
                            _FakeAudioPlaybackController.new,
                      ),
                    ),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump();
    await tester.ensureVisible(find.text(_deleteMemoryText));
    await tester.tap(find.text(_deleteMemoryText));
    await tester.pump();

    expect(find.text(_deleteDialogText), findsOneWidget);

    await tester.tap(find.text(_confirmDeleteText));
    await tester.pump();
    await tester.pump();

    expect(repository.deletedMemoryIds, ['memory_001']);
    expect(find.text('open'), findsOneWidget);
  });
}

Future<void> _pumpDetail(
  WidgetTester tester, {
  required _FakeMemoryRepository repository,
  PhotoLibraryService? photoLibraryService,
  RecordingFileService recordingFileService = const RecordingFileService(),
  bool allowPermanentPhotoDelete = false,
}) async {
  tester.view.physicalSize = const Size(900, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      home: MemoryDetailScreen(
        initialRecord: repository.record,
        repository: repository,
        photoLibraryService: photoLibraryService ?? _FakePhotoLibraryService(),
        audioPlaybackControllerFactory: _FakeAudioPlaybackController.new,
        recordingFileService: recordingFileService,
        allowPermanentPhotoDelete: allowPermanentPhotoDelete,
      ),
    ),
  );
}

MemoryRecord _record({
  List<String> userTags = const [],
  bool important = false,
  bool deleteCandidate = false,
  bool skipped = false,
  String? audioPath,
  String memoryText = '',
}) {
  final now = DateTime.utc(2026, 7, 5, 10);
  return MemoryRecord(
    memoryId: 'memory_001',
    assetId: 'asset_001',
    photoTime: DateTime.utc(2024, 5, 1, 8),
    createdAt: now,
    updatedAt: now,
    important: important,
    deleteCandidate: deleteCandidate,
    skipped: skipped,
    userTags: userTags,
    audioPath: audioPath,
    memoryText: memoryText,
  );
}

class _FakeMemoryRepository extends MemoryRepository {
  _FakeMemoryRepository(this.record);

  MemoryRecord record;
  final List<String> deletedMemoryIds = [];

  @override
  Future<MemoryRecord?> getByMemoryId(String memoryId) async {
    if (deletedMemoryIds.contains(memoryId)) {
      return null;
    }
    return record.memoryId == memoryId ? record : null;
  }

  @override
  Future<void> upsert(MemoryRecord record) async {
    this.record = record;
  }

  @override
  Future<int> deleteByMemoryId(String memoryId) async {
    deletedMemoryIds.add(memoryId);
    return 1;
  }
}

class _FakePhotoLibraryService implements PhotoLibraryService {
  _FakePhotoLibraryService({
    this.deleteResult = const PhotoDeleteResult.unsupported(),
    Uint8List? thumbnailBytes,
  }) : thumbnailBytes = thumbnailBytes ?? _onePixelPng;

  final PhotoDeleteResult deleteResult;
  final Uint8List? thumbnailBytes;
  final List<String> thumbnailRequests = [];
  final List<String> deletedAssetIds = [];

  @override
  Future<PhotoDeleteResult> deleteOriginalPhoto(String assetId) async {
    deletedAssetIds.add(assetId);
    return deleteResult;
  }

  @override
  Future<List<PhotoAsset>> getPhotoAssets({int limit = 80}) async => const [];

  @override
  Future<DateTime?> getPhotoTime(String assetId) async => null;

  @override
  Future<Uint8List?> getThumbnail(String assetId, {int size = 900}) async {
    thumbnailRequests.add(assetId);
    return thumbnailBytes;
  }

  @override
  Future<void> openSettings() async {}

  @override
  Future<PhotoPermissionResult> requestPermission() async =>
      PhotoPermissionResult.authorized;
}

class _FakeAudioPlaybackController implements AudioPlaybackController {
  final _playingController = StreamController<bool>.broadcast();
  final _positionController = StreamController<Duration>.broadcast();
  final _durationController = StreamController<Duration?>.broadcast();

  @override
  Stream<bool> get playingStream => _playingController.stream;

  @override
  Stream<Duration> get positionStream => _positionController.stream;

  @override
  Stream<Duration?> get durationStream => _durationController.stream;

  @override
  bool get isPlaying => false;

  @override
  Duration get position => Duration.zero;

  @override
  Duration? get duration => null;

  @override
  Future<void> play(String audioPath) async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> dispose() async {
    await _playingController.close();
    await _positionController.close();
    await _durationController.close();
  }
}

final Uint8List _onePixelPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAFgwJ/lK3Q2wAAAABJRU5ErkJggg==',
);
