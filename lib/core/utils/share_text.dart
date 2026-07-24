import '../../domain/models/destination.dart';
import '../../domain/models/festival.dart';
import '../../domain/models/restaurant.dart';

/// Builds the plain-text summaries shared from each Details screen's share
/// button. No app/web link is included — TripNest PH doesn't have a
/// public website or deep-link domain to point back into, so a fabricated
/// URL would just be a dead link.
class ShareText {
  ShareText._();

  static String forDestination(Destination d) {
    return '${d.name} — ${d.provinceName}\n'
        '★ ${d.rating.toStringAsFixed(1)} (${d.reviewCount} reviews)\n\n'
        '${d.shortDescription}\n\n'
        'Found on TripNest PH.';
  }

  static String forRestaurant(Restaurant r) {
    return '${r.name} — ${r.cuisine} · ${r.provinceName}\n'
        '★ ${r.rating.toStringAsFixed(1)} (${r.reviewCount} reviews) · ${r.priceRange}\n\n'
        '${r.description}\n\n'
        'Found on TripNest PH.';
  }

  static String forFestival(Festival f) {
    return '${f.name} — ${f.provinceName}\n'
        '${f.dateLabel}\n'
        '★ ${f.rating.toStringAsFixed(1)} (${f.reviewCount} reviews)\n\n'
        '${f.description}\n\n'
        'Found on TripNest PH.';
  }
}
