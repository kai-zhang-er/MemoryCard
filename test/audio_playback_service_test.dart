import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:memory_cards/services/audio_playback_service.dart';
import 'package:path/path.dart' as p;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('memory_cards_audio_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('resolveAudioPath resolves relative paths under app documents',
      () async {
    final resolved = await resolveAudioPath(
      'audio/2026/memory_photo_001.m4a',
      documentsDirectoryProvider: () async => tempDir,
    );

    expect(resolved,
        p.join(tempDir.path, 'audio', '2026', 'memory_photo_001.m4a'));
  });

  test('play reports a controlled failure when the file is missing', () async {
    final controller = JustAudioPlaybackController(
      documentsDirectoryProvider: () async => tempDir,
    );

    await expectLater(
      controller.play('audio/2026/missing.m4a'),
      throwsA(isA<AudioPlaybackFailure>()),
    );

    await controller.dispose();
  });
}
