import '../../core/services/api_service.dart';
import 'package:http/http.dart' as http;
import '../../core/constants/api_constants.dart';
import '../../core/constants/app_config.dart';
import '../../core/services/storage_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../models/user_model.dart';
import '../../models/lecture_model.dart';
import '../../providers/admin_provider.dart';
import '../../widgets/glass_container.dart';
import '../../widgets/status_badge.dart';
import '../lectures/lecture_detail_screen.dart';

class AdminDashboardTab extends StatefulWidget {
  const AdminDashboardTab({super.key});

  @override
  State<AdminDashboardTab> createState() => _AdminDashboardTabState();
}

class _AdminDashboardTabState extends State<AdminDashboardTab> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchUserController = TextEditingController();
  final _searchLectureController = TextEditingController();
  final _searchLogController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging && mounted) {
        final admin = Provider.of<AdminProvider>(context, listen: false);
        if (_tabController.index == 1) {
          admin.fetchAdminLectures();
        } else if (_tabController.index == 2) {
          admin.fetchDashboardData();
        }
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final admin = Provider.of<AdminProvider>(context, listen: false);
      admin.fetchDashboardData();
      admin.fetchAdminLectures();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchUserController.dispose();
    _searchLectureController.dispose();
    _searchLogController.dispose();
    super.dispose();
  }

  void _showCreateUserDialog() {
    final usernameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    final fullNameCtrl = TextEditingController();
    String role = 'user';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF161F30),
          title: const Text('Создать пользователя', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: usernameCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'Логин', labelStyle: TextStyle(color: Color(0xFF94A3B8))),
                ),
                TextField(
                  controller: emailCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'Email', labelStyle: TextStyle(color: Color(0xFF94A3B8))),
                ),
                TextField(
                  controller: fullNameCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'ФИО (необязательно)', labelStyle: TextStyle(color: Color(0xFF94A3B8))),
                ),
                TextField(
                  controller: passwordCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'Пароль', labelStyle: TextStyle(color: Color(0xFF94A3B8))),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('Роль:', style: TextStyle(color: Colors.white70)),
                    const SizedBox(width: 14),
                    DropdownButton<String>(
                      value: role,
                      dropdownColor: const Color(0xFF1E293B),
                      style: const TextStyle(color: Colors.white),
                      items: const [
                        DropdownMenuItem(value: 'user', child: Text('Пользователь')),
                        DropdownMenuItem(value: 'admin', child: Text('Администратор')),
                      ],
                      onChanged: (val) {
                        if (val != null) setDialogState(() => role = val);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Отмена', style: TextStyle(color: Color(0xFF64748B))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
              onPressed: () async {
                final u = usernameCtrl.text.trim();
                final e = emailCtrl.text.trim();
                final p = passwordCtrl.text;
                final f = fullNameCtrl.text.trim();
                if (u.isEmpty || p.isEmpty || e.isEmpty) return;

                Navigator.of(ctx).pop();
                final messenger = ScaffoldMessenger.of(context);
                final admin = Provider.of<AdminProvider>(context, listen: false);
                try {
                  await admin.createUser(
                    username: u,
                    email: e,
                    password: p,
                    fullName: f,
                    role: role,
                  );
                  messenger.showSnackBar(
                    SnackBar(backgroundColor: AppTheme.success, content: Text('Пользователь $u успешно создан')),
                  );
                } catch (err) {
                  messenger.showSnackBar(
                    SnackBar(backgroundColor: AppTheme.error, content: Text('Ошибка: $err')),
                  );
                }
              },
              child: const Text('Создать', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditUserDialog(UserModel user) {
    final usernameCtrl = TextEditingController(text: user.username);
    final emailCtrl = TextEditingController(text: user.email);
    final fullNameCtrl = TextEditingController(text: user.fullName);
    final passwordCtrl = TextEditingController();
    String role = user.role;
    bool isActive = user.isActive;
    bool canTranscribe = user.canTranscribe;
    bool canSummarize = user.canSummarize;
    bool canChatGeneral = user.canChatGeneral;
    bool canChatLecture = user.canChatLecture;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF161F30),
          title: Text('Редактировать: ${user.username}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: usernameCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'Логин', labelStyle: TextStyle(color: Color(0xFF94A3B8))),
                ),
                TextField(
                  controller: emailCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'Email', labelStyle: TextStyle(color: Color(0xFF94A3B8))),
                ),
                TextField(
                  controller: fullNameCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'ФИО', labelStyle: TextStyle(color: Color(0xFF94A3B8))),
                ),
                TextField(
                  controller: passwordCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Новый пароль (оставьте пустым если не меняется)',
                    labelStyle: TextStyle(color: Color(0xFF94A3B8)),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('Роль:', style: TextStyle(color: Colors.white70)),
                    const SizedBox(width: 14),
                    DropdownButton<String>(
                      value: role,
                      dropdownColor: const Color(0xFF1E293B),
                      style: const TextStyle(color: Colors.white),
                      items: const [
                        DropdownMenuItem(value: 'user', child: Text('Пользователь')),
                        DropdownMenuItem(value: 'admin', child: Text('Администратор')),
                      ],
                      onChanged: (val) {
                        if (val != null) setDialogState(() => role = val);
                      },
                    ),
                  ],
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Активен', style: TextStyle(color: Colors.white70)),
                  value: isActive,
                  activeColor: AppTheme.success,
                  onChanged: (val) => setDialogState(() => isActive = val),
                ),
                const Divider(color: Color(0xFF334155), height: 28),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Разрешения и доступ:',
                    style: TextStyle(color: AppTheme.cyan, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 6),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.mic_rounded, color: AppTheme.secondary, size: 20),
                  title: const Text('Транскрибация (STT)', style: TextStyle(color: Colors.white, fontSize: 13)),
                  subtitle: const Text('Распознавание речи с аудио', style: TextStyle(color: Color(0xFF64748B), fontSize: 11)),
                  value: canTranscribe,
                  activeColor: AppTheme.cyan,
                  onChanged: (val) => setDialogState(() => canTranscribe = val),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.auto_awesome, color: AppTheme.cyan, size: 20),
                  title: const Text('AI-Конспектирование', style: TextStyle(color: Colors.white, fontSize: 13)),
                  subtitle: const Text('Генерация конспектов нейросетью', style: TextStyle(color: Color(0xFF64748B), fontSize: 11)),
                  value: canSummarize,
                  activeColor: AppTheme.cyan,
                  onChanged: (val) => setDialogState(() => canSummarize = val),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.psychology_rounded, color: AppTheme.accent, size: 20),
                  title: const Text('Общий AI-чат', style: TextStyle(color: Colors.white, fontSize: 13)),
                  subtitle: const Text('Доступ к общему ассистенту', style: TextStyle(color: Color(0xFF64748B), fontSize: 11)),
                  value: canChatGeneral,
                  activeColor: AppTheme.cyan,
                  onChanged: (val) => setDialogState(() => canChatGeneral = val),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.question_answer_rounded, color: AppTheme.primaryLight, size: 20),
                  title: const Text('Вопросы по лекциям', style: TextStyle(color: Colors.white, fontSize: 13)),
                  subtitle: const Text('AI-чат внутри деталей лекции', style: TextStyle(color: Color(0xFF64748B), fontSize: 11)),
                  value: canChatLecture,
                  activeColor: AppTheme.cyan,
                  onChanged: (val) => setDialogState(() => canChatLecture = val),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Отмена', style: TextStyle(color: Color(0xFF64748B))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
              onPressed: () async {
                Navigator.of(ctx).pop();
                final messenger = ScaffoldMessenger.of(context);
                final admin = Provider.of<AdminProvider>(context, listen: false);
                try {
                  await admin.updateUser(
                    user.id,
                    username: usernameCtrl.text.trim(),
                    email: emailCtrl.text.trim(),
                    fullName: fullNameCtrl.text.trim(),
                    role: role,
                    isActive: isActive,
                    password: passwordCtrl.text.isNotEmpty ? passwordCtrl.text : null,
                    canTranscribe: canTranscribe,
                    canSummarize: canSummarize,
                    canChatGeneral: canChatGeneral,
                    canChatLecture: canChatLecture,
                  );
                  messenger.showSnackBar(
                    const SnackBar(backgroundColor: AppTheme.success, content: Text('Данные сохранены')),
                  );
                } catch (err) {
                  messenger.showSnackBar(
                    SnackBar(backgroundColor: AppTheme.error, content: Text('Ошибка: $err')),
                  );
                }
              },
              child: const Text('Сохранить', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteLecture(LectureModel lecture) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161F30),
        title: const Text('Полное удаление с сервера', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(
          'Вы уверены, что хотите навсегда удалить лекцию «${lecture.title}»?\n\nАудиозапись будет стерта с диска сервера, а данные из базы данных.',
          style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Отмена', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Удалить навсегда', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final messenger = ScaffoldMessenger.of(context);
      final admin = Provider.of<AdminProvider>(context, listen: false);
      try {
        await admin.deleteAdminLecture(lecture.id);
        messenger.showSnackBar(
          SnackBar(backgroundColor: AppTheme.success, content: Text('Лекция «${lecture.title}» удалена с сервера')),
        );
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(backgroundColor: AppTheme.error, content: Text('Ошибка: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final admin = Provider.of<AdminProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset('assets/images/logo.png', width: 28, height: 28, fit: BoxFit.contain),
            ),
            const SizedBox(width: 10),
            const Text('Панель управления', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primary,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: const Color(0xFF94A3B8),
          tabs: const [
            Tab(icon: Icon(Icons.people_alt_rounded, size: 18), text: 'Пользователи'),
            Tab(icon: Icon(Icons.library_books_rounded, size: 18), text: 'Все лекции'),
            Tab(icon: Icon(Icons.receipt_long_rounded, size: 18), text: 'Логи & Аудит'),
            Tab(icon: Icon(Icons.tune_rounded, size: 18), text: 'Настройки'),
          ],
        ),
      ),
      body: admin.isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildUsersTab(admin),
                _buildLecturesTab(admin),
                _buildLogsTab(admin),
                _buildSettingsTab(admin),
              ],
            ),
    );
  }

  // USERS TAB
  Widget _buildUsersTab(AdminProvider admin) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Registration toggle
          GlassContainer(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            borderRadius: 18,
            child: Row(
              children: [
                const Icon(Icons.person_add_disabled_rounded, color: AppTheme.secondary, size: 22),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Свободная регистрация', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                      Text('Если выключено, регистрация на экране входа скрыта', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                    ],
                  ),
                ),
                Switch(
                  value: admin.registrationEnabled,
                  activeColor: AppTheme.success,
                  onChanged: (val) => admin.toggleRegistration(),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Пользователи (${admin.users.length})', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.add, size: 18, color: Colors.white),
                label: const Text('Создать', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                onPressed: _showCreateUserDialog,
              ),
            ],
          ),

          const SizedBox(height: 12),

          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: admin.users.length,
            itemBuilder: (context, i) {
              final u = admin.users[i];
              return GlassContainer(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                borderRadius: 16,
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: u.role == 'admin' ? AppTheme.accent.withOpacity(0.2) : const Color(0xFF1E293B),
                      child: Icon(
                        u.role == 'admin' ? Icons.shield_rounded : Icons.person_rounded,
                        color: u.role == 'admin' ? AppTheme.accent : Colors.white70,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(u.username, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                              const SizedBox(width: 8),
                              StatusBadge(status: u.role == 'admin' ? 'Админ' : 'Юзер', color: u.role == 'admin' ? AppTheme.primary : const Color(0xFF64748B)),
                              if (!u.isActive) ...[
                                const SizedBox(width: 4),
                                const StatusBadge(status: 'БАН', color: AppTheme.error),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text('${u.email} • Лекций: ${u.lecturesCount}', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_note_rounded, color: AppTheme.cyan),
                      onPressed: () => _showEditUserDialog(u),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ALL LECTURES TAB (WITH FULL PLAYBACK, TRANSCRIPT, SUMMARY & CARDS VIEWING AS USER)
  Widget _buildLecturesTab(AdminProvider admin) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Все лекции (${admin.adminLectures.length})', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
              IconButton(
                icon: const Icon(Icons.sync_rounded, color: AppTheme.cyan, size: 20),
                onPressed: () => admin.fetchAdminLectures(),
                tooltip: 'Обновить список',
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (admin.adminLectures.isEmpty) ...[
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text('На сервере нет сохраненных лекций', style: TextStyle(color: Color(0xFF64748B))),
              ),
            ),
          ] else ...[
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: admin.adminLectures.length,
              itemBuilder: (context, i) {
                final lec = admin.adminLectures[i];
                return GlassContainer(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  borderRadius: 16,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      // OPEN FULL LECTURE SCREEN EXACTLY AS USER CAN!
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => LectureDetailScreen(lectureId: lec.id)),
                      );
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                lec.title,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                            ),
                            StatusBadge(status: lec.statusText, color: lec.statusColor),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 12,
                          runSpacing: 4,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.person_outline_rounded, size: 14, color: AppTheme.cyan),
                                const SizedBox(width: 4),
                                Text('Автор: ${lec.ownerUsername ?? "ID: ${lec.userId}"}', style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 12, fontWeight: FontWeight.w600)),
                              ],
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.timer_outlined, size: 14, color: AppTheme.secondary),
                                const SizedBox(width: 4),
                                Text(lec.formattedDuration, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                              ],
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.save_outlined, size: 14, color: AppTheme.primaryLight),
                                const SizedBox(width: 4),
                                Text(lec.formattedFileSize, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primary.withOpacity(0.25),
                                  foregroundColor: AppTheme.primaryLight,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                icon: const Icon(Icons.visibility_rounded, size: 16),
                                label: const FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text('Открыть лекцию', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                ),
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(builder: (_) => LectureDetailScreen(lectureId: lec.id)),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              tooltip: 'Удалить навсегда',
                              style: IconButton.styleFrom(
                                backgroundColor: AppTheme.error.withOpacity(0.12),
                                foregroundColor: AppTheme.error,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: const Icon(Icons.delete_forever_rounded, size: 18),
                              onPressed: () => _confirmDeleteLecture(lec),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  // LOGS TAB
  Widget _buildLogsTab(AdminProvider admin) {
    final logs = admin.filteredLogs;
    return Column(
      children: [
        // Log filters
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchLogController,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Поиск по логам, IP или действию...',
                    hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                    prefixIcon: const Icon(Icons.search, color: Color(0xFF64748B), size: 18),
                    filled: true,
                    fillColor: const Color(0xFF0F172A),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                  onChanged: (val) => admin.searchLogs(val),
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                icon: const Icon(Icons.copy_all_rounded, color: AppTheme.cyan, size: 22),
                tooltip: 'Скопировать видимые логи в буфер',
                onPressed: () {
                  final logs = admin.filteredLogs;
                  if (logs.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Список логов пуст')),
                    );
                    return;
                  }
                  final buffer = StringBuffer();
                  buffer.writeln('=== ЖУРНАЛ ЛОГОВ LIBENET (Всего записей: ${logs.length}) ===\n');
                  for (final log in logs) {
                    buffer.writeln('[${log.createdAt}] [${log.level}] ${log.action}');
                    buffer.writeln('Категория: ${log.category} | Пользователь: ${log.username.isNotEmpty ? log.username : "Anonymous"} (ID: ${log.userId ?? "-"}) | IP: ${log.ipAddress.isNotEmpty ? log.ipAddress : "-"}');
                    if (log.details.isNotEmpty) {
                      buffer.writeln('Детали:\n${log.details}');
                    }
                    buffer.writeln('--------------------------------------------------');
                  }
                  Clipboard.setData(ClipboardData(text: buffer.toString()));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: AppTheme.success,
                      content: Text('Скопировано ${logs.length} записей логов в буфер обмена!'),
                    ),
                  );
                },
              ),
              const SizedBox(width: 2),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: AppTheme.primaryLight, size: 22),
                tooltip: 'Обновить логи',
                onPressed: () => admin.fetchDashboardData(),
              ),
              IconButton(
                icon: const Icon(Icons.delete_sweep_rounded, color: AppTheme.error, size: 22),
                tooltip: 'Очистить логи',
                onPressed: () async {
                  await admin.clearLogs();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Журнал логов очищен')),
                    );
                  }
                },
              ),
            ],
          ),
        ),

        // Filter chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: ['ALL', 'INFO', 'WARN', 'ERROR'].map((lvl) {
              final isSel = admin.selectedLogLevel == lvl;
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: Text(lvl, style: TextStyle(color: isSel ? Colors.white : const Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.bold)),
                  selected: isSel,
                  selectedColor: AppTheme.primary,
                  backgroundColor: const Color(0xFF161F30),
                  onSelected: (_) => admin.setLogLevelFilter(lvl),
                ),
              );
            }).toList(),
          ),
        ),

        const SizedBox(height: 8),

        Expanded(
          child: logs.isEmpty
              ? const Center(child: Text('Логов не найдено', style: TextStyle(color: Color(0xFF64748B))))
              : ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: logs.length,
                  itemBuilder: (context, i) {
                    final log = logs[i];
                    Color lvlColor = AppTheme.primaryLight;
                    if (log.level == 'WARN') lvlColor = AppTheme.warning;
                    if (log.level == 'ERROR') lvlColor = AppTheme.error;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF111827),
                        borderRadius: BorderRadius.circular(10),
                        border: Border(left: BorderSide(color: lvlColor, width: 3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                log.action,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                              const Spacer(),
                              Text(
                                log.formattedTime,
                                style: const TextStyle(color: Color(0xFF64748B), fontSize: 10),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            log.details,
                            style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 11),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.person, size: 10, color: Color(0xFF64748B)),
                              const SizedBox(width: 4),
                              Text(log.username, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10)),
                              const SizedBox(width: 10),
                              const Icon(Icons.wifi, size: 10, color: Color(0xFF64748B)),
                              const SizedBox(width: 4),
                              Text(log.ipAddress.isNotEmpty ? log.ipAddress : '127.0.0.1', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10)),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // SETTINGS & AI CONFIGURATION TAB
  Widget _buildSettingsTab(AdminProvider admin) {
    return _AdminSettingsView(admin: admin);
  }

}

