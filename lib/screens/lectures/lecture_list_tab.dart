import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/lecture_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/lecture_model.dart';
import '../../widgets/glass_container.dart';
import '../../widgets/status_badge.dart';
import 'lecture_detail_screen.dart';

class LectureListTab extends StatefulWidget {
  const LectureListTab({super.key});

  @override
  State<LectureListTab> createState() => _LectureListTabState();
}

class _LectureListTabState extends State<LectureListTab> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lectureProvider = Provider.of<LectureProvider>(context);
    final auth = Provider.of<AuthProvider>(context);
    final lectures = lectureProvider.lectures;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                'assets/images/logo.png',
                width: 32,
                height: 32,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(Icons.mic, color: AppTheme.primaryLight),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'LibeNetLA',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, letterSpacing: -0.3),
                ),
                Text(
                  'Привет, ${auth.user?.fullName.isNotEmpty == true ? auth.user!.fullName : auth.user?.username ?? 'Студент'}! 👋',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => lectureProvider.fetchLectures(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => lectureProvider.fetchLectures(),
        child: Column(
          children: [
            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextField(
                controller: _searchController,
                onChanged: (val) => lectureProvider.setSearchQuery(val),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Поиск лекций, тем, предметов...',
                  hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
                  prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF818CF8)),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Color(0xFF64748B), size: 18),
                          onPressed: () {
                            _searchController.clear();
                            lectureProvider.setSearchQuery('');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: const Color(0xFF1E293B).withOpacity(0.6),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0x33475569)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0x33475569)),
                  ),
                ),
              ),
            ),

            // Lectures List
            Expanded(
              child: lectureProvider.isLoading && lectures.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : lectures.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: lectures.length + 1,
                          itemBuilder: (context, index) {
                            if (index == lectures.length) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 20),
                                child: Center(
                                  child: Text(
                                    '© LibeNet • AI Lecture Assistant',
                                    style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                                  ),
                                ),
                              );
                            }
                            final item = lectures[index];
                            return _buildLectureCard(item, index);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.primary.withOpacity(0.12),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(30),
                      child: Image.asset(
                        'assets/images/logo.png',
                        width: 64,
                        height: 64,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Icon(Icons.mic_none_outlined, size: 54, color: AppTheme.primaryLight),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Лекций пока нет',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Нажмите на вкладку «Запись», чтобы записать свою первую лекцию и получить AI-конспект без воды!',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8), height: 1.4),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    '© LibeNet',
                    style: TextStyle(fontSize: 11, color: Color(0xFF475569)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLectureCard(LectureModel item, int index) {
    return GlassContainer(
      margin: const EdgeInsets.only(bottom: 14),
      borderRadius: 20,
      padding: const EdgeInsets.all(16),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => LectureDetailScreen(lectureId: item.id)),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: item.hasSummary ? AppTheme.primaryGradient : AppTheme.cardGradient,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  item.hasSummary ? Icons.auto_awesome : Icons.audio_file_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (item.subject.isNotEmpty) ...[
                          Text(
                            item.subject,
                            style: const TextStyle(fontSize: 12, color: AppTheme.primaryLight, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(width: 8),
                          const Text('•', style: TextStyle(color: Color(0xFF64748B))),
                          const SizedBox(width: 8),
                        ],
                        if (item.teacherName.isNotEmpty)
                          Expanded(
                            child: Text(
                              item.teacherName,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              StatusBadge(status: item.status),
            ],
          ),

          const SizedBox(height: 14),
          const Divider(color: Color(0x22475569), height: 1),
          const SizedBox(height: 10),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.timer_outlined, size: 14, color: Color(0xFF94A3B8)),
                  const SizedBox(width: 4),
                  Text(
                    item.formattedDuration,
                    style: const TextStyle(fontSize: 12, color: Color(0xFFCBD5E1), fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(width: 14),
                  const Icon(Icons.storage_rounded, size: 14, color: Color(0xFF94A3B8)),
                  const SizedBox(width: 4),
                  Text(
                    item.formattedFileSize,
                    style: const TextStyle(fontSize: 12, color: Color(0xFFCBD5E1), fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              const Icon(Icons.arrow_forward_ios_rounded, size: 13, color: Color(0xFF64748B)),
            ],
          ),
        ],
      ),
    );
  }
}
