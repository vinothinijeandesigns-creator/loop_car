import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/ride_service.dart';

class ItineraryDetailsPage extends StatefulWidget {
  final Map<String, dynamic> rideData;
  const ItineraryDetailsPage({super.key, required this.rideData});

  @override
  State<ItineraryDetailsPage> createState() => _ItineraryDetailsPageState();
}

class _ItineraryDetailsPageState extends State<ItineraryDetailsPage> {
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.parse(widget.rideData['departure_datetime']).toLocal();
  }

  Future<void> _pickDateTime() async {
    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) {
      final TimeOfDay? time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_selectedDate),
      );
      if (time != null) {
        setState(() {
          _selectedDate = DateTime(
            date.year, date.month, date.day, time.hour, time.minute,
          );
          widget.rideData['departure_datetime'] = _selectedDate.toUtc().toIso8601String();
        });
        
        try {
          await RideService().updateRide(
            widget.rideData['id'].toString(), 
            {'departure_datetime': widget.rideData['departure_datetime']}
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Date and time updated successfully!")),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Failed to update date: $e")),
            );
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormatted = DateFormat('E, d MMM').format(_selectedDate);
    final timeFormatted = DateFormat('hh:mm a').format(_selectedDate);
    final endTimeFormatted = DateFormat('hh:mm a').format(_selectedDate.add(const Duration(hours: 2, minutes: 10)));
    
    String startLoc = widget.rideData['start_location'] ?? 'Unknown';
    String endLoc = widget.rideData['end_location'] ?? 'Unknown';

    return Scaffold(
      backgroundColor: const Color(0xfff2f2f2),
      appBar: AppBar(
        leading: const BackButton(color: Color(0xFF00C6D2)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: const Text(
          "Itinerary Details",
          style: TextStyle(
            color: Color(0xFF00C6D2),
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Your Journey",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 30),
            
            // Timeline View
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    const Icon(Icons.circle_outlined, color: Color(0xFF00C6D2), size: 20),
                    Container(
                      width: 2,
                      height: 50,
                      color: const Color(0xFF00C6D2).withOpacity(0.5),
                    ),
                    const Icon(Icons.location_on, color: Color(0xFF00C6D2), size: 20),
                  ],
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLocationInfo("Pickup", startLoc, timeFormatted),
                      const SizedBox(height: 30),
                      _buildLocationInfo("Drop-off", endLoc, endTimeFormatted),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 40),
            
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  )
                ]
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_month, color: Colors.grey),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Date", style: TextStyle(color: Colors.grey, fontSize: 12)),
                        Text(dateFormatted, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: _pickDateTime,
                    child: const Text("Edit", style: TextStyle(color: Color(0xFF00C6D2))),
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationInfo(String label, String address, String time) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.grey, fontSize: 12),
        ),
        const SizedBox(height: 4),
        Text(
          address,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 4),
        Text(
          time,
          style: const TextStyle(color: Colors.black54, fontSize: 14),
        ),
      ],
    );
  }
}
