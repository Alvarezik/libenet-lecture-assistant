import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;
  static Function(int lectureId)? onNotificationTapped;

  static const int recordingNotificationId = 1001;
  static const int lectureReadyNotificationId = 1002;

  static Future<void> init() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        if (response.payload != null && response.payload!.isNotEmpty) {
          final id = int.tryParse(response.payload!);
          if (id != null && onNotificationTapped != null) {
            onNotificationTapped!(id);
          }
        }
      },
    );

    final androidImplementation = _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidImplementation?.requestNotificationsPermission();

    _initialized = true;
  }

  static Future<void> showRecordingNotification({
    required String timeString,
    required bool isPaused,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      'libenet_record_channel',
      'Запись лекций',
      channelDescription: 'Уведомление о текущем процессе записи лекции',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      showWhen: false,
      icon: '@mipmap/ic_launcher',
      subText: isPaused ? 'ПАУЗА' : 'ИДЕТ ЗАПИСЬ',
    );

    final notificationDetails = NotificationDetails(android: androidDetails);

    await _notifications.show(
      recordingNotificationId,
      isPaused ? 'Запись на паузе' : 'Идет запись лекции...',
      'Длительность: $timeString • LibeNetLA',
      notificationDetails,
    );
  }

  static Future<void> cancelRecordingNotification() async {
    await _notifications.cancel(recordingNotificationId);
  }

  static Future<void> showLectureReadyNotification({
    required int lectureId,
    required String lectureTitle,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'libenet_alerts_channel',
      'Оповещения о лекциях',
      channelDescription: 'Уведомления о завершении транскрибации и AI конспекта',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const notificationDetails = NotificationDetails(android: androidDetails);

    await _notifications.show(
      lectureReadyNotificationId + lectureId,
      'Конспект готов! ✨',
      'Лекция «$lectureTitle» успешно обработана нейросетью',
      notificationDetails,
      payload: lectureId.toString(),
    );
  }
}
