import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'core/constants/api_constants.dart';
import 'core/services/storage_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/api_service.dart';
import 'providers/locale_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/lecture_provider.dart';
import 'providers/admin_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/lectures/lecture_detail_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Catch Flutter framework errors
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      try {
        ApiService.sendClientLog(
          'FLUTTER_ERROR',
          'ERROR',
          '${details.exceptionAsString()}\n${details.stack}',
        );
      } catch (_) {}
    };

    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    // Restore custom server URL if configured
    try {
      final customServerUrl = await StorageService.getServerUrl();
      if (customServerUrl != null && customServerUrl.isNotEmpty) {
        ApiConstants.setBaseUrl(customServerUrl);
      }
    } catch (e) {
      debugPrint('Error restoring server URL: $e');
    }

    try {
      await NotificationService.init();
      NotificationService.onNotificationTapped = (int lectureId) {
        navigatorKey.currentState?.push(
          MaterialPageRoute(builder: (_) => LectureDetailScreen(lectureId: lectureId)),
        );
      };
    } catch (e) {
      debugPrint('Notification init error: $e');
    }

    runApp(const LibeNetApp());
  }, (error, stackTrace) {
    final errStr = error.toString();
    if (errStr.contains('Bad state: No element') ||
        errStr.contains('AudioPlayer.seek') ||
        errStr.contains('AudioPlayerService.seek') ||
        errStr.contains('TimeoutException after 0:00:30')) {
      return; // Benign platform stream or teardown, do not spam audit logs
    }
    debugPrint('Uncaught async error: $error\n$stackTrace');
    try {
      ApiService.sendClientLog('UNCAUGHT_ASYNC_ERROR', 'ERROR', '$error\n$stackTrace');
    } catch (_) {}
  });
}

class LibeNetApp extends StatelessWidget {
  const LibeNetApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => LectureProvider()),
        ChangeNotifierProvider(create: (_) => AdminProvider()),
      ],
      child: Consumer<LocaleProvider>(
        builder: (context, localeProvider, _) {
          return MaterialApp(
            navigatorKey: navigatorKey,
            title: 'LibeNetLA',
            debugShowCheckedModeBanner: false,
            locale: localeProvider.flutterLocale,
            theme: AppTheme.darkTheme,
            home: const AuthWrapper(),
          );
        },
      ),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AuthProvider>(context, listen: false).checkAuth();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    if (auth.isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppTheme.primary),
        ),
      );
    }

    if (auth.isAuthenticated) {
      return const HomeScreen();
    }

    return const LoginScreen();
  }
}
