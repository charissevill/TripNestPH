import 'package:material_symbols_icons/symbols.dart';

import '../../core/constants/app_images.dart';
import '../../domain/models/category.dart';

/// The six primary browsing categories featured on Home and Explore.
final List<TravelCategory> mockCategories = [
  TravelCategory(
    id: 'beaches',
    label: 'Beaches',
    icon: Symbols.beach_access_rounded,
    imageUrl: AppImages.boracayBeach,
  ),
  TravelCategory(
    id: 'mountains',
    label: 'Mountains',
    icon: Symbols.landscape_rounded,
    imageUrl: AppImages.mountainSunrise,
  ),
  TravelCategory(
    id: 'historical',
    label: 'Historical',
    icon: Symbols.account_balance_rounded,
    imageUrl: AppImages.calleCrisologo,
  ),
  TravelCategory(
    id: 'nature',
    label: 'Nature',
    icon: Symbols.forest_rounded,
    imageUrl: AppImages.jungleWaterfall,
  ),
  TravelCategory(
    id: 'food',
    label: 'Food',
    icon: Symbols.restaurant_rounded,
    imageUrl: AppImages.filipinoFeast,
  ),
  TravelCategory(
    id: 'festivals',
    label: 'Festivals',
    icon: Symbols.celebration_rounded,
    imageUrl: AppImages.festivalDancers,
  ),
];
