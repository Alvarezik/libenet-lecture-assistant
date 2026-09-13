import '../../providers/auth_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/audio_recorder_service.dart';
import '../../core/services/notification_service.dart';
import '../../providers/lecture_provider.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/glass_container.dart';
import '../../widgets/waveform_visualizer.dart';
import '../lectures/lecture_detail_screen.dart';

class RecordLectureScreen extends StatefulWidget {
  const RecordLectureScreen({super.key});

  @override
  State<RecordLectureScreen> createState() => _RecordLectureScreenState();
}

class _RecordLectureScreenState extends State<RecordLectureScreen> {
  int? _getCurrentUserId() {
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      return auth.user?.id;
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveDraft() async {
    final userId = _getCurrentUserId();
    if (_recordedPath == null || userId == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('draft_audio_path_$userId', _recordedPath!);
      if (_pickedFileName != null) {
        await prefs.setString('draft_file_name_$userId', _pickedFileName!);
      }
      await prefs.setString('draft_title_$userId', _titleController.text);
      await prefs.setString('draft_subject_$userId', _subjectController.text);
      await prefs.setString('draft_teacher_$userId', _teacherController.text);
      await prefs.setInt('draft_seconds_$userId', _seconds);
      await prefs.setBool('draft_is_custom_$userId', _isCustomUploadedAudio);
    } catch (_) {}
  }

  String? _pendingDraftPath;
  String? _pendingDraftFileName;
  String? _pendingDraftTitle;
  String? _pendingDraftSubject;
  String? _pendingDraftTeacher;
  int _pendingDraftSeconds = 0;
  bool _pendingDraftIsCustom = false;
  bool _hasPendingDraft = false;

  Future<void> _checkPendingDraft() async {
    final userId = _getCurrentUserId();
    if (userId == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final path = prefs.getString('draft_audio_path_$userId');
      final fileName = prefs.getString('draft_file_name_$userId');
      final title = prefs.getString('draft_title_$userId');
      final subject = prefs.getString('draft_subject_$userId');
      final teacher = prefs.getString('draft_teacher_$userId');
      final seconds = prefs.getInt('draft_seconds_$userId') ?? 0;
      final isCustom = prefs.getBool('draft_is_custom_$userId') ?? false;

      if (path != null && path.isNotEmpty) {
        final f = File(path);
        if (await f.exists() && await f.length() > 1024 && seconds > 2) {
          if (mounted) {
            setState(() {
              _hasPendingDraft = true;
              _pendingDraftPath = path;
              _pendingDraftFileName = fileName;
              _pendingDraftTitle = title;
              _pendingDraftSubject = subject;
              _pendingDraftTeacher = teacher;
              _pendingDraftSeconds = seconds;
              _pendingDraftIsCustom = isCustom;
            });
          }
          return;
        }
      }
      await _clearDraft(silent: true);
    } catch (_) {}
  }

  Future<void> _restoreDraft() async {
    if (!_hasPendingDraft || _pendingDraftPath == null) return;
    final path = _pendingDraftPath!;
    final f = File(path);
    if (!await f.exists()) {
      await _clearDraft(silent: true);
      return;
    }

    setState(() {
      _recordedPath = path;
      _pickedFileName = _pendingDraftFileName;
      _isCustomUploadedAudio = _pendingDraftIsCustom;
      _seconds = _pendingDraftSeconds;
      if (_pendingDraftTitle != null) _titleController.text = _pendingDraftTitle!;
      if (_pendingDraftSubject != null) _subjectController.text = _pendingDraftSubject!;
      if (_pendingDraftTeacher != null) _teacherController.text = _pendingDraftTeacher!;
      _hasPendingDraft = false;
    });

    try {
      await _player.setSource(DeviceFileSource(path));
      final dur = await _player.getDuration();
      if (dur != null && dur.inSeconds > 0) {
        setState(() {
          _playbackDuration = dur;
          if (_seconds == 0) _seconds = dur.inSeconds;
        });
      }
    } catch (_) {}

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.cyan,
          content: Text(
            'Черновик восстановлен (${_formatTime(_seconds)})',
            style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _clearDraft({bool silent = false}) async {
    final userId = _getCurrentUserId();
    if (userId != null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('draft_audio_path_$userId');
        await prefs.remove('draft_file_name_$userId');
        await prefs.remove('draft_title_$userId');
        await prefs.remove('draft_subject_$userId');
        await prefs.remove('draft_teacher_$userId');
        await prefs.remove('draft_seconds_$userId');
        await prefs.remove('draft_is_custom_$userId');
      } catch (_) {}
    }
    if (mounted) {
      setState(() {
        _hasPendingDraft = false;
        _pendingDraftPath = null;
        _pendingDraftFileName = null;
        _pendingDraftTitle = null;
        _pendingDraftSubject = null;
        _pendingDraftTeacher = null;
        _pendingDraftSeconds = 0;
        _pendingDraftIsCustom = false;
      });
      if (!silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFF334155),
            content: Text('Черновик удален'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  final AudioRecorderService _recorder = AudioRecorderService();
  final AudioPlayer _player = AudioPlayer();

  final _titleController = TextEditingController();
  final _subjectController = TextEditingController();
  final _teacherController = TextEditingController();

  double _currentAmplitude = 0.05;
  int _seconds = 0;
  String? _recordedPath;
  String? _pickedFileName;
  bool _isCustomUploadedAudio = false;

  bool _isPlaying = false;
  Duration _playbackPosition = Duration.zero;
  Duration _playbackDuration = Duration.zero;

  bool _isProcessing = false;
  String _processStep = '';
  double _processProgress = 0.0;

  StreamSubscription<int>? _durationSub;
  StreamSubscription<double>? _amplitudeSub;
  StreamSubscription<PlayerState>? _playerStateSub;
  StreamSubscription<Duration>? _playerPosSub;
  StreamSubscription<Duration>? _playerDurSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkPendingDraft());
    _durationSub = _recorder.durationStream.listen((sec) {
      if (mounted) setState(() => _seconds = sec);
    });
    _amplitudeSub = _recorder.amplitudeStream.listen((amp) {
      if (mounted) setState(() => _currentAmplitude = amp);
    });

    _playerStateSub = _player.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _isPlaying = state == PlayerState.playing);
    });
    _playerPosSub = _player.onPositionChanged.listen((pos) {
      if (mounted) setState(() => _playbackPosition = pos);
    });
    _playerDurSub = _player.onDurationChanged.listen((dur) {
      if (mounted) {
        setState(() {
          _playbackDuration = dur;
          if (_isCustomUploadedAudio && dur.inSeconds > 0) {
            _seconds = dur.inSeconds;
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _durationSub?.cancel();
    _amplitudeSub?.cancel();
    _playerStateSub?.cancel();
    _playerPosSub?.cancel();
    _playerDurSub?.cancel();
    _recorder.dispose();
    _player.dispose();
    _titleController.dispose();
    _subjectController.dispose();
    _teacherController.dispose();
    super.dispose();
  }

  String _formatTime(int sec) {
    final m = (sec ~/ 60).toString().padLeft(2, '0');
    final s = (sec % 60).toString().padLeft(2, '0');
    final h = (sec ~/ 3600);
    if (h > 0) return '$h:$m:$s';
    return '$m:$s';
  }

  void _toggleRecord() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (!auth.isAdmin && auth.user?.canTranscribe == false) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppTheme.error,
          content: Text('Администратор ограничил доступ к транскрибации для вашего аккаунта'),
        ),
      );
      return;
    }
    await _player.stop();
    if (!_recorder.isRecording) {
      await _clearDraft(silent: true);
      setState(() {
        _recordedPath = null;
        _isCustomUploadedAudio = false;
        _pickedFileName = null;
      });
      final ok = await _recorder.startRecording();
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppTheme.error,
            content: Text('Предоставьте разрешение на микрофон в настройках'),
          ),
        );
      }
      setState(() {});
    } else if (_recorder.isPaused) {
      await _recorder.resumeRecording();
      setState(() {});
    } else {
      await _recorder.pauseRecording();
      setState(() {});
    }
  }

  void _stopRecording() async {
    final path = await _recorder.stopRecording();
      if (path != null) { _recordedPath = path; await _saveDraft(); }
    setState(() {
      _recordedPath = path;
      _isCustomUploadedAudio = false;
    });
    if (path != null) {
      try {
        await _player.setSource(DeviceFileSource(path));
      } catch (_) {}
    }
  }

  Future<void> _pickAudioFile() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (!auth.isAdmin && auth.user?.canTranscribe == false) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppTheme.error,
          content: Text('Администратор ограничил доступ к транскрибации для вашего аккаунта'),
        ),
      );
      return;
    }
    try {
      await _player.stop();
      if (_recorder.isRecording) {
        await _recorder.cancelAndDiscard();
      }

      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['m4a', 'mp3', 'wav', 'aac', 'ogg', 'opus', 'mp4', 'm4v'],
      );

      if (result != null && result.files.single.path != null) {
        final path = result.files.single.path!;
        final name = result.files.single.name;
        final sizeBytes = result.files.single.size;

        if (sizeBytes > 300 * 1024 * 1024) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                backgroundColor: AppTheme.warning,
                content: Text('Файл превышает 300 МБ. Рекомендуется сжатие.'),
              ),
            );
          }
        }

        // Pre-fill title from filename
        final baseName = name.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '');
        if (_titleController.text.trim().isEmpty) {
          _titleController.text = baseName;
        }

        setState(() {
          _recordedPath = path;
          _pickedFileName = name;
          _isCustomUploadedAudio = true;
          _playbackPosition = Duration.zero;
          _playbackDuration = Duration.zero;
        });
        await _saveDraft();

        await _player.setSource(DeviceFileSource(path));
        final dur = await _player.getDuration();
        if (dur != null && dur.inSeconds > 0) {
          setState(() {
            _playbackDuration = dur;
            _seconds = dur.inSeconds;
          });
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppTheme.success,
              content: Text('Аудиофайл выбран: $name'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: AppTheme.error, content: Text('Ошибка выбора аудио: $e')),
        );
      }
    }
  }

  void _resetRecording() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161F30),
        title: const Text('Сбросить запись?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(
          _isCustomUploadedAudio
              ? 'Убрать выбранный аудиофайл?'
              : 'Текущая аудиозапись будет удалена. Начать запись заново?',
          style: const TextStyle(color: Color(0xFF94A3B8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Отмена', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Сбросить', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _player.stop();
      if (!_isCustomUploadedAudio) {
        await _recorder.cancelAndDiscard();
      }
      await _clearDraft();
      setState(() {
        _recordedPath = null;
        _pickedFileName = null;
        _isCustomUploadedAudio = false;
        _seconds = 0;
        _playbackPosition = Duration.zero;
        _playbackDuration = Duration.zero;
      });
    }
  }

  void _playPauseReview() async {
    if (_recordedPath == null) return;
    try {
      if (_isPlaying) {
        await _player.pause();
      } else {
        await _player.play(DeviceFileSource(_recordedPath!));
      }
    } catch (e) {
      debugPrint('Player play error: $e');
    }
  }

  void _seekRelative(int seconds) async {
    final current = _playbackPosition.inSeconds;
    final total = _playbackDuration.inSeconds > 0 ? _playbackDuration.inSeconds : _seconds;
    final next = (current + seconds).clamp(0, total);
    await _player.seek(Duration(seconds: next));
  }

  void _executeProcessing({required bool autoSummarize}) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final lectureProvider = Provider.of<LectureProvider>(context, listen: false);

    if (_recordedPath == null && _recorder.isRecording) {
      _recordedPath = await _recorder.stopRecording();
    }

    if (_recordedPath == null) {
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('Сначала сделайте запись или выберите файл')),
      );
      return;
    }

    await _player.stop();

    String title = _titleController.text.trim();
    if (title.isEmpty) {
      final now = DateTime.now();
      title = 'Лекция ${now.day}.${now.month.toString().padLeft(2, '0')} (${_formatTime(_seconds)})';
    }

    setState(() {
      _isProcessing = true;
      _processStep = autoSummarize ? '1/3 Загрузка аудио на сервер...' : '1/2 Загрузка аудиозаписи...';
      _processProgress = 0.25;
    });

    try {
      // Step 1: Upload (safe against network drops)
      final lectureId = await lectureProvider.createLectureAndUpload(
        title: title,
        subject: _subjectController.text.trim(),
        teacherName: _teacherController.text.trim(),
        audioFilePath: _recordedPath!,
        durationSeconds: _seconds,
      );

      if (!mounted) return;
      setState(() {
        _processStep = autoSummarize
            ? '2/3 Распознавание русской речи Gladia AI / Deepgram...'
            : '2/2 Распознавание речи...';
        _processProgress = 0.65;
      });

      // Step 2: Transcription
      await lectureProvider.transcribeLecture(lectureId, language: 'ru', localFilePath: _recordedPath);

      if (autoSummarize) {
        if (!mounted) return;
        setState(() {
          _processStep = '3/3 LibeNet AI: создание академического конспекта...';
          _processProgress = 0.90;
        });

        // Step 3: Summarization
        await lectureProvider.summarizeLecture(lectureId);
      }

      await NotificationService.showLectureReadyNotification(
        lectureId: lectureId,
        lectureTitle: title,
      );

      // Successfully uploaded & processed -> Safely delete temporary local recorded audio
      if (!_isCustomUploadedAudio && _recordedPath != null) {
        try {
          final file = File(_recordedPath!);
          if (await file.exists()) {
            await file.delete();
          }
        } catch (_) {}
      }

      await _clearDraft();
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _processProgress = 1.0;
        _recordedPath = null;
        _pickedFileName = null;
        _isCustomUploadedAudio = false;
        _seconds = 0;
        _titleController.clear();
        _subjectController.clear();
        _teacherController.clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.success,
          content: Text(autoSummarize ? 'Конспект и карточки готовы!' : 'Транскрипция успешно завершена!'),
        ),
      );

      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => LectureDetailScreen(lectureId: lectureId)),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF161F30),
            title: const Text('Сбой отправки', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            content: Text(
              'Ошибка при обработке лекции: $e\n\nВаш аудиофайл сохранен и защищен! Вы можете повторить отправку прямо сейчас без потери записи.',
              style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 13),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Закрыть', style: TextStyle(color: Color(0xFF64748B))),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _executeProcessing(autoSummarize: autoSummarize);
                },
                child: const Text('Повторить отправку'),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRec = _recorder.isRecording;
    final isPaused = _recorder.isPaused;
    final hasRecording = _recordedPath != null;
    final totalSec = _playbackDuration.inSeconds > 0 ? _playbackDuration.inSeconds : _seconds;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset('assets/images/logo.png', width: 28, height: 28, fit: BoxFit.contain),
            ),
            const SizedBox(width: 10),
            const Text('Студия записи & Загрузки', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Pending Draft Banner (if user has unfinished recording)
              if (_hasPendingDraft && _recordedPath == null && !isRec) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.cyan.withOpacity(0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.history_toggle_off_rounded, color: AppTheme.cyan, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Несохраненный черновик',
                              style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              '${_pendingDraftTitle?.isNotEmpty == true ? _pendingDraftTitle : "Запись"} (${_formatTime(_pendingDraftSeconds)})',
                              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          backgroundColor: AppTheme.cyan.withOpacity(0.15),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: _restoreDraft,
                        child: const Text('Восстановить', style: TextStyle(color: AppTheme.cyan, fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 6),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8), size: 18),
                        onPressed: () => _clearDraft(),
                        tooltip: 'Удалить черновик',
                      ),
                    ],
                  ),
                ),
              ],
              // Visual Studio Card
              GlassContainer(
                padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 20),
                borderRadius: 26,
                backgroundColor: isRec && !isPaused
                    ? const Color(0xFF1E1E38)
                    : const Color(0xFF161F30),
                child: Column(
                  children: [
                    // Timer Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isRec
                              ? (isPaused ? AppTheme.warning : AppTheme.error)
                              : const Color(0x33475569),
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isRec && !isPaused)
                            Container(
                              width: 10,
                              height: 10,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: const BoxDecoration(
                                color: AppTheme.error,
                                shape: BoxShape.circle,
                              ),
                            ),
                          Text(
                            _formatTime(_seconds),
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    WaveformVisualizer(
                      amplitude: _currentAmplitude,
                      isRecording: isRec,
                      isPaused: isPaused,
                    ),

                    const SizedBox(height: 22),

                    // Controls Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (isRec) ...[
                          IconButton.filledTonal(
                            style: IconButton.styleFrom(
                              backgroundColor: const Color(0xFF334155),
                              padding: const EdgeInsets.all(14),
                            ),
                            icon: const Icon(Icons.stop_rounded, color: Colors.white, size: 28),
                            onPressed: _stopRecording,
                            tooltip: 'Завершить запись',
                          ),
                          const SizedBox(width: 20),
                        ],

                        // Main Big Record / Pause / Resume Button
                        GestureDetector(
                          onTap: _toggleRecord,
                          child: Container(
                            width: 76,
                            height: 76,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: isRec
                                  ? (isPaused ? AppTheme.cyanGradient : const LinearGradient(colors: [Color(0xFFEF4444), Color(0xFFDC2626)]))
                                  : AppTheme.primaryGradient,
                              boxShadow: [
                                BoxShadow(
                                  color: (isRec ? (isPaused ? AppTheme.cyan : Colors.red) : AppTheme.primary).withOpacity(0.35),
                                  blurRadius: 18,
                                  spreadRadius: 1,
                                )
                              ],
                            ),
                            child: Icon(
                              isRec
                                  ? (isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded)
                                  : Icons.mic_rounded,
                              size: 38,
                              color: Colors.white,
                            ),
                          ),
                        ),

                        if (hasRecording && !isRec) ...[
                          const SizedBox(width: 20),
                          IconButton.filledTonal(
                            style: IconButton.styleFrom(
                              backgroundColor: const Color(0xFF334155),
                              padding: const EdgeInsets.all(14),
                            ),
                            icon: const Icon(Icons.refresh_rounded, color: AppTheme.warning, size: 28),
                            onPressed: _resetRecording,
                            tooltip: 'Сбросить',
                          ),
                        ],
                      ],
                    ),

                    const SizedBox(height: 12),
                    Text(
                      isRec
                          ? (isPaused ? 'Пауза: таймер зафиксирован, нажмите продолжить' : 'Идет запись лекции (фоновый режим активен)')
                          : (hasRecording ? 'Аудио готово к обработке' : 'Нажмите на микрофон или выберите файл ниже'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isRec ? (isPaused ? AppTheme.warning : AppTheme.error) : const Color(0xFF94A3B8),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // PICK AUDIO FILE BUTTON (If not currently recording)
              if (!isRec) ...[
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
                    side: const BorderSide(color: Color(0xFF3B82F6), width: 1.2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: const Icon(Icons.audio_file_rounded, color: Color(0xFF60A5FA), size: 22),
                  label: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Выбрать готовое аудио из памяти устройства (MP3, M4A, WAV)',
                      style: TextStyle(color: Color(0xFF93C5FD), fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                  ),
                  onPressed: _pickAudioFile,
                ),
              ],

              // PROMINENT REVIEW PLAYER
              if (_recordedPath != null && !isRec) ...[
                const SizedBox(height: 16),
                GlassContainer(
                  padding: const EdgeInsets.all(18),
                  borderRadius: 22,
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(
                            _isCustomUploadedAudio ? Icons.file_present_rounded : Icons.headphones_rounded,
                            color: AppTheme.cyan,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _pickedFileName ?? 'Прослушивание записи',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          InkWell(
                            onTap: _resetRecording,
                            borderRadius: BorderRadius.circular(8),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.close_rounded, color: AppTheme.warning, size: 16),
                                  SizedBox(width: 4),
                                  Text('Убрать', style: TextStyle(color: AppTheme.warning, fontSize: 11, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Slider with Clear Left and Right Times
                      Row(
                        children: [
                          Text(
                            _formatTime(_playbackPosition.inSeconds),
                            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                          Expanded(
                            child: SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                trackHeight: 5,
                                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
                                activeTrackColor: AppTheme.cyan,
                                inactiveTrackColor: const Color(0xFF334155),
                                thumbColor: AppTheme.cyan,
                              ),
                              child: Slider(
                                value: _playbackPosition.inSeconds.toDouble().clamp(0.0, totalSec.toDouble()),
                                max: totalSec.toDouble() > 0 ? totalSec.toDouble() : 1.0,
                                onChanged: (val) {
                                  _player.seek(Duration(seconds: val.toInt()));
                                },
                              ),
                            ),
                          ),
                          Text(
                            _formatTime(totalSec),
                            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      // Player buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1E293B),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            icon: const Icon(Icons.replay_10_rounded, color: Colors.white, size: 20),
                            label: const Text('-10с', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                            onPressed: () => _seekRelative(-10),
                          ),
                          const SizedBox(width: 16),
                          GestureDetector(
                            onTap: _playPauseReview,
                            child: Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: AppTheme.cyanGradient,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.cyan.withOpacity(0.4),
                                    blurRadius: 16,
                                  ),
                                ],
                              ),
                              child: Icon(
                                _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                color: Colors.black,
                                size: 34,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1E293B),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            icon: const Icon(Icons.forward_10_rounded, color: Colors.white, size: 20),
                            label: const Text('+10с', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                            onPressed: () => _seekRelative(10),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 22),

              // Metadata
              const Text(
                'Информация о лекции',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
              ),
              const SizedBox(height: 12),

              GlassContainer(
                padding: const EdgeInsets.all(18),
                borderRadius: 20,
                child: Column(
                  children: [
                    TextField(
                      controller: _titleController,
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                      decoration: InputDecoration(
                        labelText: 'Название темы лекции',
                        hintText: 'Например: Дифференциальные уравнения',
                        labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                        prefixIcon: const Icon(Icons.title_rounded, color: AppTheme.primaryLight, size: 20),
                        filled: true,
                        fillColor: const Color(0xFF0F172A).withOpacity(0.5),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _subjectController,
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                      decoration: InputDecoration(
                        labelText: 'Предмет / Дисциплина',
                        hintText: 'Например: Математический анализ',
                        labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                        prefixIcon: const Icon(Icons.school_outlined, color: AppTheme.secondary, size: 20),
                        filled: true,
                        fillColor: const Color(0xFF0F172A).withOpacity(0.5),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _teacherController,
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                      decoration: InputDecoration(
                        labelText: 'Преподаватель / Спикер',
                        hintText: 'Например: проф. Иванов А.С.',
                        labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                        prefixIcon: const Icon(Icons.person_pin_outlined, color: AppTheme.accent, size: 20),
                        filled: true,
                        fillColor: const Color(0xFF0F172A).withOpacity(0.5),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 22),

              // Processing Options
              if (_isProcessing) ...[
                GlassContainer(
                  padding: const EdgeInsets.all(20),
                  borderRadius: 20,
                  backgroundColor: const Color(0xFF1E293B),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2.5, color: AppTheme.accent),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _processStep,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: _processProgress,
                          minHeight: 8,
                          backgroundColor: const Color(0xFF0F172A),
                          valueColor: const AlwaysStoppedAnimation(AppTheme.accent),
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Поддерживаются длинные лекции (1–2+ ч). Приложение можно свернуть.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                // Action 1: Auto 1-click full AI summary
                CustomButton(
                  text: 'Полный AI Конспект (LibeNet AI)',
                  icon: Icons.auto_awesome,
                  onPressed: hasRecording ? () => _executeProcessing(autoSummarize: true) : null,
                ),
                const SizedBox(height: 12),

                // Action 2: Transcript only
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                    side: const BorderSide(color: Color(0xFF06B6D4), width: 1.2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: hasRecording ? () => _executeProcessing(autoSummarize: false) : null,
                  child: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.description_outlined, color: AppTheme.cyan, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Только расшифровка (Текст лекции)',
                          style: TextStyle(color: AppTheme.cyan, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 20),
              const Center(
                child: Text(
                  '© LibeNet • Voice AI Studio',
                  style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
