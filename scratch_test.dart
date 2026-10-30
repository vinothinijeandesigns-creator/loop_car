import 'package:supabase_flutter/supabase_flutter.dart';
import 'lib/config/supabase_config.dart';

void main() async {
  await Supabase.initialize(
    url: SupabaseConfig.supabaseUrl,
    anonKey: SupabaseConfig.supabaseAnonKey,
  );
  
  final client = Supabase.instance.client;
  
  try {
    final response = await client.from('rides').select('*');
    print('ALL RIDES IN DATABASE:');
    print(response);
  } catch (e) {
    print('Error: $e');
  }
}
