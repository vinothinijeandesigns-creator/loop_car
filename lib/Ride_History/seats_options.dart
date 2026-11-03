import 'package:flutter/material.dart';

class SeatsOptionsPage extends StatefulWidget {
  final Map<String, dynamic> rideData;
  const SeatsOptionsPage({super.key, required this.rideData});

  @override
  State<SeatsOptionsPage> createState() => _SeatsOptionsPageState();
}

class _SeatsOptionsPageState extends State<SeatsOptionsPage> {
  late int _seats;
  late int _maxSeats;
  bool _instantBooking = true;
  bool _luggageAllowed = true;
  bool _petsAllowed = false;
  bool _smokingAllowed = false;
  bool _maxTwoInBack = true;

  @override
  void initState() {
    super.initState();
    _maxSeats = (widget.rideData['available_seats'] as num?)?.toInt() ?? 
                (widget.rideData['seats_available'] as num?)?.toInt() ?? 
                (widget.rideData['seats'] as num?)?.toInt() ?? 4;
    
    _seats = (widget.rideData['seats_available'] as num?)?.toInt() ?? _maxSeats;
    if (_seats > _maxSeats) _seats = _maxSeats;

    _instantBooking = widget.rideData['instant_booking'] ?? true;
    _maxTwoInBack = widget.rideData['max_two_in_back'] ?? true;
    _luggageAllowed = widget.rideData['luggage_allowed'] ?? true;
    _petsAllowed = widget.rideData['pets_allowed'] ?? false;
    _smokingAllowed = widget.rideData['smoking_allowed'] ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff2f2f2),
      appBar: AppBar(
        leading: const BackButton(color: Color(0xFF00C6D2)),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Seats & Options",
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xFF00C6D2),
              ),
            ),
            const SizedBox(height: 30),
            
            // Seats Selection
            const Text(
              "Available Seats",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 15),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(_maxSeats, (index) {
                int seatNumber = index + 1;
                bool isSelected = _seats == seatNumber;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _seats = seatNumber;
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF00C6D2) : Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 5,
                        )
                      ]
                    ),
                    child: Center(
                      child: Text(
                        "$seatNumber",
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
            
            const SizedBox(height: 40),
            
            // Options
            const Text(
              "Ride Preferences",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 15),
            
            _buildOptionSwitch("Instant Booking", "Approve requests automatically", _instantBooking, (val) => setState(() => _instantBooking = val)),
            _buildOptionSwitch("Max 2 in the back", "More comfort for passengers", _maxTwoInBack, (val) => setState(() => _maxTwoInBack = val)),
            _buildOptionSwitch("Luggage Allowed", "Medium to large bags", _luggageAllowed, (val) => setState(() => _luggageAllowed = val)),
            _buildOptionSwitch("Pets Allowed", "Small pets in carriers", _petsAllowed, (val) => setState(() => _petsAllowed = val)),
            _buildOptionSwitch("Smoking Allowed", "During the ride", _smokingAllowed, (val) => setState(() => _smokingAllowed = val)),
            
            const SizedBox(height: 40),
            
            // Save Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00C6D2),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
                onPressed: () {
                  widget.rideData['seats_available'] = _seats;
                  widget.rideData['instant_booking'] = _instantBooking;
                  widget.rideData['max_two_in_back'] = _maxTwoInBack;
                  widget.rideData['luggage_allowed'] = _luggageAllowed;
                  widget.rideData['pets_allowed'] = _petsAllowed;
                  widget.rideData['smoking_allowed'] = _smokingAllowed;
                  
                  // Update available_seats if necessary for other parts of the app
                  widget.rideData['available_seats'] = _seats;
                  
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Preferences updated!")),
                  );
                },
                child: const Text(
                  "Save Preferences",
                  style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionSwitch(String title, String subtitle, bool value, Function(bool) onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 5,
            offset: const Offset(0, 2),
          )
        ]
      ),
      child: SwitchListTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        value: value,
        activeColor: const Color(0xFF00C6D2),
        onChanged: onChanged,
      ),
    );
  }
}
