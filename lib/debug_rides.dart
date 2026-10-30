import 'package:loop_car/config/supabase_config.dart';
import 'package:loop_car/services/ride_service.dart';

void main() async {
  await SupabaseConfig.initialize();
  final service = RideService();
  
  // Just get all active rides
  final response = await SupabaseConfig.client
        .from('rides')
        .select('*')
        .eq('status', 'active');
        
  print('All active rides:');
  for (var ride in response) {
    print('- Ride: ${ride['id']}, start: ${ride['start_location']}, end: ${ride['end_location']}, date: ${ride['departure_datetime']}, seats: ${ride['available_seats']}');
  }
}
