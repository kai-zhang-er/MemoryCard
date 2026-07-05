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
const _deleteAudioText = '\u5220\u9664\u5f55\u97f3';
const _noAudioText = '\u8fd8\u6ca1\u6709\u5f55\u97f3\u3002';
const _deleteMemoryText = '\u5220\u9664\u8fd9\u6761\u8bb0\u5fc6\u8bb0\u5f55';
const _deleteDialogText =
    '\u8fd9\u53ea\u4f1a\u5220\u9664 App \u91cc\u7684\u8bb0\u5fc6\u8bb0\u5f55\uff0c\u4e0d\u4f1a\u5220\u9664\u6216\u4fee\u6539\u539f\u59cb\u7167\u7247\u3002';
const _confirmDeleteText = '\u5220\u9664\u8bb0\u5f55';

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

  testWidgets('audio can be deleted without deleting the memory record',
      (tester) async {
    final tempDir =
        await Directory.systemTemp.createTemp('memory_detail_audio_');
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

    await _pumpDetail(
      tester,
      repository: repository,
      recordingFileService: RecordingFileService(
        documentsDirectoryProvider: () async => tempDir,
      ),
    );
    await tester.pump();

    await tester.ensureVisible(find.text(_deleteAudioText));
    await tester.tap(find.text(_deleteAudioText));
    await tester.pump();

    expect(await audioFile.exists(), isFalse);
    expect(repository.deletedMemoryIds, isEmpty);
    expect(repository.record.audioPath, isNull);
    expect(find.text(_noAudioText), findsOneWidget);
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
  final List<String> thumbnailRequests = [];

  @override
  Future<List<PhotoAsset>> getPhotoAssets({int limit = 80}) async => const [];

  @override
  Future<DateTime?> getPhotoTime(String assetId) async => null;

  @override
  Future<Uint8List?> getThumbnail(String assetId, {int size = 900}) async {
    thumbnailRequests.add(assetId);
    return _onePixelPng;
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
