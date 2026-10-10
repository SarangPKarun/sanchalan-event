import 'package:flutter/material.dart';

/// The organizer app frame: the current tab's content above a bottom
/// navigation bar. Independent of the router, so it works with
/// `StatefulShellRoute` (the router passes the index and `goBranch`).
class OrganizerShell extends StatelessWidget {
  const OrganizerShell({
    super.key,
    required this.body,
    required this.currentIndex,
    required this.onSelect,
  });

  final Widget body;
  final int currentIndex;
  final ValueChanged<int> onSelect;

  static const destinations = [
    (Icons.home_outlined, Icons.home, 'Home'),
    (Icons.event_outlined, Icons.event, 'Events'),
    (Icons.storefront_outlined, Icons.storefront, 'Vendors'),
    (Icons.person_outline, Icons.person, 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: onSelect,
        destinations: [
          for (final (icon, selectedIcon, label) in destinations)
            NavigationDestination(icon: Icon(icon), selectedIcon: Icon(selectedIcon), label: label),
        ],
      ),
    );
  }
}
