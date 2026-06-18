import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import '../../core/supabase/supabase_config.dart';
import '../../core/supabase/supabase_tables.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('Handling a background message: ${message.messageId}');
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  RealtimeChannel? _notificationChannel;

  Future<void> initialize() async {
    // Android initialization
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS initialization
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _localNotifications.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint('Notification clicked: ${response.payload}');
      },
    );

    // Initialize Firebase Cloud Messaging
    try {
      FirebaseMessaging messaging = FirebaseMessaging.instance;
      
      // Request permissions (specifically for iOS/Android 13+)
      await messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      // Register background handler
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // Listen for foreground FCM messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('Got a FCM message in the foreground: ${message.messageId}');
        if (message.notification != null) {
          _showLocalNotification(
            title: message.notification!.title ?? 'New Notification',
            body: message.notification!.body ?? '',
            payload: message.data['id'],
          );
        }
      });

      // Handle notification interaction when app is launched from background or terminated states
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('FCM Notification clicked to open app: ${message.data}');
      });

      FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
        if (message != null) {
          debugPrint('App opened from terminated state by FCM: ${message.data}');
        }
      });
    } catch (e) {
      debugPrint('Error initializing Firebase Messaging: $e');
    }

    // Listen to Supabase auth changes to start/stop listening to notifications
    SupabaseConfig.client.auth.onAuthStateChange.listen((data) {
      final session = data.session;
      if (session != null) {
        _startListening(session.user.id);
        _registerFcmToken(session.user.id);
      } else {
        _unregisterFcmToken();
        _stopListening();
      }
    });

    // Start listening immediately if already logged in
    final currentUser = SupabaseConfig.client.auth.currentUser;
    if (currentUser != null) {
      _startListening(currentUser.id);
      _registerFcmToken(currentUser.id);
    }
  }

  void _startListening(String userId) {
    _stopListening();

    _notificationChannel = SupabaseConfig.client
        .channel('public:notifications')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: SupabaseTables.notifications,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            final newRecord = payload.newRecord;
            _showLocalNotification(
              title: newRecord['title'] ?? 'New Notification',
              body: newRecord['message'] ?? '',
              payload: newRecord['id'],
            );
          },
        )
        .subscribe();
  }

  void _stopListening() {
    if (_notificationChannel != null) {
      SupabaseConfig.client.removeChannel(_notificationChannel!);
      _notificationChannel = null;
    }
  }

  Future<void> _registerFcmToken(String userId) async {
    try {
      String? token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;

      final deviceType = defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';

      await SupabaseConfig.client.from('user_fcm_tokens').upsert({
        'user_id': userId,
        'fcm_token': token,
        'device_type': deviceType,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'fcm_token');

      // Listen for token refreshes
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
        await SupabaseConfig.client.from('user_fcm_tokens').upsert({
          'user_id': userId,
          'fcm_token': newToken,
          'device_type': deviceType,
          'updated_at': DateTime.now().toIso8601String(),
        }, onConflict: 'fcm_token');
      });
    } catch (e) {
      debugPrint('Error registering FCM token: $e');
    }
  }

  Future<void> _unregisterFcmToken() async {
    try {
      String? token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await SupabaseConfig.client
            .from('user_fcm_tokens')
            .delete()
            .eq('fcm_token', token);
      }
    } catch (e) {
      debugPrint('Error unregistering FCM token: $e');
    }
  }

  Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'litops_notifications',
      'Lit Life Notifications',
      channelDescription: 'Notifications for Lit Life app',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
    );

    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await _localNotifications.show(
      id: DateTime.now().millisecond,
      title: title,
      body: body,
      notificationDetails: platformChannelSpecifics,
      payload: payload,
    );
  }
}
