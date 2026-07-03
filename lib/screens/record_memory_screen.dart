import 'package:flutter/material.dart';

import '../models/photo_asset.dart';
import '../utils/date_utils.dart';

class RecordMemoryScreen extends StatelessWidget {
  const RecordMemoryScreen({super.key, required this.asset});

  final PhotoAsset asset;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('讲讲')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.mic_none, size: 56),
                const SizedBox(height: 16),
                Text(
                  '录音功能将在 Task 4 接入',
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  '当前照片：${asset.assetId}\n拍摄时间：${formatNullableDate(asset.createdAt)}',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('先返回'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
