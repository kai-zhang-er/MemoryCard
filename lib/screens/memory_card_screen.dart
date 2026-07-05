import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/photo_asset.dart';
import '../services/memory_action_service.dart';
import '../services/memory_repository.dart';
import '../services/photo_library_service.dart';
import '../services/prompt_question_service.dart';
import '../services/recording_service.dart';
import '../services/weighted_random_service.dart';
import '../utils/date_utils.dart';
import '../widgets/action_buttons.dart';
import '../widgets/adaptive_photo_card.dart';
import 'record_memory_screen.dart';

class MemoryCardScreen extends StatefulWidget {
  MemoryCardScreen({
    super.key,
    required this.photoLibraryService,
    required this.memoryRepository,
    this.sessionLimit,
    RecordingService Function()? recordingServiceFactory,
    this.processedAssetIdsLoader,
    this.weightedRandomService = const WeightedRandomService(),
    this.promptQuestionService = const PromptQuestionService(),
    Random? random,
  })  : recordingServiceFactory =
            recordingServiceFactory ?? (() => RecordRecordingService()),
        random = random ?? Random();

  final PhotoLibraryService photoLibraryService;
  final MemoryRepository memoryRepository;
  final int? sessionLimit;
  final RecordingService Function() recordingServiceFactory;
  final Future<Set<String>> Function()? processedAssetIdsLoader;
  final WeightedRandomService weightedRandomService;
  final PromptQuestionService promptQuestionService;
  final Random random;

  @override
  State<MemoryCardScreen> createState() => _MemoryCardScreenState();
}

class _MemoryCardScreenState extends State<MemoryCardScreen> {
  static const List<String> _quickTags = [
    '旅行',
    '家人',
    '朋友',
    '聚会',
    '学校',
    '工作',
    '日常',
    '美食',
    '风景',
    '不确定',
  ];

  MemoryCardState _state = MemoryCardState.loading;
  PhotoPermissionResult? _permission;
  List<PhotoAsset> _assets = const [];
  Set<String> _processedAssetIds = const {};
  Set<String> _sessionShownAssetIds = const {};
  Set<String> _selectedTags = const {};
  PhotoAsset? _currentAsset;
  Uint8List? _thumbnailBytes;
  String? _currentPromptQuestion;
  String? _errorMessage;
  bool _isSavingAction = false;
  bool _isSavingTags = false;
  SessionSummary _sessionSummary = const SessionSummary();

  bool get _usesFolderSelection =>
      widget.photoLibraryService is WindowsFolderPhotoLibraryService;

  bool get _hasReachedSessionLimit {
    final limit = widget.sessionLimit;
    return limit != null && _sessionShownAssetIds.length >= limit;
  }

  String get _completionTitle {
    return widget.sessionLimit == null ? '这轮照片看完了' : '今日 5 张完成了';
  }

  String get _completionMessage {
    return widget.sessionLimit == null
        ? '没有更多未处理的照片可显示。'
        : '今天已经看过 5 张照片，可以先休息一下。';
  }

  String get _emptyStateMessage {
    if (_permission == PhotoPermissionResult.limited) {
      return '当前只授权了部分照片，但没有可显示的图片。';
    }
    if (_usesFolderSelection) {
      return '所选文件夹里没有找到可显示的图片。';
    }
    return '相册里暂时没有找到图片。';
  }

