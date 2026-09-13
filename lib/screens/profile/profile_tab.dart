import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/api_service.dart';
import '../../core/services/storage_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/locale_provider.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/glass_container.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  bool _performanceMode = false;
  bool _isLoadingHealth = false;
  Map<String, dynamic> _healthData = {};

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _checkHealth();
  }

  Future<void> _loadSettings() async {
    final perf = await StorageService.getPerformanceMode();
    if (mounted) setState(() => _performanceMode = perf);
  }

  Future<void> _checkHealth() async {
    if (!mounted) return;
    setState(() => _isLoadingHealth = true);
    try {
      final data = await ApiService.getSystemHealthDetails();
      if (mounted) {
        setState(() {
          _healthData = data;
          _isLoadingHealth = false;
        });
      }
    } catch (e) {
      debugPrint('Error checking health: $e');
      if (mounted) {
        setState(() {
          _isLoadingHealth = false;
        });
      }
    }
  }

  void _togglePerformanceMode(bool val) async {
    final t = Provider.of<LocaleProvider>(context, listen: false).t;
    setState(() => _performanceMode = val);
    await StorageService.setPerformanceMode(val);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.primary,
          content: Text(val ? t.perfModeOn : t.perfModeOff),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _showLanguageSelector(BuildContext context) {
    final localeProvider = Provider.of<LocaleProvider>(context, listen: false);
    final t = localeProvider.t;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Color(0xFF0F172A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(top: BorderSide(color: Color(0x336366F1), width: 1.5)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    const Icon(Icons.translate_rounded, color: AppTheme.cyan, size: 24),
                    const SizedBox(width: 12),
                    Text(
                      t.selectLanguage,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _buildLanguageOption(
                  ctx: ctx,
                  code: 'ru',
                  title: 'Русский',
                  flag: '🇷🇺',
                  subtitle: 'Русский язык (Russian)',
                  isSelected: localeProvider.languageCode == 'ru',
                  onSelect: () async {
                    await localeProvider.setLocale('ru');
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                ),
                const SizedBox(height: 12),
                _buildLanguageOption(
                  ctx: ctx,
                  code: 'en',
                  title: 'English',
                  flag: '🇬🇧',
                  subtitle: 'English language (English)',
                  isSelected: localeProvider.languageCode == 'en',
                  onSelect: () async {
                    await localeProvider.setLocale('en');
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLanguageOption({
    required BuildContext ctx,
    required String code,
    required String title,
    required String flag,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onSelect,
  }) {
    return InkWell(
      onTap: onSelect,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary.withOpacity(0.18) : const Color(0x11FFFFFF),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppTheme.primaryLight : const Color(0x22475569),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Text(flag, style: const TextStyle(fontSize: 26)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? Colors.white : const Color(0xFFE2E8F0),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle_rounded, color: AppTheme.cyan, size: 22)
            else
              const Icon(Icons.radio_button_unchecked_rounded, color: Color(0xFF64748B), size: 22),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final localeProvider = Provider.of<LocaleProvider>(context);
    final t = localeProvider.t;
    final user = auth.user;

    final hostInfo = _healthData['host'] as Map<String, dynamic>?;
    final dbInfo = _healthData['database'] as Map<String, dynamic>?;
    final dgInfo = _healthData['deepgram'] as Map<String, dynamic>?;
    final engineInfo = _healthData['neural_engine'] as Map<String, dynamic>?;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset('assets/images/logo.png', width: 28, height: 28, fit: BoxFit.contain),
            ),
            const SizedBox(width: 10),
            Text(t.profileAndSettings, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
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
              // User Avatar & Name Card
              GlassContainer(
                padding: const EdgeInsets.all(22),
                borderRadius: 24,
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: user?.isAdmin == true ? AppTheme.primaryGradient : AppTheme.cyanGradient,
                      ),
                      child: CircleAvatar(
                        radius: 38,
                        backgroundColor: const Color(0xFF0F172A),
                        child: Icon(
                          user?.isAdmin == true ? Icons.shield_rounded : Icons.person_rounded,
                          size: 40,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      user?.fullName.isNotEmpty == true ? user!.fullName : user?.username ?? t.user,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user?.email ?? '',
                      style: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: user?.isAdmin == true ? AppTheme.accent.withOpacity(0.2) : AppTheme.primary.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: user?.isAdmin == true ? AppTheme.accent.withOpacity(0.4) : AppTheme.primaryLight.withOpacity(0.4),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            user?.isAdmin == true ? Icons.verified_user_rounded : Icons.school_rounded,
                            size: 14,
                            color: user?.isAdmin == true ? AppTheme.accent : AppTheme.primaryLight,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            user?.isAdmin == true ? t.adminRole : t.studentRole,
                            style: TextStyle(
                              color: user?.isAdmin == true ? AppTheme.accent : AppTheme.primaryLight,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // System Diagnostics & Health Status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(t.apiServicesStatus, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                  IconButton(
                    icon: _isLoadingHealth
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.cyan))
                        : const Icon(Icons.sync_rounded, color: AppTheme.cyan, size: 20),
                    onPressed: _isLoadingHealth ? null : _checkHealth,
                    tooltip: t.checkPing,
                  ),
                ],
              ),
              const SizedBox(height: 8),

              GlassContainer(
                borderRadius: 20,
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildHealthRow(
                      title: t.hostApiTitle,
                      subtitle: hostInfo != null ? t.pingSuccess((hostInfo['latency_ms'] as num?)?.round() ?? 0) : t.connecting,
                      icon: Icons.cloud_done_rounded,
                      isOk: hostInfo != null && hostInfo['status'] == 'online',
                    ),
                    const Divider(color: Color(0x22475569), height: 18),
                    _buildHealthRow(
                      title: t.dbTitle,
                      subtitle: dbInfo != null && dbInfo['connected'] == true
                          ? '${t.dbConnected} • ${(dbInfo['latency_ms'] as num?)?.round() ?? 0} ms'
                          : t.dbError,
                      icon: Icons.storage_rounded,
                      isOk: dbInfo != null && dbInfo['connected'] == true,
                    ),
                    const Divider(color: Color(0x22475569), height: 18),
                    _buildHealthRow(
                      title: t.deepgramTitle,
                      subtitle: dgInfo != null ? '${dgInfo['status'] ?? 'Ready'} • ${(dgInfo['latency_ms'] as num?)?.round() ?? 0} ms' : t.connecting,
                      icon: Icons.record_voice_over_rounded,
                      isOk: dgInfo != null && dgInfo['connected'] == true,
                    ),
                    const Divider(color: Color(0x22475569), height: 18),
                    _buildHealthRow(
                      title: t.neuralEngineTitle,
                      subtitle: engineInfo != null ? t.engineReady : t.initializing,
                      icon: Icons.psychology_rounded,
                      isOk: true,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Application Settings
              Text(t.appSettings, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
              const SizedBox(height: 8),

              // Language Setting Tile
              GlassContainer(
                borderRadius: 20,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.translate_rounded, color: AppTheme.primaryLight, size: 22),
                  ),
                  title: Text(
                    t.appLanguage,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  subtitle: Text(
                    localeProvider.isRu ? '🇷🇺 Русский (Russian)' : '🇬🇧 English (English)',
                    style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0x22FFFFFF),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0x336366F1)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          localeProvider.languageCode.toUpperCase(),
                          style: const TextStyle(color: AppTheme.cyan, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFF94A3B8), size: 12),
                      ],
                    ),
                  ),
                  onTap: () => _showLanguageSelector(context),
                ),
              ),



              const SizedBox(height: 10),

              // Performance Mode Toggle
              GlassContainer(
                borderRadius: 20,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.warning.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.speed_rounded, color: AppTheme.warning, size: 22),
                  ),
                  title: Text(
                    t.perfMode,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  subtitle: Text(
                    t.perfModeDesc,
                    style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                  ),
                  value: _performanceMode,
                  activeColor: AppTheme.warning,
                  onChanged: _togglePerformanceMode,
                ),
              ),

              const SizedBox(height: 20),

              // About App Card
              GlassContainer(
                borderRadius: 20,
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.asset('assets/images/logo.png', width: 44, height: 44, fit: BoxFit.contain),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('LibeNetLA v2.3.0', style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white, fontSize: 14)),
                          const SizedBox(height: 2),
                          Text(
                            t.appVersionDesc,
                            style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), height: 1.3),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              CustomButton(
                text: t.logout,
                icon: Icons.logout_rounded,
                isSecondary: true,
                onPressed: () async {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                  await auth.logout();
                },
              ),

              const SizedBox(height: 24),
              Center(
                child: Text(
                  t.copyright,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHealthRow({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isOk,
  }) {
    final color = isOk ? AppTheme.success : AppTheme.error;
    return Row(
      children: [
        Icon(icon, color: isOk ? AppTheme.cyan : AppTheme.error, size: 22),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
              Text(subtitle, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
        Icon(
          isOk ? Icons.check_circle_rounded : Icons.error_outline_rounded,
          color: color,
          size: 18,
        ),
      ],
    );
  }
}
