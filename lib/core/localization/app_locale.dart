
class AppLocale {
  final String languageCode;

  const AppLocale(this.languageCode);

  bool get isRu => languageCode == 'ru';
  bool get isEn => languageCode == 'en';

  // Navigation
  String get navLectures => isRu ? 'Лекции' : 'Lectures';
  String get navRecord => isRu ? 'Запись' : 'Record';
  String get navAiChat => isRu ? 'AI Чат' : 'AI Chat';
  String get navAdmin => isRu ? 'Админка' : 'Admin';
  String get navProfile => isRu ? 'Профиль' : 'Profile';

  // Profile & Settings
  String get profileAndSettings => isRu ? 'Профиль и Настройки' : 'Profile & Settings';
  String get user => isRu ? 'Пользователь' : 'User';
  String get adminRole => isRu ? 'Администратор' : 'Administrator';
  String get studentRole => isRu ? 'Студент / Пользователь' : 'Student / User';
  String get apiServicesStatus => isRu ? 'Состояние API & Сервисов' : 'API & Services Status';
  String get checkPing => isRu ? 'Проверить пинг' : 'Check Ping';
  String get appSettings => isRu ? 'Настройки приложения' : 'App Settings';
  String get perfMode => isRu ? 'Режим высокой производительности' : 'High Performance Mode';
  String get perfModeDesc => isRu
      ? 'Отключает тяжелые размытия для максимальной скорости на слабых устройствах'
      : 'Disables heavy blurs for maximum speed on low-end devices';
  String get perfModeOn => isRu ? 'Режим высокой производительности включен' : 'High performance mode enabled';
  String get perfModeOff => isRu ? 'Стандартный визуальный режим включен' : 'Standard visual mode enabled';

  // Language settings
  String get appLanguage => isRu ? 'Язык приложения' : 'App Language';
  String get appLanguageDesc => isRu ? 'Русский (RU) / English (EN)' : 'Russian (RU) / English (EN)';
  String get selectLanguage => isRu ? 'Выберите язык интерфейса' : 'Select Interface Language';
  String get russianLang => isRu ? '🇷🇺 Русский' : '🇷🇺 Russian';
  String get englishLang => isRu ? '🇬🇧 English' : '🇬🇧 English';

  // API Server Host
  String get apiServerHost => isRu ? 'Сервер API (Хостинг)' : 'API Server Host';
  String get apiServerHostDesc => isRu
      ? 'Адрес бэкенда для синхронизации и AI обработки'
      : 'Backend address for sync and AI processing';
  String get currentHost => isRu ? 'Текущий хост' : 'Current Host';
  String get changeHost => isRu ? 'Сменить адрес сервера' : 'Change Server Host';
  String get serverUrlHint => isRu ? 'https://silenceteam.alwaysdata.net или свой IP:порт' : 'https://silenceteam.alwaysdata.net or your IP:port';
  String get testPing => isRu ? 'Проверить связь' : 'Test Ping';
  String get testingPing => isRu ? 'Проверка...' : 'Testing...';
  String pingSuccess(dynamic ms) {
    final int val = ms is num ? ms.round() : (int.tryParse(ms?.toString() ?? '') ?? 0);
    return isRu ? 'Онлайн • пинг $val мс' : 'Online • latency $val ms';
  }
  String get pingFailed => isRu ? 'Ошибка подключения к серверу' : 'Server connection failed';
  String get resetDefault => isRu ? 'По умолчанию' : 'Reset Default';
  String get hostUpdated => isRu ? 'Адрес сервера обновлен' : 'Server host updated';
  String get invalidUrl => isRu ? 'Введите корректный адрес (начиная с http:// или https://)' : 'Enter a valid URL (starting with http:// or https://)';

  // About App
  String get aboutApp => isRu ? 'О приложении' : 'About App';
  String get appVersionDesc => isRu
      ? 'LibeNet Lecture Assistant • Студия конспектирования лекций на базе искусственного интеллекта.'
      : 'LibeNet Lecture Assistant • AI-powered lecture transcription and summarization studio.';
  String get logout => isRu ? 'Выйти из аккаунта' : 'Log Out';
  String get copyright => isRu ? '© 2026 LibeNet • All rights reserved' : '© 2026 LibeNet • All rights reserved';

  // Diagnostics items
  String get hostApiTitle => isRu ? 'API Сервер' : 'API Server Host';
  String get dbTitle => isRu ? 'База данных MySQL 8.0' : 'MySQL 8.0 Database';
  String get deepgramTitle => isRu ? 'Deepgram Nova-2' : 'Deepgram Nova-2';
  String get neuralEngineTitle => isRu ? 'Нейросеть LibeNet NLP' : 'LibeNet NLP Neural Engine';
  String get connecting => isRu ? 'Подключение...' : 'Connecting...';
  String get dbConnected => isRu ? 'Подключена' : 'Connected';
  String get dbError => isRu ? 'Ошибка соединения' : 'Connection error';
  String get engineReady => isRu ? 'Готова к очистке от воды' : 'Ready for summarization';
  String get initializing => isRu ? 'Инициализация...' : 'Initializing...';

  // Common buttons
  String get save => isRu ? 'Сохранить' : 'Save';
  String get cancel => isRu ? 'Отмена' : 'Cancel';
  String get close => isRu ? 'Закрыть' : 'Close';
  String get ok => isRu ? 'ОК' : 'OK';
  String get copy => isRu ? 'Копировать' : 'Copy';
  String get copied => isRu ? 'Скопировано' : 'Copied';

  // Lectures
  String get myLectures => isRu ? 'Библиотека лекций' : 'Lecture Library';
  String get searchLectures => isRu ? 'Поиск по лекциям...' : 'Search lectures...';
  String get noLecturesYet => isRu ? 'Лекций пока нет' : 'No lectures yet';
  String get tabSummary => isRu ? 'Конспект' : 'Summary';
  String get tabTranscription => isRu ? 'Транскрипция' : 'Transcription';
  String get tabQuiz => isRu ? 'Тест' : 'Quiz';
  String get tabMindmap => isRu ? 'Интеллект-карта' : 'Mind Map';
  String get tabAudio => isRu ? 'Аудио' : 'Audio';
  String get retranscribe => isRu ? 'Пересоздать транскрипцию' : 'Retranscribe';
  String get rawTranscript => isRu ? 'Исходный текст' : 'Raw Transcript';
  String get downloadAudio => isRu ? 'Скачать аудио' : 'Download Audio';

  // Record
  String get recordStudio => isRu ? 'Студия записи' : 'Recording Studio';
  String get startRecord => isRu ? 'Начать запись' : 'Start Recording';
  String get pauseRecord => isRu ? 'Пауза' : 'Pause';
  String get resumeRecord => isRu ? 'Продолжить' : 'Resume';
  String get stopAndSave => isRu ? 'Остановить и обработать' : 'Stop & Process';
  String get recordingActive => isRu ? 'Идет запись...' : 'Recording in progress...';
  String get importAudio => isRu ? 'Импорт аудио' : 'Import Audio';
}
