import 'package:flutter/material.dart';

class EditPricePage extends StatefulWidget {
  final Map<String, dynamic> rideData;
  const EditPricePage({super.key, required this.rideData});

  @override
  State<EditPricePage> createState() => _EditPricePageState();
}

class _EditPricePageState extends State<EditPricePage> {
  late int _price;
  final int _minPrice = 50;
  final int _maxPrice = 5000;

  @override
  void initState() {
    super.initState();
    _price = (widget.rideData['price_per_seat'] as num?)?.toInt() ?? 150;
  }

  void _incrementPrice() {
    if (_price < _maxPrice) {
      setState(() {
        _price += 10;
      });
    }
  }

  void _decrementPrice() {
    if (_price > _minPrice) {
      setState(() {
        _price -= 10;
      });
    }
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
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Edit Price",
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xFF00C6D2),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              "Set a fair price per seat to attract more passengers.",
              style: TextStyle(color: Colors.black54, fontSize: 16),
            ),
            const Spacer(),
            
            // Price Editor
            Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildRoundButton(Icons.remove, _decrementPrice, _price > _minPrice),
                  const SizedBox(width: 40),
                  Text(
                    "₹$_price",
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(width: 40),
                  _buildRoundButton(Icons.add, _incrementPrice, _price < _maxPrice),
                ],
              ),
            ),
            
            const SizedBox(height: 30),
            const Center(
              child: Text(
                "Recommended price: ₹120 - ₹200",
                style: TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            
            const Spacer(),
            
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
                  widget.rideData['price_per_seat'] = _price.toDouble();
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Price updated successfully!")),
                  );
                },
                child: const Text(
                  "Save Price",
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

  Widget _buildRoundButton(IconData icon, VoidCallback onPressed, bool isEnabled) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isEnabled ? Colors.white : Colors.grey.shade300,
        boxShadow: isEnabled
            ? [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)]
            : [],
      ),
      child: IconButton(
        icon: Icon(icon, color: isEnabled ? const Color(0xFF00C6D2) : Colors.grey),
        onPressed: isEnabled ? onPressed : null,
        iconSize: 32,
      ),
    );
  }
}
