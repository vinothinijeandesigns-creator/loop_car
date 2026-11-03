import 'package:intl/intl.dart';
import '../config/supabase_config.dart';
import 'chat_service.dart';
import 'communication_service.dart';

class BookingService {
  final _client = SupabaseConfig.client;

  // ==================== CREATE BOOKING ====================

  /// Book a ride
  Future<Map<String, dynamic>> bookRide({
    required String rideId,
    required int seatsBooked,
    required double totalPrice,
    String? pickupLocation,
    double? pickupLat,
    double? pickupLng,
    String? dropoffLocation,
    double? dropoffLat,
    double? dropoffLng,
  }) async {
    final userId = SupabaseConfig.userId;
    if (userId == null) throw Exception('Not authenticated');

    final response =
        await _client
            .from('bookings')
            .insert({
              'ride_id': rideId,
              'passenger_id': userId,
              'seats_booked': seatsBooked,
              'total_price': totalPrice,
              'pickup_location': pickupLocation,
              'pickup_lat': pickupLat,
              'pickup_lng': pickupLng,
              'dropoff_location': dropoffLocation,
              'dropoff_lat': dropoffLat,
              'dropoff_lng': dropoffLng,
              'status': 'pending',
            })
            .select('*, passenger:profiles!passenger_id(first_name, last_name), ride:rides(driver_id, departure_datetime)')
            .single();

    try {
      final passengerName = response['passenger'] != null ? '${response['passenger']['first_name']} ${response['passenger']['last_name']}' : 'Passenger';
      final threadId = '${rideId}_$userId';
      final pickup = pickupLocation ?? 'Pickup';
      final drop = dropoffLocation ?? 'Dropoff';
      String dateFormatted = '';
      if (response['ride'] != null && response['ride']['departure_datetime'] != null) {
        final rideDate = DateTime.parse(response['ride']['departure_datetime']).toLocal();
        dateFormatted = ' on ${DateFormat('MMM dd, yyyy').format(rideDate)}';
      }
      final msg = 'New booking from $passengerName for your $pickup - $drop ride$dateFormatted. Wait for driver approval.';
      await ChatService().sendSystemMessage(threadId, msg);
      
      // Notify Driver
      final driverId = response['ride'] != null ? response['ride']['driver_id'] : null;
      if (driverId != null) {
         await CommunicationService.notifyUser(
           userId: driverId,
           title: 'New Ride Request',
           message: '$passengerName requested $seatsBooked seat(s) for $pickup to $drop.',
         );
      }
    } catch (e) {
      print("Error sending new booking chat message: $e");
    }

    return response;
  }

  // ==================== GET BOOKINGS (AS PASSENGER) ====================

