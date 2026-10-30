import 'package:flutter/material.dart';
import '../services/ride_service.dart';

class CancelRidePage extends StatefulWidget {
  final String rideId;
  const CancelRidePage({super.key, required this.rideId});

  @override
  State<CancelRidePage> createState() => _CancelRidePageState();
}

class _CancelRidePageState extends State<CancelRidePage> {
  bool _isLoading = false;

  void _cancelRide() async {
    setState(() => _isLoading = true);
    try {
      try {
        await RideService().deleteRide(widget.rideId);
      } catch (e) {
        // Fallback to cancel if it can't be deleted (e.g., has bookings)
        await RideService().cancelRide(widget.rideId);
      }
      
      if (mounted) {
        Navigator.pop(context); // Close warning box/page
        Navigator.pop(context, true); // Go back to previous screen and indicate it was deleted
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Ride cancelled successfully")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to cancel ride: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff2f2f2),

      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// TOP BAR
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back,
                      color: Color(0xFF00C6D2),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                    },
                  ),

                  const Expanded(
                    child: Center(
                      child: Text(
                        "Ride, Laugh, Repeat, For Less!",
                        style: TextStyle(
                          color: Color(0xFF00C6D2),
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 40),
                ],
              ),
            ),

            const SizedBox(height: 10),

            /// TITLE
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                "Cancel Your Ride",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF00C6D2),
                ),
              ),
            ),

            const SizedBox(height: 20),

            /// WARNING BOX
            Center(
              child: Container(
                width: 300,
                height: 420,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(12),
                ),

                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.red,
                      size: 40,
                    ),

                    const SizedBox(height: 20),

                    const Text(
                      "You're about to cancel your ride. It will be deleted and passengers won't be able to travel with you.",
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),

                    const Spacer(),

                    /// BUTTONS
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        /// CLOSE BUTTON
                        Container(
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              Navigator.pop(context);
                            },
                          ),
                        ),

                        /// CANCEL RIDE BUTTON
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
                            ),
                          ),
                          onPressed: _isLoading ? null : _cancelRide,
                          child: _isLoading 
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Text("Cancel the ride"),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
