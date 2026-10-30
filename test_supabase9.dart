import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://usysfcfncfiwdqpqzije.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVzeXNmY2ZuY2Zpd2RxcHF6aWplIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njk0MDc2OTMsImV4cCI6MjA4NDk4MzY5M30.XafXkazhRb9wDqJZSNb27z9G3WRRboHmZatDIMFrRDs',
  );

  final userId = '543959a0-2a23-46ab-9d4c-daf5ef634d09';
  
  try {
    print("Testing bookings query 2 (driver)...");
    final res2 = await client
        .from('bookings')
        .select('*, ride:rides!inner(*, driver:profiles!driver_id(*)), passenger:profiles!passenger_id(*)')
        .eq('rides.driver_id', userId)
        .eq('status', 'completed');
    print("Bookings 2 OK: $res2");
  } catch (e) {
    print("Bookings 2 Error: $e");
  }
}
