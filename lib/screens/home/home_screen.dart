import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/locale_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/lecture_provider.dart';
import '../../providers/admin_provider.dart';
import '../lectures/lecture_list_tab.dart';
import '../chat/ai_chat_screen.dart';
import '../record/record_lecture_screen.dart';
import '../admin/admin_dashboard_tab.dart';
import '../profile/profile_tab.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<LectureProvider>(context, listen: false).fetchLectures();
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (auth.isAdmin) {
        Provider.of<AdminProvider>(context, listen: false).fetchDashboardData();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final localeProvider = Provider.of<LocaleProvider>(context);
    final t = localeProvider.t;
    final isAdmin = auth.isAdmin;

    final tabs = [
      const LectureListTab(),
      const RecordLectureScreen(),
      const AiChatScreen(),
      if (isAdmin) const AdminDashboardTab(),
      const ProfileTab(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex >= tabs.length ? 0 : _currentIndex,
        children: tabs,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0x22475569), width: 1)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex >= tabs.length ? 0 : _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          items: [
            BottomNavigationBarItem(
              icon: const Icon(Icons.library_books_rounded),
              label: t.navLectures,
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.fiber_smart_record_rounded),
              label: t.navRecord,
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.psychology_rounded),
              label: t.navAiChat,
            ),
            if (isAdmin)
              BottomNavigationBarItem(
                icon: const Icon(Icons.admin_panel_settings_rounded),
                label: t.navAdmin,
              ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.person_rounded),
              label: t.navProfile,
            ),
          ],
        ),
      ),
    );
  }
}
