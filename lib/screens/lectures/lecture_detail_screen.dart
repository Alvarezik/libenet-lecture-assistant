import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/constants/api_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/audio_player_service.dart';
import '../../core/services/api_service.dart';
import '../../models/lecture_model.dart';
import '../../providers/lecture_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/flashcard_card.dart';
import '../../widgets/glass_container.dart';
import '../../widgets/status_badge.dart';

class LectureDetailScreen extends StatefulWidget {
  final int lectureId;

  const LectureDetailScreen({super.key, required this.lectureId});

  @override
  State<LectureDetailScreen> createState() => _LectureDetailScreenState();
}

class _LectureDetailScreenState extends State<LectureDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final AudioPlayerService _audioPlayer = AudioPlayerService();
  bool _isAudioReady = false;
  double _currentSpeed = 1.0;
  bool _isActionRunning = false;
  String _actionStatusText = '';
  int _transcriptTabMode = 0;
  double? _scrubPosition;

  final ValueNotifier<int> _activeSegmentIndex = ValueNotifier<int>(-1);
  StreamSubscription<Duration>? _posSub;

  // AI Chat state
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();
  final List<Map<String, String>> _chatMessages = [];
  bool _isSendingQuestion = false;

  Future<void> _seekAndPlay(double startSeconds) async {
    final provider = Provider.of<LectureProvider>(context, listen: false);
    final filename = provider.selectedLecture?.audioFilename;
    if (filename == null || filename.isEmpty) return;

    try {
      final target = Duration(seconds: startSeconds.toInt());
      if (!_isAudioReady) {
        final url = ApiConstants.audioStream(filename);
        await _audioPlayer.setUrl(url);
        _isAudioReady = true;
      }
      await _audioPlayer.seek(target);
      if (!_audioPlayer.isPlaying) {
        await _audioPlayer.play();
      }
    } catch (_) {}
  }

  Future<void> _downloadOrShareAudio(LectureModel? lecture) async {
    if (lecture == null || lecture.audioFilename == null || lecture.audioFilename!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Аудиозапись отсутствует для данной лекции')),
      );
      return;
    }
    final filename = lecture.audioFilename!;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: AppTheme.primary,
        content: Text('Подготовка аудиофайла...'),
        duration: Duration(seconds: 2),
      ),
    );

    try {
      final url = ApiConstants.audioStream(filename);
      final res = await http.get(Uri.parse(url));
      if (res.statusCode == 200) {
        final tempDir = await getTemporaryDirectory();
        final localFile = File('${tempDir.path}/lecture_${lecture.id}_$filename');
        await localFile.writeAsBytes(res.bodyBytes);

        await Share.shareXFiles(
          [XFile(localFile.path, mimeType: 'audio/m4a')],
          text: 'Аудиозапись лекции: ${lecture.title}',
          subject: lecture.title,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: AppTheme.error, content: Text('Ошибка скачивания: $e')),
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });

    _posSub = _audioPlayer.positionStream.listen((pos) {
      if (!mounted) return;
      final provider = Provider.of<LectureProvider>(context, listen: false);
      final timed = provider.selectedLecture?.timedTranscript ?? [];
      if (timed.isEmpty) return;
      final sec = pos.inSeconds.toDouble();
      final idx = timed.indexWhere((s) => sec >= s.start && sec < (s.start + 25));
      if (_activeSegmentIndex.value != idx) {
        _activeSegmentIndex.value = idx;
      }
    });
  }

  Future<void> _loadData() async {
    final provider = Provider.of<LectureProvider>(context, listen: false);
    await provider.fetchLectureDetail(widget.lectureId);
    final lecture = provider.selectedLecture;
    if (lecture != null && lecture.audioFilename != null && lecture.audioFilename!.isNotEmpty) {
      final audioUrl = ApiConstants.audioStream(lecture.audioFilename!);
      await _audioPlayer.setUrl(audioUrl);
      if (mounted) setState(() => _isAudioReady = true);
    }
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _activeSegmentIndex.dispose();
    _tabController.dispose();
    _audioPlayer.dispose();
    _chatController.dispose();
    _chatScrollController.dispose();
    super.dispose();
  }


    Widget _buildEngineRadio({
    required String title,
    required String subtitle,
    required String value,
    required String selected,
    required ValueChanged<String?> onChanged,
  }) {
    final isSelected = value == selected;
    return GestureDetector(
      onTap: () => onChanged(value),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary.withOpacity(0.15) : const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? AppTheme.cyan : const Color(0x22475569)),
        ),
        child: Row(
          children: [
            Radio<String>(
              value: value,
              groupValue: selected,
              onChanged: onChanged,
              activeColor: AppTheme.cyan,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _retranscribe(LectureModel lecture, LectureProvider provider) async {
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
    String selectedEngine = 'auto';
    final proceed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: const Color(0xFF161F30),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Row(
                children: [
                  Icon(Icons.record_voice_over_rounded, color: AppTheme.cyan, size: 22),
                  SizedBox(width: 10),
                  Text('Переделать транскрипцию', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                'Выберите сервис распознавания речи (с резервным шлюзом):',
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
              ),
              const SizedBox(height: 14),
              _buildEngineRadio(
                title: '⚡ Умный авто-каскад',
                subtitle: 'Groq Whisper ➔ Deepgram ➔ Gladia ➔ AssemblyAI',
                value: 'auto',
                selected: selectedEngine,
                onChanged: (val) => setModalState(() => selectedEngine = val!),
              ),
              _buildEngineRadio(
                title: '🚀 Groq Whisper Large v3',
                subtitle: 'Сверхбыстрая расшифровка с таймкодами',
                value: 'groq',
                selected: selectedEngine,
                onChanged: (val) => setModalState(() => selectedEngine = val!),
              ),
              _buildEngineRadio(
                title: '🎙️ Deepgram Nova-2 RU',
                subtitle: 'Потоковое распознавание русской речи',
                value: 'deepgram',
                selected: selectedEngine,
                onChanged: (val) => setModalState(() => selectedEngine = val!),
              ),
              _buildEngineRadio(
                title: '🎧 Gladia AI (с фильтрацией шума)',
                subtitle: 'Усиление тихого голоса лектора с дальних парт',
                value: 'gladia',
                selected: selectedEngine,
                onChanged: (val) => setModalState(() => selectedEngine = val!),
              ),
              _buildEngineRadio(
                title: '🤖 AssemblyAI Universal',
                subtitle: 'Резервная транскрипция с высокой точностью',
                value: 'assemblyai',
                selected: selectedEngine,
                onChanged: (val) => setModalState(() => selectedEngine = val!),
              ),
              _buildEngineRadio(
                title: '🌐 OpenAI / Локальный Whisper',
                subtitle: 'Совместимый OpenAI Whisper API или Local Whisper',
                value: 'whisper',
                selected: selectedEngine,
                onChanged: (val) => setModalState(() => selectedEngine = val!),
              ),
              const SizedBox(height: 14),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Запустить транскрипцию', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
              ),
            ],
          ),
        ),
      ),
    );

    if (proceed != true || !mounted) return;

    setState(() {
      _isActionRunning = true;
      _actionStatusText = 'Распознавание речи ($selectedEngine)...';
    });

    try {
      await provider.transcribeLecture(lecture.id, language: 'ru', engine: selectedEngine);
      if (!mounted) return;
      setState(() {
        _actionStatusText = 'LibeNet AI: создание конспекта без воды...';
      });
      await provider.summarizeLecture(lecture.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(backgroundColor: AppTheme.success, content: Text('Транскрипция и конспект успешно обновлены!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: AppTheme.error, content: Text('Ошибка: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isActionRunning = false);
    }
  }

  Future<void> _resummarize(LectureModel lecture, LectureProvider provider) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (!auth.isAdmin && auth.user?.canSummarize == false) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppTheme.error,
          content: Text('Администратор ограничил доступ к генерации конспектов для вашего аккаунта'),
        ),
      );
      return;
    }
    setState(() {
      _isActionRunning = true;
      _actionStatusText = 'Глубокий анализ конспекта LibeNet AI...';
    });

    try {
      await provider.summarizeLecture(lecture.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(backgroundColor: AppTheme.success, content: Text('Конспект и карточки успешно обновлены!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: AppTheme.error, content: Text('Ошибка: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isActionRunning = false);
    }
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final h = d.inHours;
    if (h > 0) return '$h:$m:$s';
    return '$m:$s';
  }

  void _cyclePlaybackSpeed() {
    final speeds = [1.0, 1.25, 1.5, 2.0];
    int idx = speeds.indexOf(_currentSpeed);
    int nextIdx = (idx + 1) % speeds.length;
    setState(() {
      _currentSpeed = speeds[nextIdx];
    });
    _audioPlayer.setPlaybackRate(_currentSpeed);
  }

  void _sendChatMessage([String? prefilledText]) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (!auth.isAdmin && auth.user?.canChatLecture == false) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppTheme.error,
          content: Text('Администратор ограничил доступ к чату по лекции для вашего аккаунта'),
        ),
      );
      return;
    }
    final text = prefilledText ?? _chatController.text.trim();
    if (text.isEmpty || _isSendingQuestion) return;

    if (prefilledText == null) {
      _chatController.clear();
    }

    setState(() {
      _chatMessages.add({'role': 'user', 'content': text});
      _isSendingQuestion = true;
    });

    _scrollChatToBottom();

    try {
      final previousMessages = _chatMessages.length > 1
          ? _chatMessages.sublist(0, _chatMessages.length - 1)
          : <Map<String, String>>[];
      final history = previousMessages.map((m) => {'role': m['role']!, 'content': m['content']!}).toList();
      final provider = Provider.of<LectureProvider>(context, listen: false);
      final lec = provider.selectedLecture;
      final answer = await ApiService.askLectureChat(
        lectureId: widget.lectureId,
        question: text,
        history: history,
        lectureTitle: lec?.title,
        lectureSummary: lec?.cleanSummary,
        lectureTranscript: lec?.rawTranscript,
      );

      if (mounted) {
        setState(() {
          _chatMessages.add({'role': 'assistant', 'content': answer});
          _isSendingQuestion = false;
        });
        _scrollChatToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _chatMessages.add({
            'role': 'assistant',
            'content': 'Ошибка связи с нейросетью: $e. Проверьте интернет-соединение.'
          });
          _isSendingQuestion = false;
        });
        _scrollChatToBottom();
      }
    }
  }

  void _scrollChatToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScrollController.hasClients) {
        _chatScrollController.animateTo(
          _chatScrollController.position.maxScrollExtent + 80,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<LectureProvider>(context);
    final lecture = provider.selectedLecture;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          lecture?.title ?? 'Детали лекции',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (lecture != null) ...[
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
              color: const Color(0xFF161F30),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              onSelected: (val) {
                if (val == 'retranscribe') {
                  _retranscribe(lecture, provider);
                } else if (val == 'resummarize') {
                  _resummarize(lecture, provider);
                }
              },
              itemBuilder: (ctx) => [
                const PopupMenuItem(
                  value: 'resummarize',
                  child: Row(
                    children: [
                      Icon(Icons.auto_awesome, color: AppTheme.cyan, size: 18),
                      SizedBox(width: 10),
                      Text('Пересоздать конспект (LibeNet AI)', style: TextStyle(color: Colors.white, fontSize: 13)),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'retranscribe',
                  child: Row(
                    children: [
                      Icon(Icons.refresh_rounded, color: AppTheme.secondary, size: 18),
                      SizedBox(width: 10),
                      Text('Переделать транскрипцию (Nova-2)', style: TextStyle(color: Colors.white, fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.download_rounded, color: AppTheme.cyan),
              tooltip: 'Скачать аудиозапись',
              onPressed: () => _downloadOrShareAudio(provider.selectedLecture),
            ),
            IconButton(
              icon: const Icon(Icons.share_outlined, color: Colors.white),
              onPressed: () {
                final shareText = 'Лекция: ${lecture.title}\nПредмет: ${lecture.subject}\nСпикер: ${lecture.teacherName}\n\nAI Конспект:\n${lecture.cleanSummary ?? lecture.rawTranscript ?? "Конспект формируется..."}\n\nLibeNet Lecture Assistant';
                Share.share(shareText);
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.error),
              onPressed: () async {
                final nav = Navigator.of(context);
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: const Color(0xFF161F30),
                    title: const Text('Удалить лекцию?', style: TextStyle(color: Colors.white)),
                    content: const Text('Данные лекции и конспект будут удалены.', style: TextStyle(color: Color(0xFF94A3B8))),
                    actions: [
                      TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Отмена', style: TextStyle(color: Color(0xFF64748B)))),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
                        onPressed: () => Navigator.of(ctx).pop(true),
                        child: const Text('Удалить', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                );
                if (confirm == true && mounted) {
                  await provider.deleteLecture(lecture.id);
                  if (mounted) {
                    nav.pop();
                  }
                }
              },
            ),
          ],
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: AppTheme.primary,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: const Color(0xFF94A3B8),
          tabs: const [
            Tab(icon: Icon(Icons.menu_book_rounded, size: 18), text: 'Конспект'),
            Tab(icon: Icon(Icons.graphic_eq_rounded, size: 18), text: 'Расшифровка'),
            Tab(icon: Icon(Icons.style_outlined, size: 18), text: 'Карточки'),
            Tab(icon: Icon(Icons.forum_rounded, size: 18), text: 'Чат с AI'),
          ],
        ),
      ),
      body: lecture == null
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : Column(
              children: [
                                // Action Running Banner
                if (_isActionRunning) ...[
                  Container(
                    width: double.infinity,
                    color: AppTheme.primary.withOpacity(0.25),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.cyan)),
                        const SizedBox(width: 10),
                        Text(
                          _actionStatusText,
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
                // Offline banner if loaded from cache
                if (lecture.isFromOfflineCache) ...[
                  Container(
                    width: double.infinity,
                    color: AppTheme.warning.withOpacity(0.2),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.cloud_off_rounded, size: 16, color: AppTheme.warning),
                        SizedBox(width: 8),
                        Text(
                          'Офлайн-режим • Данные загружены из памяти устройства',
                          style: TextStyle(color: AppTheme.warning, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],

                // Compact Player Widget
                if (_isAudioReady) _buildPlayerCard(lecture),

                // Main Tab Content
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildSummaryTab(lecture, provider),
                      _buildTranscriptTab(lecture, provider),
                      _buildFlashcardsTab(lecture),
                      _buildChatTab(lecture),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  // PLAYER CARD
  Widget _buildPlayerCard(LectureModel lecture) {
    return StreamBuilder<Duration>(
      stream: _audioPlayer.positionStream,
      builder: (context, snapshotPos) {
        final pos = snapshotPos.data ?? Duration.zero;
        return StreamBuilder<Duration>(
          stream: _audioPlayer.durationStream,
          builder: (context, snapshotDur) {
            final dur = snapshotDur.data ?? Duration(seconds: lecture.durationSeconds);
            final maxSec = dur.inSeconds > 0 ? dur.inSeconds.toDouble() : 1.0;
            final currentSec = pos.inSeconds.toDouble().clamp(0.0, maxSec);

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: const BoxDecoration(
                color: Color(0xFF101726),
                border: Border(bottom: BorderSide(color: Color(0x22475569), width: 1)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Text(
                        _formatDuration(pos),
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      Expanded(
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 4,
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                            activeTrackColor: AppTheme.cyan,
                            inactiveTrackColor: const Color(0xFF334155),
                            thumbColor: AppTheme.cyan,
                          ),
                          child: Slider(
                            value: (_scrubPosition ?? currentSec).clamp(0.0, maxSec),
                            max: maxSec,
                            onChanged: (val) {
                              setState(() {
                                _scrubPosition = val;
                              });
                            },
                            onChangeEnd: (val) {
                              _audioPlayer.seek(Duration(seconds: val.toInt()));
                              setState(() {
                                _scrubPosition = null;
                              });
                            },
                          ),
                        ),
                      ),
                      Text(
                        _formatDuration(dur),
                        style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.replay_10_rounded, color: Colors.white70, size: 22),
                        onPressed: () => _audioPlayer.seekRelative(-10),
                        tooltip: '-10 сек',
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => _audioPlayer.playPause(),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: AppTheme.cyanGradient,
                          ),
                          child: Icon(
                            _audioPlayer.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                            color: Colors.black,
                            size: 26,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.forward_10_rounded, color: Colors.white70, size: 22),
                        onPressed: () => _audioPlayer.seekRelative(10),
                        tooltip: '+10 сек',
                      ),
                      const Spacer(),
                      InkWell(
                        onTap: _cyclePlaybackSpeed,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFF475569), width: 1),
                          ),
                          child: Text(
                            '${_currentSpeed}x',
                            style: const TextStyle(color: AppTheme.cyan, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // TAB 1: SUMMARY
  Widget _buildSummaryTab(LectureModel lecture, LectureProvider provider) {
    if (lecture.cleanSummary == null || lecture.cleanSummary!.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.psychology_outlined, size: 56, color: Color(0xFF64748B)),
              const SizedBox(height: 16),
              const Text('Конспект еще не сформирован', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text(
                'Запустите обработку LibeNet AI для удаления воды и выделения ключевых понятий.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
                label: const Text('Сгенерировать конспект', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                onPressed: () async {
                  await provider.summarizeLecture(lecture.id);
                },
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Meta Header Card
          GlassContainer(
            padding: const EdgeInsets.all(16),
            borderRadius: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        lecture.title,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white),
                      ),
                    ),
                    StatusBadge(status: lecture.statusText, color: lecture.statusColor),
                  ],
                ),
                if (lecture.subject.isNotEmpty || lecture.teacherName.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (lecture.subject.isNotEmpty) ...[
                        const Icon(Icons.school_outlined, size: 14, color: AppTheme.cyan),
                        const SizedBox(width: 4),
                        Text(lecture.subject, style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 12, fontWeight: FontWeight.w600)),
                        const SizedBox(width: 12),
                      ],
                      if (lecture.teacherName.isNotEmpty) ...[
                        const Icon(Icons.person_pin_outlined, size: 14, color: AppTheme.accent),
                        const SizedBox(width: 4),
                        Text(lecture.teacherName, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Key points
          if (lecture.keyPoints.isNotEmpty) ...[
            const Text('Главные тезисы', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
            const SizedBox(height: 8),
            ...lecture.keyPoints.map((point) => Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF161F30),
                borderRadius: BorderRadius.circular(12),
                border: const Border(left: BorderSide(color: AppTheme.accent, width: 3)),
              ),
              child: Text(point, style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 13, height: 1.4)),
            )),
            const SizedBox(height: 16),
          ],

          // Markdown Content
          const Text('Структурированный конспект', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
          const SizedBox(height: 8),
          GlassContainer(
            padding: const EdgeInsets.all(16),
            borderRadius: 20,
            child: MarkdownBody(
              data: lecture.cleanSummary ?? '',
              selectable: true,
              styleSheet: MarkdownStyleSheet(
                p: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 14, height: 1.5),
                h2: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800, height: 1.4),
                h3: const TextStyle(color: AppTheme.cyan, fontSize: 16, fontWeight: FontWeight.bold, height: 1.3),
                h4: const TextStyle(color: AppTheme.accent, fontSize: 14, fontWeight: FontWeight.bold),
                strong: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                blockquote: const TextStyle(color: Color(0xFFFBBF24), fontStyle: FontStyle.italic),
                blockquoteDecoration: BoxDecoration(
                  color: const Color(0xFF231C14),
                  borderRadius: BorderRadius.circular(8),
                  border: const Border(left: BorderSide(color: Color(0xFFF59E0B), width: 3)),
                ),
                listBullet: const TextStyle(color: AppTheme.primaryLight),
              ),
            ),
          ),
        ],
      ),
    );
  }

    // TAB 2: TRANSCRIPT (RAW TEXT VS INTERACTIVE TIMECODES - 120 FPS LAG-FREE)
  Widget _buildTranscriptTab(LectureModel lecture, LectureProvider provider) {
    final rawText = lecture.rawTranscript ?? '';
    if (rawText.isEmpty) {
      return const Center(
        child: Text('Транскрипция отсутствует', style: TextStyle(color: Color(0xFF64748B))),
      );
    }

    final timed = lecture.timedTranscript;
    final wordCount = rawText.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;

    return Column(
      children: [
        // Mode Selector: Raw Text vs Interactive Timed List
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0x22475569)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _transcriptTabMode = 0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      decoration: BoxDecoration(
                        color: _transcriptTabMode == 0 ? AppTheme.primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.description_outlined, size: 16, color: _transcriptTabMode == 0 ? Colors.white : const Color(0xFF94A3B8)),
                          const SizedBox(width: 6),
                          Text(
                            'Сырой текст (Без AI)',
                            style: TextStyle(
                              color: _transcriptTabMode == 0 ? Colors.white : const Color(0xFF94A3B8),
                              fontSize: 12,
                              fontWeight: _transcriptTabMode == 0 ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _transcriptTabMode = 1),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      decoration: BoxDecoration(
                        color: _transcriptTabMode == 1 ? AppTheme.primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.timer_outlined, size: 16, color: _transcriptTabMode == 1 ? Colors.white : const Color(0xFF94A3B8)),
                          const SizedBox(width: 6),
                          Text(
                            'Таймкоды (${timed.length})',
                            style: TextStyle(
                              color: _transcriptTabMode == 1 ? Colors.white : const Color(0xFF94A3B8),
                              fontSize: 12,
                              fontWeight: _transcriptTabMode == 1 ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Action Toolbar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              Text(
                'Слов: $wordCount • Символов: ${rawText.length}',
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: AppTheme.secondary, size: 20),
                tooltip: 'Переделать расшифровку (выбор сервиса)',
                onPressed: _isActionRunning ? null : () => _retranscribe(lecture, provider),
              ),
              IconButton(
                icon: const Icon(Icons.copy_rounded, color: AppTheme.cyan, size: 20),
                tooltip: 'Скопировать весь сырой текст',
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: rawText));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Сырой текст скопирован в буфер обмена!')),
                  );
                },
              ),
            ],
          ),
        ),

        // Content Area
        Expanded(
          child: _transcriptTabMode == 0
              ? SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  child: GlassContainer(
                    padding: const EdgeInsets.all(16),
                    borderRadius: 18,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.verified_outlined, color: AppTheme.cyan, size: 16),
                            SizedBox(width: 6),
                            Text(
                              'Исходная речь лектора (Без сжатия нейросетью)',
                              style: TextStyle(color: AppTheme.cyan, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SelectableText(
                          rawText,
                          style: const TextStyle(
                            color: Color(0xFFE2E8F0),
                            fontSize: 14,
                            height: 1.6,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : (timed.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Таймкоды не разбиты на сегменты. Используйте вкладку «Сырой текст».',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                        ),
                      ),
                    )
                  : ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      itemCount: timed.length,
                      itemBuilder: (ctx, i) {
                        final seg = timed[i];
                        return ValueListenableBuilder<int>(
                          valueListenable: _activeSegmentIndex,
                          builder: (ctx, activeIdx, _) {
                            final isActive = activeIdx == i;
                            return GestureDetector(
                              onTap: () {
                                _seekAndPlay(seg.start);
                              },
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isActive ? const Color(0xFF1E2640) : const Color(0xFF111827),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isActive ? AppTheme.cyan : const Color(0x22475569),
                                    width: isActive ? 1.5 : 1.0,
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: isActive ? AppTheme.cyan : const Color(0xFF1E293B),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.play_arrow_rounded, size: 12, color: isActive ? Colors.black : AppTheme.cyan),
                                          const SizedBox(width: 2),
                                          Text(
                                            seg.time,
                                            style: TextStyle(
                                              color: isActive ? Colors.black : AppTheme.cyan,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        seg.text,
                                        style: TextStyle(
                                          color: isActive ? Colors.white : const Color(0xFFCBD5E1),
                                          fontSize: 13,
                                          height: 1.4,
                                          fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    )),
        ),
      ],
    );
  }

  // TAB 3: FLASHCARDS
  Widget _buildFlashcardsTab(LectureModel lecture) {
    if (lecture.flashcards.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Карточки появятся после AI-обработки лекции', style: TextStyle(color: Color(0xFF64748B))),
        ),
      );
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(18),
      itemCount: lecture.flashcards.length,
      itemBuilder: (context, i) {
        final card = lecture.flashcards[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: FlashcardCard(
            question: card['question'] ?? '',
            answer: card['answer'] ?? '',
            index: i + 1,
            total: lecture.flashcards.length,
          ),
        );
      },
    );
  }

  // TAB 4: INTERACTIVE AI CHAT (LIBENET AI)
  Widget _buildChatTab(LectureModel lecture) {
    final auth = Provider.of<AuthProvider>(context);
    if (!auth.isAdmin && auth.user?.canChatLecture == false) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.lock_outline_rounded, size: 56, color: AppTheme.primaryLight),
              SizedBox(height: 16),
              Text(
                'Чат по лекции ограничен',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'Администратор ограничил доступ к вопросам по лекциям для вашего аккаунта.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }
    return Column(
      children: [
        // Quick suggestion chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              _buildPromptChip('Объясни простыми словами'),
              _buildPromptChip('Возможные вопросы на зачете?'),
              _buildPromptChip('Сделай краткую шпаргалку'),
              _buildPromptChip('Где лектор сомневался или невнятно говорил?'),
            ],
          ),
        ),

        // Chat messages list
        Expanded(
          child: _chatMessages.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.forum_outlined, size: 52, color: Color(0xFF64748B)),
                        const SizedBox(height: 12),
                        const Text(
                          'Спросите что угодно по лекции',
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Нейросеть LibeNet AI проанализирует материал лекции и даст четкий ответ без воды.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  controller: _chatScrollController,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.all(14),
                  itemCount: _chatMessages.length,
                  itemBuilder: (context, i) {
                    final msg = _chatMessages[i];
                    final isUser = msg['role'] == 'user';
                    return Align(
                      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.84),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isUser ? AppTheme.primary : const Color(0xFF161F30),
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(16),
                            topRight: const Radius.circular(16),
                            bottomLeft: Radius.circular(isUser ? 16 : 4),
                            bottomRight: Radius.circular(isUser ? 4 : 16),
                          ),
                          border: isUser ? null : Border.all(color: const Color(0x33475569), width: 1),
                        ),
                        child: isUser
                            ? Text(msg['content'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 14))
                            : MarkdownBody(
                                data: msg['content'] ?? '',
                                styleSheet: MarkdownStyleSheet(
                                  p: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 13, height: 1.45),
                                  strong: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                  h3: const TextStyle(color: AppTheme.cyan, fontSize: 14, fontWeight: FontWeight.bold),
                                ),
                              ),
                      ),
                    );
                  },
                ),
        ),

        if (_isSendingQuestion) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: const Row(
              children: [
                SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accent)),
                SizedBox(width: 10),
                Text('LibeNet AI изучает материалы лекции...', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
              ],
            ),
          ),
        ],

        // Input bar
        Container(
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(
            color: Color(0xFF0F172A),
            border: Border(top: BorderSide(color: Color(0x22475569), width: 1)),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _chatController,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Задайте вопрос по лекции...',
                    hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                    filled: true,
                    fillColor: const Color(0xFF1E293B),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  ),
                  onSubmitted: (_) => _sendChatMessage(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                style: IconButton.styleFrom(backgroundColor: AppTheme.primary),
                icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                onPressed: _isSendingQuestion ? null : () => _sendChatMessage(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPromptChip(String text) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        backgroundColor: const Color(0xFF1E293B),
        side: const BorderSide(color: Color(0x33475569)),
        label: Text(text, style: const TextStyle(color: AppTheme.primaryLight, fontSize: 11, fontWeight: FontWeight.bold)),
        onPressed: () => _sendChatMessage(text),
      ),
    );
  }
}