class _AdminSettingsView extends StatefulWidget {
  final AdminProvider admin;
  const _AdminSettingsView({required this.admin});

  @override
  State<_AdminSettingsView> createState() => _AdminSettingsViewState();
}

class _AdminSettingsViewState extends State<_AdminSettingsView> {
  static const String defaultOrcaUrl = 'https://api.orcarouter.ai/v1';
  static const String defaultOrcaModel = 'deepseek/deepseek-v4-flash-free';
  static String get defaultOrcaKey => AppConfig.orcaApiKey;

  final _serverUrlCtrl = TextEditingController(text: ApiConstants.baseUrl);
  final _llmBaseUrlCtrl = TextEditingController();
  final _llmKeyCtrl = TextEditingController();
  final _llmModelCtrl = TextEditingController();
  final _deepgramKeyCtrl = TextEditingController();
  final _gladiaKeyCtrl = TextEditingController();
  final _assemblyKeyCtrl = TextEditingController();

  bool _obscureLlmKey = true;
  bool _obscureDgKey = true;
  bool _obscureGladiaKey = true;
  bool _obscureAssemblyKey = true;
  bool _isSaving = false;
  bool _isLoading = true;

  bool _isPingingServer = false;
  String? _serverPingResult;
  bool? _serverPingSuccess;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _serverUrlCtrl.dispose();
    _llmBaseUrlCtrl.dispose();
    _llmKeyCtrl.dispose();
    _llmModelCtrl.dispose();
    _deepgramKeyCtrl.dispose();
    _gladiaKeyCtrl.dispose();
    _assemblyKeyCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final settings = await ApiService.getAdminSettings();
    if (mounted) {
      setState(() {
        _llmBaseUrlCtrl.text = (settings['llm_base_url']?.isNotEmpty == true) ? settings['llm_base_url']! : defaultOrcaUrl;
        _llmKeyCtrl.text = (settings['llm_api_key']?.isNotEmpty == true) ? settings['llm_api_key']! : defaultOrcaKey;
        _llmModelCtrl.text = (settings['llm_model']?.isNotEmpty == true) ? settings['llm_model']! : defaultOrcaModel;
        _deepgramKeyCtrl.text = settings['deepgram_api_key'] ?? '';
        _gladiaKeyCtrl.text = settings['gladia_api_key'] ?? '';
        _assemblyKeyCtrl.text = settings['assemblyai_api_key'] ?? '';
        _serverUrlCtrl.text = ApiConstants.baseUrl;
        _isLoading = false;
      });
    }
  }

  Future<void> _restoreDefaultLlm() async {
    setState(() {
      _llmBaseUrlCtrl.text = defaultOrcaUrl;
      _llmModelCtrl.text = defaultOrcaModel;
    });
    try {
      final settings = await ApiService.getAdminSettings();
      if (mounted) {
        setState(() {
          final serverKey = settings['llm_api_key'] ?? settings['orcarouter_api_key'];
          if (serverKey != null && serverKey.isNotEmpty) {
            _llmKeyCtrl.text = serverKey;
          } else if (defaultOrcaKey.isNotEmpty) {
            _llmKeyCtrl.text = defaultOrcaKey;
          }
        });
      }
    } catch (_) {
      if (mounted && defaultOrcaKey.isNotEmpty) {
        setState(() {
          _llmKeyCtrl.text = defaultOrcaKey;
        });
      }
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppTheme.accent,
          content: Text('Восстановлены параметры по умолчанию (OrcaRouter). Нажмите «Сохранить» для применения.'),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _testServerPing() async {
    setState(() {
      _isPingingServer = true;
      _serverPingResult = null;
      _serverPingSuccess = null;
    });
    var url = _serverUrlCtrl.text.trim();
    if (url.isEmpty) url = ApiConstants.defaultBaseUrl;
    if (url.endsWith('/')) url = url.substring(0, url.length - 1);
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
    }

    final stopwatch = Stopwatch()..start();
    try {
      final response = await http
          .get(Uri.parse('$url/api/health'))
          .timeout(const Duration(seconds: 5));
      stopwatch.stop();
      if (mounted) {
        if (response.statusCode == 200) {
          setState(() {
            _isPingingServer = false;
            _serverPingSuccess = true;
            _serverPingResult = 'Онлайн: ответ за ${stopwatch.elapsedMilliseconds} мс';
          });
        } else {
          setState(() {
            _isPingingServer = false;
            _serverPingSuccess = false;
            _serverPingResult = 'Ошибка HTTP ${response.statusCode}';
          });
        }
      }
    } catch (e) {
      stopwatch.stop();
      if (mounted) {
        setState(() {
          _isPingingServer = false;
          _serverPingSuccess = false;
          _serverPingResult = 'Сервер недоступен: $e';
        });
      }
    }
  }

  Future<void> _saveServerHost() async {
    final target = _serverUrlCtrl.text.trim();
    if (target.isEmpty) {
      ApiConstants.setBaseUrl(ApiConstants.defaultBaseUrl);
      await StorageService.setServerUrl('');
    } else {
      ApiConstants.setBaseUrl(target);
      await StorageService.setServerUrl(ApiConstants.baseUrl);
    }
    _serverUrlCtrl.text = ApiConstants.baseUrl;
    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.success,
          content: Text('Серверный хост обновлен: ${ApiConstants.baseUrl}'),
        ),
      );
    }
  }

  void _resetServerHost() {
    setState(() {
      _serverUrlCtrl.text = ApiConstants.defaultBaseUrl;
      _serverPingResult = null;
      _serverPingSuccess = null;
    });
    _testServerPing();
  }

  void _applyPreset(String name, String baseUrl, String model) {
    setState(() {
      _llmBaseUrlCtrl.text = baseUrl;
      _llmModelCtrl.text = model;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppTheme.primary,
        content: Text('Применен пресет: $name'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _saveAllSettings() async {
    setState(() => _isSaving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final Map<String, dynamic> payload = {
        'registration_enabled': widget.admin.registrationEnabled,
      };
      if (_llmBaseUrlCtrl.text.isNotEmpty) payload['llm_base_url'] = _llmBaseUrlCtrl.text.trim();
      if (_llmKeyCtrl.text.isNotEmpty && !_llmKeyCtrl.text.contains('***') && !_llmKeyCtrl.text.contains('...')) {
        payload['llm_api_key'] = _llmKeyCtrl.text.trim();
        payload['orcarouter_api_key'] = _llmKeyCtrl.text.trim();
      }
      if (_llmModelCtrl.text.isNotEmpty) payload['llm_model'] = _llmModelCtrl.text.trim();
      if (_deepgramKeyCtrl.text.isNotEmpty && !_deepgramKeyCtrl.text.contains('***') && !_deepgramKeyCtrl.text.contains('...')) {
        payload['deepgram_api_key'] = _deepgramKeyCtrl.text.trim();
      }
      if (_gladiaKeyCtrl.text.isNotEmpty && !_gladiaKeyCtrl.text.contains('***') && !_gladiaKeyCtrl.text.contains('...')) {
        payload['gladia_api_key'] = _gladiaKeyCtrl.text.trim();
      }
      if (_assemblyKeyCtrl.text.isNotEmpty && !_assemblyKeyCtrl.text.contains('***') && !_assemblyKeyCtrl.text.contains('...')) {
        payload['assemblyai_api_key'] = _assemblyKeyCtrl.text.trim();
      }

      await widget.admin.saveSettings(payload);
      messenger.showSnackBar(
        const SnackBar(backgroundColor: AppTheme.success, content: Text('Настройки успешно сохранены на сервере!')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(backgroundColor: AppTheme.error, content: Text('Ошибка сохранения: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
    }

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      children: [
        // Server Host Configuration Card
        GlassContainer(
          padding: const EdgeInsets.all(16),
          borderRadius: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.dns_rounded, color: AppTheme.cyan, size: 22),
                  SizedBox(width: 10),
                  Text('Сервер API (Server Host)', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Базовый адрес бэкенда приложения. Можно переключить на локальный сервер, VPS или AlwaysData.',
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
              ),
              const SizedBox(height: 14),

              TextField(
                controller: _serverUrlCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'URL бэкенда (хост)',
                  hintText: 'https://silenceteam.alwaysdata.net',
                  prefixIcon: const Icon(Icons.link_rounded, color: AppTheme.cyan, size: 18),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.clear_rounded, color: Color(0xFF64748B), size: 18),
                    onPressed: () => _serverUrlCtrl.clear(),
                  ),
                  labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                  filled: true,
                  fillColor: const Color(0xFF0F172A),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),

              if (_isPingingServer) ...[
                const SizedBox(height: 10),
                const Row(
                  children: [
                    SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.cyan)),
                    SizedBox(width: 10),
                    Text('Проверка доступности...', style: TextStyle(color: AppTheme.cyan, fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
              ] else if (_serverPingResult != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: (_serverPingSuccess == true ? AppTheme.success : AppTheme.error).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: (_serverPingSuccess == true ? AppTheme.success : AppTheme.error).withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _serverPingSuccess == true ? Icons.check_circle_rounded : Icons.error_rounded,
                        size: 16,
                        color: _serverPingSuccess == true ? AppTheme.success : AppTheme.error,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _serverPingResult!,
                          style: TextStyle(
                            color: _serverPingSuccess == true ? AppTheme.success : AppTheme.error,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 12),
              Row(
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.cyan,
                      side: const BorderSide(color: Color(0x4438BDF8)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.network_ping_rounded, size: 16),
                    label: const Text('Проверить пинг', style: TextStyle(fontSize: 12)),
                    onPressed: _isPingingServer ? null : _testServerPing,
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _resetServerHost,
                    child: const Text('Сбросить (Default)', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                  ),
                  const SizedBox(width: 6),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.cyan,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _saveServerHost,
                    child: const Text('Применить', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Registration Switch Card
        GlassContainer(
          padding: const EdgeInsets.all(16),
          borderRadius: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.how_to_reg_rounded, color: AppTheme.cyan, size: 20),
                  SizedBox(width: 10),
                  Text('Регистрация пользователей', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Свободная регистрация', style: TextStyle(color: Colors.white, fontSize: 14)),
                subtitle: const Text('Если выключено, регистрация на экране входа будет скрыта и заблокирована', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                value: widget.admin.registrationEnabled,
                activeColor: AppTheme.cyan,
                onChanged: (_) => widget.admin.toggleRegistration(),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Universal AI Gateway Card
        GlassContainer(
          padding: const EdgeInsets.all(16),
          borderRadius: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.psychology_rounded, color: AppTheme.accent, size: 22),
                  SizedBox(width: 10),
                  Text('Универсальный AI-шлюз (LLM)', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Поддерживается ЛЮБОЙ OpenAI-совместимый провайдер, Base URL и API-ключ. Все вычисления производятся удаленно в облаке без нагрузки на телефон.',
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
              ),
              const SizedBox(height: 12),

              // Quick presets
              const Text('Быстрые пресеты:', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ActionChip(
                    backgroundColor: const Color(0xFF161F30),
                    avatar: const Icon(Icons.bolt_rounded, color: AppTheme.cyan, size: 16),
                    label: const Text('OrcaRouter', style: TextStyle(color: Colors.white, fontSize: 12)),
                    onPressed: () => _applyPreset('OrcaRouter', 'https://api.orcarouter.ai/v1', 'deepseek/deepseek-v4-flash-free'),
                  ),
                  ActionChip(
                    backgroundColor: const Color(0xFF161F30),
                    avatar: const Icon(Icons.speed_rounded, color: AppTheme.accent, size: 16),
                    label: const Text('Groq Cloud (Быстро)', style: TextStyle(color: Colors.white, fontSize: 12)),
                    onPressed: () => _applyPreset('Groq', 'https://api.groq.com/openai/v1', 'llama-3.3-70b-versatile'),
                  ),
                  ActionChip(
                    backgroundColor: const Color(0xFF161F30),
                    avatar: const Icon(Icons.hub_rounded, color: AppTheme.secondary, size: 16),
                    label: const Text('OpenRouter', style: TextStyle(color: Colors.white, fontSize: 12)),
                    onPressed: () => _applyPreset('OpenRouter', 'https://openrouter.ai/api/v1', 'deepseek/deepseek-chat'),
                  ),
                  ActionChip(
                    backgroundColor: const Color(0xFF161F30),
                    avatar: const Icon(Icons.alt_route_rounded, color: AppTheme.primaryLight, size: 16),
                    label: const Text('DeepSeek Direct', style: TextStyle(color: Colors.white, fontSize: 12)),
                    onPressed: () => _applyPreset('DeepSeek Direct', 'https://api.deepseek.com/v1', 'deepseek-chat'),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.accent,
                    backgroundColor: AppTheme.accent.withOpacity(0.12),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.settings_backup_restore_rounded, size: 16),
                  label: const Text('⚡ Восстановить по умолчанию (OrcaRouter)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  onPressed: _restoreDefaultLlm,
                ),
              ),

              const SizedBox(height: 16),

              TextField(
                controller: _llmBaseUrlCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'LLM Base URL (OpenAI-compatible)',
                  hintText: 'https://api.orcarouter.ai/v1',
                  prefixIcon: const Icon(Icons.link_rounded, color: AppTheme.cyan, size: 18),
                  labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                  filled: true,
                  fillColor: const Color(0xFF0F172A),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),

              const SizedBox(height: 12),

              TextField(
                controller: _llmKeyCtrl,
                obscureText: _obscureLlmKey,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'API Key (Провайдера / OrcaRouter)',
                  prefixIcon: const Icon(Icons.key_rounded, color: AppTheme.accent, size: 18),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureLlmKey ? Icons.visibility_off : Icons.visibility, color: const Color(0xFF64748B), size: 18),
                    onPressed: () => setState(() => _obscureLlmKey = !_obscureLlmKey),
                  ),
                  labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                  filled: true,
                  fillColor: const Color(0xFF0F172A),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),

              const SizedBox(height: 12),

              TextField(
                controller: _llmModelCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'Модель нейросети (ID модели)',
                  hintText: 'deepseek/deepseek-v4-flash-free',
                  prefixIcon: const Icon(Icons.model_training_rounded, color: AppTheme.primaryLight, size: 18),
                  labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                  filled: true,
                  fillColor: const Color(0xFF0F172A),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // STT Configuration Card
        GlassContainer(
          padding: const EdgeInsets.all(16),
          borderRadius: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.mic_rounded, color: AppTheme.secondary, size: 22),
                  SizedBox(width: 10),
                  Text('Ключи распознавания речи (STT)', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Резервный каскад транскрибации автоматически пробует доступные шлюзы.',
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
              ),
              const SizedBox(height: 14),

              TextField(
                controller: _deepgramKeyCtrl,
                obscureText: _obscureDgKey,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'Deepgram API Key (Nova-2 RU)',
                  prefixIcon: const Icon(Icons.vpn_key_rounded, color: AppTheme.secondary, size: 18),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureDgKey ? Icons.visibility_off : Icons.visibility, color: const Color(0xFF64748B), size: 18),
                    onPressed: () => setState(() => _obscureDgKey = !_obscureDgKey),
                  ),
                  labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                  filled: true,
                  fillColor: const Color(0xFF0F172A),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),

              const SizedBox(height: 12),

              TextField(
                controller: _gladiaKeyCtrl,
                obscureText: _obscureGladiaKey,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'Gladia API Key (Шумоподавление)',
                  prefixIcon: const Icon(Icons.graphic_eq_rounded, color: AppTheme.cyan, size: 18),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureGladiaKey ? Icons.visibility_off : Icons.visibility, color: const Color(0xFF64748B), size: 18),
                    onPressed: () => setState(() => _obscureGladiaKey = !_obscureGladiaKey),
                  ),
                  labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                  filled: true,
                  fillColor: const Color(0xFF0F172A),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),

              const SizedBox(height: 12),

              TextField(
                controller: _assemblyKeyCtrl,
                obscureText: _obscureAssemblyKey,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'AssemblyAI API Key',
                  prefixIcon: const Icon(Icons.audiotrack_rounded, color: AppTheme.primaryLight, size: 18),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureAssemblyKey ? Icons.visibility_off : Icons.visibility, color: const Color(0xFF64748B), size: 18),
                    onPressed: () => setState(() => _obscureAssemblyKey = !_obscureAssemblyKey),
                  ),
                  labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                  filled: true,
                  fillColor: const Color(0xFF0F172A),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primary,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          icon: _isSaving
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.save_rounded, color: Colors.white),
          label: Text(_isSaving ? 'Сохранение...' : 'Сохранить все настройки', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
          onPressed: _isSaving ? null : _saveAllSettings,
        ),

        const SizedBox(height: 28),
      ],
    );
  }
}
