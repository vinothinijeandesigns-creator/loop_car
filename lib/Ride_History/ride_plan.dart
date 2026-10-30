import 'package:flutter/material.dart';
import 'ride_details.dart';
import 'edit_post.dart';

class RidePlanPage extends StatelessWidget {
  const RidePlanPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(color: Colors.black),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          "Ride, Laugh, Repeat, For Less!",
          style: TextStyle(
            color: Color(0xFF00C6D2),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Ride Plan",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF00C6D2),
                ),
              ),

              const SizedBox(height: 30),

              ListTile(
                leading: const Icon(
                  Icons.verified_user,
                  color: Color(0xFF00C6D2),
                ),
                title: const Text("Verify your Govt. ID"),
                subtitle: const Text(
                  "It's quick to do and inspires trust in your fellow travellers.",
                ),
              ),

              ListTile(
                leading: const Icon(Icons.camera_alt, color: Color(0xFF00C6D2)),
                title: const Text("Add your profile picture"),
                subtitle: const Text(
                  "Passengers like to see who they're travelling with.",
                ),
              ),

              const SizedBox(height: 20),

              const Text(
                "Tue, 31 March",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 20),

              ListTile(
                leading: const Icon(Icons.location_on),
                title: const Text("Chennai"),
                subtitle: const Text("KFC"),
              ),

              ListTile(
                leading: const Icon(Icons.location_on),
                title: const Text("Chengalpattu"),
                subtitle: const Text("Chengalpattu Junction"),
              ),

              ListTile(
                leading: const Icon(Icons.flag),
                title: const Text("Puducherry"),
              ),

              const Divider(),

              const Text("No passengers for this ride"),

              const SizedBox(height: 20),

              ListTile(
                title: const Text("See your post online"),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () {
                  final mockRide = {
                    'departure_datetime': DateTime.now().toIso8601String(),
                    'start_location': 'Chennai',
                    'end_location': 'Chengalpattu',
                    'price_per_seat': 150.0,
                    'available_seats': 3,
                  };
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => RideDetailsPage(ride: mockRide)),
                  );
                },
              ),

              ListTile(
                title: const Text("Edit your post"),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () async {
                  final mockRide = {
                    'departure_datetime': DateTime.now().toIso8601String(),
                    'start_location': 'Chennai',
                    'end_location': 'Chengalpattu',
                    'price_per_seat': 150.0,
                    'available_seats': 3,
                  };
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => EditPostPage(rideData: mockRide)),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
