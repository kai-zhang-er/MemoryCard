import 'dart:convert';

class MemoryRecord {
  const MemoryRecord({
    required this.memoryId,
    required this.assetId,
    this.assetFingerprint,
    this.mediaType = 'photo',
    this.photoTime,
    required this.createdAt,
    required this.updatedAt,
    this.important = false,
    this.deleteCandidate = false,
    this.skipped = false,
    this.userTags = const [],
    this.aiLightTags = const [],
    this.promptQuestion =
        '\u8fd9\u5f20\u7167\u7247\u4f60\u8fd8\u8bb0\u5f97\u5417\uff1f',
    this.audioPath,
    this.transcript = '',
    this.memoryText = '',
    this.reviewStatus = 'raw',
  });

  final String memoryId;
  final String assetId;
  final String? assetFingerprint;
  final String mediaType;
  final DateTime? photoTime;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool important;
  final bool deleteCandidate;
  final bool skipped;
  final List<String> userTags;
  final List<String> aiLightTags;
  final String promptQuestion;
  final String? audioPath;
  final String transcript;
  final String memoryText;
  final String reviewStatus;

  MemoryRecord copyWith({
    String? memoryId,
    String? assetId,
    String? assetFingerprint,
    String? mediaType,
    DateTime? photoTime,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? important,
    bool? deleteCandidate,
    bool? skipped,
    List<String>? userTags,
    List<String>? aiLightTags,
    String? promptQuestion,
    String? audioPath,
    bool clearAudioPath = false,
    String? transcript,
    String? memoryText,
    String? reviewStatus,
  }) {
    return MemoryRecord(
      memoryId: memoryId ?? this.memoryId,
      assetId: assetId ?? this.assetId,
      assetFingerprint: assetFingerprint ?? this.assetFingerprint,
      mediaType: mediaType ?? this.mediaType,
      photoTime: photoTime ?? this.photoTime,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      important: important ?? this.important,
      deleteCandidate: deleteCandidate ?? this.deleteCandidate,
      skipped: skipped ?? this.skipped,
      userTags: userTags ?? this.userTags,
      aiLightTags: aiLightTags ?? this.aiLightTags,
      promptQuestion: promptQuestion ?? this.promptQuestion,
      audioPath: clearAudioPath ? null : audioPath ?? this.audioPath,
      transcript: transcript ?? this.transcript,
      memoryText: memoryText ?? this.memoryText,
      reviewStatus: reviewStatus ?? this.reviewStatus,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'memory_id': memoryId,
      'asset_id': assetId,
      'asset_fingerprint': assetFingerprint,
      'media_type': mediaType,
      'photo_time': photoTime?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'important': important ? 1 : 0,
      'delete_candidate': deleteCandidate ? 1 : 0,
      'skipped': skipped ? 1 : 0,
      'user_tags': jsonEncode(userTags),
      'ai_light_tags': jsonEncode(aiLightTags),
      'prompt_question': promptQuestion,
      'audio_path': audioPath,
      'transcript': transcript,
      'memory_text': memoryText,
      'review_status': reviewStatus,
    };
  }

  factory MemoryRecord.fromMap(Map<String, Object?> map) {
    return MemoryRecord(
      memoryId: map['memory_id'] as String,
      assetId: map['asset_id'] as String,
      assetFingerprint: map['asset_fingerprint'] as String?,
      mediaType: map['media_type'] as String? ?? 'photo',
      photoTime: _dateOrNull(map['photo_time']),
      createdAt: _dateOrNow(map['created_at']),
      updatedAt: _dateOrNow(map['updated_at']),
      important: _boolFromDb(map['important']),
      deleteCandidate: _boolFromDb(map['delete_candidate']),
      skipped: _boolFromDb(map['skipped']),
      userTags: _stringListFromJson(map['user_tags']),
      aiLightTags: _stringListFromJson(map['ai_light_tags']),
      promptQuestion: map['prompt_question'] as String? ??
          '\u8fd9\u5f20\u7167\u7247\u4f60\u8fd8\u8bb0\u5f97\u5417\uff1f',
      audioPath: map['audio_path'] as String?,
      transcript: map['transcript'] as String? ?? '',
      memoryText: map['memory_text'] as String? ?? '',
      reviewStatus: map['review_status'] as String? ?? 'raw',
    );
  }

  Map<String, Object?> toJson() {
    return {
      'memory_id': memoryId,
      'asset_id': assetId,
      'asset_fingerprint': assetFingerprint,
      'media_type': mediaType,
      'photo_time': photoTime?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'important': important,
      'delete_candidate': deleteCandidate,
      'skipped': skipped,
      'user_tags': userTags,
      'ai_light_tags': aiLightTags,
      'prompt_question': promptQuestion,
      'audio_path': audioPath,
      'transcript': transcript,
      'memory_text': memoryText,
      'review_status': reviewStatus,
    };
  }

  static bool _boolFromDb(Object? value) {
    if (value is bool) {
      return value;
    }
    if (value is int) {
      return value == 1;
    }
    return false;
  }

  static DateTime? _dateOrNull(Object? value) {
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  static DateTime _dateOrNow(Object? value) {
    return _dateOrNull(value) ?? DateTime.now();
  }

  static List<String> _stringListFromJson(Object? value) {
    if (value is! String || value.isEmpty) {
      return const [];
    }
    final decoded = jsonDecode(value);
    if (decoded is List) {
      return decoded.whereType<String>().toList(growable: false);
    }
    return const [];
  }
}
