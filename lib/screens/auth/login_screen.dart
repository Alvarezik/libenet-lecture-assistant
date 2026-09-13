import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/api_service.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/glass_container.dart';
import '../home/home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLogin = true;
  bool _registrationEnabled = ApiService.cachedRegistrationEnabled ?? true;

  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _fullNameController = TextEditingController();

  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _checkRegistrationSetting();
  }

  Future<void> _checkRegistrationSetting() async {
    final enabled = await ApiService.isRegistrationEnabled();
    if (mounted && _registrationEnabled != enabled) {
      setState(() {
        _registrationEnabled = enabled;
        if (!enabled) {
          _isLogin = true;
        }
      });
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _fullNameController.dispose();
    super.dispose();
  }

  void _submit() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    if (username.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppTheme.error,
          content: Text('Пожалуйста, укажите логин и пароль'),
        ),
      );
      return;
    }

    bool ok = false;
    if (_isLogin) {
      ok = await authProvider.login(username, password);
    } else {
      final email = _emailController.text.trim();
      final fullName = _fullNameController.text.trim();
      if (email.isEmpty || !email.contains('@')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppTheme.error,
            content: Text('Введите корректный email адрес'),
          ),
        );
        return;
      }
      ok = await authProvider.register(username, email, password, fullName);
    }

    if (ok && mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } else if (mounted && authProvider.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.error,
          content: Text(authProvider.errorMessage!),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF070B14), Color(0xFF0F172A), Color(0xFF070B14)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Clean Modern App Squircle Logo
                  Container(
                    width: 92,
                    height: 92,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      color: const Color(0xFF111827),
                      border: Border.all(
                        color: AppTheme.primaryLight.withOpacity(0.4),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primary.withOpacity(0.35),
                          blurRadius: 20,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.asset(
                        'assets/images/logo.png',
                        width: 92,
                        height: 92,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  const Text(
                    'LibeNetLA',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'LibeNet Lecture Assistant • Voice AI Studio',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF94A3B8),
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Auth Card
                  GlassContainer(
                    padding: const EdgeInsets.all(24),
                    borderRadius: 26,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Tabs (ONLY rendered if registration is enabled)
                        if (_registrationEnabled) ...[
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            padding: const EdgeInsets.all(4),
                            child: Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => setState(() => _isLogin = true),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                      decoration: BoxDecoration(
                                        color: _isLogin ? AppTheme.primary : Colors.transparent,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Center(
                                        child: Text(
                                          'Вход',
                                          style: TextStyle(
                                            color: _isLogin ? Colors.white : const Color(0xFF94A3B8),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => setState(() => _isLogin = false),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                      decoration: BoxDecoration(
                                        color: !_isLogin ? AppTheme.primary : Colors.transparent,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Center(
                                        child: Text(
                                          'Регистрация',
                                          style: TextStyle(
                                            color: !_isLogin ? Colors.white : const Color(0xFF94A3B8),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                        ] else ...[
                          const Text(
                            'Вход в систему',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 18),
                        ],

                        // Username Field
                        TextField(
                          controller: _usernameController,
                          style: const TextStyle(color: Colors.white, fontSize: 15),
                          decoration: InputDecoration(
                            labelText: 'Логин',
                            labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                            prefixIcon: const Icon(Icons.person_outline_rounded, color: AppTheme.primaryLight, size: 20),
                            filled: true,
                            fillColor: const Color(0xFF0B101E),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                          ),
                        ),

                        if (!_isLogin && _registrationEnabled) ...[
                          const SizedBox(height: 12),
                          TextField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            style: const TextStyle(color: Colors.white, fontSize: 15),
                            decoration: InputDecoration(
                              labelText: 'Email',
                              labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                              prefixIcon: const Icon(Icons.mail_outline_rounded, color: AppTheme.secondary, size: 20),
                              filled: true,
                              fillColor: const Color(0xFF0B101E),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _fullNameController,
                            style: const TextStyle(color: Colors.white, fontSize: 15),
                            decoration: InputDecoration(
                              labelText: 'ФИО (необязательно)',
                              labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                              prefixIcon: const Icon(Icons.badge_outlined, color: AppTheme.accent, size: 20),
                              filled: true,
                              fillColor: const Color(0xFF0B101E),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                            ),
                          ),
                        ],

                        const SizedBox(height: 12),

                        // Password Field
                        TextField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          style: const TextStyle(color: Colors.white, fontSize: 15),
                          decoration: InputDecoration(
                            labelText: 'Пароль',
                            labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                            prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppTheme.primaryLight, size: 20),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                color: const Color(0xFF64748B),
                                size: 20,
                              ),
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            ),
                            filled: true,
                            fillColor: const Color(0xFF0B101E),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                          ),
                        ),

                        const SizedBox(height: 22),

                        // Action Button
                        CustomButton(
                          text: _isLogin ? 'Войти в аккаунт' : 'Зарегистрироваться',
                          icon: _isLogin ? Icons.login_rounded : Icons.person_add_rounded,
                          isLoading: auth.isLoading,
                          onPressed: _submit,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  const Text(
                    '© LibeNet • Все права защищены',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
