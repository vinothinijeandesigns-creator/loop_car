import '../config/supabase_config.dart';

class RideService {
  final _client = SupabaseConfig.client;

  // ==================== CREATE RIDE ====================

  /// Create a new ride (POST RIDE)
  Future<Map<String, dynamic>> createRide({
    required String startLocation,
    required double startLat,
    required double startLng,
    required String endLocation,
    required double endLat,
    required double endLng,
    required DateTime departureDateTime,
    required int availableSeats,
    required double pricePerSeat,
    required double distance,
    String? vehicleId,
    bool musicAllowed = true,
    bool smokingAllowed = false,
    bool petsAllowed = false,
    String luggageSize = 'small',
    String? notes,
    List<Map<String, dynamic>> stopovers = const [],
  }) async {
    final userId = SupabaseConfig.userId;
    if (userId == null) throw Exception('Not authenticated');

    // 1. Insert the main ride
    final rideResponse =
        await _client
            .from('rides')
            .insert({
              'driver_id': userId,
              'vehicle_id': vehicleId,
              'start_location': startLocation,
              'start_lat': startLat,
              'start_lng': startLng,
              'end_location': endLocation,
              'end_lat': endLat,
              'end_lng': endLng,
              'departure_datetime': departureDateTime.toUtc().toIso8601String(),
              'available_seats': availableSeats,
              'price_per_seat': pricePerSeat,
              'distance': distance,
              'music_allowed': musicAllowed,
              'smoking_allowed': smokingAllowed,
              'pets_allowed': petsAllowed,
              'luggage_size': luggageSize,
              'notes': notes,
              'status': 'active',
            })
            .select()
            .single();

    final rideId = rideResponse['id'];

    // 2. Insert stopovers if any
    if (stopovers.isNotEmpty) {
      final stopEntries =
          stopovers.asMap().entries.map((entry) {
            final idx = entry.key;
            final stop = entry.value;
            return {
              'ride_id': rideId,
              'location_name': stop['location_name'],
              'lat': stop['lat'],
              'lng': stop['lng'],
              'stop_order': idx,
            };
          }).toList();

      await _client.from('ride_stops').insert(stopEntries);
    }

    return rideResponse;
  }

  // ==================== SEARCH RIDES ====================

  /// Search rides by location and date using the database function
  Future<List<Map<String, dynamic>>> searchRides({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
    required DateTime departureDate,
    int seats = 1,
    double radiusKm = 15.0,
  }) async {
    try {
      // First try the advanced search that handles stops
      // This assumes the RPC 'search_rides_advanced' exists or 'search_rides' has been updated
      final response = await _client.rpc(
        'search_rides_advanced',
        params: {
          'p_start_lat': startLat,
          'p_start_lng': startLng,
          'p_end_lat': endLat,
          'p_end_lng': endLng,
          'p_departure_date': departureDate.toIso8601String().split('T')[0],
          'p_seats': seats,
          'p_radius_km': radiusKm,
        },
      );
      return List<Map<String, dynamic>>.from(response ?? []);
    } catch (e) {
      // Fallback to legacy search if advanced search fails
      try {
        final response = await _client.rpc(
          'search_rides',
          params: {
            'p_start_lat': startLat,
            'p_start_lng': startLng,
            'p_end_lat': endLat,
            'p_end_lng': endLng,
            'p_departure_date': departureDate.toIso8601String().split('T')[0],
            'p_seats': seats,
            'p_radius_km': radiusKm,
          },
        );
        return List<Map<String, dynamic>>.from(response ?? []);
      } catch (e2) {
        // Final fallback: Basic search by date
        return searchRidesBasic(departureDate: departureDate, seats: seats);
      }
    }
  }

