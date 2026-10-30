import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://usysfcfncfiwdqpqzije.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVzeXNmY2ZuY2Zpd2RxcHF6aWplIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njk0MDc2OTMsImV4cCI6MjA4NDk4MzY5M30.XafXkazhRb9wDqJZSNb27z9G3WRRboHmZatDIMFrRDs',
  );

  // Fake user UUID
  final userId = '11111111-1111-1111-1111-111111111111';
  final vehicleData = {
    'user_id': userId,
    'make': 'Test',
    'model': '2026',
    'color': 'Black',
  };

  try {
    print("Trying to insert new vehicle...");
    final res = await client.from('vehicles').insert(vehicleData).select();
    print("Inserted successfully! Returning: $res");
  } catch (e) {
    print("Insert Error: $e");
  }
}
