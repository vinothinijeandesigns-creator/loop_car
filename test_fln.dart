import 'package:flutter_local_notifications/flutter_local_notifications.dart';

void main() async {
  final FlutterLocalNotificationsPlugin plugin = FlutterLocalNotificationsPlugin();
  await plugin.initialize(settings: const InitializationSettings());
  await plugin.show(
    id: 1, 
    title: 'title', 
    body: 'body', 
    notificationDetails: const NotificationDetails()
  );
}
