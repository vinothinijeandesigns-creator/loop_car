import 'package:flutter/material.dart';
import '../../../config/supabase_config.dart';

class RatingsSection extends StatefulWidget {
  final List<dynamic>? receivedRatings;
  final List<dynamic>? givenRatings;
  final List<dynamic>? rateableBookings;
  final VoidCallback? onRefresh;

  const RatingsSection({
    super.key,
    this.receivedRatings,
    this.givenRatings,
    this.rateableBookings,
    this.onRefresh,
  });

  @override
  State<RatingsSection> createState() => _RatingsSectionState();
}

class _RatingsSectionState extends State<RatingsSection> {
  int selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final ratingsToShow =
        selectedIndex == 0 ? widget.receivedRatings : widget.givenRatings;

    return Column(
      children: [
        /// BLUE BOX TOGGLE
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFE6FAFC), // light blue background
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF00C6D2)),
          ),
          child: ToggleButtons(
            borderRadius: BorderRadius.circular(10),
            borderColor: Colors.transparent,
            selectedBorderColor: Colors.transparent,
            fillColor: const Color(0xFF00C6D2),
            selectedColor: Colors.white,
            color: Colors.black87,
            isSelected: [selectedIndex == 0, selectedIndex == 1],
            onPressed: (index) {
              setState(() {
                selectedIndex = index;
              });
            },
            children: const [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Text("Received"),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Text("Given"),
              ),
            ],
          ),
        ),

        const SizedBox(height: 25),

        if (selectedIndex == 1 &&
            widget.rateableBookings != null &&
            widget.rateableBookings!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: ElevatedButton.icon(
              onPressed: () => _showRatingDialog(context),
              icon: const Icon(Icons.rate_review),
              label: const Text("Rate a recent trip"),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00C6D2),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),

        if (ratingsToShow == null || ratingsToShow.isEmpty) ...[
          const Icon(Icons.thumb_up_alt_outlined, size: 60),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFF00C6D2)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              selectedIndex == 0
                  ? "You haven't received any ratings yet."
                  : "You haven't given any ratings yet.",
              textAlign: TextAlign.center,
            ),
          ),
        ] else
          ...ratingsToShow.map((rating) => _buildRatingItem(rating)),
      ],
    );
  }

  void _showRatingDialog(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (ctx) => _GiveRatingDialog(
            bookings: widget.rateableBookings!,
            onSubmitted: () {
              if (widget.onRefresh != null) widget.onRefresh!();
            },
          ),
    );
  }

  Widget _buildRatingItem(Map<String, dynamic> rating) {
    // ... rest of the method as before
    final raterOrRatee = selectedIndex == 0 ? rating['rater'] : rating['ratee'];
    final name =
        raterOrRatee != null
            ? "${raterOrRatee['first_name']} ${raterOrRatee['last_name']}"
            : "Unknown User";
    final starCount = (rating['rating'] as num?)?.toInt() ?? 0;
    final review = rating['review']?.toString() ?? "";

    return Container(
      margin: const EdgeInsets.only(bottom: 12, left: 20, right: 20),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
              Row(
                children: List.generate(
                  5,
                  (index) => Icon(
                    index < starCount ? Icons.star : Icons.star_border,
                    size: 16,
                    color: Colors.amber,
                  ),
                ),
              ),
            ],
          ),
          if (review.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              review,
              style: const TextStyle(fontSize: 13, color: Colors.black87),
            ),
          ],
        ],
      ),
    );
  }
}

class _GiveRatingDialog extends StatefulWidget {
  final List<dynamic> bookings;
  final VoidCallback onSubmitted;

  const _GiveRatingDialog({required this.bookings, required this.onSubmitted});

  @override
  State<_GiveRatingDialog> createState() => _GiveRatingDialogState();
}

class _GiveRatingDialogState extends State<_GiveRatingDialog> {
  int rating = 5;
  final TextEditingController reviewController = TextEditingController();
  dynamic selectedBooking;
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    selectedBooking = widget.bookings.first;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Rate Your Trip"),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Select trip to rate:"),
            DropdownButton<dynamic>(
              isExpanded: true,
              value: selectedBooking,
              items:
                  widget.bookings.map((b) {
                    final userId = SupabaseConfig.userId;
                    final isDriver = b['ride']['driver_id'] == userId;
                    
                    // If user is driver, they are rating the passenger
                    // If user is passenger, they are rating the driver
                    final targetUser = isDriver ? b['passenger'] : b['ride']['driver'];
                    final roleText = isDriver ? "Passenger" : "Driver";
                    
                    final date = DateTime.parse(
                      b['ride']['departure_datetime'],
                    );
                    
                    return DropdownMenuItem(
                      value: b,
                      child: Text(
                        "$roleText: ${targetUser['first_name']} - ${date.day}/${date.month}/${date.year}",
                      ),
                    );
                  }).toList(),
              onChanged: (val) => setState(() => selectedBooking = val),
            ),
            const SizedBox(height: 16),
            const Text("How was your experience?"),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  return IconButton(
                    onPressed: () => setState(() => rating = index + 1),
                    icon: Icon(
                      index < rating ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                    ),
                  );
                }),
              ),
            ),
            TextField(
              controller: reviewController,
              decoration: const InputDecoration(
                hintText: "Write a short review (optional)",
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
        ElevatedButton(
          onPressed: isSaving ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00C6D2),
          ),
          child:
              isSaving
                  ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                  : const Text("Submit", style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    setState(() => isSaving = true);
    try {
      final userId = SupabaseConfig.userId;
      if (userId == null) return;

      final booking = selectedBooking as Map<String, dynamic>;
      final ride = booking['ride'] as Map<String, dynamic>;
      
      final isDriver = ride['driver_id'] == userId;
      final rateeId = isDriver ? booking['passenger_id'] : ride['driver_id'];
      final ratingType = isDriver ? 'driver_to_passenger' : 'passenger_to_driver';

      await SupabaseConfig.client.from('ratings').insert({
        'booking_id': booking['id'],
        'ride_id': ride['id'],
        'rater_id': userId,
        'ratee_id': rateeId,
        'rating': rating,
        'review': reviewController.text,
        'rating_type': ratingType,
      });

      if (mounted) {
        widget.onSubmitted();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Rating submitted successfully!"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error submitting rating: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }
}
