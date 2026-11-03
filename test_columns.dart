import 'package:supabase_flutter/supabase_flutter.dart';
import 'lib/config/supabase_config.dart';

void main() async {
  await SupabaseConfig.initialize();
  
  try {
    final response = await SupabaseConfig.client
        .from('profiles')
        .select('fcm_token')
        .limit(1);
    print('fcm_token exists: $response');
  } catch (e) {
    print('fcm_token Error: $e');
  }

  try {
    final response = await SupabaseConfig.client
        .from('profiles')
        .select('comm_push_notifications, comm_emails, comm_text_messages, comm_phone_calls')
        .limit(1);
    print('comm preferences exists: $response');
  } catch (e) {
    print('comm preferences Error: $e');
  }
}
