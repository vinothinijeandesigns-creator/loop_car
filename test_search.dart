import 'package:supabase/supabase.dart';
import 'dart:math';

// Simplified Geolocator distance function
double distanceBetween(double startLat, double startLng, double endLat, double endLng) {
  var p = 0.017453292519943295;
  var c = cos;
  var a = 0.5 - c((endLat - startLat) * p) / 2 +
      c(startLat * p) * c(endLat * p) *
          (1 - c((endLng - startLng) * p)) / 2;
  return 12742 * asin(sqrt(a)) * 1000;
}

void main() async {
  final client = SupabaseClient(
    'https://usysfcfncfiwdqpqzije.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVzeXNmY2ZuY2Zpd2RxcHF6aWplIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njk0MDc2OTMsImV4cCI6MjA4NDk4MzY5M30.XafXkazhRb9wDqJZSNb27z9G3WRRboHmZatDIMFrRDs'
  );

  final departureDate = DateTime(2026, 8, 15);
  final startOfDay = DateTime(
    departureDate.year,
    departureDate.month,
    departureDate.day,
  );
  final endOfDay = startOfDay.add(const Duration(days: 1));

  print('Searching from \${startOfDay.toUtc().toIso8601String()} to \${endOfDay.toUtc().toIso8601String()}');

  try {
    final response = await client
        .from('rides')
        .select('''
          *,
          driver:profiles!driver_id (
            id,
            first_name,
            last_name,
            avatar_url,
            rating_avg
          ),
          ride_stops (
            location_name,
            lat,
            lng,
            stop_order
          )
        ''')
        .eq('status', 'active')
        .gte('available_seats', 1)
        .gte('departure_datetime', startOfDay.toUtc().toIso8601String())
        .lt('departure_datetime', endOfDay.toUtc().toIso8601String())
        .order('departure_datetime', ascending: true);

    print('Query returned \${response.length} rides');

    if (response.isNotEmpty) {
      final ride = response.first;
      print("Ride from: \${ride['start_location']}");
      
      // Now filter
      double startLat = 10.3724058876903;
      double startLng = 78.8184533268213;
      double dropLat = 10.7823528802693;
      double dropLng = 79.1346780583262;

      // Extract waypoints
      List<Map<String, dynamic>> waypoints = [];
      if (ride['start_lat'] != null && ride['start_lng'] != null) {
        waypoints.add({
          'locationName': ride['start_location']?.toString() ?? 'Start',
          'lat': (ride['start_lat'] as num).toDouble(),
          'lng': (ride['start_lng'] as num).toDouble(),
          'order': -1,
        });
      }

      if (ride['ride_stops'] != null && ride['ride_stops'] is List) {
        List stops = ride['ride_stops'] as List;
        stops.sort((a, b) => (a['stop_order'] ?? 0).compareTo(b['stop_order'] ?? 0));
        for (var stop in stops) {
          if (stop['lat'] != null && stop['lng'] != null) {
            waypoints.add({
              'locationName': stop['location_name']?.toString() ?? 'Stop',
              'lat': (stop['lat'] as num).toDouble(),
              'lng': (stop['lng'] as num).toDouble(),
              'order': stop['stop_order'] ?? 0,
            });
          }
        }
      }

      if (ride['end_lat'] != null && ride['end_lng'] != null) {
        waypoints.add({
          'locationName': ride['end_location']?.toString() ?? 'End',
          'lat': (ride['end_lat'] as num).toDouble(),
          'lng': (ride['end_lng'] as num).toDouble(),
          'order': 999,
        });
      }

      print('Waypoints: \${waypoints.length}');
      for (var wp in waypoints) {
        print("  wp: \${wp['locationName']} (\${wp['order']})");
      }

      Map<String, dynamic>? matchedStart;
      Map<String, dynamic>? matchedDrop;

      for (var wp in waypoints) {
        double d = distanceBetween(startLat, startLng, wp['lat'], wp['lng']);
        print("Distance to \${wp['locationName']}: \${d/1000} km");
        if (d / 1000 <= 15.0) {
          matchedStart = wp;
          break;
        }
      }

      for (var wp in waypoints.reversed) {
        double d = distanceBetween(dropLat, dropLng, wp['lat'], wp['lng']);
        print("Distance to \${wp['locationName']}: \${d/1000} km");
        if (d / 1000 <= 15.0) {
          matchedDrop = wp;
          break;
        }
      }

      if (matchedStart != null && matchedDrop != null) {
        if (matchedStart['order'] < matchedDrop['order']) {
          print('MATCHED!');
        } else {
          print("FAILED ORDER! Start order: \${matchedStart['order']}, Drop order: \${matchedDrop['order']}");
        }
      } else {
        print('FAILED MATCH: Start: \$matchedStart, Drop: \$matchedDrop');
      }

    }
  } catch (e) {
    print('Exception: \$e');
  }
}
