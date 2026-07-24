import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/icon_registry.dart';

/// A full mock itinerary produced by the (non-AI, Phase 1/2) trip planner.
class Itinerary {
  const Itinerary({
    required this.destinationName,
    required this.coverImageUrl,
    required this.totalDays,
    required this.travelers,
    required this.totalBudget,
    required this.days,
    required this.budgetBreakdown,
    required this.weather,
    required this.travelTips,
    required this.recommendedRestaurantIds,
    required this.nearbyAttractionIds,
    this.recommendedAccommodations = const [],
  });

  final String destinationName;
  final String coverImageUrl;
  final int totalDays;
  final int travelers;
  final double totalBudget;
  final List<ItineraryDay> days;
  final List<BudgetItem> budgetBreakdown;
  final List<WeatherForecast> weather;
  final List<String> travelTips;
  final List<String> recommendedRestaurantIds;
  final List<String> nearbyAttractionIds;

  /// Top-rated live hotels near the destination at the time this itinerary
  /// was generated (Places API) — a snapshot, not a live query, so a saved
  /// itinerary keeps showing what was recommended without re-fetching on
  /// every view (same reasoning [weather] is stored once, not re-fetched).
  /// Empty for itineraries saved before this field existed.
  final List<PlaceRecommendation> recommendedAccommodations;

