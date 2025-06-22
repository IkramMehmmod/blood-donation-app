import 'package:flutter/material.dart';
import '../../utils/responsive_utils.dart';

class BottomNavigation extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const BottomNavigation({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: ResponsiveUtils.getResponsiveSpacing(context, 10.0),
            offset:
                Offset(0, -ResponsiveUtils.getResponsiveSpacing(context, 5.0)),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: onTap,
        type: BottomNavigationBarType.fixed,
        backgroundColor: Theme.of(context).colorScheme.surface,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Colors.grey,
        selectedLabelStyle: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: ResponsiveUtils.getResponsiveFontSize(context, 12.0),
        ),
        unselectedLabelStyle: TextStyle(
          fontWeight: FontWeight.normal,
          fontSize: ResponsiveUtils.getResponsiveFontSize(context, 12.0),
        ),
        elevation: 0,
        items: [
          BottomNavigationBarItem(
            icon: Icon(
              Icons.home_outlined,
              size: ResponsiveUtils.getResponsiveIconSize(context, 24.0),
            ),
            activeIcon: Icon(
              Icons.home,
              size: ResponsiveUtils.getResponsiveIconSize(context, 24.0),
            ),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(
              Icons.bloodtype_outlined,
              size: ResponsiveUtils.getResponsiveIconSize(context, 24.0),
            ),
            activeIcon: Icon(
              Icons.bloodtype,
              size: ResponsiveUtils.getResponsiveIconSize(context, 24.0),
            ),
            label: 'Doners',
          ),
          BottomNavigationBarItem(
            icon: Icon(
              Icons.volunteer_activism_outlined,
              size: ResponsiveUtils.getResponsiveIconSize(context, 24.0),
            ),
            activeIcon: Icon(
              Icons.volunteer_activism,
              size: ResponsiveUtils.getResponsiveIconSize(context, 24.0),
            ),
            label: 'Requests',
          ),
          BottomNavigationBarItem(
            icon: Icon(
              Icons.person_outline,
              size: ResponsiveUtils.getResponsiveIconSize(context, 24.0),
            ),
            activeIcon: Icon(
              Icons.person,
              size: ResponsiveUtils.getResponsiveIconSize(context, 24.0),
            ),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
