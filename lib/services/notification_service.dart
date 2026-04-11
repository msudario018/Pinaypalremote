import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'firebase_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  FirebaseMessaging get _firebaseMessaging => FirebaseMessaging.instance;

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    // Initialize timezone
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Manila'));

    // Initialize local notifications
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings();
    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Request notification permissions
    await _requestPermissions();

    // Initialize FCM
    await _initializeFCM();

    _initialized = true;
  }

  Future<void> _requestPermissions() async {
    // Android 13+ needs explicit permission
    if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
          _localNotificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.requestNotificationsPermission();
    }

    // iOS permissions
    if (Platform.isIOS) {
      await _localNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
    }
  }

  Future<void> _initializeFCM() async {
    try {
      // Get FCM token
      final token = await _firebaseMessaging.getToken();
      if (kDebugMode) {
        print('FCM Token: $token');
      }

      // Save FCM token to Firebase for PC app to use
      if (token != null) {
        await _saveFCMTokenToFirebase(token);
      }

      // Listen to FCM messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageTap);

      // Listen to token refresh
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
        if (kDebugMode) {
          print('FCM Token refreshed: $newToken');
        }
        _saveFCMTokenToFirebase(newToken);
      });
    } catch (e) {
      if (kDebugMode) {
        print('[NotificationService] FCM initialization failed: $e');
      }
      // FCM initialization failed, but continue with local notifications
    }
  }

  Future<void> _saveFCMTokenToFirebase(String token) async {
    try {
      final username = FirebaseService.currentUsername;
      if (username != null) {
        await FirebaseService.saveFCMToken(username, token);
        if (kDebugMode) {
          print('[NotificationService] FCM token saved to Firebase');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('[NotificationService] Failed to save FCM token: $e');
      }
    }
  }

  void _onNotificationTap(NotificationResponse response) {
    // Handle notification tap
    if (kDebugMode) {
      print('Notification tapped: ${response.payload}');
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    // Show notification when app is in foreground
    showNotification(
      title: message.notification?.title ?? 'New Message',
      body: message.notification?.body ?? '',
      payload: message.data.toString(),
    );
  }

  void _handleMessageTap(RemoteMessage message) {
    // Handle notification tap when app is in background
    if (kDebugMode) {
      print('FCM Message tapped: ${message.data}');
    }
  }

  // Local Notification Methods
  Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
    int? id,
  }) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'backup_channel',
      'Backup Notifications',
      channelDescription: 'Notifications for backup events',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails();
    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotificationsPlugin.show(
      id ?? DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      notificationDetails,
      payload: payload,
    );
  }

  // Backup completion notification
  Future<void> showBackupCompletionNotification(
    String service,
    bool success,
  ) async {
    final title = success ? 'Backup Completed' : 'Backup Failed';
    final body = success
        ? '$service backup completed successfully'
        : '$service backup failed. Please check your PC app.';

    await showNotification(
      title: title,
      body: body,
      id: service.hashCode,
    );
  }

  // Backup failure alert
  Future<void> showBackupFailureAlert(String service, String error) async {
    await showNotification(
      title: 'Backup Failure',
      body: '$service backup failed: $error',
      id: service.hashCode + 1,
    );
  }

  // Scheduled backup reminder
  Future<void> scheduleBackupReminder(
    String service,
    DateTime scheduledTime,
  ) async {
    final now = DateTime.now();
    final scheduledDateTime = DateTime(
      now.year,
      now.month,
      now.day,
      scheduledTime.hour,
      scheduledTime.minute,
    );

    if (scheduledDateTime.isBefore(now)) {
      // Schedule for next day if time has passed
      scheduledDateTime.add(const Duration(days: 1));
    }

    await _localNotificationsPlugin.zonedSchedule(
      service.hashCode,
      'Backup Reminder',
      '$service backup is scheduled for ${_formatTime(scheduledTime)}',
      tz.TZDateTime.from(scheduledDateTime, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'backup_channel',
          'Backup Notifications',
          channelDescription: 'Notifications for backup events',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  // Health check warning
  Future<void> showHealthCheckWarning(
    String service,
    String message,
  ) async {
    await showNotification(
      title: 'Health Check Warning',
      body: '$service: $message',
      id: service.hashCode + 2,
    );
  }

  // PC app status change notification
  Future<void> showPCStatusNotification(String status) async {
    await showNotification(
      title: 'PC App Status Changed',
      body: 'PC app is now $status',
      id: 'pc_status'.hashCode,
    );
  }

  // Cancel specific notification
  Future<void> cancelNotification(int id) async {
    await _localNotificationsPlugin.cancel(id);
  }

  // Cancel all notifications
  Future<void> cancelAllNotifications() async {
    await _localNotificationsPlugin.cancelAll();
  }

  // Get FCM token
  Future<String?> getFCMToken() async {
    try {
      return await _firebaseMessaging.getToken();
    } catch (e) {
      if (kDebugMode) {
        print('[NotificationService] Failed to get FCM token: $e');
      }
      return null;
    }
  }

  String _formatTime(DateTime time) {
    final hour = time.hour;
    final minute = time.minute;
    final period = hour >= 12 ? 'PM' : 'AM';
    final hour12 = hour % 12 == 0 ? 12 : hour % 12;
    return '${hour12}:${minute.toString().padLeft(2, '0')} $period';
  }
}
