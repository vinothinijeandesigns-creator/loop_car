import 'package:flutter/material.dart';
import 'post_ride_data.dart';
import '../services/ride_service.dart';
import '../services/pricing_service.dart';
import '../Ride_History/ride_history.dart';
class SeatsPriceScreen extends StatefulWidget {
  final PostRideData data;
  const SeatsPriceScreen({super.key, required this.data});

  @override
  State<SeatsPriceScreen> createState() => _SeatsPriceScreenState();
}

class _SeatsPriceScreenState extends State<SeatsPriceScreen> {
  int seats = 1;
  late int price;
  late int recommendedPrice;
  late int minPrice;
  late int maxPrice;

  @override
  void initState() {
    super.initState();
    _initPricing();
  }

  void _initPricing() {
    final pricing = PricingService.calculateDefaultPrice(
      distanceKm: widget.data.distance > 0 ? widget.data.distance : 1.0,
      availableSeats: seats,
    );
    recommendedPrice = (pricing['recommendedPrice'] as double).round();
    minPrice = (pricing['minPrice'] as double).round();
    maxPrice = (pricing['maxPrice'] as double).round();
    price = recommendedPrice;
    widget.data.pricePerSeat = price.toDouble();
  }

  void _updatePricing() {
    final pricing = PricingService.calculateDefaultPrice(
      distanceKm: widget.data.distance > 0 ? widget.data.distance : 1.0,
      availableSeats: seats,
    );
    recommendedPrice = (pricing['recommendedPrice'] as double).round();
    minPrice = (pricing['minPrice'] as double).round();
    maxPrice = (pricing['maxPrice'] as double).round();
    
    // Adjust price if it's out of bounds
    if (price < minPrice) price = minPrice;
    if (price > maxPrice) price = maxPrice;
    widget.data.pricePerSeat = price.toDouble();
  }

  void addSeat() => setState(() {
    seats++;
    widget.data.seats = seats;
    _updatePricing();
  });
  void removeSeat() {
    if (seats > 1) {
      // Minimum 1 seat
      setState(() {
        seats--;
        widget.data.seats = seats;
        _updatePricing();
      });
    }
  }

  void addPrice() => setState(() {
    if (price + 10 <= maxPrice) {
      price += 10;
      widget.data.pricePerSeat = price.toDouble();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum price reached. Drivers cannot make a profit.'), duration: Duration(seconds: 2)),
      );
    }
  });
  void removePrice() {
    if (price - 10 >= minPrice) {
      setState(() {
        price -= 10;
        widget.data.pricePerSeat = price.toDouble();
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Minimum allowed price reached.'), duration: Duration(seconds: 2)),
      );
    }
  }

  bool _isPosting = false;

  Future<void> _postRide() async {
    if (widget.data.selectedDate == null || widget.data.selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Missing date or time information')),
      );
      return;
    }

    setState(() => _isPosting = true);

    try {
      final DateTime date = widget.data.selectedDate!;
      final TimeOfDay time = widget.data.selectedTime!;
      final departureDateTime = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );

      final rideService = RideService();
      await rideService.createRide(
        startLocation: widget.data.pickupAddress,
        startLat: widget.data.pickup?.latitude ?? 0.0,
        startLng: widget.data.pickup?.longitude ?? 0.0,
        endLocation: widget.data.destinationAddress,
        endLat: widget.data.destination?.latitude ?? 0.0,
        endLng: widget.data.destination?.longitude ?? 0.0,
        departureDateTime: departureDateTime,
        availableSeats: seats,
        pricePerSeat: price.toDouble(),
        distance: widget.data.distance,
        stopovers:
            widget.data.selectedStopovers.map((s) {
              return {
                'location_name': s.name,
                'lat': s.location.latitude,
                'lng': s.location.longitude,
              };
            }).toList(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ride posted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        // Navigate to Ride History
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const RideHistoryPage()),
          (route) => route.isFirst,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isPosting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F1EF),

      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              /// top bar
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Expanded(
                      child: Text(
                        "Ride, Laugh, Repeat, For Less!",
                        style: TextStyle(fontSize: 13, color: Colors.black54),
                      ),
                    ),
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Colors.orange,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              ),

              /// title
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "So how many LoopCar\npassengers can you take?",
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                ),
              ),

              const SizedBox(height: 30),

              /// seat selector
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _circleBtn(Icons.remove, removeSeat),
                  const SizedBox(width: 30),
                  Text(
                    seats.toString(),
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal,
                    ),
                  ),
                  const SizedBox(width: 30),
                  _circleBtn(Icons.add, addSeat),
                ],
              ),

              const SizedBox(height: 30),

              /// price card
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "Set your price per seat",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _circleBtn(Icons.remove, removePrice),
                        const SizedBox(width: 30),
                        Text(
                          "₹$price",
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.teal,
                          ),
                        ),
                        const SizedBox(width: 30),
                        _circleBtn(Icons.add, addPrice),
                      ],
                    ),

                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.teal.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          Text(
                            "Recommended price: ₹$recommendedPrice\nPerfect price for this ${widget.data.distance.toStringAsFixed(1)} km ride!",
                            style: const TextStyle(fontSize: 12),
                          ),
                          const Divider(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                "Total Potential Earnings:",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                "₹${price * seats}",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: Colors.teal,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              /// passenger options
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Passenger options",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
              ),

              const SizedBox(height: 10),

              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  "Flexible about where and when to meet?\nNot taking the motorway?\nKeep passengers in the loop.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black54),
                ),
              ),

              const SizedBox(height: 30),

              /// post ride button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _isPosting ? null : _postRide,
                    child:
                        _isPosting
                            ? const CircularProgressIndicator(
                              color: Colors.white,
                            )
                            : const Text(
                              "Post Ride",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                  ),
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _circleBtn(IconData icon, VoidCallback onTap) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.teal, width: 2),
      ),
      child: IconButton(icon: Icon(icon, color: Colors.teal), onPressed: onTap),
    );
  }
}