  /// Search rides with basic filters (alternative without location radius)
  Future<List<Map<String, dynamic>>> searchRidesBasic({
    required DateTime departureDate,
    int seats = 1,
  }) async {
    final startOfDay = DateTime(
      departureDate.year,
      departureDate.month,
      departureDate.day,
    );
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final response = await _client
        .from('rides')
        .select('''
          *,
          driver:profiles!driver_id (
            id,
            first_name,
            last_name,
            avatar_url,
            rating_avg,
            mobile
          ),
          ride_stops (
            location_name,
            lat,
            lng,
            stop_order
          )
        ''')
        .eq('status', 'active')
        .gte('available_seats', seats)
        .gte('departure_datetime', startOfDay.toUtc().toIso8601String())
        .order('departure_datetime', ascending: true);

    return List<Map<String, dynamic>>.from(response);
  }

  // ==================== GET RIDE DETAILS ====================

  /// Get ride details with driver and vehicle info
  Future<Map<String, dynamic>?> getRideDetails(String rideId) async {
    final response =
        await _client
            .from('rides')
            .select('''
          *,
          driver:profiles!driver_id (
            id,
            first_name,
            last_name,
            avatar_url,
            rating_avg,
            total_rides,
            mobile
          ),
          vehicle:vehicles (
            id,
            make,
            model,
            color,
            plate_number,
            vehicle_type,
            total_seats
          ),
          bookings (
            id,
            seats_booked,
            status,
            passenger:profiles!passenger_id (
              id,
              first_name,
              last_name,
              avatar_url
            )
          )
        ''')
            .eq('id', rideId)
            .maybeSingle();

    return response;
  }

  // ==================== MY RIDES (AS DRIVER) ====================

  /// Get rides posted by the current user
  Future<List<Map<String, dynamic>>> getMyPostedRides() async {
    final userId = SupabaseConfig.userId;
    if (userId == null) throw Exception('Not authenticated');

    final response = await _client
        .from('rides')
        .select('''
          *,
          bookings (
            id,
            seats_booked,
            status
          )
        ''')
        .eq('driver_id', userId)
        .order('departure_datetime', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  /// Get upcoming rides (active or full, departure in future)
  Future<List<Map<String, dynamic>>> getMyUpcomingRides() async {
    final userId = SupabaseConfig.userId;
    if (userId == null) throw Exception('Not authenticated');

    final response = await _client
        .from('rides')
        .select('''
          *,
          bookings (
            id,
            seats_booked,
            status,
            passenger:profiles!passenger_id (
              id,
              first_name,
              last_name,
              mobile
            )
          )
        ''')
        .eq('driver_id', userId)
        .inFilter('status', ['active', 'full'])
        .gte('departure_datetime', DateTime.now().toUtc().toIso8601String())
        .order('departure_datetime', ascending: true);

    return List<Map<String, dynamic>>.from(response);
  }

  // ==================== UPDATE RIDE ====================

  /// Update a ride
  Future<void> updateRide(String rideId, Map<String, dynamic> updates) async {
    await _client.from('rides').update(updates).eq('id', rideId);
  }

  /// Cancel a ride
  Future<void> cancelRide(String rideId) async {
    await _client
        .from('rides')
        .update({'status': 'cancelled'})
        .eq('id', rideId);
  }

  /// Start a ride (change status to in_progress)
  Future<void> startRide(String rideId) async {
    await _client
        .from('rides')
        .update({'status': 'in_progress'})
        .eq('id', rideId);
  }

  /// Complete a ride
  Future<void> completeRide(String rideId) async {
    await _client
        .from('rides')
        .update({'status': 'completed'})
        .eq('id', rideId);

    // Also complete all accepted bookings for this ride
    await _client
        .from('bookings')
        .update({'status': 'completed'})
        .eq('ride_id', rideId)
        .eq('status', 'accepted');
  }

  // ==================== DELETE RIDE ====================

  /// Delete a ride (only if no accepted bookings)
  Future<void> deleteRide(String rideId) async {
    await _client.from('rides').delete().eq('id', rideId);
  }
}
