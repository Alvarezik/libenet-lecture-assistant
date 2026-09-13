import 'package:flutter/material.dart';

class TimedSegment {
  final double start;
  final String time;
  final String text;

  TimedSegment({required this.start, required this.time, required this.text});

  factory TimedSegment.fromJson(Map<String, dynamic> json) {
    return TimedSegment(
      start: (json['start'] as num?)?.toDouble() ?? 0.0,
      time: json['time'] ?? '00:00',
      text: json['text'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'start': start,
    'time': time,
    'text': text,
  };
}

class LectureModel {
  final int id;
  final int userId;
  final String title;
  final String subject;
  final String teacherName;
  final int durationSeconds;
  final String? audioFilename;
  final int fileSizeBytes;
  final String status;
  final String? errorMessage;
  final DateTime createdAt;
  final String? ownerUsername;

  // Detail fields
  final String? rawTranscript;
  final String? cleanSummary;
  final List<String> keyPoints;
  final List<Map<String, String>> flashcards;
  final List<TimedSegment> timedTranscript;
  final String detectedLanguage;
  final bool isFromOfflineCache;

  LectureModel({
    required this.id,
    required this.userId,
    required this.title,
    this.subject = '',
    this.teacherName = '',
    this.durationSeconds = 0,
    this.audioFilename,
    this.fileSizeBytes = 0,
    this.status = 'recorded',
    this.errorMessage,
    required this.createdAt,
    this.ownerUsername,
    this.rawTranscript,
    this.cleanSummary,
    this.keyPoints = const [],
    this.flashcards = const [],
    this.timedTranscript = const [],
    this.detectedLanguage = 'ru',
    this.isFromOfflineCache = false,
  });

  factory LectureModel.fromJson(Map<String, dynamic> json, {bool fromCache = false}) {
    List<String> parsedKeyPoints = [];
    if (json['key_points'] is List) {
      parsedKeyPoints = (json['key_points'] as List).map((e) => e.toString()).toList();
    }

    List<Map<String, String>> parsedFlashcards = [];
    if (json['flashcards'] is List) {
      for (var f in json['flashcards']) {
        if (f is Map) {
          parsedFlashcards.add({
            'question': f['question']?.toString() ?? '',
            'answer': f['answer']?.toString() ?? '',
          });
        }
      }
    }

    List<TimedSegment> parsedTimed = [];
    if (json['timed_transcript'] is List) {
      for (var t in json['timed_transcript']) {
        if (t is Map<String, dynamic>) {
          parsedTimed.add(TimedSegment.fromJson(t));
        } else if (t is Map) {
          parsedTimed.add(TimedSegment.fromJson(Map<String, dynamic>.from(t)));
        }
      }
    }

    DateTime parsedDate;
    try {
      parsedDate = json['created_at'] != null ? DateTime.parse(json['created_at']) : DateTime.now();
    } catch (_) {
      parsedDate = DateTime.now();
    }

    return LectureModel(
      id: json['id'] ?? 0,
      userId: json['user_id'] ?? 0,
      title: json['title'] ?? 'Без названия',
      subject: json['subject'] ?? '',
      teacherName: json['teacher_name'] ?? '',
      durationSeconds: json['duration_seconds'] ?? 0,
      audioFilename: json['audio_filename'],
      fileSizeBytes: json['file_size_bytes'] ?? 0,
      status: json['status'] ?? 'recorded',
      errorMessage: json['error_message'],
      createdAt: parsedDate,
      ownerUsername: json['owner_username'],
      rawTranscript: json['raw_transcript'],
      cleanSummary: json['clean_summary'],
      keyPoints: parsedKeyPoints,
      flashcards: parsedFlashcards,
      timedTranscript: parsedTimed,
      detectedLanguage: json['detected_language'] ?? 'ru',
      isFromOfflineCache: fromCache,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'subject': subject,
      'teacher_name': teacherName,
      'duration_seconds': durationSeconds,
      'audio_filename': audioFilename,
      'file_size_bytes': fileSizeBytes,
      'status': status,
      'error_message': errorMessage,
      'created_at': createdAt.toIso8601String(),
      'owner_username': ownerUsername,
      'raw_transcript': rawTranscript,
      'clean_summary': cleanSummary,
      'key_points': keyPoints,
      'flashcards': flashcards,
      'timed_transcript': timedTranscript.map((t) => t.toJson()).toList(),
      'detected_language': detectedLanguage,
    };
  }

  
  bool get hasSummary => (cleanSummary != null && cleanSummary!.isNotEmpty);
  bool get hasTranscript => (rawTranscript != null && rawTranscript!.isNotEmpty);

  String get formattedDuration {
    final m = durationSeconds ~/ 60;
    final s = durationSeconds % 60;
    return '$m мин $s сек';
  }

  String get formattedFileSize {
    if (fileSizeBytes <= 0) return '0 MB';
    return '${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String get statusText {
    switch (status) {
      case 'completed':
        return 'Готов (AI)';
      case 'transcribed':
        return 'Транскрибировано';
      case 'transcribing':
        return 'Распознавание...';
      case 'summarizing':
        return 'Обработка AI...';
      case 'recorded':
        return 'Записано';
      case 'error':
        return 'Ошибка';
      default:
        return status;
    }
  }

  Color get statusColor {
    switch (status) {
      case 'completed':
        return const Color(0xFF10B981); // Emerald
      case 'transcribed':
        return const Color(0xFF06B6D4); // Cyan
      case 'transcribing':
      case 'summarizing':
        return const Color(0xFFF59E0B); // Amber
      case 'recorded':
        return const Color(0xFF6366F1); // Indigo
      case 'error':
        return const Color(0xFFEF4444); // Red
      default:
        return const Color(0xFF94A3B8);
    }
  }
}
