import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/ride_service.dart';
import 'edit_post.dart';
import '../screens/chat_room_screen.dart';
import '../config/supabase_config.dart';

class RideDetailsPage extends StatefulWidget {
  final Map<String, dynamic> ride;
  const RideDetailsPage({super.key, required this.ride});

  @override
  State<RideDetailsPage> createState() => _RideDetailsPageState();
}

class _RideDetailsPageState extends State<RideDetailsPage> {
  bool _isLoading = true;
  Map<String, dynamic>? _fullRideDetails;

  @override
  void initState() {
    super.initState();
    _fetchDetails();
  }

  Future<void> _fetchDetails() async {
    try {
      final details = await RideService().getRideDetails(widget.ride['id']);
      setState(() {
        _fullRideDetails = details ?? widget.ride;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _fullRideDetails = widget.ride;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final rideData = Map<String, dynamic>.from(widget.ride);
    if (_fullRideDetails != null) {
      rideData.addAll(_fullRideDetails!);
      // Ensure passenger-specific properties from widget.ride are preserved
      if (widget.ride.containsKey('is_passenger')) {
        rideData['is_passenger'] = widget.ride['is_passenger'];
      }
      if (widget.ride.containsKey('booking_status')) {
        rideData['booking_status'] = widget.ride['booking_status'];
      }
      if (widget.ride.containsKey('seats_booked')) {
        rideData['seats_booked'] = widget.ride['seats_booked'];
      }
    }
    
    final date = DateTime.parse(rideData['departure_datetime']).toLocal();
    final dateFormatted = DateFormat('EEEE, dd MMMM').format(date);
    final timeFormatted = DateFormat('HH:mm').format(date);
    
    // For visual similarity to the mockup, adding an estimated end time
    final endTimeFormatted = DateFormat('HH:mm').format(date.add(const Duration(hours: 2, minutes: 10)));
    
    String startLoc = rideData['start_location'] ?? 'Unknown';
    String endLoc = rideData['end_location'] ?? 'Unknown';
    
    final double rawPrice = (rideData['price_per_seat'] as num?)?.toDouble() ?? 0.0;
    final price = rawPrice.toStringAsFixed(2);
    
    final bool isDriver = rideData['driver_id'] == SupabaseConfig.userId;
    int displaySeats = 1;
    if (rideData['is_passenger'] == true) {
      displaySeats = rideData['seats_booked'] ?? 1;
    } else if (isDriver) {
      int totalBooked = 0;
      if (rideData['bookings'] != null) {
        for (var b in rideData['bookings']) {
          if (b['status'] == 'accepted') {
            totalBooked += (b['seats_booked'] as num?)?.toInt() ?? 1;
          }
        }
      }
      displaySeats = totalBooked;
    }
    final seats = displaySeats.toString();
    
    List<Map<String, dynamic>> acceptedPassengers = [];
    if (isDriver && rideData['bookings'] != null) {
      for (var b in rideData['bookings']) {
        if (b['status'] == 'accepted' && b['passenger'] != null) {
          acceptedPassengers.add(b);
        }
      }
    }
    
    final driver = rideData['driver'] ?? {};
    final driverName = driver['first_name'] ?? 'Driver';
    
    final vehicle = rideData['vehicle'] ?? {};
    final vehicleName = vehicle.isNotEmpty 
        ? "${vehicle['make'] ?? ''} ${vehicle['model'] ?? ''} - ${vehicle['color'] ?? ''}".trim()
        : "Vehicle info not available";

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(color: Colors.black),
        elevation: 0,
        backgroundColor: Colors.transparent,
        centerTitle: true,
        title: const Text(
          "Ride, Laugh, Repeat, For Less!",
          style: TextStyle(
            color: Color(0xFF00C6D2),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Color(0xFF00C6D2)))
        : SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Ride Details",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF00C6D2),
                  ),
                ),

                const SizedBox(height: 20),

                if (rideData['is_passenger'] != true)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline, size: 18, color: Colors.grey),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "This is your ride as it is seen by passengers. Only your booked stopovers are shown.",
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                        ),
                      ),
                    ],
                  ),

                if (rideData['is_passenger'] != true)
                  const SizedBox(height: 20),

                Text(dateFormatted, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),

                const SizedBox(height: 20),

                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      children: [
                        Text(timeFormatted, style: const TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text("2h10", style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                        const SizedBox(height: 12),
                        Text(endTimeFormatted, style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(width: 10),
                    Column(
                      children: [
                        const Icon(Icons.circle_outlined, size: 12, color: Colors.black54),
                        Container(height: 40, width: 2, color: Colors.black54),
                        const Icon(Icons.circle, size: 12, color: Colors.black54),
                      ],
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(child: Text(startLoc, style: const TextStyle(fontWeight: FontWeight.bold))),
                              const SizedBox(width: 4),
                              const Icon(Icons.map_outlined, size: 16, color: Colors.blue),
                            ],
                          ),
                          const SizedBox(height: 42),
                          Row(
                            children: [
                              Expanded(child: Text(endLoc, style: const TextStyle(fontWeight: FontWeight.bold))),
                              const SizedBox(width: 4),
                              const Icon(Icons.map_outlined, size: 16, color: Colors.blue),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),
                const Divider(),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("$seats passenger${seats == '1' ? '' : 's'}", style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text("₹$price", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  ],
                ),

                const Divider(),

                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(backgroundColor: Colors.grey, child: Icon(Icons.person, color: Colors.white)),
                  title: Text(driverName, style: const TextStyle(fontWeight: FontWeight.bold)),
                  trailing: const Icon(Icons.chevron_right),
                ),

                const Divider(),

                const ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.flash_on, color: Colors.grey),
                  title: Text("Passenger bookings will be confirmed instantly", style: TextStyle(color: Colors.black87, fontSize: 14)),
                ),

                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.directions_car, color: Colors.grey),
                  title: Text(vehicleName, style: const TextStyle(color: Colors.black87, fontSize: 14)),
                ),

                const SizedBox(height: 20),
                
                // Show accepted passengers to the driver
                if (isDriver && acceptedPassengers.isNotEmpty) ...[
                  const Text("Passengers", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 10),
                  ...acceptedPassengers.map((b) {
                    final passenger = b['passenger'];
                    final pName = '${passenger['first_name']} ${passenger['last_name']}';
                    final pAvatar = passenger['avatar_url'];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: Colors.grey.shade200,
                        backgroundImage: pAvatar != null ? NetworkImage(pAvatar) : null,
                        child: pAvatar == null ? const Icon(Icons.person, color: Colors.grey) : null,
                      ),
                      title: Text(pName, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text("${b['seats_booked']} seat(s) booked"),
                      trailing: IconButton(
                        icon: const Icon(Icons.chat, color: Color(0xFF00C6D2)),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatRoomScreen(
                                threadId: '${rideData['id']}_${passenger['id']}',
                                userName: pName,
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  }).toList(),
                  const Divider(),
                ],
                
                // Show Chat with Driver for passenger if accepted
                if (rideData['is_passenger'] == true && rideData['booking_status'] == 'accepted')
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4A4EFE),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          icon: const Icon(Icons.chat),
                          label: const Text("Chat with Driver", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          onPressed: () {
                            final driver = rideData['driver'] ?? {};
                            final driverName = '${driver['first_name'] ?? 'Driver'} ${driver['last_name'] ?? ''}'.trim();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ChatRoomScreen(
                                  threadId: '${rideData['id']}_${SupabaseConfig.userId}',
                                  userName: driverName,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),

                if (rideData['is_passenger'] != true)
                  Center(
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00C6D2),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => EditPostPage(rideData: rideData)),
                          );
                          _fetchDetails();
                        },
                        child: const Text("Manage Ride Offer", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ),
                  ),
              ],
            ),
          ),
    );
  }
}
