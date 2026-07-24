import '../../core/constants/app_images.dart';
import '../../domain/models/destination.dart';

/// Realistic Philippine tourist destinations used to seed the
/// `tourist_spots` Firestore collection (see `tool/seed_firestore.js`).
final List<Destination> mockDestinations = [
  Destination(
    id: 'chocolate-hills',
    name: 'Chocolate Hills',
    provinceId: 'bohol',
    provinceName: 'Bohol',
    regionId: 'region-7',
    categoryId: 'nature',
    heroImageUrl: AppImages.chocolateHills,
    galleryImageUrls: [
      AppImages.chocolateHills,
      AppImages.greenValley,
      AppImages.riceTerraces,
    ],
    rating: 0,
    reviewCount: 0,
    isFeatured: true,
    shortDescription: 'Over 1,700 cone-shaped hills that turn cocoa-brown every dry season.',
    longDescription:
        'One of the most iconic natural wonders in the Philippines, the Chocolate Hills of Bohol '
        'are a geological marvel of more than 1,700 near-identical grass-covered mounds spread '
        'across 50 square kilometers. During the dry season the grass turns a rich brown, giving '
        'the hills their unmistakable chocolate-kiss appearance. A viewing deck in Carmen town '
        'offers a sweeping panorama that photographs best at sunrise, when soft light rakes '
        'across the hills and mist still lingers in the valleys.',
    entranceFee: '₱75 per person',
    bestTimeToVisit: 'March – May (dry season, hills turn brown)',
    travelTips: [
      'Arrive before 8 AM to beat the tour buses and the heat.',
      'Combine with the Tarsier Sanctuary and Loboc River Cruise for a full-day loop.',
      'Wear comfortable shoes — the viewing deck has about 200 steps.',
    ],
    highlights: const ['Sunrise viewpoint', 'Zipline nearby', 'ATV adventure park'],
    nearbyRestaurantIds: const ['loboc-river-grill', 'bohol-bee-farm'],
    nearbyDestinationIds: const ['tinuy-an-falls'],
    latitude: 9.9298,
    longitude: 124.1636,
    openingHours: '6:00 AM – 6:00 PM daily',
  ),
  Destination(
    id: 'mayon-volcano',
    name: 'Mayon Volcano',
    provinceId: 'albay',
    provinceName: 'Albay',
    regionId: 'region-5',
    categoryId: 'mountains',
    heroImageUrl: AppImages.mayonVolcano,
    galleryImageUrls: [AppImages.mayonVolcano, AppImages.mountainSunrise, AppImages.greenValley],
    rating: 0,
    reviewCount: 0,
    isFeatured: true,
    shortDescription: 'The world-famous perfect cone volcano overlooking Legazpi City.',
    longDescription:
        'Mayon is celebrated as having the most symmetrical volcanic cone in the world, rising '
        '2,463 meters above Albay with almost mathematical precision. It remains an active '
        'volcano, which only adds to its dramatic presence on the skyline. The best vantage '
        'points are Lignon Hill and the Cagsawa Ruins, where a centuries-old bell tower — buried '
        'by a 1814 eruption — frames the volcano in one of the most photographed shots in the '
        'country.',
    entranceFee: '₱20 (Cagsawa Ruins entrance)',
    bestTimeToVisit: 'December – May for the clearest skies',
    travelTips: [
      'Check the latest PHIVOLCS alert level before planning an ATV or trek near the base.',
      'Cagsawa Ruins is best photographed in late afternoon light.',
      'Try ATV rides on the volcano\'s lower slopes for an adrenaline boost.',
    ],
    highlights: const ['Cagsawa Ruins', 'ATV adventure', 'Lignon Hill viewpoint'],
    nearbyRestaurantIds: const ['small-talk-cafe'],
    nearbyDestinationIds: const ['chocolate-hills'],
    latitude: 13.2571,
    longitude: 123.6856,
    openingHours: 'Cagsawa Ruins: 7:00 AM – 7:00 PM daily',
  ),
  Destination(
    id: 'cloud-9',
    name: 'Cloud 9',
    provinceId: 'surigao-del-norte',
    provinceName: 'Surigao del Norte',
    regionId: 'region-13',
    cityId: 'general-luna',
    categoryId: 'beaches',
    heroImageUrl: AppImages.siargaoCloud9,
    galleryImageUrls: [AppImages.siargaoCloud9, AppImages.boracayBeach, AppImages.turquoiseWater],
    rating: 0,
    reviewCount: 0,
    isFeatured: true,
    shortDescription: 'World-class surf break and the beating heart of Siargao\'s surf town.',
    longDescription:
        'Cloud 9 put Siargao on the global surfing map, thanks to a powerful reef break that '
        'hosts international competitions every year. A raised wooden boardwalk winds through '
        'mangroves out to the famous surf tower, where you can watch riders carve the barrel '
        'even if you never touch a board. Beyond the waves, General Luna\'s stretch of cafes, '
        'surf shops and beach bars has made this one of the most laid-back, Instagram-friendly '
        'towns in the country.',
    entranceFee: 'Free (boardwalk); surfboard rental from ₱300/hr',
    bestTimeToVisit: 'August – November for the best swells',
    travelTips: [
      'Beginners should book a lesson at nearby Jom\'s Surf Camp before paddling out at Cloud 9 itself.',
      'Rent a scooter to explore Sugba Lagoon and Magpupungko Rock Pools nearby.',
      'Sunset at the Cloud 9 boardwalk is free and spectacular.',
    ],
    highlights: const ['Surf tower boardwalk', 'Sugba Lagoon day trip', 'Beach bars & live music'],
    nearbyRestaurantIds: const ['kermit-surf-resto', 'shaka-cafe'],
    nearbyDestinationIds: const ['hundred-islands'],
    latitude: 9.8756,
    longitude: 126.1683,
    openingHours: 'Boardwalk open 24 hours',
  ),
  Destination(
    id: 'calle-crisologo',
    name: 'Calle Crisologo',
    provinceId: 'ilocos-sur',
    provinceName: 'Ilocos Sur',
    regionId: 'region-1',
    cityId: 'vigan',
    categoryId: 'historical',
    heroImageUrl: AppImages.calleCrisologo,
    galleryImageUrls: [AppImages.calleCrisologo, AppImages.intramurosWalls, AppImages.jeepneyStreet],
    rating: 0,
    reviewCount: 0,
    isFeatured: true,
    shortDescription: 'A cobblestone street of Spanish colonial mansions, frozen in the 1800s.',
    longDescription:
        'Calle Crisologo is the postcard heart of Vigan, a UNESCO World Heritage city that '
        'preserved its Spanish colonial architecture better than almost anywhere else in Asia. '
        'Capiz-shell windows, wrought-iron balconies and horse-drawn kalesa carriages clatter '
        'over cobblestones at dusk when the street closes to cars and lanterns flicker on. '
        'Antique shops, weaving workshops and empanada stalls line the route, making it as much '
        'a living museum as a place to shop and eat.',
    entranceFee: 'Free to walk; kalesa ride ₱150–₱300',
    bestTimeToVisit: 'Year-round; evenings after 5 PM are most atmospheric',
    travelTips: [
      'Visit after 5 PM when the street turns pedestrian-only and lanterns are lit.',
      'Try Vigan empanada and bagnet from the street stalls near the plaza.',
      'Rent a kalesa for a slow loop of the heritage village.',
    ],
    highlights: const ['Kalesa horse-carriage rides', 'Vigan empanada stalls', 'Syquia Mansion museum'],
    nearbyRestaurantIds: const ['cafe-leona', 'vigan-empanadaan'],
    nearbyDestinationIds: const ['calle-crisologo'],
    latitude: 17.5747,
    longitude: 120.3869,
    openingHours: 'Open 24 hours (pedestrian-only after 5 PM)',
  ),
  Destination(
    id: 'hundred-islands',
    name: 'Hundred Islands',
    provinceId: 'pangasinan',
    provinceName: 'Pangasinan',
    regionId: 'region-1',
    cityId: 'alaminos',
    categoryId: 'beaches',
    heroImageUrl: AppImages.hundredIslands,
    galleryImageUrls: [AppImages.hundredIslands, AppImages.tropicalIslandAerial, AppImages.boatOnLagoon],
    rating: 0,
    reviewCount: 0,
    isFeatured: false,
    shortDescription: '124 limestone islets scattered across the Lingayen Gulf.',
    longDescription:
        'The Hundred Islands National Park is a sprawling marine park of over a hundred small '
        'limestone islands, only a handful of which are developed for visitors. Governor Island '
        'has a viewing tower with a 360-degree panorama, Quezon Island offers a wide swimming '
        'beach, and Children\'s Island is known for calm, shallow water. Island-hopping boats can '
        'be chartered for a half or full day, making it an easy weekend escape from Manila.',
    entranceFee: '₱200 environmental fee + boat rental from ₱1,200/group',
    bestTimeToVisit: 'November – May for calm seas',
    travelTips: [
      'Book a boat at Lucap Wharf early — prices are fixed per boat, so group up to split cost.',
      'Bring reef-safe sunscreen; snorkeling gear can be rented at Quezon Island.',
      'Camping overnight on Marcos Island is allowed with a permit.',
    ],
    highlights: const ['Island hopping', 'Governor Island viewing tower', 'Cave exploring on Quezon Island'],
    nearbyRestaurantIds: const ['lucap-seafood-market'],
    nearbyDestinationIds: const ['cloud-9'],
    latitude: 16.2000,
    longitude: 120.0167,
    openingHours: '7:00 AM – 5:00 PM daily',
  ),
  Destination(
    id: 'tinuy-an-falls',
    name: 'Tinuy-an Falls',
    provinceId: 'surigao-del-sur',
    provinceName: 'Surigao del Sur',
    regionId: 'region-13',
    cityId: 'bislig',
    categoryId: 'nature',
    heroImageUrl: AppImages.tinuyanFalls,
    galleryImageUrls: [AppImages.tinuyanFalls, AppImages.jungleWaterfall, AppImages.greenValley],
    rating: 0,
    reviewCount: 0,
    isHiddenGem: true,
    shortDescription: 'The "Niagara Falls of the Philippines" cascading over three wide tiers.',
    longDescription:
        'Tucked deep in Surigao del Sur, Tinuy-an Falls spreads across a 95-meter-wide curtain of '
        'milky turquoise water tumbling down three limestone tiers into a wide natural pool. '
        'Bamboo rafts ferry visitors right up to the base of the falls, where the spray and roar '
        'make for one of the most dramatic swims in Mindanao. Because it sits off the usual '
        'tourist trail, mornings here are often quiet enough to have the entire pool to yourself.',
    entranceFee: '₱50 entrance + ₱150 bamboo raft rental',
    bestTimeToVisit: 'March – May for the clearest turquoise water',
    travelTips: [
      'Go on a weekday morning to avoid local day-trip crowds.',
      'Combine with Hagukan Cave and Enchanted River in Hinatuan for a full Surigao del Sur loop.',
      'Water is strongest (and muddiest) right after rain — check the forecast.',
    ],
    highlights: const ['Bamboo raft ride', 'Three-tier cascade', 'Nearby Enchanted River'],
    nearbyRestaurantIds: const [],
    nearbyDestinationIds: const ['cloud-9'],
    latitude: 8.1957,
    longitude: 126.3622,
    openingHours: '6:00 AM – 5:00 PM daily',
  ),
  Destination(
    id: 'el-nido-lagoons',
    name: 'El Nido Lagoons',
    provinceId: 'palawan',
    provinceName: 'Palawan',
    regionId: 'region-4b',
    cityId: 'el-nido',
    categoryId: 'beaches',
    heroImageUrl: AppImages.elNidoLagoon,
    galleryImageUrls: [AppImages.elNidoLagoon, AppImages.palawanCliffs, AppImages.turquoiseWater],
    rating: 0,
    reviewCount: 0,
    isFeatured: true,
    shortDescription: 'Limestone karsts and hidden lagoons accessible only by boat.',
    longDescription:
        'El Nido\'s Bacuit Archipelago is a maze of towering limestone cliffs, secret lagoons and '
        'powder-white beaches that consistently ranks among the world\'s best island destinations. '
        'The Big and Small Lagoon tours (Tour A) are the most iconic, with kayaks gliding through '
        'narrow rock crevices into perfectly still turquoise pools. Tour C ventures further out to '
        'wilder, less-visited reefs and beaches for travelers chasing a quieter island-hopping day.',
    entranceFee: 'Island-hopping tours from ₱1,400/person (boat + lunch)',
    bestTimeToVisit: 'November – May, dry season',
    travelTips: [
      'Book Tour A (Big/Small Lagoon) at least a day ahead — it\'s the most popular route.',
      'Bring cash; most boat operators and beach cafes don\'t accept cards.',
      'Pack a dry bag — you will get splashed climbing into the lagoons.',
    ],
    highlights: const ['Big Lagoon kayaking', 'Secret Beach', 'Matinloc Shrine'],
    nearbyRestaurantIds: const ['altrove-el-nido'],
    nearbyDestinationIds: const ['hundred-islands'],
    latitude: 11.1949,
    longitude: 119.4116,
    openingHours: 'Island-hopping tours depart 8:00 AM – 9:00 AM',
  ),
  Destination(
    id: 'banaue-rice-terraces',
    name: 'Banaue Rice Terraces',
    provinceId: 'ifugao',
    provinceName: 'Ifugao',
    regionId: 'car',
    categoryId: 'mountains',
    heroImageUrl: AppImages.riceTerraces,
    galleryImageUrls: [AppImages.riceTerraces, AppImages.greenValley, AppImages.mountainSunrise],
    rating: 0,
    reviewCount: 0,
    isHiddenGem: true,
    shortDescription: '2,000-year-old terraces carved by hand into the Cordillera mountains.',
    longDescription:
        'Often called the "Eighth Wonder of the World," the Banaue Rice Terraces were carved '
        'into the mountainside by the Ifugao people using little more than hand tools, forming a '
        'vast staircase of paddies that still feeds local communities today. The Batad terraces, '
        'shaped like a natural amphitheater, require a short trek to reach but reward hikers with '
        'one of the most striking landscapes in Southeast Asia.',
    entranceFee: '₱50 viewpoint fee; Batad village fee ₱20',
    bestTimeToVisit: 'April – May (planting) or October – November (harvest, terraces turn gold)',
    travelTips: [
      'Hire a local Ifugao guide for the Batad trek — trails fork often and guides support the community.',
      'Bring layers; Banaue nights get cool at around 20°C year-round.',
      'The night bus from Manila is the most common way to arrive — book seats in advance.',
    ],
    highlights: const ['Batad amphitheater terraces', 'Tappiya Waterfall trek', 'Ifugao weaving villages'],
    nearbyRestaurantIds: const [],
    nearbyDestinationIds: const ['tinuy-an-falls'],
    latitude: 16.9107,
    longitude: 121.0583,
    openingHours: 'Viewpoint open 24 hours',
  ),
  Destination(
    id: 'intramuros',
    name: 'Intramuros',
    provinceId: 'metro-manila',
    provinceName: 'Metro Manila',
    regionId: 'ncr',
    cityId: 'manila',
    categoryId: 'historical',
    heroImageUrl: AppImages.intramurosWalls,
    galleryImageUrls: [AppImages.intramurosWalls, AppImages.manilaSkyline, AppImages.jeepneyStreet],
    rating: 0,
    reviewCount: 0,
    isFeatured: false,
    shortDescription: 'The walled Spanish city at the historic core of Manila.',
    longDescription:
        'Intramuros is the original 16th-century walled city that Spanish colonizers built at the '
        'mouth of the Pasig River, and it remains Manila\'s best-preserved link to that era. Fort '
        'Santiago, San Agustin Church (a UNESCO World Heritage Site), and the cobbled streets '
        'around Plaza Roma are best explored by bike or calesa, with the massive stone walls '
        'themselves offering a walkable perimeter loop above the moat-turned-golf-course.',
    entranceFee: 'Fort Santiago ₱75; San Agustin Church ₱200',
    bestTimeToVisit: 'Early morning or late afternoon to avoid the heat',
    travelTips: [
      'Join a bamboo-bike tour for the most efficient way to see the whole district.',
      'Visit Fort Santiago\'s Rizal Shrine to learn the story of the national hero\'s final days.',
      'Barbara\'s Restaurant nearby hosts a nightly cultural dinner show.',
    ],
    highlights: const ['Fort Santiago', 'San Agustin Church', 'Bamboo bike tours'],
    nearbyRestaurantIds: const ['barbaras-intramuros'],
    nearbyDestinationIds: const ['calle-crisologo'],
    latitude: 14.5895,
    longitude: 120.9750,
    openingHours: 'Fort Santiago: 8:00 AM – 7:00 PM daily',
  ),
  Destination(
    id: 'kawasan-falls',
    name: 'Kawasan Falls',
    provinceId: 'cebu',
    provinceName: 'Cebu',
    regionId: 'region-7',
    cityId: 'badian',
    categoryId: 'nature',
    heroImageUrl: AppImages.jungleWaterfall,
    galleryImageUrls: [AppImages.jungleWaterfall, AppImages.tinuyanFalls, AppImages.greenValley],
    rating: 0,
    reviewCount: 0,
    isHiddenGem: true,
    shortDescription: 'Turquoise waterfalls famous for canyoneering adventures.',
    longDescription:
        'Kawasan Falls is the centerpiece of one of the Philippines\' most thrilling canyoneering '
        'routes, where cliff jumps, rope swings and river-scrambling lead you through a series of '
        'cascades before ending at the main three-tier falls. Even without the adventure trek, the '
        'main pool\'s milky-blue water framed by limestone cliffs makes it worth the trip on its own.',
    entranceFee: '₱30 entrance; canyoneering tours from ₱1,500/person',
    bestTimeToVisit: 'November – May, avoid after heavy rain (water turns brown)',
    travelTips: [
      'Book canyoneering through a licensed local guide association for safety gear and insurance.',
      'Wear a rash guard — the rocks can scrape bare skin on the jumps.',
      'Arrive early; the falls get crowded with day-trippers by 11 AM.',
    ],
    highlights: const ['Canyoneering trek', 'Cliff jumping', 'Bamboo raft floating cafes'],
    nearbyRestaurantIds: const [],
    nearbyDestinationIds: const ['el-nido-lagoons'],
    latitude: 9.8167,
    longitude: 123.3833,
    openingHours: '6:00 AM – 5:00 PM daily',
  ),
];

Destination destinationById(String id) =>
    mockDestinations.firstWhere((d) => d.id == id, orElse: () => mockDestinations.first);
