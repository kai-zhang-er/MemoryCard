import 'package:flutter_test/flutter_test.dart';
import 'package:memory_cards/services/recording_service.dart';

void main() {
  test('RecordingPathBuilder creates relative m4a paths', () {
    final path = RecordingPathBuilder.relativePath(
      'asset:/one two',
      DateTime.utc(2026, 7, 3, 8, 9, 10, 0, 42),
    );

    expect(path, 'audio/2026/memory_1783066150000042_asset_one_two.m4a');
  });
}