  @override
  void initState() {
    super.initState();
    _loadLibrary();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar:
          AppBar(title: Text(widget.sessionLimit == null ? '开始一局' : '今日 5 张')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: switch (_state) {
            MemoryCardState.loading => const _CenteredMessage(
                icon: Icons.photo_library_outlined,
                title: '正在读取本地照片',
                message: '只读取缩略图和元数据，不保存原始照片。',
                showProgress: true,
              ),
            MemoryCardState.permissionDenied => _PermissionDeniedView(
                permission: _permission,
                onRetry: _loadLibrary,
                onOpenSettings: widget.photoLibraryService.openSettings,
              ),
            MemoryCardState.empty => _CenteredMessage(
                icon: Icons.image_not_supported_outlined,
                title: '没有可用照片',
                message: _emptyStateMessage,
                actionLabel: _usesFolderSelection ? '重新选择文件夹' : null,
                onAction: _usesFolderSelection ? _changePhotoSource : null,
              ),
            MemoryCardState.sessionComplete => _CompletionView(
                title: _completionTitle,
                message: _completionMessage,
                summary: _sessionSummary,
                onDone: () => Navigator.of(context).maybePop(),
              ),
            MemoryCardState.thumbnailFailed => _CenteredMessage(
                icon: Icons.broken_image_outlined,
                title: '缩略图加载失败',
                message: _errorMessage ?? '这张照片暂时无法显示，请换一张。',
                actionLabel: '换一张',
                onAction: _pickRandomPhoto,
              ),
            MemoryCardState.loaded => _LoadedPhotoView(
                asset: _currentAsset!,
                thumbnailBytes: _thumbnailBytes!,
                isLimited: _permission == PhotoPermissionResult.limited,
                isSavingAction: _isSavingAction,
                isSavingTags: _isSavingTags,
                promptQuestion: _currentPromptQuestion!,
                selectedTags: _selectedTags,
                quickTags: _quickTags,
                onTagSelected: _toggleTag,
                onSaveTags: _saveSelectedTags,
                onTalk: _openRecordPlaceholder,
                onMarkImportant: () =>
                    _saveAction(MemoryRecordAction.important),
                onMarkDeleteCandidate: () =>
                    _saveAction(MemoryRecordAction.deleteCandidate),
                onSkip: () => _saveAction(MemoryRecordAction.skipped),
              ),
          },
        ),
      ),
    );
  }

  Future<void> _loadLibrary() async {
    setState(() {
      _state = MemoryCardState.loading;
      _errorMessage = null;
      _sessionShownAssetIds = const {};
      _selectedTags = const {};
      _sessionSummary = const SessionSummary();
    });

    try {
      final permission = await widget.photoLibraryService.requestPermission();
      _permission = permission;
      if (!permission.canAccessPhotos) {
        if (!mounted) {
          return;
        }
        setState(() => _state = MemoryCardState.permissionDenied);
        return;
      }

      final assets = await widget.photoLibraryService.getPhotoAssets();
      if (!mounted) {
        return;
      }
      if (assets.isEmpty) {
        setState(() {
          _assets = const [];
          _state = MemoryCardState.empty;
        });
        return;
      }

      _assets = assets;
      await _refreshProcessedAssetIds();
      await _pickRandomPhoto();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = error.toString();
        _state = MemoryCardState.thumbnailFailed;
      });
    }
  }

  Future<void> _changePhotoSource() async {
    await widget.photoLibraryService.openSettings();
    await _loadLibrary();
  }

  Future<void> _pickRandomPhoto() async {
    if (_assets.isEmpty) {
      if (!mounted) {
        return;
      }
      setState(() => _state = MemoryCardState.empty);
      return;
    }

    if (_hasReachedSessionLimit) {
      _completeSession();
      return;
    }

    final excludedAssetIds = <String>{
      ..._processedAssetIds,
      ..._sessionShownAssetIds,
    };
    final candidates = _assets
        .where((asset) => !excludedAssetIds.contains(asset.assetId))
        .toList(growable: false);
    if (candidates.isEmpty) {
      _completeSession();
      return;
    }

    setState(() {
      _state = MemoryCardState.loading;
      _errorMessage = null;
      _isSavingAction = false;
      _isSavingTags = false;
    });

    final asset = widget.weightedRandomService.pickPhoto(
      candidates,
      random: widget.random,
    );
    if (asset == null) {
      _completeSession();
      return;
    }

    try {
      final thumbnail =
          await widget.photoLibraryService.getThumbnail(asset.assetId);
      if (!mounted) {
        return;
      }
      if (thumbnail == null || thumbnail.isEmpty) {
        setState(() {
          _currentAsset = asset;
          _thumbnailBytes = null;
          _errorMessage = '没有拿到可显示的缩略图。';
          _state = MemoryCardState.thumbnailFailed;
        });
        return;
      }

      setState(() {
        _currentAsset = asset;
        _thumbnailBytes = thumbnail;
        _currentPromptQuestion = widget.promptQuestionService.questionForPhoto(
          asset.assetId,
          random: widget.random,
        );
        _selectedTags = const {};
        _sessionShownAssetIds = {
          ..._sessionShownAssetIds,
          asset.assetId,
        };
        _sessionSummary = _sessionSummary.copyWith(
          shownCount: _sessionSummary.shownCount + 1,
        );
        _state = MemoryCardState.loaded;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _currentAsset = asset;
        _thumbnailBytes = null;
        _errorMessage = error.toString();
        _state = MemoryCardState.thumbnailFailed;
      });
    }
  }

  void _completeSession() {
    if (!mounted) {
      return;
    }
    setState(() {
      _currentAsset = null;
      _thumbnailBytes = null;
      _selectedTags = const {};
      _isSavingAction = false;
      _isSavingTags = false;
      _state = MemoryCardState.sessionComplete;
    });
  }

  Future<void> _saveAction(MemoryRecordAction action) async {
    final asset = _currentAsset;
    final promptQuestion = _currentPromptQuestion;
    if (asset == null || promptQuestion == null || _isSavingAction) {
      return;
    }

    setState(() => _isSavingAction = true);
    try {
      await MemoryActionService(widget.memoryRepository).saveAction(
        asset,
        action,
        promptQuestion: promptQuestion,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _sessionSummary = switch (action) {
          MemoryRecordAction.important => _sessionSummary.copyWith(
              importantCount: _sessionSummary.importantCount + 1,
            ),
          MemoryRecordAction.deleteCandidate => _sessionSummary.copyWith(
              deleteCandidateCount: _sessionSummary.deleteCandidateCount + 1,
            ),
          MemoryRecordAction.skipped => _sessionSummary.copyWith(
              skippedCount: _sessionSummary.skippedCount + 1,
            ),
        };
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${action.confirmationText}，已保存')),
      );
      await _refreshProcessedAssetIds();
      await _pickRandomPhoto();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _isSavingAction = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存失败：$error')),
      );
    }
  }

  Future<void> _saveSelectedTags() async {
    final asset = _currentAsset;
    final promptQuestion = _currentPromptQuestion;
    if (asset == null ||
        promptQuestion == null ||
        _selectedTags.isEmpty ||
        _isSavingTags) {
      return;
    }

    setState(() => _isSavingTags = true);
    try {
      await MemoryActionService(widget.memoryRepository).saveTags(
        asset,
        _selectedTags.toList(growable: false),
        promptQuestion: promptQuestion,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _isSavingTags = false;
        _sessionSummary = _sessionSummary.copyWith(
          taggedCount: _sessionSummary.taggedCount + 1,
        );
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('标签已保存')),
      );
      await _refreshProcessedAssetIds();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _isSavingTags = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存标签失败：$error')),
      );
    }
  }

  void _toggleTag(String tag, bool selected) {
    setState(() {
      final updated = {..._selectedTags};
      if (selected) {
        updated.add(tag);
      } else {
        updated.remove(tag);
      }
      _selectedTags = updated;
    });
  }

  Future<void> _openRecordPlaceholder() async {
    final asset = _currentAsset;
    final promptQuestion = _currentPromptQuestion;
    if (asset == null || promptQuestion == null) {
      return;
    }
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => RecordMemoryScreen(
          asset: asset,
          memoryRepository: widget.memoryRepository,
          recordingService: widget.recordingServiceFactory(),
          thumbnailBytes: _thumbnailBytes,
          promptQuestion: promptQuestion,
        ),
      ),
    );
    if (!mounted || saved != true) {
      return;
    }
    setState(() {
      _sessionSummary = _sessionSummary.copyWith(
        recordedCount: _sessionSummary.recordedCount + 1,
      );
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('录音已保存')),
    );
    await _refreshProcessedAssetIds();
    await _pickRandomPhoto();
  }

  Future<void> _refreshProcessedAssetIds() async {
    final loader = widget.processedAssetIdsLoader;
    if (loader != null) {
      _processedAssetIds = await loader();
      return;
    }

    final records = await widget.memoryRepository.getAll();
    _processedAssetIds = records.map((record) => record.assetId).toSet();
  }
}

