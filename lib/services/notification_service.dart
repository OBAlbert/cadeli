import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';


class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'cadeli_high_importance_channel',
    'Cadeli High Importance Notifications',
    description: 'This channel is used for important notifications.',
    importance: Importance.high,
  );

  static Future<void> initialize() async {
    // Request permissions
    await _requestPermissions();

    // Initialize local notifications
    await _initializeLocalNotifications();

    // Configure FCM
    await _configureFCM();

    // Handle background messages
    FirebaseMessaging.onBackgroundMessage(_handleBackgroundMessage);
  }

  static Future<void> _requestPermissions() async {
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('User granted permission');
    } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
      print('User granted provisional permission');
    } else {
      print('User declined or has not accepted permission');
    }
  }

  static Future<void> _initializeLocalNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create notification channel for Android
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);
  }

  static Future<void> _configureFCM() async {
    try {
      // Get the token with retry logic
      String? token = await _getTokenWithRetry();
      print('FCM Token: $token');
      
      // Save token to preferences for backend registration
      if (token != null) {
        await _saveTokenToPreferences(token);
        await _registerTokenWithBackend(token); // <-- add this
      } else {
        print('Warning: FCM token is null. This might affect push notifications.');
      }

      // Listen for token refresh
      _messaging.onTokenRefresh.listen((newToken) {
        print('FCM Token refreshed: $newToken');
        _saveTokenToPreferences(newToken);
        _registerTokenWithBackend(newToken);    // <-- add this

      });
    } catch (e) {
      print('Error configuring FCM: $e');
    }

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle notification opened app
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationOpenedApp);

    // Handle initial message (app opened from terminated state)
    RemoteMessage? initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationOpenedApp(initialMessage);
    }
  }

  static Future<String?> _getTokenWithRetry() async {
    int maxRetries = 3;
    int delay = 2; // seconds
    
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        String? token = await _messaging.getToken();
        if (token != null && token.isNotEmpty) {
          return token;
        }
        
        if (attempt < maxRetries) {
          print('FCM token attempt $attempt failed, retrying in ${delay}s...');
          await Future.delayed(Duration(seconds: delay));
          delay *= 2; // Exponential backoff
        }
      } catch (e) {
        print('FCM token retrieval error on attempt $attempt: $e');
        if (attempt < maxRetries) {
          await Future.delayed(Duration(seconds: delay));
          delay *= 2;
        }
      }
    }
    
    print('Failed to retrieve FCM token after $maxRetries attempts');
    return null;
  }

  static Future<void> _saveTokenToPreferences(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('fcm_token', token);
    print('FCM Token saved: $token');
    // TODO: Send token to your backend server
  }

  static Future<String?> getFCMToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('fcm_token');
  }

  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    print('Handling a foreground message: ${message.messageId}');

    // Show local notification when app is in foreground
    await _showLocalNotification(
      title: message.notification?.title ?? 'Cadeli',
      body: message.notification?.body ?? 'You have a new notification',
      payload: jsonEncode(message.data),
    );

    // Save notification to local storage
    await _saveNotificationToHistory(message);
  }

  static Future<void> _handleBackgroundMessage(RemoteMessage message) async {
    print('Handling a background message: ${message.messageId}');
    // Save notification to local storage
    await _saveNotificationToHistory(message);
  }

  static Future<void> _handleNotificationOpenedApp(RemoteMessage message) async {
    print('A new onMessageOpenedApp event was published!');
    // Handle navigation based on notification data
    _handleNotificationNavigation(message.data);
  }

  static void _onNotificationTapped(NotificationResponse response) {
    if (response.payload != null) {
      final data = jsonDecode(response.payload!);
      _handleNotificationNavigation(data);
    }
  }

  static void _handleNotificationNavigation(Map<String, dynamic> data) {
    // Navigate based on notification type
    final type = data['type'];
    switch (type) {
      case 'order_update':
        // Navigate to order details
        break;
      case 'delivery_update':
        // Navigate to delivery tracking
        break;
      case 'promotion':
        // Navigate to promotions page
        break;
      default:
        // Navigate to notifications page
        break;
    }
  }

  static Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'cadeli_high_importance_channel',
      'Cadeli High Importance Notifications',
      channelDescription: 'This channel is used for important notifications.',
      importance: Importance.high,
      priority: Priority.high,
      color: Color(0xFF1A233D),
      icon: '@mipmap/ic_launcher',
      showWhen: true,
    );

    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      platformChannelSpecifics,
      payload: payload,
    );
  }

  static Future<void> _saveNotificationToHistory(RemoteMessage message) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> notifications = prefs.getStringList('notification_history') ?? [];
    
    final notification = {
      'id': message.messageId,
      'title': message.notification?.title ?? 'Cadeli',
      'body': message.notification?.body ?? '',
      'data': message.data,
      'timestamp': DateTime.now().toIso8601String(),
      'read': false,
    };

    notifications.insert(0, jsonEncode(notification));
    
    // Keep only last 50 notifications
    if (notifications.length > 50) {
      notifications = notifications.take(50).toList();
    }

    await prefs.setStringList('notification_history', notifications);
  }

  static Future<List<Map<String, dynamic>>> getNotificationHistory() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> notifications = prefs.getStringList('notification_history') ?? [];
    
    return notifications.map((n) => jsonDecode(n) as Map<String, dynamic>).toList();
  }

  static Future<void> markNotificationAsRead(String notificationId) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> notifications = prefs.getStringList('notification_history') ?? [];
    
    for (int i = 0; i < notifications.length; i++) {
      final notification = jsonDecode(notifications[i]) as Map<String, dynamic>;
      if (notification['id'] == notificationId) {
        notification['read'] = true;
        notifications[i] = jsonEncode(notification);
        break;
      }
    }

    await prefs.setStringList('notification_history', notifications);
  }

  static Future<void> clearAllNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('notification_history');
    await _localNotifications.cancelAll();
  }

  static Future<int> getUnreadNotificationCount() async {
    final notifications = await getNotificationHistory();
    return notifications.where((n) => n['read'] == false).length;
  }

  // Send local notification manually (for testing or app-generated notifications)
  static Future<void> sendLocalNotification({
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    await _showLocalNotification(
      title: title,
      body: body,
      payload: data != null ? jsonEncode(data) : null,
    );

    // Save to history
    final notification = RemoteMessage(
      messageId: DateTime.now().millisecondsSinceEpoch.toString(),
      notification: RemoteNotification(title: title, body: body),
      data: data ?? {},
    );
    
    await _saveNotificationToHistory(notification);
  }

  // Notification types for easy categorization
  static Future<void> sendOrderUpdateNotification({
    required String orderId,
    required String status,
    String? message,
  }) async {
    await sendLocalNotification(
      title: 'Order Update',
      body: message ?? 'Your order status has been updated to $status',
      data: {
        'type': 'order_update',
        'order_id': orderId,
        'status': status,
      },
    );
  }

  static Future<void> sendDeliveryNotification({
    required String orderId,
    required String message,
    String? driverName,
  }) async {
    await sendLocalNotification(
      title: 'Delivery Update',
      body: message,
      data: {
        'type': 'delivery_update',
        'order_id': orderId,
        'driver_name': driverName,
      },
    );
  }

  static Future<void> sendPromotionNotification({
    required String title,
    required String message,
    String? promoCode,
  }) async {
    await sendLocalNotification(
      title: title,
      body: message,
      data: {
        'type': 'promotion',
        'promo_code': promoCode,
      },
    );
  }

  static Future<void> _registerTokenWithBackend(String token) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'fcmTokens': { token: true },
    }, SetOptions(merge: true));
  }


}
