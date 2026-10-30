import 'package:flutter/material.dart';
import 'cancel_ride.dart';
import 'itinerary_details.dart';
import 'route_map_screen.dart';
import 'edit_price.dart';
import 'seats_options.dart';

class EditPostPage extends StatelessWidget {
  final Map<String, dynamic> rideData;
  const EditPostPage({super.key, required this.rideData});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(color: Colors.black),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),

      body: Padding(
        padding: const EdgeInsets.all(20),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Edit your Post",
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xFF00C6D2),
              ),
            ),

            const SizedBox(height: 30),

            buildItem(context, "Itinerary details", destination: ItineraryDetailsPage(rideData: rideData)),
            buildItem(context, "Route Map", destination: RouteMapScreen(rideData: rideData)),
            buildItem(context, "Price", subtitle: "Passengers will pay in cash.", destination: EditPricePage(rideData: rideData)),
            buildItem(context, "Seats and options", destination: SeatsOptionsPage(rideData: rideData)),
            buildItem(context, "Boost booking requests"),

            const SizedBox(height: 30),

            const Text(
              "Duplicate your post",
              style: TextStyle(color: Colors.blue),
            ),

            const SizedBox(height: 10),

            const Text(
              "Post your return ride",
              style: TextStyle(color: Colors.blue),
            ),

            const SizedBox(height: 10),

            InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CancelRidePage(rideId: rideData['id'].toString()),
                  ),
                );
              },
              child: const Text(
                "Cancel your ride",
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  //decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildItem(BuildContext context, String title, {String? subtitle, Widget? destination}) {
    return ListTile(
      onTap: destination != null
          ? () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => destination),
              );
            }
          : null,
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle) : null,
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
    );
  }
}