enum MemoryCardState {
  loading,
  permissionDenied,
  empty,
  sessionComplete,
  thumbnailFailed,
  loaded,
}

class SessionSummary {
  const SessionSummary({
    this.shownCount = 0,
    this.recordedCount = 0,
    this.importantCount = 0,
    this.deleteCandidateCount = 0,
    this.skippedCount = 0,
    this.taggedCount = 0,
  });

  final int shownCount;
  final int recordedCount;
  final int importantCount;
  final int deleteCandidateCount;
  final int skippedCount;
  final int taggedCount;

  SessionSummary copyWith({
    int? shownCount,
    int? recordedCount,
    int? importantCount,
    int? deleteCandidateCount,
    int? skippedCount,
    int? taggedCount,
  }) {
    return SessionSummary(
      shownCount: shownCount ?? this.shownCount,
      recordedCount: recordedCount ?? this.recordedCount,
      importantCount: importantCount ?? this.importantCount,
      deleteCandidateCount: deleteCandidateCount ?? this.deleteCandidateCount,
      skippedCount: skippedCount ?? this.skippedCount,
      taggedCount: taggedCount ?? this.taggedCount,
    );
  }
}

class _LoadedPhotoView extends StatelessWidget {
  const _LoadedPhotoView({
    required this.asset,
    required this.thumbnailBytes,
    required this.isLimited,
    required this.isSavingAction,
    required this.isSavingTags,
    required this.promptQuestion,
    required this.selectedTags,
    required this.quickTags,
    required this.onTagSelected,
    required this.onSaveTags,
    required this.onTalk,
    required this.onMarkImportant,
    required this.onMarkDeleteCandidate,
    required this.onSkip,
  });

