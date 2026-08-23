import 'package:material_symbols_icons/symbols.dart';

import '../../domain/models/category.dart';

/// The six primary browsing categories featured on Home and Explore. Each
/// [TravelCategory.imageUrl] is a real Wikimedia Commons photo of an
/// actual, named Philippine place/dish for that category — not a generic
/// stock photo — verified to resolve before being wired in here (same
/// stable direct-thumbnail URL scheme used for festival photos: see
/// `mock_festivals.dart`'s doc comments for why `Special:FilePath` is
/// avoided).
final List<TravelCategory> mockCategories = [
  TravelCategory(
    id: 'beaches',
    label: 'Beaches',
    icon: Symbols.beach_access_rounded,
    imageUrl:
        'https://upload.wikimedia.org/wikipedia/commons/thumb/5/50/Boracay_White_Beach_in_day_(985286231).jpg/500px-Boracay_White_Beach_in_day_(985286231).jpg',
  ),
  TravelCategory(
    id: 'mountains',
    label: 'Mountains',
    icon: Symbols.landscape_rounded,
    imageUrl:
        'https://upload.wikimedia.org/wikipedia/commons/thumb/4/47/The_Mayon_Volcano_-_Albay%2C_Bicol%2C_Philippines.jpg/500px-The_Mayon_Volcano_-_Albay%2C_Bicol%2C_Philippines.jpg',
  ),
  TravelCategory(
    id: 'historical',
    label: 'Historical',
    icon: Symbols.account_balance_rounded,
    imageUrl:
        'https://upload.wikimedia.org/wikipedia/commons/thumb/4/4a/The_Calle_Crisologo_in_Vigan%2C_Ilocos_Sur.jpg/500px-The_Calle_Crisologo_in_Vigan%2C_Ilocos_Sur.jpg',
  ),
  TravelCategory(
    id: 'nature',
    label: 'Nature',
    icon: Symbols.forest_rounded,
    imageUrl:
        'https://upload.wikimedia.org/wikipedia/commons/thumb/3/36/Chocolate_Hills.jpg/500px-Chocolate_Hills.jpg',
  ),
  TravelCategory(
    id: 'food',
    label: 'Food',
    icon: Symbols.restaurant_rounded,
    imageUrl:
        'https://upload.wikimedia.org/wikipedia/commons/thumb/3/38/Chicken_adobo.jpg/500px-Chicken_adobo.jpg',
  ),
  TravelCategory(
    id: 'festivals',
    label: 'Festivals',
    icon: Symbols.celebration_rounded,
    imageUrl:
        'https://upload.wikimedia.org/wikipedia/commons/thumb/9/97/Colors_of_Sinulog_Festival_of_Cebu.jpg/500px-Colors_of_Sinulog_Festival_of_Cebu.jpg',
  ),
];
