import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

// Top-level function: handles background messages when app is killed/closed
@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  // If the payload has a notification block, Android OS handles displaying it natively.
  // Only display local notification manually if there is no notification block (data-only payload).
  if (message.notification == null) {
    final FlutterLocalNotificationsPlugin plugin = FlutterLocalNotificationsPlugin();
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/launcher_icon');
    const InitializationSettings initSettings =
        InitializationSettings(android: androidSettings);
    await plugin.initialize(initSettings);
    _showLocalNotification(plugin, message);
  }
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
      print('🔔 FCM TOKEN FETCHED: $token');
      if (token != null) {
        await _saveFCMTokenToBackend(token, apiService);
      }
    } catch (e) {
      print('❌ FCM TOKEN FETCH ERROR: $e');
    }
  }

  Future<void> _saveFCMTokenToBackend(String token, ApiService apiService) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      print('🚀 SAVING FCM TOKEN TO BACKEND...');
      final res = await apiService.postRequest('/notifications/fcm-token', data: {
        'token': token,
        'deviceInfo': 'android',
      });
      print('✅ FCM TOKEN SAVED TO BACKEND: ${res.data}');
      await prefs.setString('fcm_token', token);
    } catch (e) {
      if (e is DioException) {
        print('❌ FCM TOKEN BACKEND SAVE ERROR RESPONSE: ${e.response?.statusCode} - ${e.response?.data}');
      } else {
        print('❌ FCM TOKEN BACKEND SAVE ERROR: $e');
      }
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