  final PhotoAsset asset;
  final Uint8List thumbnailBytes;
  final bool isLimited;
  final bool isSavingAction;
  final bool isSavingTags;
  final String promptQuestion;
  final Set<String> selectedTags;
  final List<String> quickTags;
  final void Function(String tag, bool selected) onTagSelected;
  final VoidCallback onSaveTags;
  final VoidCallback onTalk;
  final VoidCallback onMarkImportant;
  final VoidCallback onMarkDeleteCandidate;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final actionHandler = isSavingAction ? null : onTalk;
    return LayoutBuilder(
      builder: (context, constraints) {
        final windowHeight = MediaQuery.sizeOf(context).height;
        final availableHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : windowHeight;
        final maxPhotoHeight = availableHeight * 0.48;

        return ListView(
          children: [
            AdaptivePhotoCard(
              imageBytes: thumbnailBytes,
              imageWidth: asset.width,
              imageHeight: asset.height,
              maxHeight: maxPhotoHeight,
            ),
            const SizedBox(height: 16),
            Text(
              promptQuestion,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              '拍摄时间：${formatNullableDate(asset.createdAt)}',
              textAlign: TextAlign.center,
            ),
            if (asset.title != null && asset.title!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                asset.title!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                for (final tag in quickTags)
                  FilterChip(
                    label: Text(tag),
                    selected: selectedTags.contains(tag),
                    onSelected: (selected) => onTagSelected(tag, selected),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Center(
              child: OutlinedButton.icon(
                onPressed:
                    selectedTags.isEmpty || isSavingTags ? null : onSaveTags,
                icon: const Icon(Icons.sell_outlined),
                label: Text(isSavingTags ? '保存中...' : '保存标签'),
              ),
            ),
            const SizedBox(height: 20),
            ActionButtons(
              children: [
                FilledButton.icon(
                  onPressed: actionHandler,
                  icon: const Icon(Icons.mic_none),
                  label: const Text('讲讲'),
                ),
                OutlinedButton.icon(
                  onPressed: isSavingAction ? null : onMarkImportant,
                  icon: const Icon(Icons.star_outline),
                  label: const Text('重要'),
                ),
                OutlinedButton.icon(
                  onPressed: isSavingAction ? null : onMarkDeleteCandidate,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('待删除'),
                ),
                TextButton.icon(
                  onPressed: isSavingAction ? null : onSkip,
                  icon: const Icon(Icons.skip_next),
                  label: const Text('跳过'),
                ),
              ],
            ),
            if (isSavingAction) ...[
              const SizedBox(height: 16),
              const Center(child: CircularProgressIndicator()),
            ],
            const SizedBox(height: 12),
            Text(
              isLimited ? '当前是有限相册授权，只会显示你允许访问的照片。' : '照片只读显示，不会复制、修改、删除或上传。',
              textAlign: TextAlign.center,
            ),
          ],
        );
      },
    );
  }
}

class _CompletionView extends StatelessWidget {
  const _CompletionView({
    required this.title,
    required this.message,
    required this.summary,
    required this.onDone,
  });

