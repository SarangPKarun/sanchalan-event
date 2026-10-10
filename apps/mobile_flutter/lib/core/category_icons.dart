import 'package:flutter/material.dart';

/// Icon for a task, budget or vendor category key.
IconData categoryIcon(String key) => switch (key) {
      'venue' => Icons.villa_outlined,
      'catering' => Icons.restaurant_outlined,
      'decor' => Icons.local_florist_outlined,
      'photography' => Icons.photo_camera_outlined,
      'attire' => Icons.checkroom_outlined,
      'invitations' => Icons.mail_outline,
      'music_entertainment' => Icons.music_note_outlined,
      'priest_officiant' => Icons.self_improvement_outlined,
      'transport' => Icons.directions_bus_outlined,
      'guest_logistics' => Icons.groups_outlined,
      'legal_documentation' => Icons.description_outlined,
      _ => Icons.category_outlined,
    };
