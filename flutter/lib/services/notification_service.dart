import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  NotificationService();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static const _progressId = 1001;
  static const _resultId = 1002;

  Future<void> init() async {
    if (kIsWeb) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();
    _ready = true;
  }

  Future<void> showProgress(String title, String body) async {
    if (!_ready || kIsWeb) return;
    await _plugin.show(
      _progressId,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'wakeed_submit',
          'تسجيل السندات',
          channelDescription: 'تقدم تسجيل سندات وكيد',
          importance: Importance.high,
          priority: Priority.high,
          ongoing: true,
          autoCancel: false,
          playSound: false,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(presentSound: false),
      ),
    );
  }

  Future<void> showDone(String title, String body, {bool success = true}) async {
    if (!_ready || kIsWeb) return;
    await _plugin.cancel(_progressId);
    await _plugin.show(
      _resultId,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'wakeed_result',
          'نتائج السندات',
          channelDescription: 'نجاح أو فشل تسجيل السند',
          importance: Importance.high,
          priority: Priority.high,
          autoCancel: true,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(),
      ),
    );
  }

  Future<void> cancelAll() async {
    if (!_ready || kIsWeb) return;
    await _plugin.cancel(_progressId);
  }
}

