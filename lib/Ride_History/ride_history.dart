import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/ride_service.dart';
import '../services/booking_service.dart';
import '../screens/driver_requests_screen.dart';
import 'ride_details.dart';

class RideHistoryPage extends StatefulWidget {
  const RideHistoryPage({super.key});

  @override
  State<RideHistoryPage> createState() => _RideHistoryPageState();
}

class _RideHistoryPageState extends State<RideHistoryPage> {
  bool showYourRide = true; // open by default
  bool showUpcoming = false; // closed by default
  bool showCompleted = false; // closed by default
  bool isLoading = true;
  
  List<Map<String, dynamic>> yourRides = [];
  List<Map<String, dynamic>> upcomingRides = [];
  List<Map<String, dynamic>> completedRides = [];
  
  final RideService _rideService = RideService();
  final BookingService _bookingService = BookingService();

  @override
  void initState() {
    super.initState();
    _fetchRides();
  }

  Future<void> _fetchRides() async {
    try {
      final postedRides = await _rideService.getMyPostedRides();
      final myBookings = await _bookingService.getMyBookings();
      
      final now = DateTime.now();
      
      // Map bookings into ride objects so they can be displayed the same way
      final passengerRides = myBookings.map((booking) {
        final rideData = Map<String, dynamic>.from(booking['ride'] ?? {});
        rideData['is_passenger'] = true;
        rideData['booking_status'] = booking['status'];
        rideData['seats_booked'] = booking['seats_booked'];
        rideData['pickup_location'] = booking['pickup_location'] ?? rideData['start_location'];
        rideData['dropoff_location'] = booking['dropoff_location'] ?? rideData['end_location'];
        return rideData;
      }).toList();

      final allRides = [...postedRides, ...passengerRides];
      
      setState(() {
        yourRides = allRides.where((ride) {
          if (ride['departure_datetime'] == null) return false;
          final date = DateTime.parse(ride['departure_datetime']).toLocal();
          
          if (ride['is_passenger'] == true) return false; // Not a posted ride

          if (ride['status'] == 'completed' || ride['status'] == 'cancelled' || date.isBefore(now)) return false;

          int totalBookings = 0;
          if (ride['bookings'] != null) {
            final bookings = List<dynamic>.from(ride['bookings']);
            totalBookings = bookings.length;
          }

          return totalBookings == 0;
        }).toList();

        upcomingRides = allRides.where((ride) {
          if (ride['departure_datetime'] == null) return false;
          final date = DateTime.parse(ride['departure_datetime']).toLocal();
          
          if (ride['is_passenger'] == true) {
            final bStatus = ride['booking_status'];
            return bStatus != 'cancelled' && bStatus != 'rejected' && ride['status'] != 'completed' && ride['status'] != 'cancelled' && date.isAfter(now);
          }
          
          if (ride['status'] == 'completed' || ride['status'] == 'cancelled' || date.isBefore(now)) return false;

          int totalBookings = 0;
          if (ride['bookings'] != null) {
            final bookings = List<dynamic>.from(ride['bookings']);
            totalBookings = bookings.length;
          }

          return totalBookings > 0;
        }).toList();

        completedRides = allRides.where((ride) {
          if (ride['departure_datetime'] == null) return false;
          final date = DateTime.parse(ride['departure_datetime']).toLocal();
          
          if (ride['is_passenger'] == true) {
             final bStatus = ride['booking_status'];
             return bStatus == 'cancelled' || bStatus == 'rejected' || ride['status'] == 'completed' || ride['status'] == 'cancelled' || date.isBefore(now);
          }
          
          return ride['status'] == 'completed' || ride['status'] == 'cancelled' || date.isBefore(now);
        }).toList();

        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      // Print error or show snackbar
      debugPrint("Error fetching rides: $e");
    }
  }

  Widget _buildRideCard(Map<String, dynamic> ride) {
    int pendingCount = 0;
    int totalBookings = 0;
    if (ride['bookings'] != null) {
      final bookings = List<dynamic>.from(ride['bookings']);
      pendingCount = bookings.where((b) => b['status'] == 'pending').length;
      totalBookings = bookings.length;
    }

    final date = DateTime.parse(ride['departure_datetime']).toLocal();
    final dateFormatted = DateFormat('EEE dd MMM').format(date);
    final timeFormatted = DateFormat('HH:mm').format(date);
    
    // Split locations to get just city names if possible
    String startLoc = ride['is_passenger'] == true ? (ride['pickup_location'] ?? ride['start_location'] ?? 'Unknown') : (ride['start_location'] ?? 'Unknown');
    String endLoc = ride['is_passenger'] == true ? (ride['dropoff_location'] ?? ride['end_location'] ?? 'Unknown') : (ride['end_location'] ?? 'Unknown');
    
    if (startLoc.contains(',')) {
      startLoc = startLoc.split(',').first;
    }
    if (endLoc.contains(',')) {
      endLoc = endLoc.split(',').first;
    }

    String displayStatus = '';
    Color statusColor = Colors.grey;
    if (ride['is_passenger'] == true) {
      final bStatus = ride['booking_status'] ?? '';
      if (bStatus == 'pending') {
        displayStatus = 'Waiting';
        statusColor = Colors.orange;
      } else if (bStatus == 'accepted') {
        displayStatus = 'Accepted';
        statusColor = Colors.green;
      } else if (bStatus == 'cancelled' || bStatus == 'rejected') {
        displayStatus = 'Cancelled';
        statusColor = Colors.red;
      }
    }

    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => RideDetailsPage(ride: ride),
          ),
        );
        _fetchRides();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 15, left: 40, right: 40),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              blurRadius: 6,
              color: Colors.grey.withValues(alpha: 0.2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              dateFormatted,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Column(
                  children: [
                    const Icon(Icons.circle_outlined, size: 12, color: Colors.black54),
                    Container(height: 20, width: 2, color: Colors.black54),
                    const Icon(Icons.circle, size: 12, color: Colors.black54),
                  ],
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "$timeFormatted   $startLoc",
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        "---   $endLoc",
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    ElevatedButton(
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => RideDetailsPage(ride: ride),
                          ),
                        );
                        _fetchRides();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.shade300,
                        foregroundColor: Colors.black87,
                        elevation: 4,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: Text(
                        ride['is_passenger'] == true ? 'View Ride' : 'Ride Details',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    if (ride['is_passenger'] == true && displayStatus.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          displayStatus,
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                    if (ride['is_passenger'] != true && totalBookings > 0) ...[
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => DriverRequestsScreen(rideId: ride['id'].toString()),
                            ),
                          );
                          _fetchRides();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey.shade300,
                          foregroundColor: Colors.black87,
                          elevation: 4,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        child: Text(
                          pendingCount > 0 ? 'Requests ($pendingCount)' : 'Requests',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff2f2f2),

      body: SafeArea(
        child: isLoading 
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00C6D2))) 
          : SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 40),

                  const Text(
                    "Ride, Laugh, Repeat, For Less!",
                    style: TextStyle(
                      color: Color(0xFF00C6D2),
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 25),

                  /// YOUR RIDE HEADER
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          showYourRide = !showYourRide;
                          if (showYourRide) {
                            showUpcoming = false;
                            showCompleted = false;
                          }
                        });
                      },
                      child: Row(
                        children: [
                          Icon(
                            showYourRide
                                ? Icons.remove_circle_outline
                                : Icons.add_circle_outline,
                            color: const Color(0xFF00C6D2),
                            size: 28,
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            "Your Ride",
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF00C6D2),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  /// YOUR RIDE CONTENT
                  if (showYourRide)
                    if (yourRides.isEmpty)
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 40),
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              blurRadius: 6,
                              color: Colors.grey.withValues(alpha: 0.2),
                            ),
                          ],
                        ),
                        child: const Text(
                          "No posted rides without requests",
                          style: TextStyle(color: Colors.black54),
                        ),
                      )
                    else
                      ...yourRides.map((ride) => _buildRideCard(ride)),

                  const SizedBox(height: 40),

                  /// UPCOMING RIDE HEADER
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          showUpcoming = !showUpcoming;
                          if (showUpcoming) {
                            showYourRide = false;
                            showCompleted = false;
                          }
                        });
                      },
                      child: Row(
                        children: [
                          Icon(
                            showUpcoming
                                ? Icons.remove_circle_outline
                                : Icons.add_circle_outline,
                            color: const Color(0xFF00C6D2),
                            size: 28,
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            "Upcoming Ride",
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF00C6D2),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  /// UPCOMING RIDE CONTENT
                  if (showUpcoming)
                    if (upcomingRides.isEmpty)
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 40),
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              blurRadius: 6,
                              color: Colors.grey.withValues(alpha: 0.2),
                            ),
                          ],
                        ),
                        child: const Text(
                          "No upcoming rides",
                          style: TextStyle(color: Colors.black54),
                        ),
                      )
                    else
                      ...upcomingRides.map((ride) => _buildRideCard(ride)),

                  const SizedBox(height: 40),

                  /// COMPLETED RIDE HEADER
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          showCompleted = !showCompleted;
                          if (showCompleted) {
                            showYourRide = false;
                            showUpcoming = false;
                          }
                        });
                      },
                      child: Row(
                        children: [
                          Icon(
                            showCompleted
                                ? Icons.remove_circle_outline
                                : Icons.add_circle_outline,
                            color: const Color(0xFF00C6D2),
                            size: 28,
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            "Completed Ride",
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF00C6D2),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  /// COMPLETED RIDE CONTENT
                  if (showCompleted)
                    if (completedRides.isEmpty)
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 40),
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              blurRadius: 6,
                              color: Colors.grey.withValues(alpha: 0.2),
                            ),
                          ],
                        ),
                        child: const Text(
                          "No completed rides yet",
                          style: TextStyle(color: Colors.black54),
                        ),
                      )
                    else
                      ...completedRides.map((ride) => _buildRideCard(ride)),
                      
                  const SizedBox(height: 40),
                ],
              ),
            ),
      ),
    );
  }
}
