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
    debugPrint('NotificationService: Initializing...');
    
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
        debugPrint('NotificationService: Notification clicked: ${response.payload}');
      },
    );

    // Initialize Firebase Cloud Messaging
    try {
      debugPrint('NotificationService: Initializing Firebase Messaging...');
      FirebaseMessaging messaging = FirebaseMessaging.instance;
      
      // Request permissions (specifically for iOS/Android 13+)
      NotificationSettings settings = await messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );
      debugPrint('NotificationService: Permission status: ${settings.authorizationStatus}');

      // Get APNs token for iOS
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        String? apnsToken = await messaging.getAPNSToken();
        debugPrint('NotificationService: APNs token: $apnsToken');
      }

      // Register background handler
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
      debugPrint('NotificationService: Background handler registered');

      // Listen for foreground FCM messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('NotificationService: Got FCM message in foreground: ${message.messageId}');
        debugPrint('NotificationService: Message data: ${message.data}');
        if (message.notification != null) {
          debugPrint('NotificationService: Notification title: ${message.notification!.title}');
          debugPrint('NotificationService: Notification body: ${message.notification!.body}');
          _showLocalNotification(
            title: message.notification!.title ?? 'New Notification',
            body: message.notification!.body ?? '',
            payload: message.data['id'],
          );
        }
      });

      // Handle notification interaction when app is launched from background or terminated states
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('NotificationService: FCM Notification clicked to open app: ${message.data}');
      });

      FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
        if (message != null) {
          debugPrint('NotificationService: App opened from terminated state by FCM: ${message.data}');
        }
      });
    } catch (e) {
      debugPrint('NotificationService: Error initializing Firebase Messaging: $e');
    }

    // Listen to Supabase auth changes to start/stop listening to notifications
    SupabaseConfig.client.auth.onAuthStateChange.listen((data) {
      final session = data.session;
      if (session != null) {
        debugPrint('NotificationService: User logged in, starting listening...');
        _startListening(session.user.id);
        _registerFcmToken(session.user.id);
      } else {
        debugPrint('NotificationService: User logged out, stopping listening...');
        _unregisterFcmToken();
        _stopListening();
      }
    });

    // Start listening immediately if already logged in
    final currentUser = SupabaseConfig.client.auth.currentUser;
    if (currentUser != null) {
      debugPrint('NotificationService: User already logged in, starting listening...');
      _startListening(currentUser.id);
      _registerFcmToken(currentUser.id);
    }
  }

  void _startListening(String userId) {
    debugPrint('NotificationService: Starting to listen for notifications for user: $userId');
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
            debugPrint('NotificationService: Received new notification from Supabase: $payload');
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
      debugPrint('NotificationService: Stopping listening for notifications');
      SupabaseConfig.client.removeChannel(_notificationChannel!);
      _notificationChannel = null;
    }
  }

  Future<void> _registerFcmToken(String userId) async {
    debugPrint('NotificationService: Registering FCM token for user: $userId');
    try {
      String? token = await FirebaseMessaging.instance.getToken();
      debugPrint('NotificationService: FCM token: $token');
      if (token == null) {
        debugPrint('NotificationService: FCM token is null, skipping registration');
        return;
      }

      final deviceType = defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';

      await SupabaseConfig.client.from('user_fcm_tokens').upsert({
        'user_id': userId,
        'fcm_token': token,
        'device_type': deviceType,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'fcm_token');
      debugPrint('NotificationService: FCM token registered successfully');

      // Listen for token refreshes
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
        debugPrint('NotificationService: FCM token refreshed: $newToken');
        await SupabaseConfig.client.from('user_fcm_tokens').upsert({
          'user_id': userId,
          'fcm_token': newToken,
          'device_type': deviceType,
          'updated_at': DateTime.now().toIso8601String(),
        }, onConflict: 'fcm_token');
        debugPrint('NotificationService: Refreshed FCM token registered successfully');
      });
    } catch (e) {
      debugPrint('NotificationService: Error registering FCM token: $e');
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
    debugPrint('NotificationService: Showing local notification - Title: $title, Body: $body');
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'litops_notifications',
      'Lit Life Notifications',
      channelDescription: 'Notifications for Lit Life app',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
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
