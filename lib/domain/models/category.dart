import 'package:flutter/material.dart';

/// A browsable destination category shown as a chip/grid tile on Home and Explore.
class TravelCategory {
  const TravelCategory({
    required this.id,
    required this.label,
    required this.icon,
    required this.imageUrl,
  });

  final String id;
  final String label;
  final IconData icon;
  final String imageUrl;
}
