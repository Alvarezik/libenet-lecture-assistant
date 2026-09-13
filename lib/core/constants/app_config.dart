/// Конфигурация внешних AI и STT шлюзов приложения LibeNetLA.
///
/// Безопасная архитектура: ключи не хранятся в открытом коде репозитория.
/// Они могут передаваться при компиляции через флаги:
///   flutter build apk --dart-define=GLADIA_API_KEY=... --dart-define=DEEPGRAM_API_KEY=...
/// По умолчанию все запросы транскрибации и генерации конспектов
/// направляются через защищенный серверный шлюз LibeNet API.
class AppConfig {
  static const String gladiaApiKey = String.fromEnvironment('GLADIA_API_KEY', defaultValue: '');
  static const String deepgramApiKey = String.fromEnvironment('DEEPGRAM_API_KEY', defaultValue: '');
  static const String orcaApiKey = String.fromEnvironment('ORCAROUTER_API_KEY', defaultValue: '');

  static bool get hasDirectGladia => gladiaApiKey.isNotEmpty;
  static bool get hasDirectDeepgram => deepgramApiKey.isNotEmpty;
  static bool get hasDirectOrca => orcaApiKey.isNotEmpty;
}
