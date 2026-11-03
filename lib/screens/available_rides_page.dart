import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:loop_car/services/booking_service.dart';
import 'ride.dart';
import 'booking_details_page.dart';

class AvailableRidesPage extends StatefulWidget {
  final List<Map<String, dynamic>> rides;
  final String startLocation;
  final String endLocation;

  const AvailableRidesPage({
    super.key,
    required this.rides,
    required this.startLocation,
    required this.endLocation,
  });

  @override
  State<AvailableRidesPage> createState() => _AvailableRidesPageState();
}

class _AvailableRidesPageState extends State<AvailableRidesPage> {
  final Map<String, String> _rideStatuses = {};
  final BookingService _bookingService = BookingService();
  String? _loadingRideId;

  // For opening the details page without requesting
  void _openRideDetails(BuildContext context, Map<String, dynamic> rideData) async {
    final ride = _mapToRideObject(rideData);
    final newStatus = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => BookingDetailsPage(ride: ride)),
    );

    if (newStatus != null && newStatus is String) {
      if (mounted) {
        setState(() {
          _rideStatuses[ride.id] = newStatus;
        });
      }
    }
  }

  // 1-Click Request directly from the list
  void _handleRequestRide(BuildContext context, Map<String, dynamic> rideData) async {
    final rideIdStr = rideData['id'].toString();
    
    // Check if already waiting
    final currentStatus = _rideStatuses[rideIdStr] ?? rideData['status'];
    if (currentStatus == 'pending') {
       // Navigate to details if already waiting
       _openRideDetails(context, rideData);
       return;
    }

    setState(() {
      _loadingRideId = rideIdStr;
    });

    try {
      final seats = (rideData['available_seats'] ?? rideData['available_seat'] ?? rideData['seats'] ?? 0).toInt();
      final price = (rideData['price_per_seat'] ?? 0).toDouble();
      
      await _bookingService.bookRide(
        rideId: rideIdStr,
        seatsBooked: seats == 0 ? 1 : seats, // Request at least 1 seat
        totalPrice: price * (seats == 0 ? 1 : seats),
        pickupLocation: widget.startLocation.isNotEmpty ? widget.startLocation : (rideData['matched_start_location'] ?? rideData['start_location'] ?? 'Unknown'),
        dropoffLocation: widget.endLocation.isNotEmpty ? widget.endLocation : (rideData['matched_end_location'] ?? rideData['end_location'] ?? 'Unknown'),
      );
      
      if (mounted) {
        setState(() {
          _rideStatuses[rideIdStr] = 'pending';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ride request sent successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send request: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _loadingRideId = null;
        });
      }
    }
  }

  Ride _mapToRideObject(Map<String, dynamic> rideData) {
    // Robustly extract driver name
    final isDriverMap = rideData['driver'] is Map;
    final firstName =
        rideData['driver_first_name'] ??
        rideData['first_name'] ??
        (isDriverMap
            ? rideData['driver']['first_name']
            : 'Unknown');
    final lastName =
        rideData['driver_last_name'] ??
        rideData['last_name'] ??
        (isDriverMap ? rideData['driver']['last_name'] : '');
    final avatar =
        rideData['driver_avatar'] ??
        rideData['avatar_url'] ??
        (isDriverMap ? rideData['driver']['avatar_url'] : '');
    final phone =
        rideData['driver_phone'] ??
        rideData['driver_mobile'] ??
        rideData['phone'] ??
        rideData['mobile'] ??
        (isDriverMap ? (rideData['driver']['mobile'] ?? rideData['driver']['phone']) : null) ??
        'Not provided';

    // Robustly extract pricing/seats
    final priceRaw = rideData['price_per_seat'] ?? 0;
    final price = priceRaw is num ? priceRaw.toInt() : (double.tryParse(priceRaw.toString())?.toInt() ?? 0);
    
    final seatsRaw = rideData['available_seats'] ??
                rideData['available_seat'] ??
                rideData['seats'] ??
                0;
    final seats = seatsRaw is num ? seatsRaw.toInt() : (int.tryParse(seatsRaw.toString()) ?? 0);

    final ratingRaw = rideData['driver_rating'] ?? 0.0;
    final rating = ratingRaw is num ? ratingRaw.toDouble() : (double.tryParse(ratingRaw.toString()) ?? 0.0);

    // Parse time
    final departureData =
        rideData['departure_datetime'] ?? rideData['departure_dat'] ?? '';
    DateTime departureTime;
    try {
      departureTime = DateTime.parse(departureData.toString());
    } catch (e) {
      departureTime = DateTime.now();
    }
    final formattedTime = DateFormat('h:mm a').format(departureTime);

    return Ride(
      id: rideData['id'].toString(),
      driverId: rideData['driver_id']?.toString() ?? '',
      hostName: '$firstName $lastName'.trim(),
      hostPhone: phone.toString(),
      hostImage: avatar.toString(),
      rating: rating,
      price: price,
      pickup: widget.startLocation.isNotEmpty ? widget.startLocation : (rideData['matched_start_location'] ?? rideData['start_location'] ?? 'Unknown').toString(),
      drop: widget.endLocation.isNotEmpty ? widget.endLocation : (rideData['matched_end_location'] ?? rideData['end_location'] ?? 'Unknown').toString(),
      carName: (rideData['car_model'] ?? 'Car').toString(),
      carColor: (rideData['car_color'] ?? '').toString(),
      time: formattedTime,
      seats: seats,
      instantBooking: rideData['instant_booking'] ?? true,
      maxTwoInBack: rideData['max_two_in_back'] ?? true,
      luggageAllowed: rideData['luggage_allowed'] ?? (rideData['luggage_size'] != 'none' && rideData['luggage_size'] != null),
      petsAllowed: rideData['pets_allowed'] ?? false,
      smokingAllowed: rideData['smoking_allowed'] ?? false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9FB), // Very light grey background
      body: SafeArea(
        child: Column(
          children: [
            // Custom Header
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 16, 20),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Color(0xFF00C6D2), size: 32),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  Column(
                    children: [
                      const Text(
                        'Available Rides',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'serif', 
                          color: Color(0xFF263238),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Ride, Laugh, Repeat, For Less!',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Container(
                            width: 5,
                            height: 5,
                            decoration: const BoxDecoration(
                              color: Colors.orange,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Rides List
            Expanded(
              child: widget.rides.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: widget.rides.length,
                      itemBuilder: (context, index) {
                        final ride = widget.rides[index];
                        return _buildRideCard(context, ride);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.directions_car_outlined,
            size: 64,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          const Text(
            'No rides found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Try adjusting your search criteria',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildRideCard(BuildContext context, Map<String, dynamic> ride) {
    final departureData = ride['departure_datetime'] ?? ride['departure_dat'] ?? '';
    DateTime departureTime;
    try {
      departureTime = DateTime.parse(departureData);
    } catch (e) {
      departureTime = DateTime.now();
    }

    String dayLabel = "Today";
    final now = DateTime.now();
    if (departureTime.year == now.year && departureTime.month == now.month && departureTime.day == now.day) {
      dayLabel = "Today";
    } else if (departureTime.year == now.year && departureTime.month == now.month && departureTime.day == now.day + 1) {
      dayLabel = "Tomorrow";
    } else {
      dayLabel = DateFormat('MMM d').format(departureTime);
    }
    final formattedTime = "$dayLabel, ${DateFormat('h:mm a').format(departureTime)}";

    final seats = ride['available_seats'] ?? ride['available_seat'] ?? ride['seats'] ?? 0;
    final driverFirstName = ride['driver_first_name'] ?? ride['first_name'] ?? (ride['driver'] != null ? ride['driver']['first_name'] : 'Unknown');
    final driverLastName = ride['driver_last_name'] ?? ride['last_name'] ?? (ride['driver'] != null ? ride['driver']['last_name'] : '');
    final avatarUrl = ride['driver_avatar'] ?? ride['avatar_url'] ?? (ride['driver'] != null ? ride['driver']['avatar_url'] : null);
        
    final rating = (ride['driver_rating'] ?? 4.8).toString();
    final trips = (ride['driver_trips'] ?? 156).toString();
    final price = (ride['price_per_seat'] ?? 150).toString();
    
    final rideIdStr = ride['id'].toString();
    final currentStatus = _rideStatuses[rideIdStr] ?? ride['status'];
    final isWaiting = currentStatus == 'pending';

    return GestureDetector(
      onTap: () => _openRideDetails(context, ride),
      child: Container(
        margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: isWaiting ? Border.all(color: const Color(0xFFFF5252), width: 1.5) : Border.all(color: Colors.grey.shade100),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile and Price
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(25),
                  child: avatarUrl != null
                      ? Image.network(
                          avatarUrl,
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => _buildAvatarPlaceholder(driverFirstName),
                        )
                      : _buildAvatarPlaceholder(driverFirstName),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$driverFirstName $driverLastName'.trim(),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF263238)),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.star, color: Colors.orangeAccent, size: 14),
                          const SizedBox(width: 4),
                          Text(rating, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          Text(' • $trips trips', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₹$price',
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 22, color: Color(0xFF536DFE)),
                    ),
                    const Text(
                      'PER SEAT',
                      style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            // Timeline and Chat
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTimelineItem(
                        context,
                        title: 'Pickup',
                        location: widget.startLocation.isNotEmpty ? widget.startLocation : (ride['matched_start_location'] ?? ride['start_location'] ?? 'Unknown'),
                        color: const Color(0xFF536DFE),
                        isFirst: true,
                      ),
                      _buildTimelineItem(
                        context,
                        title: 'Drop-off',
                        location: widget.endLocation.isNotEmpty ? widget.endLocation : (ride['matched_end_location'] ?? ride['end_location'] ?? 'Unknown'),
                        color: const Color(0xFF00E676),
                        isLast: true,
                      ),
                      if (ride['car_model'] != null) ...[
                         const SizedBox(height: 8),
                         Text.rich(
                           TextSpan(
                             children: [
                               const TextSpan(text: 'Car Name: ', style: TextStyle(color: Colors.black87, fontSize: 12)),
                               TextSpan(text: ride['car_model'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                             ],
                           ),
                         ),
                      ],
                      if (ride['car_color'] != null) ...[
                         const SizedBox(height: 4),
                         Row(
                           children: [
                             const Text('Car Colour: ', style: TextStyle(color: Colors.black87, fontSize: 12)),
                             Container(
                               width: 14, height: 14,
                               decoration: BoxDecoration(
                                 color: _parseColor(ride['car_color']),
                                 shape: BoxShape.circle,
                                 border: Border.all(color: Colors.grey.shade300),
                               ),
                             ),
                           ],
                         ),
                      ],
                    ],
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(colors: [Colors.grey.shade200, Colors.grey.shade300], begin: Alignment.topCenter, end: Alignment.bottomCenter),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 6, offset: const Offset(0, 3))],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => _openRideDetails(context, ride),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!isWaiting) ...[
                              const Icon(Icons.chat_bubble, color: Colors.amber, size: 16),
                              const SizedBox(width: 6),
                            ],
                            Text(isWaiting ? 'Ride Details' : 'Chat', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 14)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            // Bottom Row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(6)),
                  child: Text(formattedTime, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
                ),
                const SizedBox(width: 12),
                const Icon(Icons.person_outline, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text('$seats', style: const TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.bold)),
                const Spacer(),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: isWaiting 
                      ? const LinearGradient(colors: [Color(0xFFFF8A80), Color(0xFFFF5252)])
                      : const LinearGradient(colors: [Color(0xFF00C6D2), Color(0xFF00E5FF)]),
                    boxShadow: [BoxShadow(color: (isWaiting ? Colors.redAccent : const Color(0xFF00C6D2)).withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(24),
                      onTap: _loadingRideId == rideIdStr ? null : () => _handleRequestRide(context, ride),
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: isWaiting ? 16 : 24, vertical: 10),
                        child: _loadingRideId == rideIdStr
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : Text(
                                isWaiting ? 'Waiting for\nConfirmation' : 'Request Ride',
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14, height: 1.2),
                              ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            
            if (isWaiting) ...[
               const SizedBox(height: 16),
               const Center(
                 child: Text(
                   '"Your ride will be confirmed after the driver approves your request."',
                   style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: Colors.black87),
                 ),
               ),
            ],
          ],
        ),
      ),
    ));
  }

  Color _parseColor(String colorStr) {
    switch (colorStr.toLowerCase()) {
      case 'black': return Colors.black;
      case 'white': return Colors.white;
      case 'red': return Colors.red;
      case 'blue': return Colors.blue;
      case 'silver': return Colors.grey.shade400;
      case 'grey': return Colors.grey;
      default: return Colors.black;
    }
  }

  Widget _buildTimelineItem(BuildContext context, {required String title, required String location, required Color color, bool isFirst = false, bool isLast = false}) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 24,
            child: Column(
              children: [
                if (!isFirst) Container(width: 2, height: 12, color: Colors.grey.shade300),
                Container(
                  width: 14,
                  height: 14,
                  margin: EdgeInsets.only(top: isFirst ? 4 : 0, bottom: isLast ? 4 : 0),
                  decoration: BoxDecoration(color: color.withOpacity(0.2), shape: BoxShape.circle),
                  child: Center(
                    child: Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                  ),
                ),
                if (!isLast) Expanded(child: Container(width: 2, color: Colors.grey.shade300)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(location, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF263238)), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarPlaceholder(String name) {
    return Container(
      width: 50,
      height: 50,
      color: Colors.grey.shade200,
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : 'U',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey),
        ),
      ),
    );
  }
}
