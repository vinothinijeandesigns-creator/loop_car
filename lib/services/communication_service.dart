import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../config/supabase_config.dart';

class CommunicationService {
  static final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  /// Initialize Firebase Messaging and save FCM token to Supabase
  static Future<void> initializePushNotifications() async {
    try {
      final messaging = FirebaseMessaging.instance;
      
      // Request permission
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      // Initialize Local Notifications for foreground
      const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
      const DarwinInitializationSettings initializationSettingsIOS = DarwinInitializationSettings();
      const InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsIOS,
      );
      await _localNotifications.initialize(
        settings: initializationSettings,
      );

      // Listen to foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        if (message.notification != null) {
          _showLocalNotification(message.notification!.title, message.notification!.body);
        }
      });
      
      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        // Get token
        final token = await messaging.getToken();
        debugPrint('FCM Token: $token');
        
        if (token != null && SupabaseConfig.userId != null) {
          // Save token to Supabase
          try {
            await SupabaseConfig.client
                .from('profiles')
                .update({'fcm_token': token})
                .eq('id', SupabaseConfig.userId!);
          } catch (e) {
            debugPrint('Note: Could not save FCM token. Make sure "fcm_token" column exists in "profiles" table. Error: $e');
          }
        }
        
        // Listen to token refresh
        messaging.onTokenRefresh.listen((newToken) async {
          if (SupabaseConfig.userId != null) {
             try {
               await SupabaseConfig.client
                  .from('profiles')
                  .update({'fcm_token': newToken})
                  .eq('id', SupabaseConfig.userId!);
             } catch (_) {}
          }
        });
      }
    } catch (e) {
      debugPrint('Error initializing push notifications: $e');
    }
  }

  static Future<void> _showLocalNotification(String? title, String? body) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'loopcar_main_channel', // channel Id
      'LoopCar Notifications', // channel Name
      channelDescription: 'Main channel for LoopCar push notifications',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    const NotificationDetails platformChannelSpecifics = NotificationDetails(android: androidPlatformChannelSpecifics);
    await _localNotifications.show(
      id: DateTime.now().millisecond,
      title: title,
      body: body,
      notificationDetails: platformChannelSpecifics,
    );
  }

  /// Fetches a user's communication preferences and sends notifications 
  /// ONLY through the channels they have enabled.
  static Future<void> notifyUser({
    required String userId,
    required String title,
    required String message,
  }) async {
    try {
      // 1. Fetch the user's communication preferences
      final response = await SupabaseConfig.client
          .from('profiles')
          .select('comm_push_notifications, comm_emails, comm_text_messages, comm_phone_calls')
          .eq('id', userId)
          .maybeSingle();

      if (response == null) return;

      final bool allowPush = response['comm_push_notifications'] ?? true;
      final bool allowEmail = response['comm_emails'] ?? true;
      final bool allowSms = response['comm_text_messages'] ?? true;

      // 2. Send via enabled channels
      
      if (allowPush) {
        await _sendPushNotification(userId, title, message);
      }

      if (allowEmail) {
        await _sendEmail(userId, title, message);
      }

      if (allowSms) {
        await _sendSms(userId, message);
      }

    } catch (e) {
      debugPrint("Error sending communication: $e");
    }
  }

  static Future<void> _sendPushNotification(String userId, String title, String body) async {
    try {
      final response = await SupabaseConfig.client.functions.invoke(
        'send-notification',
        body: {
          'userId': userId,
          'title': title,
          'message': body,
        },
      );
      if (response.status != 200) {
         debugPrint("Failed to send push notification: ${response.data}");
      } else {
         debugPrint("📱 [PUSH NOTIFICATION sent to $userId]: $title - $body");
      }
    } catch (e) {
      debugPrint("Error invoking send-notification edge function: $e");
    }
  }

  static Future<void> _sendEmail(String userId, String subject, String body) async {
    // TODO: Implement Email logic (e.g. Supabase Edge Function with Resend/SendGrid)
    debugPrint("📧 [EMAIL sent to $userId]: $subject - $body");
  }

  static Future<void> _sendSms(String userId, String message) async {
    // TODO: Implement SMS logic (e.g. Twilio via Supabase Edge Function)
    debugPrint("💬 [SMS sent to $userId]: $message");
  }

  /// Helper to check if we are allowed to show the "Call" button for a user
  static Future<bool> canCallUser(String userId) async {
    try {
      final response = await SupabaseConfig.client
          .from('profiles')
          .select('comm_phone_calls')
          .eq('id', userId)
          .maybeSingle();
          
      if (response != null) {
        return response['comm_phone_calls'] ?? true;
      }
    } catch (e) {
      debugPrint("Error checking call preference: $e");
    }
    return true; // Default to true if fails
  }
}
