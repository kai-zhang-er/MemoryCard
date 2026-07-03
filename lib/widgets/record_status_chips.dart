import 'package:flutter/material.dart';

import '../models/memory_record.dart';

class RecordStatusChips extends StatelessWidget {
  const RecordStatusChips({super.key, required this.record});

  final MemoryRecord record;

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[
      if (record.important) const _StatusChip(label: '重要', icon: Icons.star),
      if (record.deleteCandidate)
        const _StatusChip(label: '待删除', icon: Icons.delete_outline),
      if (record.skipped)
        const _StatusChip(label: '已跳过', icon: Icons.skip_next),
      if (record.audioPath != null)
        const _StatusChip(label: '有录音路径', icon: Icons.mic_none),
    ];

    if (chips.isEmpty) {
      chips.add(const _StatusChip(label: '原始记录', icon: Icons.note_outlined));
    }

    return Wrap(spacing: 8, runSpacing: 8, children: chips);
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      visualDensity: VisualDensity.compact,
    );
  }
}
