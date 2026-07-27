import 'package:padel/core/constants/app_constants.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'padel_bookings',
    'Padel Bookings',
    description: 'Booking confirmations and reminders',
    importance: Importance.high,
  );

  /// Call once after Firebase.initializeApp()
  Future<void> init({void Function(String token)? onTokenRefresh}) async {
    // Request permission (iOS / Android 13+)
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Initialize local notifications
    const initSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettingsIOS = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const initSettings = InitializationSettings(
      android: initSettingsAndroid,
      iOS: initSettingsIOS,
    );
    await _localNotifications.initialize(initSettings);

    // Create Android notification channel
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    // Handle foreground FCM messages
    FirebaseMessaging.onMessage.listen((message) {
      final notification = message.notification;
      if (notification != null) {
        _showLocalNotification(
          title: notification.title ?? AppConstants.appName,
          body: notification.body ?? '',
        );
      }
    });

    // Get and expose FCM token
    final token = await _messaging.getToken();
    if (token != null && onTokenRefresh != null) {
      onTokenRefresh(token);
    }

    _messaging.onTokenRefresh.listen((newToken) {
      if (onTokenRefresh != null) onTokenRefresh(newToken);
    });
  }

  /// Show an immediate local notification (e.g. on booking confirmation).
  Future<void> showBookingConfirmation({
    required String venueName,
    required String date,
    required String time,
  }) async {
    await _showLocalNotification(
      title: 'Booking Confirmed!',
      body: '$venueName on $date at $time',
    );
  }

  Future<void> _showLocalNotification({
    required String title,
    required String body,
    int id = 0,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      _channel.id,
      _channel.name,
      channelDescription: _channel.description,
      importance: Importance.high,
      priority: Priority.high,
      color: const Color(0xFFE63946),
    );
    const iosDetails = DarwinNotificationDetails();
    final details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _localNotifications.show(id, title, body, details);
  }

  /// Get current FCM token.
  Future<String?> getToken() => _messaging.getToken();
}
