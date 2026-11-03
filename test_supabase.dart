import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://usysfcfncfiwdqpqzije.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVzeXNmY2ZuY2Zpd2RxcHF6aWplIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njk0MDc2OTMsImV4cCI6MjA4NDk4MzY5M30.XafXkazhRb9wDqJZSNb27z9G3WRRboHmZatDIMFrRDs'
  );

  final response = await client
      .from('rides')
      .select('id, start_location, end_location, departure_datetime, start_lat, start_lng, end_lat, end_lng, available_seats, status');
      
  print('Found ${response.length} rides.');
  for (var r in response) {
    print('Ride: ${r['id']}');
    print('  From: ${r['start_location']} (${r['start_lat']}, ${r['start_lng']})');
    print('  To: ${r['end_location']} (${r['end_lat']}, ${r['end_lng']})');
    print('  Time: ${r['departure_datetime']}');
    print('  Seats: ${r['available_seats']} | Status: ${r['status']}');
  }
}
