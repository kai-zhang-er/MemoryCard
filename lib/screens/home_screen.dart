import 'package:flutter/material.dart';

import '../models/memory_record.dart';
import '../services/export_service.dart';
import '../services/memory_repository.dart';
import '../services/photo_library_service.dart';
import 'memory_card_screen.dart';
import 'memory_list_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.repository,
    required this.photoLibraryServiceFactory,
    this.exportServiceFactory,
  });

  final MemoryRepository repository;
  final PhotoLibraryService Function() photoLibraryServiceFactory;
  final ExportService Function(MemoryRepository repository)?
      exportServiceFactory;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _fakeRecordCount = 0;
  bool _isSaving = false;
  bool _isExporting = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('记忆卡')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Memory Cards',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            const Text('任务一数据库验证：先用假数据确认本地记录可以写入和读取。'),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _openMemoryCard,
              icon: const Icon(Icons.play_arrow),
              label: const Text('开始一局'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _isSaving ? null : _addFakeRecord,
              icon: const Icon(Icons.add),
              label: Text(_isSaving ? '保存中...' : '添加一条假记忆'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _openList(MemoryListFilter.all),
              icon: const Icon(Icons.list_alt),
              label: const Text('查看记忆列表'),
            ),
            OutlinedButton.icon(
              onPressed: () => _openList(MemoryListFilter.important),
              icon: const Icon(Icons.star_outline),
              label: const Text('查看重要照片'),
            ),
            OutlinedButton.icon(
              onPressed: () => _openList(MemoryListFilter.deleteCandidates),
              icon: const Icon(Icons.delete_outline),
              label: const Text('查看待删除'),
            ),
            OutlinedButton.icon(
              onPressed: _isExporting ? null : _exportJson,
              icon: const Icon(Icons.file_download_outlined),
              label: Text(_isExporting ? '导出中...' : '导出 JSON'),
            ),
            const SizedBox(height: 24),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('隐私提示：只读取本地照片缩略图和元数据，不复制原图、不录音、不上传。'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addFakeRecord() async {
    setState(() => _isSaving = true);
    final now = DateTime.now();
    final nextCount = _fakeRecordCount + 1;
    final record = MemoryRecord(
      memoryId: 'fake_memory_${now.microsecondsSinceEpoch}',
      assetId: 'fake_asset_${nextCount.toString().padLeft(3, '0')}',
      assetFingerprint: 'fake_fingerprint_$nextCount',
      photoTime: now.subtract(Duration(days: 120 + nextCount)),
      createdAt: now,
      updatedAt: now,
      important: nextCount.isOdd,
      deleteCandidate: nextCount % 3 == 0,
      skipped: nextCount % 4 == 0,
      userTags: const ['假数据'],
      aiLightTags: const ['task_one_seed'],
      audioPath: nextCount % 2 == 0 ? 'audio/fake_$nextCount.m4a' : null,
    );

    try {
      await widget.repository.upsert(record);
      if (!mounted) {
        return;
      }
      setState(() => _fakeRecordCount = nextCount);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已保存 ${record.assetId}')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存失败：$error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _exportJson() async {
    setState(() => _isExporting = true);
    try {
      final service = widget.exportServiceFactory?.call(widget.repository) ??
          ExportService(widget.repository);
      final file = await service.exportMemoriesJson();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已导出：${file.path}')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导出失败：$error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  void _openMemoryCard() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MemoryCardScreen(
          photoLibraryService: widget.photoLibraryServiceFactory(),
          memoryRepository: widget.repository,
        ),
      ),
    );
  }

  void _openList(MemoryListFilter filter) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MemoryListScreen(
          repository: widget.repository,
          filter: filter,
        ),
      ),
    );
  }
}
