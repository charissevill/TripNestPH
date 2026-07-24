import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/icon_registry.dart';

/// A bite-sized travel tip shown in the Home carousel and Details screens.
/// Backed by the `travel_tips` Firestore collection.
class TravelTip {
  const TravelTip({
    required this.id,
    required this.title,
    required this.description,
    required this.iconKey,
    required this.colorKey,
  });

  final String id;
  final String title;
  final String description;
  final String iconKey;
  final String colorKey;

  IconData get icon => IconRegistry.resolve(iconKey);
  Color get accentColor => AppColors.byKey(colorKey);

  factory TravelTip.fromMap(String id, Map<String, dynamic> map) {
    return TravelTip(
      id: id,
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      iconKey: map['iconKey'] as String? ?? 'wb_sunny',
      colorKey: map['colorKey'] as String? ?? 'primary',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'iconKey': iconKey,
      'colorKey': colorKey,
    };
  }
}
