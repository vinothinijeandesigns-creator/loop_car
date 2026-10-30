import 'package:flutter/material.dart';
import 'package:loop_car/Features/Settings/settings_page.dart';
import 'package:loop_car/screens/chat_list_screen.dart';
import 'package:loop_car/screens/search_ride_screen.dart';
import 'package:loop_car/Ride_History/ride_history.dart';
import 'pickup_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  final List<Widget> _pages = [
    const SearchRidePage(),
    const PickupScreen(),
    const RideHistoryPage(), 
    ChatListScreen(),
    const ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(child: _pages[_currentIndex]),

      // 🔵 Bottom Navigation Bar (Top Curved Only)
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xFF00C6D2),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(28),
              topRight: Radius.circular(28),
            ),
          ),
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) => setState(() => _currentIndex = index),

            type: BottomNavigationBarType.fixed,
            elevation: 0,
            backgroundColor: Colors.transparent,

            selectedItemColor: Colors.white,
            unselectedItemColor: Colors.white70,

            selectedLabelStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            unselectedLabelStyle: const TextStyle(fontSize: 11),

            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.search),
                label: 'Search',
              ),
              BottomNavigationBarItem(icon: Icon(Icons.add), label: 'Post'),
              BottomNavigationBarItem(
                icon: Icon(Icons.directions_car),
                label: 'Ride History',
              ),
              BottomNavigationBarItem(icon: Icon(Icons.mail), label: 'Chat'),
              BottomNavigationBarItem(
                icon: Icon(Icons.person),
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
