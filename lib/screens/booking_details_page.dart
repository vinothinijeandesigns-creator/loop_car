import 'package:flutter/material.dart';
import 'package:loop_car/services/booking_service.dart';
import 'package:loop_car/config/supabase_config.dart';
import 'package:url_launcher/url_launcher.dart';
import 'ride.dart';
import 'package:loop_car/services/chat_service.dart';
import 'package:loop_car/services/communication_service.dart';
import 'chat_room_screen.dart';

class BookingDetailsPage extends StatefulWidget {
  final Ride ride;

  const BookingDetailsPage({super.key, required this.ride});

  @override
  State<BookingDetailsPage> createState() => _BookingDetailsPageState();
}

class _BookingDetailsPageState extends State<BookingDetailsPage> {
  final BookingService _bookingService = BookingService();
  final TextEditingController _messageController = TextEditingController();
  
  bool _isLoading = true;
  bool _isActionLoading = false;
  
  String? _bookingId;
  String _status = 'not_requested'; // not_requested, pending, accepted, rejected, cancelled
  int _selectedSeats = 1;

  @override
  void initState() {
    super.initState();
    _checkExistingBooking();
  }
  
  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _checkExistingBooking() async {
    setState(() => _isLoading = true);
    try {
      final userId = SupabaseConfig.userId;
      if (userId == null) {
        setState(() => _isLoading = false);
        return;
      }
      
      final response = await SupabaseConfig.client
          .from('bookings')
          .select('id, status')
          .eq('ride_id', widget.ride.id)
          .eq('passenger_id', userId)
          .maybeSingle();
          
      if (response != null) {
        setState(() {
          _bookingId = response['id'].toString();
          _status = response['status'] as String;
        });
      }
    } catch (e) {
      debugPrint("Error checking booking: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _sendRequest() async {
    setState(() => _isActionLoading = true);
    try {
      final response = await _bookingService.bookRide(
        rideId: widget.ride.id,
        seatsBooked: _selectedSeats,
        totalPrice: widget.ride.price.toDouble() * _selectedSeats,
        pickupLocation: widget.ride.pickup,
        dropoffLocation: widget.ride.drop,
      );
      
      // We could also save the initial message to a chat or notes table here.
      
      if (mounted) {
        setState(() {
          _bookingId = response['id'].toString();
          _status = 'pending';
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
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  Future<void> _cancelRequest() async {
    if (_bookingId == null) return;
    setState(() => _isActionLoading = true);
    try {
      await _bookingService.cancelBooking(_bookingId!);
      if (mounted) {
        setState(() => _status = 'cancelled');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Request cancelled.')),
        );
      }
      
      try {
        final threadId = '${widget.ride.id}_${SupabaseConfig.userId}';
        final pickup = widget.ride.pickup;
        final dropoff = widget.ride.drop;
        
        await ChatService().sendSystemMessage(
          threadId, 
          'LoopCar: Passenger cancelled their request for the ride from $pickup to $dropoff.',
        );
        
        await CommunicationService.notifyUser(
          userId: widget.ride.driverId,
          title: 'Ride Request Cancelled',
          message: 'A passenger cancelled their request for $pickup to $dropoff.',
        );
      } catch (e) {
        debugPrint("Error sending cancel notification: $e");
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to cancel request: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  void _openChat() {
    final driverName = widget.ride.hostName;
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatRoomScreen(
          threadId: '${widget.ride.id}_${SupabaseConfig.userId}', 
          userName: driverName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.pop(context, _status);
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          leading: IconButton(
            icon: const BackButtonIcon(),
            color: Colors.black87,
            onPressed: () => Navigator.pop(context, _status),
          ),
          title: const Text('Ride Details', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(24),
                children: [
                _buildStatusHeader(),
                const SizedBox(height: 24),
                _TimelineSection(ride: widget.ride),
                const SizedBox(height: 24),
                _DriverProfileSection(ride: widget.ride),
                const SizedBox(height: 24),
                _RidePreferencesSection(ride: widget.ride),
                const SizedBox(height: 24),
                _PriceSummarySection(
                  ride: widget.ride,
                  selectedSeats: _selectedSeats,
                  onSeatsChanged: (int value) {
                    setState(() {
                      _selectedSeats = value;
                    });
                  },
                ),
                const SizedBox(height: 24),
                
                if (_status == 'not_requested' || _status == 'cancelled')
                  _buildMessageSection(),
                  
                const SizedBox(height: 40),
              ],
            ),
        bottomNavigationBar: _buildBottomBar(),
      ),
    );
  }

  Widget _buildStatusHeader() {
    IconData icon;
    Color color;
    String title;
    String subtitle;

    switch (_status) {
      case 'pending':
        icon = Icons.access_time_filled;
        color = Colors.orange;
        title = 'Waiting for approval';
        subtitle = 'The driver needs to approve your request.';
        break;
      case 'accepted':
        icon = Icons.check_circle;
        color = Colors.teal;
        title = 'Your ride is confirmed!';
        subtitle = 'You can now chat with the driver.';
        break;
      case 'rejected':
        icon = Icons.cancel;
        color = Colors.red;
        title = 'Request declined';
        subtitle = 'The driver has declined your request.';
        break;
      case 'cancelled':
        icon = Icons.info;
        color = Colors.grey;
        title = 'Request cancelled';
        subtitle = 'You cancelled this booking request.';
        break;
      case 'not_requested':
      default:
        icon = Icons.directions_car;
        color = const Color(0xFF00C6D2);
        title = 'Review your ride details';
        subtitle = 'Send a request to book your seat.';
        break;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 36),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color.withValues(alpha: 0.8))),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(fontSize: 13, color: Colors.black54)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Message ${widget.ride.hostName} (Optional)',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _messageController,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Hello! I’d like to book a seat for this trip...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            filled: true,
            fillColor: Colors.grey.shade100,
          ),
        ),
      ],
    );
  }

  Widget? _buildBottomBar() {
    if (_isLoading) return null;

    if (_status == 'not_requested' || _status == 'cancelled') {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -5))],
        ),
        child: ElevatedButton(
          onPressed: _isActionLoading ? null : _sendRequest,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00C6D2),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            minimumSize: const Size(double.infinity, 54),
          ),
          child: _isActionLoading
              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white))
              : const Text('Send Request', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
        ),
      );
    } else if (_status == 'pending') {
      return Container(
        padding: const EdgeInsets.all(24),
        child: OutlinedButton(
          onPressed: _isActionLoading ? null : _cancelRequest,
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.red,
            side: const BorderSide(color: Colors.red),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            minimumSize: const Size(double.infinity, 54),
          ),
          child: _isActionLoading
              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.red))
              : const Text('Cancel Request', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
      );
    } else if (_status == 'accepted') {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -5))],
        ),
        child: ElevatedButton.icon(
          onPressed: _openChat,
          icon: const Icon(Icons.chat, color: Colors.white),
          label: const Text('Chat with Driver', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF4A4EFE),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            minimumSize: const Size(double.infinity, 54),
          ),
        ),
      );
    }

    return null;
  }
}

