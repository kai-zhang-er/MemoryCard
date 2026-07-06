import 'package:flutter/material.dart';

import '../models/memory_record.dart';

class RecordStatusChips extends StatelessWidget {
  const RecordStatusChips({super.key, required this.record});

  final MemoryRecord record;

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[
      if (record.important)
        const _StatusChip(label: '\u91cd\u8981', icon: Icons.star),
      if (record.deleteCandidate)
        const _StatusChip(
            label: '\u5f85\u5220\u9664', icon: Icons.delete_outline),
      if (record.skipped)
        const _StatusChip(label: '\u5df2\u8df3\u8fc7', icon: Icons.skip_next),
      if (record.photoDeleted)
        const _StatusChip(
            label: '\u539f\u59cb\u7167\u7247\u5df2\u5220\u9664',
            icon: Icons.hide_image_outlined),
      if (record.audioPath != null)
        const _StatusChip(
            label: '\u6709\u5f55\u97f3\u8def\u5f84', icon: Icons.mic_none),
    ];

    if (chips.isEmpty) {
      chips.add(const _StatusChip(
          label: '\u539f\u59cb\u8bb0\u5f55', icon: Icons.note_outlined));
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
