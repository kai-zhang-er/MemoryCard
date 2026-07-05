import 'package:flutter/material.dart';

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
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => _openMemoryCard(),
              icon: const Icon(Icons.play_arrow),
              label: const Text('开始一局'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _openMemoryCard(sessionLimit: 5),
              icon: const Icon(Icons.today_outlined),
              label: const Text('今日 5 张'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _openList(MemoryListFilter.all),
              icon: const Icon(Icons.list_alt),
              label: const Text('记忆列表'),
            ),
            OutlinedButton.icon(
              onPressed: () => _openList(MemoryListFilter.important),
              icon: const Icon(Icons.star_outline),
              label: const Text('重要照片'),
            ),
            OutlinedButton.icon(
              onPressed: () => _openList(MemoryListFilter.deleteCandidates),
              icon: const Icon(Icons.delete_outline),
              label: const Text('待删除'),
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
                child: Text('照片只读显示；录音和记忆数据只保存在本机，不上传。'),
              ),
            ),
          ],
        ),
      ),
    );
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

  void _openMemoryCard({int? sessionLimit}) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MemoryCardScreen(
          photoLibraryService: widget.photoLibraryServiceFactory(),
          memoryRepository: widget.repository,
          sessionLimit: sessionLimit,
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
          photoLibraryService: widget.photoLibraryServiceFactory(),
        ),
      ),
    );
  }
}
