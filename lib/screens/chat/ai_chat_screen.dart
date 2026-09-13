import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/api_service.dart';

class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, String>> _messages = [];
  bool _isLoading = false;
  String _selectedTopic = 'Помощь в учебе';

  final List<String> _topics = [
    'Помощь в учебе',
    'Подготовка к экзаменам',
    'План реферата / эссе',
    'Объясни на пальцах',
    'Формулы и код',
    'Анализ лекций',
  ];

  @override
  void initState() {
    super.initState();
    _messages.add({
      'role': 'assistant',
      'content': '👋 Здравствуйте! Я ваш академический AI-ассистент **LibeNet**.\n\n'
          'Я могу объяснить сложные термины, составить план к экзамену, написать конспект или помочь с рефератом. Выберите тему выше или задайте любой вопрос!',
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage([String? quickText]) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (!auth.isAdmin && auth.user?.canChatGeneral == false) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppTheme.error,
          content: Text('Администратор ограничил доступ к общему ИИ-ассистенту для вашего аккаунта'),
        ),
      );
      return;
    }
    final text = quickText ?? _textController.text.trim();
    if (text.isEmpty || _isLoading) return;

    if (quickText == null) {
      _textController.clear();
    }

    setState(() {
      _messages.add({'role': 'user', 'content': text});
      _isLoading = true;
    });
    _scrollToBottom();

    try {
      // Build conversation history prompt
      final buffer = StringBuffer();
      buffer.writeln('Ты — продвинутый академический AI-ассистент студентов LibeNet.');
      buffer.writeln('Текущая тема диалога: $_selectedTopic.');
      buffer.writeln('Отвечай развернуто, структурированно, академично, но понятно, используя списки и выделения.');
      buffer.writeln('История диалога:');
      final recentMessages = _messages.length > 8 ? _messages.sublist(_messages.length - 8) : _messages;
      for (final m in recentMessages) {
        buffer.writeln('${m['role'] == 'user' ? 'Студент' : 'Ассистент'}: ${m['content']}');
      }

      final reply = await ApiService.askLectureChat(lectureId: 0, question: buffer.toString());

      if (mounted) {
        setState(() {
          _messages.add({'role': 'assistant', 'content': reply});
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add({
            'role': 'assistant',
            'content': '⚠️ Не удалось получить ответ: $e. Пожалуйста, проверьте соединение и попробуйте снова.',
          });
        });
        _scrollToBottom();
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _clearChat() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.delete_sweep_rounded, color: AppTheme.error),
            SizedBox(width: 8),
            Text('Очистить диалог?', style: TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
        content: const Text(
          'История переписки будет полностью сброшена, нейросеть забудет контекст текущего разговора.',
          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена', style: TextStyle(color: Color(0xFF94A3B8))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _messages.clear();
                _messages.add({
                  'role': 'assistant',
                  'content': '🧹 Контекст очищен. Я готов к новым вопросам!',
                });
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  backgroundColor: AppTheme.primary,
                  content: Text('Диалог очищен, контекст сброшен'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            child: const Text('Очистить всё', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    if (!auth.isAdmin && auth.user?.canChatGeneral == false) {
      return Scaffold(
        backgroundColor: AppTheme.bgDark,
        appBar: AppBar(
          title: const Text('AI-Ассистент'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.lock_outline_rounded, size: 56, color: AppTheme.primaryLight),
                SizedBox(height: 16),
                Text(
                  'Доступ ограничен',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(
                  'Администратор ограничил доступ к общему AI-ассистенту для вашего аккаунта.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.psychology_rounded, color: AppTheme.cyan, size: 24),
            SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('AI-Ассистент LibeNet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                Text('Умный академический собеседник', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_rounded, color: Color(0xFF94A3B8)),
            tooltip: 'Очистить историю и забыть всё',
            onPressed: _clearChat,
          ),
        ],
      ),
      body: Column(
        children: [
          // Topics horizontal scroll
          Container(
            height: 46,
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _topics.length,
              itemBuilder: (ctx, i) {
                final topic = _topics[i];
                final isSelected = topic == _selectedTopic;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(topic),
                    selected: isSelected,
                    onSelected: (val) {
                      if (val) {
                        setState(() => _selectedTopic = topic);
                      }
                    },
                    selectedColor: AppTheme.primary,
                    backgroundColor: const Color(0xFF1E293B),
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: isSelected ? AppTheme.cyan : const Color(0x22475569),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          const Divider(height: 1, color: Color(0x22475569)),

          // Messages list
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (ctx, i) {
                final msg = _messages[i];
                final isUser = msg['role'] == 'user';
                final content = msg['content'] ?? '';

                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.85,
                    ),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isUser ? AppTheme.primary : const Color(0xFF1E293B),
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: Radius.circular(isUser ? 16 : 4),
                        bottomRight: Radius.circular(isUser ? 4 : 16),
                      ),
                      border: Border.all(
                        color: isUser ? AppTheme.cyan.withOpacity(0.3) : const Color(0x22475569),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isUser ? Icons.person_rounded : Icons.auto_awesome_rounded,
                              size: 14,
                              color: isUser ? Colors.white70 : AppTheme.cyan,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isUser ? 'Вы' : 'LibeNet AI',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isUser ? Colors.white70 : AppTheme.cyan,
                              ),
                            ),
                            const Spacer(),
                            if (!isUser)
                              InkWell(
                                onTap: () {
                                  Clipboard.setData(ClipboardData(text: content));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Ответ скопирован в буфер')),
                                  );
                                },
                                child: const Icon(Icons.copy_rounded, size: 14, color: Color(0xFF94A3B8)),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        MarkdownBody(
                          data: content,
                          styleSheet: MarkdownStyleSheet(
                            p: const TextStyle(color: Colors.white, fontSize: 14, height: 1.45),
                            strong: const TextStyle(color: AppTheme.cyan, fontWeight: FontWeight.bold),
                            code: const TextStyle(
                              color: AppTheme.secondary,
                              backgroundColor: Color(0xFF0F172A),
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          if (_isLoading)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: const Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.cyan),
                  ),
                  SizedBox(width: 10),
                  Text('LibeNet AI формулирует ответ...', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                ],
              ),
            ),

          // Input field
          Container(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 10,
              bottom: MediaQuery.of(context).padding.bottom + 10,
            ),
            decoration: const BoxDecoration(
              color: Color(0xFF0F172A),
              border: Border(top: BorderSide(color: Color(0x22475569), width: 1)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    maxLines: 4,
                    minLines: 1,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Спросите что угодно по учебе или теме...',
                      hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                      filled: true,
                      fillColor: const Color(0xFF1E293B),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  style: IconButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    padding: const EdgeInsets.all(12),
                  ),
                  icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                  onPressed: _isLoading ? null : () => _sendMessage(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