  factory Itinerary.fromMap(Map<String, dynamic> map) {
    return Itinerary(
      destinationName: map['destinationName'] as String? ?? '',
      coverImageUrl: map['coverImageUrl'] as String? ?? '',
      totalDays: (map['totalDays'] as num?)?.toInt() ?? 1,
      travelers: (map['travelers'] as num?)?.toInt() ?? 1,
      totalBudget: (map['totalBudget'] as num?)?.toDouble() ?? 0,
      days: (map['days'] as List? ?? const [])
          .map((e) => ItineraryDay.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
      budgetBreakdown: (map['budgetBreakdown'] as List? ?? const [])
          .map((e) => BudgetItem.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
      weather: (map['weather'] as List? ?? const [])
          .map((e) => WeatherForecast.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
      travelTips: List<String>.from(map['travelTips'] as List? ?? const []),
      recommendedRestaurantIds: List<String>.from(map['recommendedRestaurantIds'] as List? ?? const []),
      nearbyAttractionIds: List<String>.from(map['nearbyAttractionIds'] as List? ?? const []),
      recommendedAccommodations: (map['recommendedAccommodations'] as List? ?? const [])
          .map((e) => PlaceRecommendation.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'destinationName': destinationName,
      'coverImageUrl': coverImageUrl,
      'totalDays': totalDays,
      'travelers': travelers,
      'totalBudget': totalBudget,
      'days': days.map((d) => d.toMap()).toList(),
      'budgetBreakdown': budgetBreakdown.map((b) => b.toMap()).toList(),
      'weather': weather.map((w) => w.toMap()).toList(),
      'travelTips': travelTips,
      'recommendedRestaurantIds': recommendedRestaurantIds,
      'nearbyAttractionIds': nearbyAttractionIds,
      'recommendedAccommodations': recommendedAccommodations.map((p) => p.toMap()).toList(),
    };
  }
}

/// A snapshot of one live Places API hotel result, embedded on [Itinerary]
/// at generation time (see the field doc above) — deliberately lighter than
/// the full `Place` model, keeping only what the "Recommended
/// Accommodations" carousel renders.
class PlaceRecommendation {
  const PlaceRecommendation({
    required this.placeId,
    required this.name,
    this.rating,
    this.userRatingCount,
    this.priceLevel,
    this.photoUrl = '',
    this.address = '',
    this.latitude,
    this.longitude,
  });

  final String placeId;
  final String name;
  final double? rating;
  final int? userRatingCount;
  final int? priceLevel;
  final String photoUrl;
  final String address;
  final double? latitude;
  final double? longitude;

  bool get hasCoordinates => latitude != null && longitude != null;

  factory PlaceRecommendation.fromMap(Map<String, dynamic> map) {
    return PlaceRecommendation(
      placeId: map['placeId'] as String? ?? '',
      name: map['name'] as String? ?? '',
      rating: (map['rating'] as num?)?.toDouble(),
      userRatingCount: (map['userRatingCount'] as num?)?.toInt(),
      priceLevel: (map['priceLevel'] as num?)?.toInt(),
      photoUrl: map['photoUrl'] as String? ?? '',
      address: map['address'] as String? ?? '',
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'placeId': placeId,
      'name': name,
      'rating': rating,
      'userRatingCount': userRatingCount,
      'priceLevel': priceLevel,
      'photoUrl': photoUrl,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
    };
  }
}

class ItineraryDay {
  const ItineraryDay({required this.dayNumber, required this.dateLabel, required this.activities});

  final int dayNumber;
  final String dateLabel;
  final List<ItineraryActivity> activities;

  factory ItineraryDay.fromMap(Map<String, dynamic> map) {
    return ItineraryDay(
      dayNumber: (map['dayNumber'] as num?)?.toInt() ?? 1,
      dateLabel: map['dateLabel'] as String? ?? '',
      activities: (map['activities'] as List? ?? const [])
          .map((e) => ItineraryActivity.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'dayNumber': dayNumber,
      'dateLabel': dateLabel,
      'activities': activities.map((a) => a.toMap()).toList(),
    };
  }
}

class ItineraryActivity {
  const ItineraryActivity({
    required this.time,
    required this.title,
    required this.description,
    required this.iconKey,
    required this.location,
  });

  final String time;
  final String title;
  final String description;
  final String iconKey;
  final String location;

  IconData get icon => IconRegistry.resolve(iconKey);

  factory ItineraryActivity.fromMap(Map<String, dynamic> map) {
    return ItineraryActivity(
      time: map['time'] as String? ?? '',
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      iconKey: map['iconKey'] as String? ?? 'flight_land',
      location: map['location'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {'time': time, 'title': title, 'description': description, 'iconKey': iconKey, 'location': location};
  }
}

class BudgetItem {
  const BudgetItem({required this.label, required this.amount, required this.iconKey, required this.colorKey});

  final String label;
  final double amount;
  final String iconKey;
  final String colorKey;

  IconData get icon => IconRegistry.resolve(iconKey);
  Color get color => AppColors.byKey(colorKey);

  factory BudgetItem.fromMap(Map<String, dynamic> map) {
    return BudgetItem(
      label: map['label'] as String? ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      iconKey: map['iconKey'] as String? ?? 'payments',
      colorKey: map['colorKey'] as String? ?? 'primary',
    );
  }

  Map<String, dynamic> toMap() {
    return {'label': label, 'amount': amount, 'iconKey': iconKey, 'colorKey': colorKey};
  }
}

class WeatherForecast {
  const WeatherForecast({
    required this.dayLabel,
    required this.condition,
    required this.iconKey,
    required this.highTemp,
    required this.lowTemp,
  });

  final String dayLabel;
  final String condition;
  final String iconKey;
  final int highTemp;
  final int lowTemp;

  IconData get icon => IconRegistry.resolve(iconKey);

  /// The weather tile's background — matches [iconKey] so a sunny day reads
  /// warm/bright and a stormy one reads dark/moody at a glance, rather than
  /// every forecast card looking identical regardless of conditions.
  List<Color> get gradient {
    switch (iconKey) {
      case 'wb_sunny':
        return AppColors.goldenHourGradient;
      case 'cloud':
        return AppColors.skyGradient;
      case 'wb_cloudy':
      case 'foggy':
        return AppColors.mistGradient;
      case 'rainy':
        return AppColors.rainGradient;
      case 'thunderstorm':
        return AppColors.stormGradient;
      default:
        return AppColors.skyGradient;
    }
  }

  factory WeatherForecast.fromMap(Map<String, dynamic> map) {
    return WeatherForecast(
      dayLabel: map['dayLabel'] as String? ?? '',
      condition: map['condition'] as String? ?? '',
      iconKey: map['iconKey'] as String? ?? 'wb_sunny',
      highTemp: (map['highTemp'] as num?)?.toInt() ?? 0,
      lowTemp: (map['lowTemp'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {'dayLabel': dayLabel, 'condition': condition, 'iconKey': iconKey, 'highTemp': highTemp, 'lowTemp': lowTemp};
  }
}
