import '../../core/constants/app_images.dart';
import '../../domain/models/festival.dart';

/// Well-known Philippine cultural festivals shown on Home and Festival Details.
final List<Festival> mockFestivals = [
  Festival(
    id: 'sinulog',
    name: 'Sinulog Festival',
    provinceId: 'cebu',
    provinceName: 'Cebu',
    regionId: 'region-7',
    cityId: 'cebu-city',
    heroImageUrl: AppImages.festivalDancers,
    galleryImageUrls: [AppImages.festivalDancers, AppImages.streetParade, AppImages.traditionalCostume],
    dateLabel: 'January 18, 2026',
    month: 'JAN',
    isUpcoming: true,
    rating: 0,
    reviewCount: 0,
    description:
        'One of the grandest festivals in the Philippines, Sinulog honors the Santo Niño with a '
        'thunderous street parade of drums, vibrant costumes and the iconic "sinulog" two-steps-'
        'forward-one-step-back dance. Contingents from across the Visayas compete in the main '
        'parade route through downtown Cebu, drawing millions of spectators and turning the '
        'entire city into an open-air celebration.',
    highlights: const ['Grand street parade', 'Fluvial procession', 'Street party at Fuente Circle'],
  ),
  Festival(
    id: 'panagbenga',
    name: 'Panagbenga Flower Festival',
    provinceId: 'benguet',
    provinceName: 'Benguet',
    regionId: 'car',
    cityId: 'baguio-city',
    heroImageUrl: AppImages.lanternFestival,
    galleryImageUrls: [AppImages.lanternFestival, AppImages.streetParade, AppImages.festivalDancers],
    dateLabel: 'February 1–28, 2026',
    month: 'FEB',
    isUpcoming: true,
    rating: 0,
    reviewCount: 0,
    description:
        'A month-long celebration of Baguio\'s cool-climate flowers, Panagbenga fills the city\'s '
        'streets with flower-covered floats and vibrant costume dance parades. Session Road '
        'closes to traffic for the grand float parade, while the market and park areas host '
        'flower exhibits, food fairs, and a street-dancing competition among schools from across '
        'the Cordillera region.',
    highlights: const ['Flower float parade', 'Street dance competition', 'Session Road night market'],
  ),
  Festival(
    id: 'kadayawan',
    name: 'Kadayawan Festival',
    provinceId: 'davao-del-sur',
    provinceName: 'Davao del Sur',
    regionId: 'region-11',
    cityId: 'davao-city',
    heroImageUrl: AppImages.traditionalCostume,
    galleryImageUrls: [AppImages.traditionalCostume, AppImages.festivalDancers, AppImages.streetParade],
    dateLabel: 'August 15–21, 2026',
    month: 'AUG',
    rating: 0,
    reviewCount: 0,
    description:
        'Kadayawan is Davao\'s thanksgiving celebration for a bountiful harvest and the region\'s '
        'rich indigenous heritage. Eleven tribes of Mindanao showcase their traditional dress, '
        'music and dance, while the streets fill with fruit displays, flower arrangements and a '
        'showcase of Davao\'s famous durian.',
    highlights: const ['Indak-Indak street dance', 'Floral float competition', 'Fruit and produce fair'],
  ),
  Festival(
    id: 'ati-atihan',
    name: 'Ati-Atihan Festival',
    provinceId: 'aklan',
    provinceName: 'Aklan',
    regionId: 'region-6',
    cityId: 'kalibo',
    heroImageUrl: AppImages.streetParade,
    galleryImageUrls: [AppImages.streetParade, AppImages.festivalDancers, AppImages.traditionalCostume],
    dateLabel: 'January 11, 2026',
    month: 'JAN',
    isUpcoming: true,
    rating: 0,
    reviewCount: 0,
    description:
        'Considered the "Mother of all Philippine Festivals," Ati-Atihan features revelers '
        'painting their skin with soot to honor the indigenous Ati people, dancing through '
        'Kalibo\'s streets to relentless drumbeats in tribute to the Santo Niño. The energy is '
        'infectious and famously spontaneous — anyone can join the procession.',
    highlights: const ['Soot-painted street dancing', 'Drum processions', 'Free-for-all street revelry'],
  ),
  Festival(
    id: 'moriones',
    name: 'Moriones Festival',
    provinceId: 'marinduque',
    provinceName: 'Marinduque',
    regionId: 'region-4b',
    heroImageUrl: AppImages.traditionalCostume,
    galleryImageUrls: [AppImages.traditionalCostume, AppImages.streetParade],
    dateLabel: 'March 28 – April 4, 2026',
    month: 'MAR',
    rating: 0,
    reviewCount: 0,
    description:
        'During Holy Week, the island of Marinduque transforms as locals don elaborate Roman '
        'centurion masks and armor to re-enact the story of Longinus, the biblical soldier said '
        'to have gained sight after piercing Christ\'s side. The masked "Moriones" roam entire '
        'towns for a week, staying in character for street performances and a dramatic beheading '
        're-enactment finale.',
    highlights: const ['Roman centurion masks', 'Passion play re-enactments', 'Island-wide street theater'],
  ),
  Festival(
    id: 'pahiyas',
    name: 'Pahiyas Festival',
    provinceId: 'quezon',
    provinceName: 'Quezon',
    regionId: 'region-4a',
    cityId: 'lucban',
    heroImageUrl: AppImages.streetParade,
    galleryImageUrls: [AppImages.streetParade, AppImages.festivalDancers],
    dateLabel: 'May 15, 2026',
    month: 'MAY',
    rating: 0,
    reviewCount: 0,
    description:
        'Farmers in Lucban give thanks for their harvest by decorating their houses with '
        'kiping — colorful, leaf-shaped rice wafers — alongside fruits, vegetables and woven '
        'crafts, turning entire streets into an edible art gallery. Visitors are welcome to pick '
        'kiping straight off the house facades to snack on.',
    highlights: const ['Kiping-decorated houses', 'Harvest offerings display', 'Lucban longganisa food stalls'],
  ),
];

Festival festivalById(String id) =>
    mockFestivals.firstWhere((f) => f.id == id, orElse: () => mockFestivals.first);
