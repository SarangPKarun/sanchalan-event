import 'package:flutter/material.dart';

/// Shown while the organizer or vendor account data loads (and while a session
/// is being restored).
class DataLoadingScreen extends StatelessWidget {
  const DataLoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
