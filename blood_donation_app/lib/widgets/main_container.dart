// main_container.dart
import 'package:blood_donation_app/screens/bootomNavigation/bottom_navigation.dart';
import 'package:blood_donation_app/screens/donation/doners_screens.dart';
import 'package:blood_donation_app/screens/home_screen.dart';
import 'package:blood_donation_app/screens/profile/profile_screen.dart';
import 'package:blood_donation_app/screens/requests/requests_screen.dart';
import 'package:flutter/material.dart';

class MainContainer extends StatefulWidget {
  const MainContainer({super.key});

  @override
  State<MainContainer> createState() => _MainContainerState();
}

class _MainContainerState extends State<MainContainer> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    const DonersScreen(),
    const RequestsScreen(),
    const ProfileScreen(),
  ];

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigation(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
      ),
    );
  }
}
