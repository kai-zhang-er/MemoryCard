import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_cards/models/memory_record.dart';
import 'package:memory_cards/widgets/record_status_chips.dart';

void main() {
  testWidgets('RecordStatusChips shows saved record states', (tester) async {
    final now = DateTime.utc(2026, 7, 3);
    final record = MemoryRecord(
      memoryId: 'memory_widget_001',
      assetId: 'fake_asset_001',
      createdAt: now,
      updatedAt: now,
      important: true,
      deleteCandidate: true,
      skipped: true,
      audioPath: 'audio/fake.m4a',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: RecordStatusChips(record: record)),
      ),
    );

    expect(find.text('重要'), findsOneWidget);
    expect(find.text('待删除'), findsOneWidget);
    expect(find.text('已跳过'), findsOneWidget);
    expect(find.text('有录音路径'), findsOneWidget);
  });
}
