import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

// Top-level function: handles background messages when app is killed/closed
@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  // Show local notification when app is in background/terminated
  final FlutterLocalNotificationsPlugin plugin = FlutterLocalNotificationsPlugin();
  const AndroidInitializationSettings androidSettings =
      AndroidInitializationSettings('@mipmap/launcher_icon');
  const InitializationSettings initSettings =
      InitializationSettings(android: androidSettings);
  await plugin.initialize(initSettings);
  _showLocalNotification(plugin, message);
}

void _showLocalNotification(
    FlutterLocalNotificationsPlugin plugin, RemoteMessage message) {
  final String title = message.notification?.title ?? message.data['title'] ?? 'SSSAM CRM';
  final String body = message.notification?.body ?? message.data['body'] ?? '';
  final String type = message.data['type'] ?? 'general';

  plugin.show(
    message.hashCode,
    title,
    body,
    NotificationDetails(
      android: AndroidNotificationDetails(
        'sssam_crm_channel',
        'SSSAM CRM Notifications',
        channelDescription: 'Attendance, Follow-up and Fee alerts',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/launcher_icon',
        tag: type,
      ),
    ),
    payload: jsonEncode(message.data),
  );
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  Future<void> initialize(ApiService apiService) async {
    // Setup local notifications (for foreground)
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/launcher_icon');
    const InitializationSettings initSettings =
        InitializationSettings(android: androidSettings);
    await _localNotifications.initialize(initSettings);

    // Create notification channel (Android 8+)
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'sssam_crm_channel',
      'SSSAM CRM Notifications',
      description: 'Attendance, Follow-up and Fee alerts',
      importance: Importance.high,
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // Request permission (Android 13+ and iOS)
    try {
      await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
    } catch (_) {}

    // Handle foreground messages - show local notification
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _showLocalNotification(_localNotifications, message);
    });

    // Get FCM token and send to backend
    await _registerFCMToken(apiService);

    // Listen for token refresh
    _messaging.onTokenRefresh.listen((newToken) async {
      await _saveFCMTokenToBackend(newToken, apiService);
    });
  }

  Future<void> _registerFCMToken(ApiService apiService) async {
    try {
      final String? token = await _messaging.getToken();
      if (token != null) {
        await _saveFCMTokenToBackend(token, apiService);
      }
    } catch (e) {
      // Silently ignore token errors
    }
  }

  Future<void> _saveFCMTokenToBackend(String token, ApiService apiService) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedToken = prefs.getString('fcm_token');

      // Only send if token changed
      if (savedToken != token) {
        await apiService.postRequest('/notifications/fcm-token', data: {
          'token': token,
          'deviceInfo': 'android',
        });
        await prefs.setString('fcm_token', token);
      }
    } catch (e) {
      // Silently ignore backend save errors
    }
  }

  Future<void> removeFCMTokenOnLogout(ApiService apiService) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('fcm_token');
      if (token != null) {
        await apiService.deleteRequest('/notifications/fcm-token', data: {
          'token': token,
        });
        await prefs.remove('fcm_token');
      }
      await _messaging.deleteToken();
    } catch (e) {
      // Silently ignore
    }
  }
}