// timeline section
class _TimelineSection extends StatelessWidget {
  final Ride ride;

  const _TimelineSection({required this.ride});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(ride.time, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF2C3E50))),
        const SizedBox(height: 20),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 24,
                child: Column(
                  children: [
                    Container(width: 14, height: 14, decoration: BoxDecoration(color: const Color(0xFF536DFE).withValues(alpha: 0.2), shape: BoxShape.circle), child: Center(child: Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFF536DFE), shape: BoxShape.circle)))),
                    Expanded(child: Container(width: 2, color: Colors.grey.shade300)),
                    Container(width: 14, height: 14, decoration: BoxDecoration(color: const Color(0xFF00E676).withValues(alpha: 0.2), shape: BoxShape.circle), child: Center(child: Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFF00E676), shape: BoxShape.circle)))),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Pickup\n${ride.pickup}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 24),
                    Text('Drop-off\n${ride.drop}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Divider(height: 1),
      ],
    );
  }
}

//price summary section
class _PriceSummarySection extends StatelessWidget {
  final Ride ride;
  final int selectedSeats;
  final ValueChanged<int> onSeatsChanged;

  const _PriceSummarySection({
    required this.ride,
    required this.selectedSeats,
    required this.onSeatsChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Price summary', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Available seats: ${ride.seats}', style: const TextStyle(fontSize: 14, color: Colors.black54)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: selectedSeats > 1 ? () => onSeatsChanged(selectedSeats - 1) : null,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 8),
                    Text('$selectedSeats', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: selectedSeats < ride.seats ? () => onSeatsChanged(selectedSeats + 1) : null,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 8),
                    const Text('seat(s) booking', style: TextStyle(fontSize: 15)),
                  ],
                ),
              ],
            ),
            Text('₹${ride.price * selectedSeats}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Payment Method', style: TextStyle(fontSize: 15)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.green.shade200)),
              child: const Text('Cash in Car', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
            )
          ],
        ),
        const SizedBox(height: 24),
        const Divider(height: 1),
      ],
    );
  }
}

