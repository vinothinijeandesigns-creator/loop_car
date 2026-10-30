import 'package:flutter/material.dart';
import 'package:loop_car/services/booking_service.dart';
import 'chat_room_screen.dart';
import 'package:loop_car/config/supabase_config.dart';
import 'package:loop_car/services/chat_service.dart';
import 'package:loop_car/services/communication_service.dart';

class DriverRequestsScreen extends StatefulWidget {
  final String rideId;
  
  const DriverRequestsScreen({super.key, required this.rideId});

  @override
  State<DriverRequestsScreen> createState() => _DriverRequestsScreenState();
}

class _DriverRequestsScreenState extends State<DriverRequestsScreen> {
  final BookingService _bookingService = BookingService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _pendingRequests = [];
  final Set<String> _declinedRequests = {};
  final Set<String> _acceptedRequests = {};

  @override
  void initState() {
    super.initState();
    _fetchRequests();
  }

  Future<void> _fetchRequests() async {
    setState(() => _isLoading = true);
    try {
      final requests = await _bookingService.getBookingsForRide(widget.rideId);
      if (mounted) {
        setState(() {
          _pendingRequests = requests;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading requests: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleAction(String bookingId, bool isAccept) async {
    // Show loading overlay
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      if (isAccept) {
        await _bookingService.acceptBooking(bookingId);
      } else {
        await _bookingService.rejectBooking(bookingId);
        
        try {
          final request = _pendingRequests.firstWhere((r) => r['id'].toString() == bookingId);
          final passenger = request['passenger'];
          final ride = request['ride'];
          final passengerId = passenger['id'];
          final threadId = '${ride['id']}_$passengerId';
          
          final pickup = request['pickup_location'] ?? ride['start_location'];
          final dropoff = request['dropoff_location'] ?? ride['end_location'];
          
          await ChatService().sendSystemMessage(
            threadId, 
            'LoopCar: Driver declined the request for your ride from $pickup to $dropoff.',
          );
          
          await CommunicationService.notifyUser(
            userId: passengerId,
            title: 'Ride Request Declined',
            message: 'Your request for $pickup to $dropoff was declined.',
          );
        } catch (e) {
          debugPrint("Error sending decline notification: $e");
        }
      }
      
      if (mounted) {
        Navigator.pop(context); // Remove loading overlay
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isAccept ? 'Request approved!' : 'Request declined.')),
        );
        setState(() {
          if (isAccept) {
            _acceptedRequests.add(bookingId);
          } else {
            _declinedRequests.add(bookingId);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Remove loading overlay
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to process action: $e')),
        );
      }
    }
  }

  void _openChat(Map<String, dynamic> request) {
    final passenger = request['passenger'];
    final ride = request['ride'];
    final passengerName = '${passenger['first_name']} ${passenger['last_name']}';
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatRoomScreen(
          threadId: '${ride['id']}_${passenger['id']}',
          userName: passengerName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9FB),
      appBar: AppBar(
        title: const Text('Ride Requests', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchRequests,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _pendingRequests.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _fetchRequests,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _pendingRequests.length,
                    itemBuilder: (context, index) {
                      final request = _pendingRequests[index];
                      return _buildRequestCard(request);
                    },
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            'No requests found',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Text(
            'There are no booking requests for this ride yet.',
            style: TextStyle(color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> request) {
    final passenger = request['passenger'];
    final ride = request['ride'];
    final bookingId = request['id'].toString();
    
    final avatarUrl = passenger['avatar_url'];
    final passengerName = '${passenger['first_name']} ${passenger['last_name']}';
    final rating = passenger['rating_avg']?.toString() ?? 'New';
    
    final seatsBooked = request['seats_booked'];
    final totalPrice = request['total_price'];
    final status = request['status'];
    
    final bool isDeclined = _declinedRequests.contains(bookingId) || status == 'rejected';
    final bool isAccepted = _acceptedRequests.contains(bookingId) || status == 'accepted';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Passenger Info Header
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.grey.shade200,
                  backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                  child: avatarUrl == null ? const Icon(Icons.person, color: Colors.grey) : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(passengerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 14),
                          const SizedBox(width: 4),
                          Text(rating, style: const TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('₹$totalPrice', style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),
            
            // Ride Details Summary
            Row(
              children: [
                const Icon(Icons.location_on, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(child: Text('${request['pickup_location'] ?? ride['start_location']} → ${request['dropoff_location'] ?? ride['end_location']}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.event_seat, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Text('$seatsBooked Seat(s) requested', style: const TextStyle(fontSize: 13)),
              ],
            ),
            
            // Message from Passenger (Optional - if stored)
            if (request['message'] != null && request['message'].toString().isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.format_quote, size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(child: Text('"${request['message']}"', style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.black87, fontSize: 13))),
                  ],
                ),
              ),
            ],
            
            const SizedBox(height: 20),
            
            // Action Buttons
            if (isAccepted)
              ElevatedButton.icon(
                onPressed: () => _openChat(request),
                icon: const Icon(Icons.chat, color: Colors.white),
                label: const Text('Chat', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00C6D2),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  minimumSize: const Size(double.infinity, 48), // Full width
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: isDeclined ? null : () => _handleAction(bookingId, false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        disabledForegroundColor: Colors.grey,
                        side: BorderSide(color: isDeclined ? Colors.grey : Colors.red),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(isDeclined ? 'Declined' : 'Decline'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: isDeclined ? null : () => _handleAction(bookingId, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDeclined ? Colors.grey : const Color(0xFF00C6D2),
                        disabledBackgroundColor: Colors.grey.shade300,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Approve', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