  /// Get all bookings made by the current user (as passenger)
  Future<List<Map<String, dynamic>>> getMyBookings() async {
    final userId = SupabaseConfig.userId;
    if (userId == null) throw Exception('Not authenticated');

    final response = await _client
        .from('bookings')
        .select('''
          *,
          ride:rides (
            id,
            start_location,
            end_location,
            start_lat,
            start_lng,
            end_lat,
            end_lng,
            departure_datetime,
            price_per_seat,
            status,
            driver:profiles!driver_id (
              id,
              first_name,
              last_name,
              avatar_url,
              rating_avg,
              mobile
            )
          )
        ''')
        .eq('passenger_id', userId)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  /// Get upcoming bookings (pending or accepted, ride not completed)
  Future<List<Map<String, dynamic>>> getMyUpcomingBookings() async {
    final userId = SupabaseConfig.userId;
    if (userId == null) throw Exception('Not authenticated');

    final response = await _client
        .from('bookings')
        .select('''
          *,
          ride:rides!inner (
            id,
            start_location,
            end_location,
            departure_datetime,
            price_per_seat,
            status,
            driver:profiles!driver_id (
              first_name,
              last_name,
              mobile,
              avatar_url
            )
          )
        ''')
        .eq('passenger_id', userId)
        .inFilter('status', ['pending', 'accepted'])
        .gte(
          'ride.departure_datetime',
          DateTime.now().toUtc().toIso8601String(),
        )
        .order('ride.departure_datetime', ascending: true);

    return List<Map<String, dynamic>>.from(response);
  }

  // ==================== GET BOOKINGS (AS DRIVER) ====================

  /// Get all bookings for rides posted by the current user (as driver)
  Future<List<Map<String, dynamic>>> getBookingsForMyRides() async {
    final userId = SupabaseConfig.userId;
    if (userId == null) throw Exception('Not authenticated');

    final response = await _client
        .from('bookings')
        .select('''
          *,
          ride:rides!inner (
            id,
            start_location,
            end_location,
            departure_datetime,
            driver_id
          ),
          passenger:profiles!passenger_id (
            id,
            first_name,
            last_name,
            avatar_url,
            rating_avg,
            mobile
          )
        ''')
        .eq('ride.driver_id', userId)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  /// Get pending bookings for driver to review
  Future<List<Map<String, dynamic>>> getPendingBookingsForDriver() async {
    final userId = SupabaseConfig.userId;
    if (userId == null) throw Exception('Not authenticated');

    final response = await _client
        .from('bookings')
        .select('''
          *,
          ride:rides!inner (
            id,
            start_location,
            end_location,
            departure_datetime,
            available_seats,
            driver_id
          ),
          passenger:profiles!passenger_id (
            id,
            first_name,
            last_name,
            avatar_url,
            rating_avg,
            mobile
          )
        ''')
        .eq('ride.driver_id', userId)
        .eq('status', 'pending')
        .order('created_at', ascending: true);

    return List<Map<String, dynamic>>.from(response);
  }

  /// Get ALL bookings for a specific ride (driver action)
  Future<List<Map<String, dynamic>>> getBookingsForRide(String rideId) async {
    final userId = SupabaseConfig.userId;
    if (userId == null) throw Exception('Not authenticated');

    final response = await _client
        .from('bookings')
        .select('''
          *,
          ride:rides!inner (
            id,
            start_location,
            end_location,
            departure_datetime,
            available_seats,
            driver_id
          ),
          passenger:profiles!passenger_id (
            id,
            first_name,
            last_name,
            avatar_url,
            rating_avg,
            mobile
          )
        ''')
        .eq('ride_id', rideId)
        .eq('ride.driver_id', userId)
        .order('created_at', ascending: true);

    return List<Map<String, dynamic>>.from(response);
  }

  // ==================== UPDATE BOOKING STATUS ====================

  /// Accept a booking (driver action)
  Future<void> acceptBooking(String bookingId) async {
    await _client
        .from('bookings')
        .update({'status': 'accepted'})
        .eq('id', bookingId);
        
    try {
       final req = await _client.from('bookings').select('*, passenger:profiles!passenger_id(first_name, last_name), ride:rides(id, start_location, end_location, departure_datetime)').eq('id', bookingId).single();
       final rideId = req['ride_id'];
       final pickup = req['pickup_location'] ?? req['ride']['start_location'];
       final drop = req['dropoff_location'] ?? req['ride']['end_location'];
       final threadId = '${rideId}_${req['passenger_id']}';
       
       String dateFormatted = '';
       if (req['ride'] != null && req['ride']['departure_datetime'] != null) {
         final rideDate = DateTime.parse(req['ride']['departure_datetime']).toLocal();
         dateFormatted = ' on ${DateFormat('MMM dd, yyyy').format(rideDate)}';
       }
       
       await ChatService().sendSystemMessage(threadId, 'LoopCar: Driver approved your request for $pickup to $drop$dateFormatted.');
       
       // Send push notification to passenger
       await CommunicationService.notifyUser(
         userId: req['passenger_id'],
         title: 'Ride Approved!',
         message: 'Your request for $pickup to $drop was approved.',
       );
    } catch (_) {}
  }

  /// Reject a booking (driver action)
  Future<void> rejectBooking(String bookingId) async {
    await _client
        .from('bookings')
        .update({'status': 'rejected'})
        .eq('id', bookingId);
  }

  /// Cancel a booking (passenger action)
  Future<void> cancelBooking(String bookingId) async {
    await _client
        .from('bookings')
        .update({'status': 'cancelled'})
        .eq('id', bookingId);
        
    try {
       final req = await _client.from('bookings').select('*, passenger:profiles!passenger_id(first_name, last_name), ride:rides(id, start_location, end_location, driver_id, departure_datetime)').eq('id', bookingId).single();
       final passengerName = req['passenger'] != null ? '${req['passenger']['first_name']} ${req['passenger']['last_name']}' : 'Passenger';
       final rideId = req['ride_id'];
       final pickup = req['pickup_location'] ?? req['ride']['start_location'];
       final drop = req['dropoff_location'] ?? req['ride']['end_location'];
       final threadId = '${rideId}_${req['passenger_id']}';
       
       String dateFormatted = '';
       if (req['ride'] != null && req['ride']['departure_datetime'] != null) {
         final rideDate = DateTime.parse(req['ride']['departure_datetime']).toLocal();
         dateFormatted = ' on ${DateFormat('MMM dd, yyyy').format(rideDate)}';
       }
       
       await ChatService().sendSystemMessage(threadId, 'LoopCar: $passengerName cancelled the request for $pickup to $drop$dateFormatted.');
       
       // Send push notification to driver
       final driverId = req['ride'] != null ? req['ride']['driver_id'] : null;
       if (driverId != null) {
          await CommunicationService.notifyUser(
            userId: driverId,
            title: 'Ride Cancelled',
            message: '$passengerName cancelled their request for $pickup to $drop.',
          );
       }
    } catch (_) {}
  }

  /// Complete a booking
  Future<void> completeBooking(String bookingId) async {
    await _client
        .from('bookings')
        .update({'status': 'completed'})
        .eq('id', bookingId);
  }

  // ==================== GET SINGLE BOOKING ====================

  /// Get booking details by ID
  Future<Map<String, dynamic>?> getBookingDetails(String bookingId) async {
    final response =
        await _client
            .from('bookings')
            .select('''
          *,
          ride:rides (
            id,
            start_location,
            end_location,
            start_lat,
            start_lng,
            end_lat,
            end_lng,
            departure_datetime,
            price_per_seat,
            status,
            notes,
            driver:profiles!driver_id (
              id,
              first_name,
              last_name,
              avatar_url,
              rating_avg,
              mobile
            ),
            vehicle:vehicles (
              make,
              model,
              color,
              plate_number
            )
          ),
          passenger:profiles!passenger_id (
            id,
            first_name,
            last_name,
            avatar_url,
            mobile
          )
        ''')
            .eq('id', bookingId)
            .maybeSingle();

    return response;
  }

  // ==================== CHECK EXISTING BOOKING ====================

  /// Check if user already has a booking for a ride
  Future<bool> hasExistingBooking(String rideId) async {
    final userId = SupabaseConfig.userId;
    if (userId == null) return false;

    final response =
        await _client
            .from('bookings')
            .select('id')
            .eq('ride_id', rideId)
            .eq('passenger_id', userId)
            .maybeSingle();

    return response != null;
  }
}
