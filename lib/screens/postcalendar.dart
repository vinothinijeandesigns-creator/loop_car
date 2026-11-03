import 'package:flutter/material.dart';
import 'post_ride_data.dart';
import 'posttime.dart';

class SelectDateScreen extends StatefulWidget {
  final PostRideData data;
  const SelectDateScreen({super.key, required this.data});

  @override
  State<SelectDateScreen> createState() => _SelectDateScreenState();
}

class _SelectDateScreenState extends State<SelectDateScreen> {
  DateTime today = DateTime.now();
  DateTime? selectedDate;

  @override
  void initState() {
    super.initState();
    selectedDate = widget.data.selectedDate ?? DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    DateTime nextMonth = DateTime(today.year, today.month + 1, 1);

    return Scaffold(
      backgroundColor: const Color(0xFFF3F1EF),
      body: SafeArea(
        child: Column(
          children: [
            // top bar
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
                ],
              ),
            ),

            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "When are you going?",
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                ),
              ),
            ),

            const SizedBox(height: 20),

            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        _buildMonth(today.year, today.month),
                        const SizedBox(height: 20),
                        _buildMonth(nextMonth.year, nextMonth.month),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),

      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF80E8F0),
        onPressed: () {
          if (selectedDate == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Please select a date')),
            );
            return;
          }
          widget.data.selectedDate = selectedDate;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SelectTimeScreen(data: widget.data),
            ),
          );
        },
        child: const Icon(Icons.arrow_forward, color: Colors.white),
      ),
    );
  }

  Widget _buildMonth(int year, int month) {
    int totalDays = DateTime(year, month + 1, 0).day;

    String monthName = "${_monthNames[month - 1]} $year"; // e.g. Feb 2026

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          monthName,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),

        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: totalDays,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 10,
          ),
          itemBuilder: (context, index) {
            int day = index + 1;
            DateTime date = DateTime(year, month, day);

            bool isSelected =
                selectedDate != null &&
                selectedDate!.year == year &&
                selectedDate!.month == month &&
                selectedDate!.day == day;

            return GestureDetector(
              onTap: () {
                setState(() {
                  selectedDate = date;
                });
              },
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isSelected ? Colors.teal : Colors.transparent,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  "$day",
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.black54,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  final List<String> _monthNames = [
    "January",
    "February",
    "March",
    "April",
    "May",
    "June",
    "July",
    "August",
    "September",
    "October",
    "November",
    "December",
  ];
}