  final String title;
  final String message;
  final SessionSummary summary;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ListView(
        shrinkWrap: true,
        children: [
          const Icon(Icons.check_circle_outline, size: 48),
          const SizedBox(height: 16),
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _SummaryChip(label: '看过 ${summary.shownCount} 张'),
              _SummaryChip(label: '录音 ${summary.recordedCount} 段'),
              _SummaryChip(label: '重要 ${summary.importantCount} 张'),
              _SummaryChip(label: '待删除 ${summary.deleteCandidateCount} 张'),
              _SummaryChip(label: '跳过 ${summary.skippedCount} 张'),
              _SummaryChip(label: '标签 ${summary.taggedCount} 张'),
            ],
          ),
          const SizedBox(height: 20),
          Center(
            child: FilledButton(
              onPressed: onDone,
              child: const Text('返回首页'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(label: Text(label));
  }
}

class _PermissionDeniedView extends StatelessWidget {
  const _PermissionDeniedView({
    required this.permission,
    required this.onRetry,
    required this.onOpenSettings,
  });

  final PhotoPermissionResult? permission;
  final VoidCallback onRetry;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final folderRequired = permission?.requiresFolderSelection ?? false;
    return _CenteredMessage(
      icon: folderRequired ? Icons.folder_open_outlined : Icons.lock_outline,
      title: folderRequired ? '请选择照片文件夹' : '需要相册权限',
      message: folderRequired
          ? 'Memory Cards 会只读扫描你选择的本地文件夹，不复制、修改、删除或上传照片。'
          : 'Memory Cards 只读取本地照片缩略图和拍摄时间，用来展示记忆卡。',
      actionLabel: folderRequired ? '选择文件夹' : '重新请求',
      onAction: onRetry,
      secondaryActionLabel: folderRequired ? null : '打开设置',
      onSecondaryAction: folderRequired ? null : onOpenSettings,
    );
  }
}

class _CenteredMessage extends StatelessWidget {
  const _CenteredMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.showProgress = false,
    this.actionLabel,
    this.onAction,
    this.secondaryActionLabel,
    this.onSecondaryAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final bool showProgress;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48),
          const SizedBox(height: 16),
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center),
          if (showProgress) ...[
            const SizedBox(height: 20),
            const CircularProgressIndicator(),
          ],
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 20),
            FilledButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
          if (secondaryActionLabel != null && onSecondaryAction != null) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: onSecondaryAction,
              child: Text(secondaryActionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}