// driver profile section
class _DriverProfileSection extends StatelessWidget {
  final Ride ride;

  const _DriverProfileSection({required this.ride});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Driver Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 16),
        Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: Colors.grey.shade200,
              backgroundImage: ride.hostImage.isNotEmpty ? NetworkImage(ride.hostImage) : null,
              child: ride.hostImage.isEmpty ? const Icon(Icons.person, color: Colors.grey) : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(ride.hostName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 16),
                      const SizedBox(width: 4),
                      Text('${ride.rating}', style: const TextStyle(fontSize: 14, color: Colors.black54)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        InkWell(
          onTap: () async {
            final Uri launchUri = Uri(
              scheme: 'tel',
              path: ride.hostPhone,
            );
            if (await canLaunchUrl(launchUri)) {
              await launchUrl(launchUri);
            } else {
              debugPrint('Could not launch $launchUri');
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Row(
              children: [
                const Icon(Icons.phone, color: Colors.blue, size: 20),
                const SizedBox(width: 12),
                Text(ride.hostPhone, style: const TextStyle(fontSize: 15, color: Colors.blue, decoration: TextDecoration.underline)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        const Divider(height: 1),
      ],
    );
  }
}

// ride preferences section
class _RidePreferencesSection extends StatelessWidget {
  final Ride ride;

  const _RidePreferencesSection({required this.ride});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Ride Preferences', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 16),
        
        _buildPreferenceItem(Icons.flash_on, 'Instant Booking', ride.instantBooking ? 'Requests approved automatically' : 'Requests require approval', ride.instantBooking),
        _buildPreferenceItem(Icons.group, 'Max 2 in the back', ride.maxTwoInBack ? 'More comfort in the back' : 'Up to 3 in the back', ride.maxTwoInBack),
        _buildPreferenceItem(Icons.shopping_bag, 'Luggage', ride.luggageAllowed ? 'Medium to large bags allowed' : 'No luggage allowed', ride.luggageAllowed),
        _buildPreferenceItem(Icons.pets, 'Pets', ride.petsAllowed ? 'Small pets in carriers allowed' : 'No pets allowed', ride.petsAllowed),
        _buildPreferenceItem(Icons.smoking_rooms, 'Smoking', ride.smokingAllowed ? 'Smoking allowed during ride' : 'No smoking allowed', ride.smokingAllowed),
        
        const SizedBox(height: 24),
        const Divider(height: 1),
      ],
    );
  }

  Widget _buildPreferenceItem(IconData icon, String title, String subtitle, bool isAllowed) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Icon(icon, color: isAllowed ? const Color(0xFF00C6D2) : Colors.grey, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: isAllowed ? Colors.black87 : Colors.black54, decoration: isAllowed ? null : TextDecoration.lineThrough)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(fontSize: 13, color: Colors.black54)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
