import 'package:flutter/material.dart';
import 'post_ride_data.dart';
import 'passengercost.dart';

class SelectTimeScreen extends StatefulWidget {
  final PostRideData data;
  const SelectTimeScreen({super.key, required this.data});

  @override
  State<SelectTimeScreen> createState() => _SelectTimeScreenState();
}

class _SelectTimeScreenState extends State<SelectTimeScreen> {
  TimeOfDay selectedTime = const TimeOfDay(hour: 8, minute: 0);

  Future<void> _pickTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: selectedTime,
    );

    if (picked != null) {
      setState(() => selectedTime = picked);
    }
  }

  String formatTime(TimeOfDay t) {
    final hour = t.hour.toString().padLeft(2, '0');
    final min = t.minute.toString().padLeft(2, '0');
    return "$hour:$min";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F1EF),

      body: SafeArea(
        child: Column(
          children: [
            /// top bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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

            const SizedBox(height: 20),

            /// title
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "What's your starting time?",
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                ),
              ),
            ),

            const SizedBox(height: 60),

            /// time card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: GestureDetector(
                onTap: _pickTime,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Center(
                          child: Text(
                            formatTime(selectedTime),
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF80E8F0),
                            ),
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.keyboard_arrow_down,
                        color: Color(0xFF80E8F0),
                        size: 30,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),

      /// forward arrow
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF80E8F0),
        onPressed: () {
          widget.data.selectedTime = selectedTime;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SeatsPriceScreen(data: widget.data),
            ),
          );
        },
        child: const Icon(Icons.arrow_forward, color: Colors.white),
      ),
    );
  }
}
