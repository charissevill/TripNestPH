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

  // ---- One signature spot for every other province ----
  // General, well-established facts only. Fees are left unquoted where they
  // change often, and coordinates are omitted where no reliable published
  // figure was available (see [Destination.hasCoordinates]).

  // ---- CAR — Cordillera Administrative Region ----
  Destination(
    id: 'kaparkan-falls',
    name: 'Kaparkan Falls',
    provinceId: 'abra',
    provinceName: 'Abra',
    regionId: 'car',
    categoryId: 'nature',
    heroImageUrl: AppImages.jungleWaterfall,
    galleryImageUrls: [AppImages.jungleWaterfall, AppImages.tinuyanFalls, AppImages.greenValley],
    rating: 0,
    reviewCount: 0,
    isHiddenGem: true,
    shortDescription: 'Terraced limestone cascades hidden deep in the mountains of Tineg.',
    longDescription:
        'Kaparkan Falls spills down a long staircase of natural limestone terraces in the remote '
        'municipality of Tineg, each tier forming a shallow pool you can wade through. The falls '
        'only flow at full strength in the rainy months, and getting there means a rough 4x4 ride '
        'over mountain trails from Bangued — which is exactly why it still feels undiscovered.',
    entranceFee: 'Visited on organized 4x4 trips — rates vary, confirm with the Abra tourism office',
    bestTimeToVisit: 'July – September, when the terraces are full of water',
    travelTips: [
      'Trips usually run on scheduled weekends only — book a slot ahead through the provincial tourism office.',
      'Expect a long, bumpy 4x4 ride; pack light and waterproof your gear.',
      'Wear aqua shoes with good grip for walking on the wet terraces.',
    ],
    highlights: const ['Limestone terrace pools', '4x4 mountain ride', 'Off-the-beaten-path adventure'],
  ),
  Destination(
    id: 'lussok-cave',
    name: 'Lussok Cave',
    provinceId: 'apayao',
    provinceName: 'Apayao',
    regionId: 'car',
    categoryId: 'nature',
    heroImageUrl: AppImages.boatOnLagoon,
    galleryImageUrls: [AppImages.boatOnLagoon, AppImages.jungleWaterfall, AppImages.greenValley],
    rating: 0,
    reviewCount: 0,
    isHiddenGem: true,
    shortDescription: 'A river cave in Luna explored by small boat past towering rock walls.',
    longDescription:
        'Lussok Cave and its underground river are the best-known attraction of Luna, Apayao. '
        'Local boatmen paddle visitors along a clear, jade-colored river and into the cave mouth, '
        'where stalactites hang low over the water and limestone cliffs rise on both sides. It is '
        "a quiet, community-run site that shows off the province's largely untouched landscape.",
    entranceFee: 'Small entrance and boat fees collected on site',
    bestTimeToVisit: 'November – May, when river levels are calmer',
    travelTips: [
      'Base yourself in Luna — lodging elsewhere in the province is limited.',
      'Boat trips can be suspended after heavy rain when the river rises.',
      'Bring a headlamp and a dry bag for your phone.',
    ],
    highlights: const ['Underground river boat ride', 'Limestone cliffs', 'Clear river swimming'],
  ),
  Destination(
    id: 'mount-pulag',
    name: 'Mount Pulag',
    provinceId: 'benguet',
    provinceName: 'Benguet',
    regionId: 'car',
    categoryId: 'mountains',
    heroImageUrl: AppImages.mountainSunrise,
    galleryImageUrls: [AppImages.mountainSunrise, AppImages.greenValley, AppImages.riceTerraces],
    rating: 0,
    reviewCount: 0,
    shortDescription: "Luzon's highest peak, famous for its sunrise above a sea of clouds.",
    longDescription:
        "Mount Pulag is the highest peak in Luzon and one of the country's most popular climbs. "
        'Hikers set off before dawn through mossy forest and dwarf-bamboo grassland to reach the '
        'summit in time for sunrise, when clouds often fill the valleys below like an ocean. The '
        'mountain is a protected national park and is sacred to the indigenous communities that '
        'live around it.',
    entranceFee: 'Park, guide and registration fees apply — confirm current rates with the park office',
    bestTimeToVisit: 'December – March for the clearest sunrises',
    travelTips: [
      'Reserve your climb with the park office in advance — daily hiker numbers are limited.',
      'A medical certificate is required at registration.',
      'Summit temperatures can drop near freezing; bring proper cold-weather layers.',
    ],
    highlights: const ['Sea of clouds sunrise', 'Mossy forest trail', 'Dwarf-bamboo grassland summit'],
    nearbyDestinationIds: const ['banaue-rice-terraces'],
    latitude: 16.5836,
    longitude: 120.8836,
  ),
  Destination(
    id: 'buscalan-village',
    name: 'Buscalan Tattoo Village',
    provinceId: 'kalinga',
    provinceName: 'Kalinga',
    regionId: 'car',
    categoryId: 'historical',
    heroImageUrl: AppImages.riceTerraces,
    galleryImageUrls: [AppImages.riceTerraces, AppImages.greenValley, AppImages.mountainSunrise],
    rating: 0,
    reviewCount: 0,
    shortDescription: 'Mountain village keeping the hand-tapped Kalinga tattoo tradition alive.',
    longDescription:
        'Buscalan, a village of the Butbut people in Tinglayan, is the home of Apo Whang-Od and '
        'the centuries-old art of batok — tattoos hand-tapped into the skin with a thorn and '
        'soot ink. Visitors hike up through rice terraces to reach the village, where a younger '
        'generation of tattoo artists now carries on the practice alongside her.',
    entranceFee: 'Environmental and guide fees collected at registration; tattoo prices vary by design',
    bestTimeToVisit: 'November – April for drier trails',
    travelTips: [
      'A local guide is required — register at the village turning point before hiking up.',
      'Most visitors stay overnight in a homestay; bring cash, as there are no ATMs.',
      'Ask permission before taking photos of residents and their tattoos.',
    ],
    highlights: const ['Traditional batok tattoos', 'Rice terrace hike', 'Village homestays'],
    nearbyDestinationIds: const ['banaue-rice-terraces'],
  ),
  Destination(
    id: 'sagada-hanging-coffins',
    name: 'Sagada Hanging Coffins',
    provinceId: 'mountain-province',
    provinceName: 'Mountain Province',
    regionId: 'car',
    categoryId: 'historical',
    heroImageUrl: AppImages.greenValley,
    galleryImageUrls: [AppImages.greenValley, AppImages.mountainSunrise, AppImages.riceTerraces],
    rating: 0,
    reviewCount: 0,
    shortDescription: 'Centuries-old coffins suspended on the limestone cliffs of Echo Valley.',
    longDescription:
        'In Sagada, the Kankanaey people traditionally laid their elders to rest in wooden coffins '
        'hung high on cliff faces, a practice believed to bring the dead closer to their ancestors. '
        "The most accessible site is Echo Valley, a short guided walk from the town's Anglican "
        'church through pine forest and down to the foot of the cliffs.',
    entranceFee: 'Tourist registration and guide fees apply — pay at the Sagada tourism office',
    bestTimeToVisit: 'November – May, the dry season',
    travelTips: [
      'Register at the municipal tourism office first; guides are required for Echo Valley.',
      'This is a burial site — keep your voice down and never touch the coffins.',
      'Pair it with Sumaguing Cave or sunrise at Kiltepan for a full Sagada day.',
    ],
    highlights: const ['Echo Valley trail', 'Sumaguing Cave nearby', 'Pine-forest town walks'],
    nearbyDestinationIds: const ['banaue-rice-terraces'],
    latitude: 17.0842,
    longitude: 120.9008,
  ),

  // ---- Region I — Ilocos Region ----
  Destination(
    id: 'paoay-church',
    name: 'Paoay Church',
    provinceId: 'ilocos-norte',
    provinceName: 'Ilocos Norte',
    regionId: 'region-1',
    cityId: 'paoay',
    categoryId: 'historical',
    heroImageUrl: AppImages.vigenChurch,
    galleryImageUrls: [AppImages.vigenChurch, AppImages.calleCrisologo, AppImages.intramurosWalls],
    rating: 0,
    reviewCount: 0,
    shortDescription: 'UNESCO-listed church famous for its massive earthquake-proof buttresses.',
    longDescription:
        'The Saint Augustine Church of Paoay is one of the four Baroque Churches of the '
        'Philippines inscribed as a UNESCO World Heritage Site. Its enormous coral-stone and '
        'brick buttresses were designed to withstand earthquakes, giving the building a unique '
        'fortress-like silhouette, with a separate bell tower standing a short distance away.',
    entranceFee: 'Free; donations welcome',
    bestTimeToVisit: 'November – April; late afternoon for the best light on the facade',
    travelTips: [
      'Dress modestly — this is an active parish church.',
      'Combine with the Paoay sand dunes and Laoag for a day trip.',
      'Try Ilocos empanada from the stalls across the plaza.',
    ],
    highlights: const ['Earthquake Baroque architecture', 'Coral-stone bell tower', 'UNESCO World Heritage Site'],
    nearbyDestinationIds: const ['calle-crisologo'],
    latitude: 18.0615,
    longitude: 120.5215,
    openingHours: 'Open daily during church hours',
  ),
  Destination(
    id: 'san-juan-surf-beach',
    name: 'San Juan Surf Beach',
    provinceId: 'la-union',
    provinceName: 'La Union',
    regionId: 'region-1',
    cityId: 'san-juan',
    categoryId: 'beaches',
    heroImageUrl: AppImages.siargaoCloud9,
    galleryImageUrls: [AppImages.siargaoCloud9, AppImages.boracayBeach, AppImages.turquoiseWater],
    rating: 0,
    reviewCount: 0,
    shortDescription: "The surf town of Northern Luzon, lined with cafes and board rentals.",
    longDescription:
        'The beach at Urbiztondo in San Juan is the surfing capital of Northern Luzon, with '
        'consistent, beginner-friendly waves and surf schools right on the sand. Away from the '
        'water, the strip behind the beach has grown into a lively weekend town of coffee shops, '
        'hostels and restaurants that draws crowds up from Manila.',
    entranceFee: 'Free beach access; surf lessons and board rentals priced by the hour',
    bestTimeToVisit: 'October – March for the most consistent swells',
    travelTips: [
      'First-timers should book a lesson — instructors wait along the beachfront.',
      'Weekends get crowded; come midweek for emptier waves.',
      'Stay for sunset, then walk the strip for dinner.',
    ],
    highlights: const ['Beginner-friendly surfing', 'Sunset on the beach', 'Cafe and food strip'],
    nearbyDestinationIds: const ['hundred-islands'],
    latitude: 16.6600,
    longitude: 120.3220,
    openingHours: 'Open 24 hours',
  ),

  // ---- Region II — Cagayan Valley ----
  Destination(
    id: 'basco-lighthouse',
    name: 'Basco Lighthouse',
    provinceId: 'batanes',
    provinceName: 'Batanes',
    regionId: 'region-2',
    cityId: 'basco',
    categoryId: 'nature',
    heroImageUrl: AppImages.greenValley,
    galleryImageUrls: [AppImages.greenValley, AppImages.mountainSunrise, AppImages.turquoiseWater],
    rating: 0,
    reviewCount: 0,
    shortDescription: 'A hilltop lighthouse above Basco with sweeping views of sea and pasture.',
    longDescription:
        'Standing on the Naidi Hills just outside the capital, the Basco Lighthouse is the most '
        'recognizable landmark of Batanes. From its base, rolling green pastures drop away to the '
        'sea on one side and the town of Basco on the other, with Mount Iraya rising behind. It '
        'is the classic spot to watch the sun set over the West Philippine Sea.',
    entranceFee: 'Free; visitors to Batanes pay a one-time provincial environmental fee',
    bestTimeToVisit: 'March – June for the calmest weather',
    travelTips: [
      'It is walkable or a short bike ride from Basco town proper.',
      'Winds are strong on the hills — bring a light jacket even in summer.',
      'Flights to Basco are weather-dependent, so keep a buffer day in your itinerary.',
    ],
    highlights: const ['Sunset viewpoint', 'Rolling Naidi Hills', 'Views of Mount Iraya'],
    latitude: 20.4530,
    longitude: 121.9620,
    openingHours: 'Grounds open 24 hours',
  ),
  Destination(
    id: 'callao-cave',
    name: 'Callao Cave',
    provinceId: 'cagayan',
    provinceName: 'Cagayan',
    regionId: 'region-2',
    cityId: 'penablanca',
    categoryId: 'nature',
    heroImageUrl: AppImages.palawanCliffs,
    galleryImageUrls: [AppImages.palawanCliffs, AppImages.boatOnLagoon, AppImages.greenValley],
    rating: 0,
    reviewCount: 0,
    shortDescription: 'A seven-chamber cave with a sunlit chapel built inside its first hall.',
    longDescription:
        'Callao Cave in Peñablanca is a limestone cave of seven chambers, the first of which holds '
        'a small chapel lit by a natural skylight in the roof. The cave is also an important '
        'archaeological site, where remains of the early human species Homo luzonensis were found. '
        'Below it, boats cruise the Pinacanauan River past limestone cliffs.',
    entranceFee: 'Entrance and guide fees collected on site',
    bestTimeToVisit: 'November – May; midday for light beams in the chapel chamber',
    travelTips: [
      'The cave mouth is reached by a long flight of concrete steps — wear comfortable shoes.',
      'Stay until dusk for the river cruise to watch bats leave the nearby caves.',
      'It is about a 30–45 minute drive from Tuguegarao City.',
    ],
    highlights: const ['Chapel chamber skylight', 'Pinacanauan River cruise', 'Evening bat flight'],
    latitude: 17.7033,
    longitude: 121.8238,
  ),
  Destination(
    id: 'tumauini-church',
    name: 'Tumauini Church',
    provinceId: 'isabela',
    provinceName: 'Isabela',
    regionId: 'region-2',
    cityId: 'tumauini',
    categoryId: 'historical',
    heroImageUrl: AppImages.vigenChurch,
    galleryImageUrls: [AppImages.vigenChurch, AppImages.intramurosWalls, AppImages.calleCrisologo],
    rating: 0,
    reviewCount: 0,
    shortDescription: 'An ornate red-brick church with a unique cylindrical bell tower.',
    longDescription:
        'The San Matias Parish Church in Tumauini is considered the finest brick church in the '
        'Cagayan Valley. Built in the 18th century, its facade is covered in molded clay bricks '
        'pressed with flowers, saints and garlands, and its round, tiered bell tower is often '
        'compared to a wedding cake. It is a declared National Cultural Treasure.',
    entranceFee: 'Free; donations welcome',
    bestTimeToVisit: 'November – February for cooler weather',
    travelTips: [
      'Look closely at the facade — many bricks are individually numbered and decorated.',
      'Dress modestly and avoid touring during Mass.',
      'It sits right along the highway between Ilagan and Tuguegarao, an easy stopover.',
    ],
    highlights: const ['Ornamental brickwork', 'Cylindrical bell tower', 'National Cultural Treasure'],
    nearbyDestinationIds: const ['callao-cave'],
    latitude: 17.2754,
    longitude: 121.8071,
    openingHours: 'Open daily during church hours',
  ),
  Destination(
    id: 'capisaan-cave',
    name: 'Capisaan Cave System',
    provinceId: 'nueva-vizcaya',
    provinceName: 'Nueva Vizcaya',
    regionId: 'region-2',
    cityId: 'kasibu',
    categoryId: 'nature',
    heroImageUrl: AppImages.jungleWaterfall,
    galleryImageUrls: [AppImages.jungleWaterfall, AppImages.palawanCliffs, AppImages.greenValley],
    rating: 0,
    reviewCount: 0,
    isHiddenGem: true,
    shortDescription: 'One of the longest cave systems in the country, with a river running through.',
    longDescription:
        'The Capisaan Cave System in Kasibu stretches for several kilometers beneath the hills of '
        'Nueva Vizcaya, making it one of the longest caves in the Philippines. A subterranean river '
        'runs through much of it, so exploring means wading and swimming between chambers of rare '
        'calcite formations. It is a favorite among local spelunkers but still sees few tourists.',
    entranceFee: 'Entrance and mandatory guide fees collected at the barangay',
    bestTimeToVisit: 'December – May; the cave floods in the rainy season',
    travelTips: [
      'Guides are mandatory and provide helmets and lamps.',
      'You will get wet — wear quick-dry clothes and shoes with grip.',
      "Pick up citrus on the way; Kasibu is the province's fruit-growing town.",
    ],
    highlights: const ['Underground river trek', 'Rare calcite formations', 'Guided spelunking'],
  ),
  Destination(
    id: 'governors-rapids',
    name: "Governor's Rapids",
    provinceId: 'quirino',
    provinceName: 'Quirino',
    regionId: 'region-2',
    cityId: 'maddela',
    categoryId: 'nature',
    heroImageUrl: AppImages.boatOnLagoon,
    galleryImageUrls: [AppImages.boatOnLagoon, AppImages.palawanCliffs, AppImages.greenValley],
    rating: 0,
    reviewCount: 0,
    isHiddenGem: true,
    shortDescription: 'A river gorge of tall limestone walls explored by motorized boat.',
    longDescription:
        "Governor's Rapids in Maddela is a scenic stretch of the upper Cagayan River where the "
        'water cuts between sheer, gray limestone cliffs. Boatmen take visitors upstream through '
        'the gorge to swimming spots and small caves, and river tubing is offered when conditions '
        'allow. It is the signature attraction of landlocked Quirino province.',
    entranceFee: 'Boat rental charged per group; small environmental fee',
    bestTimeToVisit: 'December – May for clearer, calmer water',
    travelTips: [
      'Life vests are provided — wear them, the current is strong in places.',
      'Avoid visiting right after heavy rain, when the river turns brown and fast.',
      'Bring your own food; facilities at the river are basic.',
    ],
    highlights: const ['Limestone gorge boat ride', 'River tubing', 'Riverside swimming'],
  ),

  // ---- Region III — Central Luzon ----
  Destination(
    id: 'sabang-beach-baler',
    name: 'Sabang Beach',
    provinceId: 'aurora',
    provinceName: 'Aurora',
    regionId: 'region-3',
    cityId: 'baler',
    categoryId: 'beaches',
    heroImageUrl: AppImages.siargaoCloud9,
    galleryImageUrls: [AppImages.siargaoCloud9, AppImages.turquoiseWater, AppImages.boracayBeach],
    rating: 0,
    reviewCount: 0,
    shortDescription: "Baler's long gray-sand surf beach, the birthplace of Philippine surfing.",
    longDescription:
        'Sabang Beach is a long, gently curving stretch of gray sand facing the Pacific in the town '
        'of Baler, widely regarded as the birthplace of surfing in the Philippines. Its sandy '
        'bottom and steady waves make it one of the best places in the country to learn, and the '
        'beachfront is lined with surf schools, board rentals and small resorts.',
    entranceFee: 'Free beach access; surf lessons and board rentals priced by the hour',
    bestTimeToVisit: 'October – February for bigger swells; March – June for calmer learner waves',
    travelTips: [
      'Book a one-hour lesson with an accredited instructor if it is your first time.',
      'The drive from Manila takes 5–6 hours — an overnight bus saves a day.',
      "Add Ditumabo (Mother) Falls and the centuries-old balete tree for a full Baler loop.",
    ],
    highlights: const ['Beginner surf lessons', 'Pacific sunrise', 'Ditumabo Falls side trip'],
    latitude: 15.7600,
    longitude: 121.5670,
    openingHours: 'Open 24 hours',
  ),
  Destination(
    id: 'mount-samat-shrine',
    name: 'Mount Samat National Shrine',
    provinceId: 'bataan',
    provinceName: 'Bataan',
    regionId: 'region-3',
    cityId: 'pilar',
    categoryId: 'historical',
    heroImageUrl: AppImages.mountainSunrise,
    galleryImageUrls: [AppImages.mountainSunrise, AppImages.greenValley, AppImages.intramurosWalls],
    rating: 0,
    reviewCount: 0,
    shortDescription: 'A towering memorial cross honoring the soldiers who defended Bataan.',
    longDescription:
        'The Dambana ng Kagitingan (Shrine of Valor) crowns Mount Samat in Pilar, commemorating '
        'the Filipino and American soldiers who fought in the Battle of Bataan in 1942. A marble '
        'colonnade with a war museum sits below the giant Memorial Cross, and an elevator carries '
        'visitors up to a viewing gallery in its arms overlooking the peninsula and Manila Bay.',
    entranceFee: 'Minimal entrance fee collected at the gate',
    bestTimeToVisit: 'November – May; mornings for the clearest views',
    travelTips: [
      'Expect big crowds around April 9, Araw ng Kagitingan (Day of Valor).',
      'Bring a jacket — it gets windy and cool at the top.',
      'Allow time for the underground museum beneath the colonnade.',
    ],
    highlights: const ['Memorial Cross viewing gallery', 'World War II museum', 'Views of Manila Bay'],
    latitude: 14.6058,
    longitude: 120.5089,
  ),
  Destination(
    id: 'barasoain-church',
    name: 'Barasoain Church',
    provinceId: 'bulacan',
    provinceName: 'Bulacan',
    regionId: 'region-3',
    cityId: 'malolos',
    categoryId: 'historical',
    heroImageUrl: AppImages.vigenChurch,
    galleryImageUrls: [AppImages.vigenChurch, AppImages.calleCrisologo, AppImages.intramurosWalls],
    rating: 0,
    reviewCount: 0,
    shortDescription: 'The church where the First Philippine Republic was born.',
    longDescription:
        'Barasoain Church in Malolos is one of the most historically important buildings in the '
        'country. The Malolos Congress convened here in 1898 to draft the first Philippine '
        'constitution, and the First Philippine Republic was inaugurated on this site in January '
        '1899. A museum in the adjoining convent tells the story of those events.',
    entranceFee: 'Free; donations welcome',
    bestTimeToVisit: 'Year-round; weekday mornings are quietest',
    travelTips: [
      'Visit the museum in the old convent beside the church.',
      'Walk on to the Malolos heritage district for its ancestral houses.',
      'Dress modestly — it remains an active parish.',
    ],
    highlights: const ['Site of the Malolos Congress', 'Convent museum', 'Malolos heritage houses'],
    nearbyDestinationIds: const ['intramuros'],
    latitude: 14.8466,
    longitude: 120.8127,
    openingHours: 'Open daily during church hours',
  ),
  Destination(
    id: 'minalungao-national-park',
    name: 'Minalungao National Park',
    provinceId: 'nueva-ecija',
    provinceName: 'Nueva Ecija',
    regionId: 'region-3',
    cityId: 'general-tinio',
    categoryId: 'nature',
    heroImageUrl: AppImages.palawanCliffs,
    galleryImageUrls: [AppImages.palawanCliffs, AppImages.boatOnLagoon, AppImages.greenValley],
    rating: 0,
    reviewCount: 0,
    shortDescription: 'An emerald river flowing between white limestone walls.',
    longDescription:
        'Minalungao National Park in General Tinio protects a stretch of the Peñaranda River '
        'where clear green water runs between tall white limestone formations at the foot of the '
        'Sierra Madre. Visitors drift downriver on bamboo rafts, jump from the rocks, explore a '
        'small cave, or climb the stairway to a hilltop cross for a view of the whole gorge.',
    entranceFee: 'Environmental fee at the gate; raft and cottage rentals extra',
    bestTimeToVisit: 'December – May, when the river runs clear green',
    travelTips: [
      'Weekends are busy with day-trippers — arrive early for a raft.',
      'The river turns brown after rain, so check the weather first.',
      'Bring your own food; cooking by the river is a local tradition.',
    ],
    highlights: const ['Bamboo rafting', 'Limestone cliff jumping', 'Hilltop cross viewpoint'],
    latitude: 15.2987,
    longitude: 121.1221,
  ),
  Destination(
    id: 'bacolor-sunken-church',
    name: 'San Guillermo Church',
    provinceId: 'pampanga',
    provinceName: 'Pampanga',
    regionId: 'region-3',
    cityId: 'bacolor',
    categoryId: 'historical',
    heroImageUrl: AppImages.vigenChurch,
    galleryImageUrls: [AppImages.vigenChurch, AppImages.intramurosWalls, AppImages.calleCrisologo],
    rating: 0,
    reviewCount: 0,
    shortDescription: "Bacolor's half-buried church, a survivor of the Pinatubo lahar flows.",
    longDescription:
        'The San Guillermo Parish Church in Bacolor was buried to half its height by lahar flows '
        'in the years after the 1991 eruption of Mount Pinatubo. Rather than abandon it, the '
        'townspeople dug out the altar and retablo and raised them to the new floor level, so '
        'today worshippers enter through what used to be the upper windows.',
    entranceFee: 'Free; donations welcome',
    bestTimeToVisit: 'Year-round',
    travelTips: [
      'Step into the small museum beside the church for photos from the lahar years.',
      'Combine with a Kapampangan food trip in nearby San Fernando or Angeles.',
      'Dress modestly and avoid touring during Mass.',
    ],
    highlights: const ['Half-buried church nave', 'Restored gilded retablo', 'Lahar history museum'],
    latitude: 15.0003,
    longitude: 120.6483,
    openingHours: 'Open daily during church hours',
  ),
  Destination(
    id: 'mount-pinatubo-crater',
    name: 'Mount Pinatubo Crater Lake',
    provinceId: 'tarlac',
    provinceName: 'Tarlac',
    regionId: 'region-3',
    cityId: 'capas',
    categoryId: 'mountains',
    heroImageUrl: AppImages.mountainSunrise,
    galleryImageUrls: [AppImages.mountainSunrise, AppImages.turquoiseWater, AppImages.greenValley],
    rating: 0,
    reviewCount: 0,
    shortDescription: 'A blue-green lake in the crater left by the 1991 eruption.',
    longDescription:
        'The 1991 eruption of Mount Pinatubo was one of the largest of the 20th century, and the '
        'crater it left behind has since filled with a strikingly blue-green lake. The usual route '
        'starts in Santa Juliana, Capas, with a 4x4 ride across a wide valley of ash and lahar '
        'followed by a hike up a stream bed to the crater rim.',
    entranceFee: 'Sold as packages covering the 4x4, guide and permits — rates vary by group size',
    bestTimeToVisit: 'November – May; treks are suspended in bad weather',
    travelTips: [
      'Book through an accredited operator and start before sunrise to avoid the heat.',
      'Swimming in the crater lake is not allowed.',
      'Bring sun protection and a face covering — the valley is dusty and has no shade.',
    ],
    highlights: const ['4x4 ride across the lahar valley', 'Crater rim viewpoint', 'Aeta community visit'],
    nearbyDestinationIds: const ['bacolor-sunken-church'],
    latitude: 15.1417,
    longitude: 120.3500,
  ),
  Destination(
    id: 'anawangin-cove',
    name: 'Anawangin Cove',
    provinceId: 'zambales',
    provinceName: 'Zambales',
    regionId: 'region-3',
    cityId: 'san-antonio',
    categoryId: 'beaches',
    heroImageUrl: AppImages.tropicalIslandAerial,
    galleryImageUrls: [AppImages.tropicalIslandAerial, AppImages.turquoiseWater, AppImages.boatOnLagoon],
    rating: 0,
    reviewCount: 0,
    shortDescription: 'A crescent of ash-white sand backed by pine-like agoho trees.',
    longDescription:
        'Anawangin Cove is a sheltered beach in San Antonio whose pale sand is a mix of volcanic '
        'ash from Mount Pinatubo. Rows of agoho trees, which look like pines, grow right up to the '
        'shore, giving the cove a look unlike any other Philippine beach. There are no resorts — '
        'only campsites — and it is reached by boat from Pundaquit.',
    entranceFee: 'Entrance and camping fees at the cove; boat hire from Pundaquit priced per boat',
    bestTimeToVisit: 'November – May for calm seas',
    travelTips: [
      'There is little to no mobile signal or electricity — come prepared to camp.',
      'Island-hop to Capones and Camara islands on the same boat hire.',
      'Hike the hill at the end of the beach for the classic view of the cove.',
    ],
    highlights: const ['Beach camping', 'Agoho tree groves', 'Capones Island lighthouse trip'],
    latitude: 14.8790,
    longitude: 120.0700,
  ),

  // ---- Region IV-A — CALABARZON ----
  Destination(
    id: 'taal-heritage-town',
    name: 'Taal Heritage Town',
    provinceId: 'batangas',
    provinceName: 'Batangas',
    regionId: 'region-4a',
    cityId: 'taal',
    categoryId: 'historical',
    heroImageUrl: AppImages.calleCrisologo,
    galleryImageUrls: [AppImages.calleCrisologo, AppImages.vigenChurch, AppImages.jeepneyStreet],
    rating: 0,
    reviewCount: 0,
    shortDescription: 'A hillside town of ancestral houses crowned by a colossal basilica.',
    longDescription:
        'The town of Taal is one of the best-preserved Spanish-era townscapes in the country, '
        'with streets of ancestral houses, several of them open as museums. Above them stands the '
        'Basilica of Saint Martin of Tours, widely described as the largest Catholic church in '
        'Asia. Taal is also known for hand-embroidered barong cloth and balisong knives.',
    entranceFee: 'Basilica is free; ancestral house museums charge small fees',
    bestTimeToVisit: 'December – May; mornings before the midday heat',
    travelTips: [
      'Explore on foot — most heritage houses are within a few blocks of the basilica.',
      'Climb the basilica bell tower for a view toward Balayan Bay.',
      'Shop for barong embroidery at the public market.',
    ],
    highlights: const ['Taal Basilica', 'Ancestral house museums', 'Barong embroidery market'],
    latitude: 13.8807,
    longitude: 120.9248,
  ),
  Destination(
    id: 'aguinaldo-shrine',
    name: 'Aguinaldo Shrine',
    provinceId: 'cavite',
    provinceName: 'Cavite',
    regionId: 'region-4a',
    cityId: 'kawit',
    categoryId: 'historical',
    heroImageUrl: AppImages.intramurosWalls,
    galleryImageUrls: [AppImages.intramurosWalls, AppImages.calleCrisologo, AppImages.jeepneyStreet],
    rating: 0,
    reviewCount: 0,
    shortDescription: 'The mansion where Philippine independence was proclaimed in 1898.',
    longDescription:
        'The ancestral home of General Emilio Aguinaldo in Kawit is where Philippine independence '
        'from Spain was proclaimed on June 12, 1898, and where the national flag was first formally '
        'unfurled. Now a national shrine and museum, the mansion is full of secret passages, period '
        "furniture and memorabilia, and Aguinaldo's tomb lies in the garden behind it.",
    entranceFee: 'Free',
    bestTimeToVisit: 'Year-round; June 12 for Independence Day ceremonies',
    travelTips: [
      'Museums like this are commonly closed on Mondays — check the schedule first.',
      'Ask the guides to point out the hidden compartments and passages.',
      'It is under an hour from Manila outside rush hour.',
    ],
    highlights: const ['Independence balcony', 'House museum tour', "Aguinaldo's tomb and garden"],
    nearbyDestinationIds: const ['intramuros'],
    latitude: 14.4450,
    longitude: 120.9069,
  ),
  Destination(
    id: 'pagsanjan-falls',
    name: 'Pagsanjan Falls',
    provinceId: 'laguna',
    provinceName: 'Laguna',
    regionId: 'region-4a',
    categoryId: 'nature',
    heroImageUrl: AppImages.jungleWaterfall,
    galleryImageUrls: [AppImages.jungleWaterfall, AppImages.boatOnLagoon, AppImages.tinuyanFalls],
    rating: 0,
    reviewCount: 0,
    shortDescription: 'A powerful gorge waterfall reached by an upriver canoe ride.',
    longDescription:
        'Pagsanjan Falls, also known as Cavinti Falls, is one of the most famous waterfalls in the '
        'Philippines. The classic way to reach it is "shooting the rapids": two boatmen paddle and '
        'haul a narrow canoe upstream through a deep, jungle-walled gorge. At the end, a bamboo '
        'raft pulls visitors under the falls and into the cave behind the curtain of water.',
    entranceFee: 'Boat ride priced per person at regulated rates; raft ride extra',
    bestTimeToVisit: 'December – May; water is strongest just after the rainy season',
    travelTips: [
      'Book the boat ride through your resort or the municipal tourism office.',
      'You will get soaked — waterproof your phone and bring a change of clothes.',
      'An alternative hiking route goes down from Cavinti via steep steel stairs.',
    ],
    highlights: const ['Shooting the rapids', 'Raft ride under the falls', "Devil's Cave"],
    latitude: 14.2626,
    longitude: 121.5000,
  ),
  Destination(
    id: 'kamay-ni-hesus',
    name: 'Kamay ni Hesus',
    provinceId: 'quezon',
    provinceName: 'Quezon',
    regionId: 'region-4a',
    cityId: 'lucban',
    categoryId: 'historical',
    heroImageUrl: AppImages.greenValley,
    galleryImageUrls: [AppImages.greenValley, AppImages.vigenChurch, AppImages.mountainSunrise],
    rating: 0,
    reviewCount: 0,
    shortDescription: 'A hilltop pilgrimage shrine in Lucban topped by a giant statue of Christ.',
    longDescription:
        'Kamay ni Hesus is a pilgrimage complex in Lucban built around a healing church and a hill '
        'crowned by a towering statue of the Ascending Christ. More than 300 steps lead to the top, '
        'passing life-size Stations of the Cross, with wide views over the town and the slopes of '
        'Mount Banahaw.',
    entranceFee: 'Free; donations welcome',
    bestTimeToVisit: 'Year-round; expect very large crowds during Holy Week',
    travelTips: [
      'Climb early in the morning or late afternoon to avoid the heat.',
      'Try pancit habhab and Lucban longganisa in town afterwards.',
      'Visit in mid-May to catch the Pahiyas Festival.',
    ],
    highlights: const ['Ascending Christ statue', 'Stations of the Cross climb', 'Views of Mount Banahaw'],
    nearbyDestinationIds: const ['pagsanjan-falls'],
    latitude: 14.1050,
    longitude: 121.5620,
  ),
  Destination(
    id: 'hinulugang-taktak',
    name: 'Hinulugang Taktak',
    provinceId: 'rizal',
    provinceName: 'Rizal',
    regionId: 'region-4a',
    cityId: 'antipolo',
    categoryId: 'nature',
    heroImageUrl: AppImages.tinuyanFalls,
    galleryImageUrls: [AppImages.tinuyanFalls, AppImages.jungleWaterfall, AppImages.greenValley],
    rating: 0,
    reviewCount: 0,
    shortDescription: "Antipolo's storied waterfall park, an easy escape from Manila.",
    longDescription:
        'Hinulugang Taktak is a protected landscape in Antipolo built around a waterfall long '
        'celebrated in Filipino folk song. The park around it has been rehabilitated with '
        'walkways, picnic areas, a hanging bridge and a swimming pool, making it a convenient '
        'half-day nature break close to Metro Manila.',
    entranceFee: 'Free admission — registration at the gate',
    bestTimeToVisit: 'July – December, when the falls are fullest',
    travelTips: [
      'Swimming is allowed in the pool only, not in the falls basin.',
      'Combine with Antipolo Cathedral and Pinto Art Museum nearby.',
      'Buy suman and kasoy from the vendors — classic Antipolo pasalubong.',
    ],
    highlights: const ['Waterfall view deck', 'Hanging bridge', 'Picnic grounds'],
    nearbyDestinationIds: const ['intramuros'],
    latitude: 14.5947,
    longitude: 121.1675,
  ),

  // ---- Region IV-B — MIMAROPA ----
  Destination(
    id: 'poctoy-white-beach',
    name: 'Poctoy White Beach',
    provinceId: 'marinduque',
    provinceName: 'Marinduque',
    regionId: 'region-4b',
    cityId: 'torrijos',
    categoryId: 'beaches',
    heroImageUrl: AppImages.boracayBeach,
    galleryImageUrls: [AppImages.boracayBeach, AppImages.turquoiseWater, AppImages.tropicalIslandAerial],
    rating: 0,
    reviewCount: 0,
    shortDescription: "Marinduque's most popular beach, with Mount Malindig on the horizon.",
    longDescription:
        'Poctoy White Beach in Torrijos is a long stretch of pale sand and clear, calm water on the '
        'eastern coast of Marinduque. The cone of Mount Malindig rises across the bay, and simple '
        'cottages and small resorts line the shore. It is a relaxed, local alternative to the '
        "country's busier beach destinations.",
    entranceFee: 'Small entrance fee; cottage rentals extra',
    bestTimeToVisit: 'March – May for the calmest seas',
    travelTips: [
      'Take a boat from nearby Buenavista or Torrijos to Maniwaya Island and its sandbar.',
      'Visit during Holy Week to see the Moriones Festival across the island.',
      'Ferries to Marinduque leave from Lucena (Dalahican Port).',
    ],
    highlights: const ['Calm swimming beach', 'Mount Malindig views', 'Maniwaya Island side trip'],
  ),
  Destination(
    id: 'apo-reef',
    name: 'Apo Reef Natural Park',
    provinceId: 'occidental-mindoro',
    provinceName: 'Occidental Mindoro',
    regionId: 'region-4b',
    cityId: 'sablayan',
    categoryId: 'beaches',
    heroImageUrl: AppImages.tropicalIslandAerial,
    galleryImageUrls: [AppImages.tropicalIslandAerial, AppImages.turquoiseWater, AppImages.boatOnLagoon],
    rating: 0,
    reviewCount: 0,
    isHiddenGem: true,
    shortDescription: 'The largest coral reef system in the Philippines, off Sablayan.',
    longDescription:
        "Apo Reef is the largest contiguous coral reef system in the Philippines and one of the "
        'largest in the world. Lying in open sea a few hours by boat from Sablayan, the protected '
        'park is prized by divers for its walls, sharks, rays and sea turtles. Non-divers can '
        'snorkel the shallows, walk the mangrove boardwalk and climb the lighthouse on Apo Island.',
    entranceFee: 'Park fees for snorkelers and divers; boat chartered from Sablayan',
    bestTimeToVisit: 'March – June for the calmest crossing and best visibility',
    travelTips: [
      'Arrange permits and boats through the Sablayan tourism office.',
      'Facilities on the island are very basic — overnight stays mean camping.',
      'The crossing can be rough outside summer; bring seasickness tablets.',
    ],
    highlights: const ['Wall diving', 'Sea turtle encounters', 'Lighthouse and mangrove lagoon'],
    latitude: 12.6617,
    longitude: 120.4144,
  ),
  Destination(
    id: 'white-beach-puerto-galera',
    name: 'White Beach, Puerto Galera',
    provinceId: 'oriental-mindoro',
    provinceName: 'Oriental Mindoro',
    regionId: 'region-4b',
    cityId: 'puerto-galera',
    categoryId: 'beaches',
    heroImageUrl: AppImages.boracayBeach,
    galleryImageUrls: [AppImages.boracayBeach, AppImages.boatOnLagoon, AppImages.turquoiseWater],
    rating: 0,
    reviewCount: 0,
    shortDescription: 'A lively beach strip a short ferry ride from Batangas.',
    longDescription:
        "White Beach is the busiest and most developed stretch of sand in Puerto Galera, one of "
        "the closest beach getaways to Manila. Restaurants, bars and small hotels line the "
        'shore, and evenings bring fire dancers and live music. The surrounding bays are known '
        'for some of the best scuba diving and snorkeling near Luzon.',
    entranceFee: 'Free beach access; environmental user fee collected on arrival',
    bestTimeToVisit: 'November – May, the dry season',
    travelTips: [
      'Ferries leave from Batangas Port; the last trips are in the late afternoon.',
      'For quieter sand, take a tricycle to Aninuan or Talipanan Beach next door.',
      'Book a snorkeling trip to the Coral Garden and giant clams.',
    ],
    highlights: const ['Beachfront nightlife', 'Coral Garden snorkeling', 'Tamaraw Falls side trip'],
    latitude: 13.5040,
    longitude: 120.9030,
    openingHours: 'Open 24 hours',
  ),
  Destination(
    id: 'bonbon-beach',
    name: 'Bonbon Beach',
    provinceId: 'romblon',
    provinceName: 'Romblon',
    regionId: 'region-4b',
    cityId: 'romblon',
    categoryId: 'beaches',
    heroImageUrl: AppImages.turquoiseWater,
    galleryImageUrls: [AppImages.turquoiseWater, AppImages.tropicalIslandAerial, AppImages.boracayBeach],
    rating: 0,
    reviewCount: 0,
    isHiddenGem: true,
    shortDescription: 'A quiet white beach with a sandbar leading to a small island.',
    longDescription:
        'Bonbon Beach lies a short ride from Romblon town on Romblon Island. Its fine white sand '
        'narrows into a long sandbar that, at low tide, lets you walk across shallow water to '
        'neighboring Bang-og Island. With no resorts on the sand and few visitors, it remains one '
        'of the most unspoiled beaches in the region.',
    entranceFee: 'Small entrance fee collected at the access path',
    bestTimeToVisit: 'March – May; time your visit for low tide',
    travelTips: [
      'Check the tide table — the sandbar only appears fully at low tide.',
      'Bring water and snacks; there are no shops on the beach.',
      'Romblon town is the place to buy locally quarried marble souvenirs.',
    ],
    highlights: const ['Low-tide sandbar walk', 'Undeveloped white sand', 'Clear shallow water'],
  ),

  // ---- Region V — Bicol Region ----
  Destination(
    id: 'calaguas-islands',
    name: 'Calaguas Islands',
    provinceId: 'camarines-norte',
    provinceName: 'Camarines Norte',
    regionId: 'region-5',
    cityId: 'vinzons',
    categoryId: 'beaches',
    heroImageUrl: AppImages.tropicalIslandAerial,
    galleryImageUrls: [AppImages.tropicalIslandAerial, AppImages.boracayBeach, AppImages.turquoiseWater],
    rating: 0,
    reviewCount: 0,
    isHiddenGem: true,
    shortDescription: 'Remote islands with a long, powdery beach and almost no development.',
    longDescription:
        'The Calaguas group lies off the coast of Camarines Norte, and its star is Mahabang '
        'Buhangin on Tinaga Island — a long sweep of fine white sand and clear turquoise water '
        'backed by grassy hills. Getting there takes a boat ride of around two hours across open '
        'sea, and most visitors camp on the beach.',
    entranceFee: 'Environmental fee per visitor; boats chartered from Vinzons or Paracale',
    bestTimeToVisit: 'March – June for calmer seas',
    travelTips: [
      'The crossing can be rough — travel in the morning and waterproof everything.',
      'Electricity and signal are limited; bring power banks and cash.',
      'Hike the hill behind the beach for a view over the whole cove.',
    ],
    highlights: const ['Mahabang Buhangin beach', 'Beach camping', 'Hilltop viewpoint'],
    latitude: 14.4500,
    longitude: 122.9167,
  ),
  Destination(
    id: 'caramoan-islands',
    name: 'Caramoan Islands',
    provinceId: 'camarines-sur',
    provinceName: 'Camarines Sur',
    regionId: 'region-5',
    cityId: 'caramoan',
    categoryId: 'beaches',
    heroImageUrl: AppImages.palawanCliffs,
    galleryImageUrls: [AppImages.palawanCliffs, AppImages.elNidoLagoon, AppImages.tropicalIslandAerial],
    rating: 0,
    reviewCount: 0,
    shortDescription: 'Limestone islets, hidden lagoons and sandbars on a rugged peninsula.',
    longDescription:
        'The Caramoan Peninsula is fringed with dozens of limestone islands, white-sand coves and '
        'sandbars that appear only at low tide. Its dramatic scenery has served as a filming '
        'location for several international editions of the TV series Survivor. Island-hopping '
        'boats visit favorites such as Matukad, Lahos and the long Manlawi sandbar.',
    entranceFee: 'Island-hopping priced per boat; environmental fee per visitor',
    bestTimeToVisit: 'March – June for calm seas',
    travelTips: [
      'Getting there takes time — by road from Naga, or by boat from Sabang port.',
      'Start island-hopping early to catch the Manlawi sandbar at low tide.',
      'Bring cash; ATMs in Caramoan town are limited.',
    ],
    highlights: const ['Matukad Island', 'Manlawi sandbar', 'Island-hopping tours'],
    nearbyDestinationIds: const ['mayon-volcano'],
    latitude: 13.7707,
    longitude: 123.8631,
  ),
  Destination(
    id: 'binurong-point',
    name: 'Binurong Point',
    provinceId: 'catanduanes',
    provinceName: 'Catanduanes',
    regionId: 'region-5',
    cityId: 'baras',
    categoryId: 'nature',
    heroImageUrl: AppImages.greenValley,
    galleryImageUrls: [AppImages.greenValley, AppImages.mountainSunrise, AppImages.turquoiseWater],
    rating: 0,
    reviewCount: 0,
    isHiddenGem: true,
    shortDescription: 'Rolling green headlands dropping into the Pacific — best at sunrise.',
    longDescription:
        'Binurong Point in Baras is a windswept headland of grassy hills and sheer rock cliffs '
        'pounded by Pacific waves. A short hike through forest opens onto the ridges, which glow '
        'gold at sunrise. It is the most photographed landscape on the island of Catanduanes.',
    entranceFee: 'Small registration and guide fees',
    bestTimeToVisit: 'March – June; start the hike before dawn',
    travelTips: [
      'A local guide is required and can be hired at the trailhead.',
      'Stay well back from the cliff edges — winds are strong.',
      'Pair it with nearby Puraran Beach, known for its surf break.',
    ],
    highlights: const ['Sunrise hike', 'Pacific cliff views', 'Rolling grass hills'],
  ),
  Destination(
    id: 'buntod-reef',
    name: 'Buntod Reef Marine Sanctuary',
    provinceId: 'masbate',
    provinceName: 'Masbate',
    regionId: 'region-5',
    cityId: 'masbate-city',
    categoryId: 'beaches',
    heroImageUrl: AppImages.turquoiseWater,
    galleryImageUrls: [AppImages.turquoiseWater, AppImages.tropicalIslandAerial, AppImages.boatOnLagoon],
    rating: 0,
    reviewCount: 0,
    isHiddenGem: true,
    shortDescription: 'A white sandbar and protected reef minutes by boat from Masbate City.',
    longDescription:
        'Buntod Reef is a marine sanctuary just off Masbate City, centered on a white sandbar '
        'ringed by mangroves and a healthy coral reef. A short boat ride from the mainland brings '
        'visitors to clear, shallow water ideal for swimming and snorkeling, with simple huts on '
        'the sandbar for shade.',
    entranceFee: 'Small sanctuary fee; boat hire priced per group',
    bestTimeToVisit: 'March – May for the calmest water',
    travelTips: [
      'Go in the morning, when the water is calmest and clearest.',
      'Snorkel only in the designated zones and do not step on the coral.',
      'Visit Masbate in April or May to catch the Rodeo Festival.',
    ],
    highlights: const ['Sandbar swimming', 'Snorkeling over coral', 'Mangrove sanctuary'],
  ),
  Destination(
    id: 'donsol-whale-sharks',
    name: 'Donsol Whale Shark Watching',
    provinceId: 'sorsogon',
    provinceName: 'Sorsogon',
    regionId: 'region-5',
    cityId: 'donsol',
    categoryId: 'nature',
    heroImageUrl: AppImages.boatOnLagoon,
    galleryImageUrls: [AppImages.boatOnLagoon, AppImages.turquoiseWater, AppImages.tropicalIslandAerial],
    rating: 0,
    reviewCount: 0,
    shortDescription: 'Swim alongside wild whale sharks in a regulated, no-feeding encounter.',
    longDescription:
        'The waters off Donsol are one of the best places in the world to see whale sharks, known '
        'locally as butanding, in the wild. Encounters are run by the community under strict '
        'rules: the animals are never fed or touched, and trained spotters guide small groups of '
        'snorkelers. In the evening, river cruises show off trees lit up by fireflies.',
    entranceFee: 'Registration fee per person plus boat hire shared among up to six passengers',
    bestTimeToVisit: 'November – June, with sightings peaking February – May',
    travelTips: [
      'Register and watch the briefing video at the Donsol Visitor Center before boarding.',
      'Sightings are never guaranteed — give yourself two mornings if you can.',
      'Scuba gear and flash photography are not allowed during interactions.',
    ],
    highlights: const ['Whale shark snorkeling', 'Firefly river cruise', 'Community-run ecotourism'],
    nearbyDestinationIds: const ['mayon-volcano'],
    latitude: 12.9083,
    longitude: 123.5981,
  ),

  // ---- Region VI — Western Visayas ----
  Destination(
    id: 'boracay-white-beach',
    name: 'White Beach, Boracay',
    provinceId: 'aklan',
    provinceName: 'Aklan',
    regionId: 'region-6',
    cityId: 'malay',
    categoryId: 'beaches',
    heroImageUrl: AppImages.boracayBeach,
    galleryImageUrls: [AppImages.boracayBeach, AppImages.turquoiseWater, AppImages.tropicalIslandAerial],
    rating: 0,
    reviewCount: 0,
    isFeatured: true,
    shortDescription: 'Four kilometers of powder-white sand and legendary sunsets.',
    longDescription:
        "White Beach is the heart of Boracay and the most famous beach in the Philippines: about "
        'four kilometers of fine, powdery white sand facing calm, shallow turquoise water. The '
        'beach is divided into Stations 1, 2 and 3, running from quieter, wider sand in the north '
        'to the busy central strip of restaurants and shops. Every evening, sailboats called '
        'paraw cross the bay against the sunset.',
    entranceFee: 'Free beach; terminal and environmental fees are paid at the Caticlan jetty port',
    bestTimeToVisit: 'November – May, when the sea on this side is calm',
    travelTips: [
      'Have your hotel booking confirmation ready — it is checked before you board the boat.',
      'Smoking, drinking and littering on the beach itself are prohibited.',
      'Book a paraw sailing trip for sunset, or walk to Station 1 for the widest sand.',
    ],
    highlights: const ['Sunset paraw sailing', "Willy's Rock", 'Station 1 powder sand'],
    latitude: 11.9590,
    longitude: 121.9250,
    openingHours: 'Open 24 hours',
  ),
  Destination(
    id: 'malumpati-cold-spring',
    name: 'Malumpati Cold Spring',
    provinceId: 'antique',
    provinceName: 'Antique',
    regionId: 'region-6',
    cityId: 'pandan',
    categoryId: 'nature',
    heroImageUrl: AppImages.tinuyanFalls,
    galleryImageUrls: [AppImages.tinuyanFalls, AppImages.jungleWaterfall, AppImages.greenValley],
    rating: 0,
    reviewCount: 0,
    isHiddenGem: true,
    shortDescription: 'A brilliantly blue, ice-cold spring pool on the Bugang River.',
    longDescription:
        'Malumpati Cold Spring in Pandan is a natural pool of startlingly clear blue water fed by '
        'the Bugang River, which has repeatedly been recognized as one of the cleanest rivers in '
        'the country. Visitors swim in the shaded pool, ride inner tubes downstream, or hike a '
        "short jungle trail to the spring's source.",
    entranceFee: 'Small entrance fee; tubing and guide fees extra',
    bestTimeToVisit: 'December – May, when the water is clearest',
    travelTips: [
      'The water is genuinely cold — a welcome break on a hot day.',
      'Pandan is about an hour from Caticlan, so it pairs well with a Boracay trip.',
      'Try river tubing down the Bugang for a slower look at the forest.',
    ],
    highlights: const ['Blue spring pool', 'River tubing', 'Trek to the river source'],
    nearbyDestinationIds: const ['boracay-white-beach'],
    latitude: 11.7400,
    longitude: 122.0639,
  ),
  Destination(
    id: 'panay-church',
    name: 'Santa Monica Church',
    provinceId: 'capiz',
    provinceName: 'Capiz',
    regionId: 'region-6',
    cityId: 'panay',
    categoryId: 'historical',
    heroImageUrl: AppImages.vigenChurch,
    galleryImageUrls: [AppImages.vigenChurch, AppImages.intramurosWalls, AppImages.calleCrisologo],
    rating: 0,
    reviewCount: 0,
    shortDescription: 'A coral-stone church housing the largest church bell in the country.',
    longDescription:
        'The Santa Monica Parish Church in the town of Panay, a few kilometers from Roxas City, is '
        'a massive coral-stone church with walls about three meters thick. Its belfry holds the '
        'largest Catholic church bell in the Philippines, cast in the 19th century from sacks of '
        'coins donated by the townspeople. The church is a National Cultural Treasure.',
    entranceFee: 'Free; donations welcome',
    bestTimeToVisit: 'Year-round',
    travelTips: [
      'Ask the caretaker about climbing the belfry to see the great bell up close.',
      'Follow up with a seafood lunch in Roxas City, the "Seafood Capital of the Philippines".',
      'Dress modestly and avoid touring during Mass.',
    ],
    highlights: const ['Giant church bell', 'Coral-stone architecture', 'National Cultural Treasure'],
    latitude: 11.5556,
    longitude: 122.7939,
    openingHours: 'Open daily during church hours',
  ),
  Destination(
    id: 'guisi-lighthouse',
    name: 'Guisi Lighthouse',
    provinceId: 'guimaras',
    provinceName: 'Guimaras',
    regionId: 'region-6',
    cityId: 'nueva-valencia',
    categoryId: 'historical',
    heroImageUrl: AppImages.turquoiseWater,
    galleryImageUrls: [AppImages.turquoiseWater, AppImages.boracayBeach, AppImages.palawanCliffs],
    rating: 0,
    reviewCount: 0,
    shortDescription: 'Spanish-era lighthouse ruins above a golden cove.',
    longDescription:
        'On a headland in Nueva Valencia stand the rusting iron tower and roofless stone quarters '
        'of a Spanish-era lighthouse, slowly being reclaimed by tree roots. Just below the ruins is '
        'Guisi Beach, a small cove of golden sand framed by rock formations, making this one of the '
        'most photogenic corners of Guimaras.',
    entranceFee: 'Small entrance fee at the access road',
    bestTimeToVisit: 'November – May; April – May for mango season',
    travelTips: [
      'The old tower is fragile — admire it from the ground rather than climbing.',
      'Guimaras is a 15-minute pump boat ride from Iloilo City.',
      'Do not leave without trying the famously sweet Guimaras mangoes.',
    ],
    highlights: const ['Lighthouse ruins', 'Guisi Beach cove', 'Guimaras mangoes'],
    nearbyDestinationIds: const ['miagao-church'],
  ),
  Destination(
    id: 'miagao-church',
    name: 'Miagao Church',
    provinceId: 'iloilo',
    provinceName: 'Iloilo',
    regionId: 'region-6',
    cityId: 'miagao',
    categoryId: 'historical',
    heroImageUrl: AppImages.vigenChurch,
    galleryImageUrls: [AppImages.vigenChurch, AppImages.calleCrisologo, AppImages.intramurosWalls],
    rating: 0,
    reviewCount: 0,
    shortDescription: 'A golden fortress church with a facade carved with tropical scenes.',
    longDescription:
        'The Santo Tomas de Villanueva Church in Miagao is a UNESCO World Heritage Site and one of '
        'the finest examples of Filipino Baroque architecture. Built in the late 1700s to double '
        'as a fortress against raiders, its ochre sandstone facade is carved with Saint Christopher '
        'carrying the Christ Child among coconut, papaya and guava trees.',
    entranceFee: 'Free; donations welcome',
    bestTimeToVisit: 'Year-round; late afternoon when the stone glows golden',
    travelTips: [
      'It is about an hour by jeepney or van from Iloilo City.',
      'Stop at the churches of Guimbal and San Joaquin along the same coastal road.',
      'Dress modestly and avoid touring during Mass.',
    ],
    highlights: const ['Carved sandstone facade', 'Fortress bell towers', 'UNESCO World Heritage Site'],
    latitude: 10.6419,
    longitude: 122.2355,
    openingHours: 'Open daily during church hours',
  ),
  Destination(
    id: 'the-ruins-talisay',
    name: 'The Ruins',
    provinceId: 'negros-occidental',
    provinceName: 'Negros Occidental',
    regionId: 'region-6',
    cityId: 'talisay',
    categoryId: 'historical',
    heroImageUrl: AppImages.intramurosWalls,
    galleryImageUrls: [AppImages.intramurosWalls, AppImages.calleCrisologo, AppImages.vigenChurch],
    rating: 0,
    reviewCount: 0,
    shortDescription: "The skeletal remains of a sugar baron's mansion, glowing at sunset.",
    longDescription:
        'The Ruins in Talisay City is what remains of the early-1900s mansion built by sugar baron '
        'Don Mariano Ledesma Lacson in memory of his wife, Maria Braga. The house was burned '
        'during World War II, but its Italianate concrete frame survived and now stands in '
        'landscaped gardens among sugarcane fields, turning gold in the late-afternoon light.',
    entranceFee: 'Entrance fee collected at the gate',
    bestTimeToVisit: 'Year-round; arrive around 4–5 PM for sunset',
    travelTips: [
      'Come before sunset and stay until the lights switch on after dark.',
      'The on-site guides are known for their entertaining retelling of the story.',
      'It is a short ride from Bacolod — pair it with chicken inasal in the city.',
    ],
    highlights: const ['Sunset over the mansion', 'Guided history tour', 'Landscaped gardens'],
    latitude: 10.7102,
    longitude: 122.9833,
  ),

  // ---- Region VII — Central Visayas ----
  Destination(
    id: 'apo-island',
    name: 'Apo Island',
    provinceId: 'negros-oriental',
    provinceName: 'Negros Oriental',
    regionId: 'region-7',
    cityId: 'dauin',
    categoryId: 'beaches',
    heroImageUrl: AppImages.tropicalIslandAerial,
    galleryImageUrls: [AppImages.tropicalIslandAerial, AppImages.turquoiseWater, AppImages.boatOnLagoon],
    rating: 0,
    reviewCount: 0,
    shortDescription: 'A tiny volcanic island where sea turtles graze in the shallows.',
    longDescription:
        'Apo Island, off the southern coast of Negros Oriental, is home to one of the oldest and '
        'most successful community-managed marine sanctuaries in the Philippines. Green sea '
        'turtles feed in waist-deep water just off the beach, and the surrounding reefs are '
        'ranked among the best dive and snorkel sites in the country.',
    entranceFee: 'Marine sanctuary fee per visitor; boat hire priced per group',
    bestTimeToVisit: 'November – May for calm crossings',
    travelTips: [
      'Boats leave from Malatapay in Zamboanguita — go early before the wind picks up.',
      'Keep your distance from the turtles and never touch them.',
      'Use reef-safe sunscreen or wear a rash guard instead.',
    ],
    highlights: const ['Snorkeling with sea turtles', 'Marine sanctuary reefs', 'Island viewpoint hike'],
    latitude: 9.0667,
    longitude: 123.2667,
  ),
  Destination(
    id: 'cambugahay-falls',
    name: 'Cambugahay Falls',
    provinceId: 'siquijor',
    provinceName: 'Siquijor',
    regionId: 'region-7',
    cityId: 'lazi',
    categoryId: 'nature',
    heroImageUrl: AppImages.tinuyanFalls,
    galleryImageUrls: [AppImages.tinuyanFalls, AppImages.jungleWaterfall, AppImages.greenValley],
    rating: 0,
    reviewCount: 0,
    shortDescription: 'Three tiers of turquoise pools with rope swings under the trees.',
    longDescription:
        'Cambugahay Falls in Lazi is a series of three low cascades tumbling into wide, milky '
        'turquoise pools shaded by forest. Rope swings hang over the water and bamboo rafts drift '
        'in the lagoons, making it the most popular swimming spot on the island of Siquijor.',
    entranceFee: 'Small entrance and parking fees; rope swing use charged separately',
    bestTimeToVisit: 'December – May; mornings before the crowds',
    travelTips: [
      'A flight of over a hundred steps leads down to the pools.',
      'Arrive before 9 AM to have the swings nearly to yourself.',
      'Continue on to the Lazi Church and Convent, a few minutes away.',
    ],
    highlights: const ['Rope swings', 'Turquoise swimming pools', 'Lazi Church nearby'],
    nearbyDestinationIds: const ['apo-island'],
    latitude: 9.1380,
    longitude: 123.6270,
  ),

  // ---- Region VIII — Eastern Visayas ----
  Destination(
    id: 'sambawan-island',
    name: 'Sambawan Island',
    provinceId: 'biliran',
    provinceName: 'Biliran',
    regionId: 'region-8',
    cityId: 'maripipi',
    categoryId: 'beaches',
    heroImageUrl: AppImages.tropicalIslandAerial,
    galleryImageUrls: [AppImages.tropicalIslandAerial, AppImages.turquoiseWater, AppImages.palawanCliffs],
    rating: 0,
    reviewCount: 0,
    isHiddenGem: true,
    shortDescription: 'A ridge-backed islet with a classic hilltop view over clear reefs.',
    longDescription:
        'Sambawan is a chain of small, grassy islets off Maripipi, joined by a strip of white '
        'coral sand. A short climb up the central ridge gives a sweeping view of the islets curving '
        'through deep blue water — the signature photo of Biliran province. The reefs just '
        'offshore are a marine sanctuary with good snorkeling and diving.',
    entranceFee: 'Entrance fee per visitor; boat hire priced per group',
    bestTimeToVisit: 'March – June for calm seas',
    travelTips: [
      'Boats leave from Kawayan on the Biliran mainland or from Maripipi.',
      'Overnight stays are possible in basic cottages or tents — bring supplies.',
      'Climb the ridge early or late in the day; there is no shade.',
    ],
    highlights: const ['Ridge viewpoint', 'Coral reef snorkeling', 'Island camping'],
  ),
  Destination(
    id: 'calicoan-island',
    name: 'Calicoan Island',
    provinceId: 'eastern-samar',
    provinceName: 'Eastern Samar',
    regionId: 'region-8',
    cityId: 'guiuan',
    categoryId: 'beaches',
    heroImageUrl: AppImages.siargaoCloud9,
    galleryImageUrls: [AppImages.siargaoCloud9, AppImages.turquoiseWater, AppImages.boracayBeach],
    rating: 0,
    reviewCount: 0,
    isHiddenGem: true,
    shortDescription: 'A Pacific-facing surf island at the southeastern tip of Samar.',
    longDescription:
        'Calicoan Island, connected by road to the town of Guiuan, sits where the Pacific Ocean '
        'meets Leyte Gulf. Its eastern shore, known as ABCD Beach, catches powerful ocean swells '
        'that draw experienced surfers, while the sheltered western side has calm lagoons and '
        'quiet white-sand coves.',
    entranceFee: 'Free beach access',
    bestTimeToVisit: 'April – October for surf; March – May for calm-side swimming',
    travelTips: [
      'The reef break at ABCD Beach is for experienced surfers — ask locals about conditions.',
      'Guiuan is about three hours by van from Tacloban.',
      'Accommodation is limited; book ahead in surf season.',
    ],
    highlights: const ['ABCD Beach surf', 'Pacific sunrise', 'Quiet lagoon coves'],
    latitude: 10.9839,
    longitude: 125.8069,
  ),
  Destination(
    id: 'macarthur-landing-memorial',
    name: 'MacArthur Landing Memorial',
    provinceId: 'leyte',
    provinceName: 'Leyte',
    regionId: 'region-8',
    cityId: 'palo',
    categoryId: 'historical',
    heroImageUrl: AppImages.intramurosWalls,
    galleryImageUrls: [AppImages.intramurosWalls, AppImages.turquoiseWater, AppImages.manilaSkyline],
    rating: 0,
    reviewCount: 0,
    shortDescription: 'Larger-than-life statues marking the 1944 Leyte landing.',
    longDescription:
        'The MacArthur Landing Memorial National Park at Red Beach in Palo marks the spot where '
        'General Douglas MacArthur waded ashore on October 20, 1944, fulfilling his promise to '
        'return and beginning the liberation of the Philippines. Seven larger-than-life bronze '
        'figures stand in a shallow pool facing inland, recreating the famous moment.',
    entranceFee: 'Free',
    bestTimeToVisit: 'Year-round; October 20 for the Leyte Landing anniversary',
    travelTips: [
      'It is a short ride from downtown Tacloban.',
      'Come in the late afternoon for softer light and a sea breeze.',
      'Continue to the San Juanico Bridge to round out a Tacloban day tour.',
    ],
    highlights: const ['Bronze landing statues', 'Red Beach shoreline', 'World War II history'],
    latitude: 11.1722,
    longitude: 125.0122,
    openingHours: 'Open daily',
  ),
  Destination(
    id: 'biri-rock-formations',
    name: 'Biri Rock Formations',
    provinceId: 'northern-samar',
    provinceName: 'Northern Samar',
    regionId: 'region-8',
    cityId: 'biri',
    categoryId: 'nature',
    heroImageUrl: AppImages.palawanCliffs,
    galleryImageUrls: [AppImages.palawanCliffs, AppImages.turquoiseWater, AppImages.greenValley],
    rating: 0,
    reviewCount: 0,
    isHiddenGem: true,
    shortDescription: 'Colossal wave-carved rock formations facing the open Pacific.',
    longDescription:
        'On the northern edge of Biri Island, where the San Bernardino Strait meets the Pacific, '
        'waves have sculpted a line of enormous rock formations. Boardwalks cross the mangroves to '
        'reach them, and natural tidal pools form among the rocks, offering calm swimming with the '
        'surf crashing just beyond.',
    entranceFee: 'Small environmental fee; local guide and habal-habal hire extra',
    bestTimeToVisit: 'March – June for calmer seas',
    travelTips: [
      'Boats to Biri leave from the port of Lavezares.',
      'Visit at low tide to walk out to the formations and swim in the tidal pools.',
      'Wear sturdy sandals — the rock is sharp and uneven.',
    ],
    highlights: const ['Magasang and Bel-at rocks', 'Natural tidal pools', 'Mangrove boardwalk'],
    latitude: 12.6700,
    longitude: 124.3800,
  ),
  Destination(
    id: 'sohoton-caves',
    name: 'Sohoton Caves and Natural Bridge',
    provinceId: 'samar',
    provinceName: 'Samar',
    regionId: 'region-8',
    cityId: 'basey',
    categoryId: 'nature',
    heroImageUrl: AppImages.boatOnLagoon,
    galleryImageUrls: [AppImages.boatOnLagoon, AppImages.palawanCliffs, AppImages.jungleWaterfall],
    rating: 0,
    reviewCount: 0,
    shortDescription: 'A river journey to cathedral-like caves and a natural stone bridge.',
    longDescription:
        'The Sohoton Caves and Natural Bridge Park in Basey is reached by boat up a jungle river '
        'lined with limestone cliffs. Guides lead visitors through a cave filled with glittering '
        'stalactites and stalagmites, then by kayak further upstream to paddle beneath a huge '
        'natural stone arch spanning the river.',
    entranceFee: 'Package rates covering boat, guide, lamps and park fees',
    bestTimeToVisit: 'March – June; trips can be cancelled when the river is high',
    travelTips: [
      'Register at the Basey tourism office, which arranges the boat and guides.',
      'Basey is under an hour from Tacloban across the San Juanico Bridge.',
      'Bring home a banig — Basey is known for its woven sedge mats.',
    ],
    highlights: const ['Cave formations tour', 'Kayaking under the natural bridge', 'River boat ride'],
    nearbyDestinationIds: const ['macarthur-landing-memorial'],
    latitude: 11.3583,
    longitude: 125.1584,
  ),
  Destination(
    id: 'limasawa-island',
    name: 'Limasawa Island',
    provinceId: 'southern-leyte',
    provinceName: 'Southern Leyte',
    regionId: 'region-8',
    cityId: 'limasawa',
    categoryId: 'historical',
    heroImageUrl: AppImages.turquoiseWater,
    galleryImageUrls: [AppImages.turquoiseWater, AppImages.tropicalIslandAerial, AppImages.boracayBeach],
    rating: 0,
    reviewCount: 0,
    isHiddenGem: true,
    shortDescription: 'The small island recognized as the site of the first Easter Mass in 1521.',
    longDescription:
        'Limasawa is a small island off the tip of Southern Leyte, officially recognized as the '
        "site of the first Easter Mass in the Philippines, held during Magellan's expedition on "
        'March 31, 1521. A shrine marks the event, and a long stairway climbs to a hilltop cross '
        "with views across the island's quiet beaches and clear water.",
    entranceFee: 'Small shrine and environmental fees',
    bestTimeToVisit: 'March – May; March 31 for the commemoration',
    travelTips: [
      'Boats cross from Padre Burgos; check the return schedule before you go.',
      'Climb the stairway to the cross early, before it gets hot.',
      'Padre Burgos and Sogod Bay are also known for diving.',
    ],
    highlights: const ['First Mass shrine', 'Hilltop cross viewpoint', 'Quiet island beaches'],
    latitude: 9.9078,
    longitude: 125.0750,
  ),

  // ---- Region IX — Zamboanga Peninsula ----
  Destination(
    id: 'rizal-shrine-dapitan',
    name: 'Rizal Shrine, Dapitan',
    provinceId: 'zamboanga-del-norte',
    provinceName: 'Zamboanga del Norte',
    regionId: 'region-9',
    cityId: 'dapitan',
    categoryId: 'historical',
    heroImageUrl: AppImages.greenValley,
    galleryImageUrls: [AppImages.greenValley, AppImages.intramurosWalls, AppImages.turquoiseWater],
    rating: 0,
    reviewCount: 0,
    shortDescription: 'The seaside estate where José Rizal lived in exile from 1892 to 1896.',
    longDescription:
        'The Rizal Park and Shrine in Dapitan preserves the estate where national hero José Rizal '
        'spent four years in exile. During that time he worked as a doctor, teacher, farmer and '
        'engineer for the community. Faithful reconstructions of his bamboo-and-nipa house, clinic '
        'and schoolhouse stand among old trees by the shore, alongside a museum of his belongings.',
    entranceFee: 'Free',
    bestTimeToVisit: 'Year-round; mornings are coolest',
    travelTips: [
      'See the relief map of Mindanao that Rizal built in the Dapitan town plaza.',
      'Museums like this are commonly closed on Mondays — check the schedule first.',
      'Dapitan is a short ride from Dipolog, the nearest airport.',
    ],
    highlights: const ['Reconstructed Casa Residencia', 'Rizal museum', 'Shaded seaside grounds'],
    latitude: 8.6672,
    longitude: 123.4167,
  ),
  Destination(
    id: 'great-santa-cruz-island',
    name: 'Great Santa Cruz Island',
    provinceId: 'zamboanga-del-sur',
    provinceName: 'Zamboanga del Sur',
    regionId: 'region-9',
    cityId: 'zamboanga-city',
    categoryId: 'beaches',
    heroImageUrl: AppImages.tropicalIslandAerial,
    galleryImageUrls: [AppImages.tropicalIslandAerial, AppImages.boracayBeach, AppImages.boatOnLagoon],
    rating: 0,
    reviewCount: 0,
    shortDescription: 'A protected island off Zamboanga City with a rare pink-sand beach.',
    longDescription:
        'Great Santa Cruz Island lies a short boat ride from Zamboanga City and is famous for its '
        'pink-tinged sand, colored by crushed red organ-pipe coral mixed into the white. The island '
        'is a protected area with a strict daily visitor limit, a mangrove lagoon explored by '
        'paddle boat, and colorful vinta sails often seen offshore.',
    entranceFee: 'Entrance, terminal and boat fees paid at the city ferry terminal',
    bestTimeToVisit: 'December – May for calm seas',
    travelTips: [
      'Reserve through the Zamboanga City tourism office — visitor numbers are capped each day.',
      'Visits are day trips only and boats leave in the morning from Paseo del Mar.',
      'Add the mangrove lagoon tour to see stingless jellyfish.',
    ],
    highlights: const ['Pink sand beach', 'Mangrove lagoon tour', 'Vinta boat views'],
    latitude: 6.8653,
    longitude: 122.0625,
    openingHours: 'Morning day trips only',
  ),
  Destination(
    id: 'buluan-island',
    name: 'Buluan Island',
    provinceId: 'zamboanga-sibugay',
    provinceName: 'Zamboanga Sibugay',
    regionId: 'region-9',
    cityId: 'ipil',
    categoryId: 'beaches',
    heroImageUrl: AppImages.turquoiseWater,
    galleryImageUrls: [AppImages.turquoiseWater, AppImages.tropicalIslandAerial, AppImages.boatOnLagoon],
    rating: 0,
    reviewCount: 0,
    isHiddenGem: true,
    shortDescription: 'A small marine-sanctuary island with white sand off the town of Ipil.',
    longDescription:
        'Buluan Island sits in Sibuguey Bay off Ipil, the provincial capital. Ringed by white sand '
        'and a protected coral reef, it is a locally loved spot for swimming, snorkeling and '
        'picnics that still sees very few visitors from outside the region.',
    entranceFee: 'Small sanctuary fee; boat hire from Ipil priced per group',
    bestTimeToVisit: 'March – May for calm water',
    travelTips: [
      'Arrange your boat and visit through the Ipil municipal tourism office.',
      'Bring your own food, water and snorkeling gear.',
      'Check current local travel advisories before planning a trip.',
    ],
    highlights: const ['Marine sanctuary snorkeling', 'White sand picnics', 'Uncrowded island'],
  ),

  // ---- Region X — Northern Mindanao ----
  Destination(
    id: 'dahilayan-adventure-park',
    name: 'Dahilayan Adventure Park',
    provinceId: 'bukidnon',
    provinceName: 'Bukidnon',
    regionId: 'region-10',
    cityId: 'manolo-fortich',
    categoryId: 'mountains',
    heroImageUrl: AppImages.mountainSunrise,
    galleryImageUrls: [AppImages.mountainSunrise, AppImages.greenValley, AppImages.riceTerraces],
    rating: 0,
    reviewCount: 0,
    shortDescription: 'A cool highland park of pine trees and long ziplines.',
    longDescription:
        'Set in the pine-covered foothills of the Mount Kitanglad range in Manolo Fortich, '
        'Dahilayan is a highland adventure park best known for its long dual zipline, which sends '
        'riders flying face-down over the forest. The cool climate, ATV trails and neighboring '
        'forest park make it a favorite family day trip from Cagayan de Oro.',
    entranceFee: 'Pay per ride or activity; package rates available',
    bestTimeToVisit: 'December – May for clear skies; it is cool year-round',
    travelTips: [
      'Bring a jacket — the park sits well above 1,000 meters.',
      'The road passes through vast pineapple plantations, worth a photo stop.',
      'Go on a weekday to skip the zipline queues.',
    ],
    highlights: const ['Long dual zipline', 'Pine forest scenery', 'ATV trails'],
  ),
  Destination(
    id: 'white-island-camiguin',
    name: 'White Island',
    provinceId: 'camiguin',
    provinceName: 'Camiguin',
    regionId: 'region-10',
    cityId: 'mambajao',
    categoryId: 'beaches',
    heroImageUrl: AppImages.tropicalIslandAerial,
    galleryImageUrls: [AppImages.tropicalIslandAerial, AppImages.turquoiseWater, AppImages.boracayBeach],
    rating: 0,
    reviewCount: 0,
    isFeatured: true,
    shortDescription: 'A bare white sandbar facing the volcanoes of Camiguin.',
    longDescription:
        'White Island is an uninhabited sandbar of pure white sand off the coast of Mambajao. '
        'There are no trees or buildings — only sand, clear water, and an uninterrupted view of '
        'Mount Hibok-Hibok and Mount Vulcan rising from the main island. Its shape shifts with the '
        'tides and seasons.',
    entranceFee: 'Boat fare per group plus an environmental fee',
    bestTimeToVisit: 'March – June; go at sunrise',
    travelTips: [
      'Go at sunrise — there is no natural shade and it gets very hot by mid-morning.',
      'Boats take about ten minutes from the Yumbing boat terminal.',
      'Rent an umbrella at the terminal and bring your own water.',
    ],
    highlights: const ['Sandbar sunrise', 'Views of Mount Hibok-Hibok', 'Snorkeling in clear shallows'],
    latitude: 9.2590,
    longitude: 124.6530,
    openingHours: 'Boats run from early morning to late afternoon',
  ),
  Destination(
    id: 'maria-cristina-falls',
    name: 'Maria Cristina Falls',
    provinceId: 'lanao-del-norte',
    provinceName: 'Lanao del Norte',
    regionId: 'region-10',
    cityId: 'iligan',
    categoryId: 'nature',
    heroImageUrl: AppImages.jungleWaterfall,
    galleryImageUrls: [AppImages.jungleWaterfall, AppImages.tinuyanFalls, AppImages.greenValley],
    rating: 0,
    reviewCount: 0,
    shortDescription: 'The twin falls that power much of Mindanao.',
    longDescription:
        'Maria Cristina Falls on the Agus River is the best-known landmark of Iligan, the "City of '
        'Majestic Waterfalls." The river splits around a rock at the brink and drops roughly 98 '
        'meters in two streams, which is why it is called the twin falls. Its flow drives a major '
        'hydroelectric plant, and a nature park provides a viewing deck facing the falls.',
    entranceFee: 'Entrance fee at the nature park; shuttle to the view deck included or extra',
    bestTimeToVisit: 'Year-round; ask locally which days the falls run at full flow',
    travelTips: [
      'The volume of water depends on power plant operations, so ask before you go.',
      'Add Tinago Falls, also in Iligan, for a swim beneath a hidden cascade.',
      'Check current local travel advisories before planning a trip.',
    ],
    highlights: const ['Twin falls view deck', 'Nature park', 'Tinago Falls side trip'],
    latitude: 8.1832,
    longitude: 124.1950,
  ),
  Destination(
    id: 'cotta-fort-ozamiz',
    name: 'Cotta Fort',
    provinceId: 'misamis-occidental',
    provinceName: 'Misamis Occidental',
    regionId: 'region-10',
    cityId: 'ozamiz',
    categoryId: 'historical',
    heroImageUrl: AppImages.intramurosWalls,
    galleryImageUrls: [AppImages.intramurosWalls, AppImages.turquoiseWater, AppImages.vigenChurch],
    rating: 0,
    reviewCount: 0,
    shortDescription: 'An 18th-century Spanish stone fort guarding Panguil Bay.',
    longDescription:
        'The Fuerte de la Concepción y del Triunfo, known locally as Cotta, was built by the '
        'Spanish in 1756 to defend the area around Panguil Bay. Its thick stone walls now enclose '
        'gardens and a small museum, and a venerated image of the Virgin on the outer wall makes '
        'it a pilgrimage site as well as a seaside promenade for the people of Ozamiz.',
    entranceFee: 'Free; small fee for the museum',
    bestTimeToVisit: 'Year-round; late afternoon for the bay breeze',
    travelTips: [
      'Walk the ramparts for views across Panguil Bay.',
      'Visit the shrine of the Birhen sa Cotta on the outer wall.',
      'Stay for sunset along the bayside promenade.',
    ],
    highlights: const ['Stone ramparts', 'Birhen sa Cotta shrine', 'Panguil Bay sunset'],
    latitude: 8.1403,
    longitude: 123.8472,
  ),
  Destination(
    id: 'cdo-whitewater-rafting',
    name: 'Cagayan de Oro River Rafting',
    provinceId: 'misamis-oriental',
    provinceName: 'Misamis Oriental',
    regionId: 'region-10',
    cityId: 'cagayan-de-oro',
    categoryId: 'nature',
    heroImageUrl: AppImages.boatOnLagoon,
    galleryImageUrls: [AppImages.boatOnLagoon, AppImages.jungleWaterfall, AppImages.greenValley],
    rating: 0,
    reviewCount: 0,
    shortDescription: "Year-round whitewater on the river that made CDO the adventure capital.",
    longDescription:
        'Cagayan de Oro is known as the whitewater rafting capital of the Philippines, thanks to '
        'the rapids of the Cagayan de Oro River. Licensed outfitters run trips year-round, from '
        'gentle beginner courses to longer advanced runs, drifting between rapids past forested '
        'canyon walls and small waterfalls.',
    entranceFee: 'Priced per person by course; includes gear, guide and transfers',
    bestTimeToVisit: 'Year-round; rapids are bigger in the rainy months',
    travelTips: [
      'Book with an accredited outfitter — helmets, vests and a safety briefing are standard.',
      'Wear quick-dry clothes and strap-on sandals, and leave valuables behind.',
      'Beginners should choose the basic course, which takes about three hours.',
    ],
    highlights: const ['Whitewater rapids', 'River canyon scenery', 'Beginner to advanced courses'],
    nearbyDestinationIds: const ['dahilayan-adventure-park'],
  ),

  // ---- Region XI — Davao Region ----
  Destination(
    id: 'mainit-hot-springs',
    name: 'Mainit Hot Springs',
    provinceId: 'davao-de-oro',
    provinceName: 'Davao de Oro',
    regionId: 'region-11',
    cityId: 'nabunturan',
    categoryId: 'nature',
    heroImageUrl: AppImages.jungleWaterfall,
    galleryImageUrls: [AppImages.jungleWaterfall, AppImages.greenValley, AppImages.tinuyanFalls],
    rating: 0,
    reviewCount: 0,
    isHiddenGem: true,
    shortDescription: 'Steaming sulfur springs and warm cascades in a forest park.',
    longDescription:
        'The Mainit Hot Springs Protected Landscape in Nabunturan is a forested park where hot, '
        'sulfur-rich water rises from the ground and runs over yellow-stained rock into a cool '
        'river. Visitors soak where the warm and cold flows meet, surrounded by steam vents and '
        'thick greenery.',
    entranceFee: 'Small entrance fee',
    bestTimeToVisit: 'Year-round; early morning when the steam is thickest',
    travelTips: [
      'Test the water before stepping in — some pools are too hot to bathe in.',
      'Remove silver jewelry; sulfur will tarnish it.',
      'Nabunturan is about two hours by bus from Davao City.',
    ],
    highlights: const ['Natural hot spring soak', 'Sulfur cascades', 'Forest picnic areas'],
    latitude: 7.4964,
    longitude: 126.0431,
  ),
  Destination(
    id: 'monfort-bat-sanctuary',
    name: 'Monfort Bat Sanctuary',
    provinceId: 'davao-del-norte',
    provinceName: 'Davao del Norte',
    regionId: 'region-11',
    cityId: 'samal',
    categoryId: 'nature',
    heroImageUrl: AppImages.greenValley,
    galleryImageUrls: [AppImages.greenValley, AppImages.jungleWaterfall, AppImages.turquoiseWater],
    rating: 0,
    reviewCount: 0,
    shortDescription: "A cave on Samal Island sheltering a record-setting fruit bat colony.",
    longDescription:
        'The Monfort Bat Sanctuary on Samal Island protects a cave system that is home to the '
        "world's largest known colony of Geoffroy's rousette fruit bats, a title recognized by "
        'Guinness World Records. Visitors look down into the cave openings from fenced viewing '
        'areas, where the walls are covered edge to edge with roosting bats.',
    entranceFee: 'Small entrance fee, including a guided walk',
    bestTimeToVisit: 'Year-round',
    travelTips: [
      'Keep your voice down and never use flash — the bats roost during the day.',
      'There is a strong smell at the cave openings; a face mask helps.',
      'Samal is a short ferry ride from Davao City — combine it with a beach stop.',
    ],
    highlights: const ['Millions of fruit bats', 'Guided cave-rim walk', 'Samal Island beaches nearby'],
    nearbyDestinationIds: const ['philippine-eagle-center'],
  ),
  Destination(
    id: 'philippine-eagle-center',
    name: 'Philippine Eagle Center',
    provinceId: 'davao-del-sur',
    provinceName: 'Davao del Sur',
    regionId: 'region-11',
    cityId: 'davao-city',
    categoryId: 'nature',
    heroImageUrl: AppImages.greenValley,
    galleryImageUrls: [AppImages.greenValley, AppImages.jungleWaterfall, AppImages.mountainSunrise],
    rating: 0,
    reviewCount: 0,
    isFeatured: true,
    shortDescription: 'The conservation home of the critically endangered national bird.',
    longDescription:
        'The Philippine Eagle Center in Malagos, in the cool foothills outside downtown Davao City, '
        'is the breeding and rehabilitation facility of the Philippine Eagle Foundation. It is the '
        "best place to see the critically endangered Philippine eagle, the country's national bird "
        'and one of the largest eagles in the world, alongside other native raptors and wildlife.',
    entranceFee: 'Entrance fee at the center plus a small fee at the watershed gate',
    bestTimeToVisit: 'Year-round; mornings, when the birds are most active',
    travelTips: [
      'Allow about an hour for the drive from downtown Davao.',
      'Join a guided tour to learn how the breeding program works.',
      'Entrance fees and donations directly fund eagle conservation.',
    ],
    highlights: const ['Philippine eagles up close', 'Guided conservation tour', 'Forest setting in Malagos'],
    latitude: 7.1850,
    longitude: 125.4150,
  ),
  Destination(
    id: 'little-boracay-santa-maria',
    name: 'Little Boracay',
    provinceId: 'davao-occidental',
    provinceName: 'Davao Occidental',
    regionId: 'region-11',
    cityId: 'santa-maria',
    categoryId: 'beaches',
    heroImageUrl: AppImages.boracayBeach,
    galleryImageUrls: [AppImages.boracayBeach, AppImages.turquoiseWater, AppImages.tropicalIslandAerial],
    rating: 0,
    reviewCount: 0,
    isHiddenGem: true,
    shortDescription: 'A quiet white-sand beach on the Davao Gulf in Santa Maria.',
    longDescription:
        'Nicknamed Little Boracay for its fine white sand and clear water, this beach in the town '
        'of Santa Maria is the most popular seaside getaway in Davao Occidental. It is far less '
        'developed than its namesake, with simple cottages, calm swimming and wide views across '
        'the Davao Gulf.',
    entranceFee: 'Small entrance fee; cottage rentals extra',
    bestTimeToVisit: 'March – May for calm seas',
    travelTips: [
      'Bring your own food and drinking water — options on the beach are limited.',
      'Weekdays are much quieter than weekends and holidays.',
      'It is roughly three hours by road from Davao City.',
    ],
    highlights: const ['White sand swimming beach', 'Davao Gulf views', 'Low-key cottages'],
  ),
  Destination(
    id: 'dahican-beach',
    name: 'Dahican Beach',
    provinceId: 'davao-oriental',
    provinceName: 'Davao Oriental',
    regionId: 'region-11',
    cityId: 'mati',
    categoryId: 'beaches',
    heroImageUrl: AppImages.siargaoCloud9,
    galleryImageUrls: [AppImages.siargaoCloud9, AppImages.boracayBeach, AppImages.turquoiseWater],
    rating: 0,
    reviewCount: 0,
    shortDescription: 'A seven-kilometer crescent of white sand known for skimboarding.',
    longDescription:
        'Dahican Beach in Mati City is a long, wide crescent of fine white sand facing the Pacific. '
        'Its steady shore break has made it the skimboarding and surfing center of the Davao '
        'region, and the bay is also a nesting ground for sea turtles, with dolphins and dugongs '
        'sometimes seen offshore.',
    entranceFee: 'Free beach access; resorts and camps charge their own fees',
    bestTimeToVisit: 'March – May for swimming; later in the year for bigger waves',
    travelTips: [
      'Waves and currents can be strong — swim only where locals say it is safe.',
      'Take a skimboarding lesson from the local boarders.',
      'Stop at the Sleeping Dinosaur viewpoint on the road into Mati.',
    ],
    highlights: const ['Skimboarding and surfing', 'Sea turtle nesting area', 'Sleeping Dinosaur viewpoint'],
    latitude: 6.9150,
    longitude: 126.2880,
    openingHours: 'Open 24 hours',
  ),

  // ---- Region XII — SOCCSKSARGEN ----
  Destination(
    id: 'asik-asik-falls',
    name: 'Asik-Asik Falls',
    provinceId: 'cotabato',
    provinceName: 'Cotabato',
    regionId: 'region-12',
    cityId: 'alamada',
    categoryId: 'nature',
    heroImageUrl: AppImages.tinuyanFalls,
    galleryImageUrls: [AppImages.tinuyanFalls, AppImages.jungleWaterfall, AppImages.greenValley],
    rating: 0,
    reviewCount: 0,
    isHiddenGem: true,
    shortDescription: 'A wide curtain of spring water pouring straight out of a green cliff.',
    longDescription:
        'Asik-Asik Falls in Alamada is unlike most waterfalls: there is no river above it. '
        'Instead, spring water bursts directly from the face of a tall, moss-covered cliff, forming '
        'a broad curtain of dozens of streams that fall into a rocky river below. It only became '
        'widely known around 2010.',
    entranceFee: 'Small entrance and parking fees',
    bestTimeToVisit: 'December – May for a drier trail',
    travelTips: [
      'Reaching the base means descending — and climbing back up — several hundred steps.',
      'The last stretch of road is rough; a habal-habal or high-clearance vehicle helps.',
      'Check current local travel advisories before planning a trip.',
    ],
    highlights: const ['Spring-fed cliff curtain', 'Cold river dip', 'Mountain scenery'],
    latitude: 7.5615,
    longitude: 124.5354,
  ),
  Destination(
    id: 'gumasa-beach',
    name: 'Gumasa Beach',
    provinceId: 'sarangani',
    provinceName: 'Sarangani',
    regionId: 'region-12',
    cityId: 'glan',
    categoryId: 'beaches',
    heroImageUrl: AppImages.boracayBeach,
    galleryImageUrls: [AppImages.boracayBeach, AppImages.turquoiseWater, AppImages.tropicalIslandAerial],
    rating: 0,
    reviewCount: 0,
    shortDescription: 'A long crescent of powdery white sand on Sarangani Bay.',
    longDescription:
        'Gumasa Beach in Glan is a long arc of fine white sand and clear, calm water often called '
        'the "Boracay of the South." Family-run resorts line the shore, and each summer the beach '
        'hosts the Sarangani Bay Festival, one of the biggest beach events in Mindanao.',
    entranceFee: 'Resort day-use fees vary',
    bestTimeToVisit: 'March – May for the calmest water',
    travelTips: [
      'Glan is about an hour and a half by road from General Santos City.',
      'Book well ahead if visiting during the Sarangani Bay Festival.',
      'Stroll through Glan town to see its old ancestral houses.',
    ],
    highlights: const ['White sand swimming', 'Sarangani Bay Festival', 'Glan heritage houses'],
  ),
  Destination(
    id: 'lake-sebu',
    name: 'Lake Sebu',
    provinceId: 'south-cotabato',
    provinceName: 'South Cotabato',
    regionId: 'region-12',
    cityId: 'lake-sebu',
    categoryId: 'nature',
    heroImageUrl: AppImages.greenValley,
    galleryImageUrls: [AppImages.greenValley, AppImages.boatOnLagoon, AppImages.jungleWaterfall],
    rating: 0,
    reviewCount: 0,
    isFeatured: true,
    shortDescription: "A highland lake at the heart of T'boli culture and the Seven Falls.",
    longDescription:
        "Lake Sebu is a cool highland lake in the ancestral homeland of the T'boli people, known "
        "for t'nalak — cloth woven from abaca in patterns said to come to the weavers in dreams. "
        'Visitors paddle among pink lotus blooms at sunrise, visit weaving and brass-casting '
        'centers, and ride a zipline high above the Seven Falls.',
    entranceFee: 'Environmental fee per visitor; boat rides and zipline priced separately',
    bestTimeToVisit: 'November – May; sunrise for the lotus flowers',
    travelTips: [
      'Take the early-morning boat or canoe ride, when the lotus flowers are open.',
      "Buy t'nalak and brassware directly from T'boli weavers and artisans.",
      'Try grilled or fried tilapia fresh from the lake.',
    ],
    highlights: const ['Seven Falls zipline', "T'nalak weaving centers", 'Lotus garden boat ride'],
    latitude: 6.2292,
    longitude: 124.7058,
  ),
  Destination(
    id: 'baras-bird-sanctuary',
    name: 'Baras Bird Sanctuary',
    provinceId: 'sultan-kudarat',
    provinceName: 'Sultan Kudarat',
    regionId: 'region-12',
    cityId: 'tacurong',
    categoryId: 'nature',
    heroImageUrl: AppImages.greenValley,
    galleryImageUrls: [AppImages.greenValley, AppImages.jungleWaterfall, AppImages.boatOnLagoon],
    rating: 0,
    reviewCount: 0,
    isHiddenGem: true,
    shortDescription: 'A riverside grove where thousands of herons and egrets roost.',
    longDescription:
        'The Baras Bird Sanctuary in Tacurong City began as a private farm and has grown into a '
        'protected roosting and nesting site for many thousands of herons and egrets. Raised '
        'walkways and view decks let visitors watch the birds at close range as they fill the '
        'trees along the riverbank.',
    entranceFee: 'Small entrance fee',
    bestTimeToVisit: 'Year-round; early morning or late afternoon when the birds are most active',
    travelTips: [
      'Arrive near dawn or dusk to see the flocks leaving or returning.',
      'Wear a hat or bring an umbrella when walking under the trees.',
      'Keep quiet and stay on the walkways to avoid disturbing the nests.',
    ],
    highlights: const ['Heron and egret colonies', 'View decks and walkways', 'Birdwatching and photography'],
    nearbyDestinationIds: const ['lake-sebu'],
  ),

  // ---- Region XIII — Caraga ----
  Destination(
    id: 'balangay-shrine-museum',
    name: 'Balangay Shrine Museum',
    provinceId: 'agusan-del-norte',
    provinceName: 'Agusan del Norte',
    regionId: 'region-13',
    cityId: 'butuan',
    categoryId: 'historical',
    heroImageUrl: AppImages.intramurosWalls,
    galleryImageUrls: [AppImages.intramurosWalls, AppImages.boatOnLagoon, AppImages.calleCrisologo],
    rating: 0,
    reviewCount: 0,
    shortDescription: 'The resting place of ancient plank boats unearthed in Butuan.',
    longDescription:
        'The Balangay Shrine in Butuan City displays the remains of balangay — large wooden plank '
        'boats built without nails — excavated nearby and dated to as early as the 4th century. '
        'They are the oldest watercraft found in the Philippines and evidence that Butuan was a '
        'major trading port long before the Spanish arrived.',
    entranceFee: 'Free',
    bestTimeToVisit: 'Year-round',
    travelTips: [
      'Also visit the National Museum branch in Butuan for gold and trade ceramics.',
      'Museums like this are commonly closed on Mondays — check the schedule first.',
      'Butuan is the main gateway for trips into the rest of Caraga.',
    ],
    highlights: const ['Ancient balangay boats', 'Pre-colonial trade history', 'National Museum in Butuan'],
  ),
  Destination(
    id: 'agusan-marsh',
    name: 'Agusan Marsh Wildlife Sanctuary',
    provinceId: 'agusan-del-sur',
    provinceName: 'Agusan del Sur',
    regionId: 'region-13',
    cityId: 'bunawan',
    categoryId: 'nature',
    heroImageUrl: AppImages.boatOnLagoon,
    galleryImageUrls: [AppImages.boatOnLagoon, AppImages.greenValley, AppImages.jungleWaterfall],
    rating: 0,
    reviewCount: 0,
    isHiddenGem: true,
    shortDescription: 'A vast wetland of lakes, swamp forest and floating villages.',
    longDescription:
        'The Agusan Marsh is one of the largest and most ecologically important wetlands in the '
        'Philippines, a maze of lakes, rivers and swamp forest in the middle of the Agusan River '
        'basin. Manobo communities live here in floating houses that rise and fall with the water, '
        'and the marsh shelters huge numbers of waterbirds as well as crocodiles.',
    entranceFee: 'Boat, guide and community fees arranged locally',
    bestTimeToVisit: 'March – October, when water levels allow boats deep into the marsh',
    travelTips: [
      'Coordinate with the municipal tourism office in Bunawan or Loreto before going.',
      'Trips are by small boat and take most of a day — bring sun protection and water.',
      'Ask permission before photographing residents of the floating villages.',
    ],
    highlights: const ['Floating Manobo villages', 'Birdwatching by boat', 'Swamp forest lakes'],
    nearbyDestinationIds: const ['tinuy-an-falls'],
    latitude: 8.3167,
    longitude: 125.8667,
  ),
  Destination(
    id: 'bitaog-beach',
    name: 'Bitaog Beach',
    provinceId: 'dinagat-islands',
    provinceName: 'Dinagat Islands',
    regionId: 'region-13',
    cityId: 'basilisa',
    categoryId: 'beaches',
    heroImageUrl: AppImages.palawanCliffs,
    galleryImageUrls: [AppImages.palawanCliffs, AppImages.elNidoLagoon, AppImages.turquoiseWater],
    rating: 0,
    reviewCount: 0,
    isHiddenGem: true,
    shortDescription: 'A pocket of white sand tucked beneath dark limestone cliffs.',
    longDescription:
        'Bitaog Beach in Basilisa is a small cove of white sand and bright turquoise water '
        'enclosed by jagged limestone cliffs. It is the most popular stop on island-hopping trips '
        'around the Dinagat Islands, a province of rugged karst scenery that remains far quieter '
        'than neighboring Siargao.',
    entranceFee: 'Small entrance fee; island-hopping boats priced per group',
    bestTimeToVisit: 'March – June for calm seas',
    travelTips: [
      'Ferries to Dinagat leave from Surigao City; boats for island-hopping start in San Jose.',
      'Bring food and water — most island stops have no shops.',
      'Cell signal is patchy around the islands.',
    ],
    highlights: const ['Limestone-framed cove', 'Island hopping', 'Clear snorkeling water'],
    nearbyDestinationIds: const ['cloud-9'],
  ),

  // ---- BARMM — Bangsamoro ----
  Destination(
    id: 'malamawi-white-beach',
    name: 'Malamawi White Beach',
    provinceId: 'basilan',
    provinceName: 'Basilan',
    regionId: 'barmm',
    cityId: 'isabela-city',
    categoryId: 'beaches',
    heroImageUrl: AppImages.boracayBeach,
    galleryImageUrls: [AppImages.boracayBeach, AppImages.turquoiseWater, AppImages.tropicalIslandAerial],
    rating: 0,
    reviewCount: 0,
    isHiddenGem: true,
    shortDescription: 'A fine white beach on a small island just across from Isabela City.',
    longDescription:
        'Malamawi Island sits a few minutes by boat from the Isabela City waterfront, and its White '
        'Beach is the best-known leisure spot in Basilan: a clean stretch of fine white sand with '
        'calm, clear water and simple cottages under the palms.',
    entranceFee: 'Small entrance fee; cottage rentals extra',
    bestTimeToVisit: 'March – May for calm seas',
    travelTips: [
      'Coordinate with the Isabela City tourism office before your visit.',
      'Check current travel advisories for the area when planning.',
      'Fast ferries connect Isabela City with Zamboanga City.',
    ],
    highlights: const ['White sand beach', 'Short boat ride from the city', 'Palm-shaded cottages'],
    nearbyDestinationIds: const ['great-santa-cruz-island'],
  ),
  Destination(
    id: 'lake-lanao',
    name: 'Lake Lanao',
    provinceId: 'lanao-del-sur',
    provinceName: 'Lanao del Sur',
    regionId: 'barmm',
    cityId: 'marawi',
    categoryId: 'nature',
    heroImageUrl: AppImages.mountainSunrise,
    galleryImageUrls: [AppImages.mountainSunrise, AppImages.greenValley, AppImages.boatOnLagoon],
    rating: 0,
    reviewCount: 0,
    shortDescription: 'The largest lake in Mindanao and the heart of Maranao culture.',
    longDescription:
        'Lake Lanao is the largest lake in Mindanao and one of the oldest lakes in the world. The '
        'Maranao — literally "people of the lake" — have lived along its shores for centuries, and '
        'it remains central to their identity, arts and livelihood. Marawi City sits on its '
        'northern shore, with wide views over the water from the surrounding hills.',
    entranceFee: 'Free',
    bestTimeToVisit: 'December – May for clearer skies',
    travelTips: [
      'Coordinate with the local tourism office and check current travel advisories first.',
      'Dress modestly, in keeping with local Muslim customs.',
      'Look for Maranao crafts such as brassware and handwoven langkit.',
    ],
    highlights: const ['Lake viewpoints', 'Maranao arts and crafts', 'Cool highland climate'],
    nearbyDestinationIds: const ['maria-cristina-falls'],
    latitude: 7.8800,
    longitude: 124.2525,
  ),
  Destination(
    id: 'grand-mosque-cotabato',
    name: 'Grand Mosque of Cotabato',
    provinceId: 'maguindanao-del-norte',
    provinceName: 'Maguindanao del Norte',
    regionId: 'barmm',
    cityId: 'cotabato-city',
    categoryId: 'historical',
    heroImageUrl: AppImages.vigenChurch,
    galleryImageUrls: [AppImages.vigenChurch, AppImages.manilaSkyline, AppImages.intramurosWalls],
    rating: 0,
    reviewCount: 0,
    shortDescription: 'A white-and-gold landmark and one of the largest mosques in the country.',
    longDescription:
        'The Sultan Haji Hassanal Bolkiah Masjid, better known as the Grand Mosque of Cotabato, is '
        'one of the largest mosques in the Philippines. Completed in 2011, its gold-painted domes '
        'and four tall minarets rise above open ground near the mouth of the Tamontaka River and '
        'are especially striking at sunset.',
    entranceFee: 'Free',
    bestTimeToVisit: 'Year-round; late afternoon outside prayer times',
    travelTips: [
      'Non-Muslim visitors are welcome outside prayer times — dress modestly and cover up.',
      'Remove your shoes before entering and ask before taking photos inside.',
      'Check current travel advisories for the area when planning.',
    ],
    highlights: const ['Golden domes', 'Towering minarets', 'Sunset photography'],
    latitude: 7.2019,
    longitude: 124.1656,
  ),
  Destination(
    id: 'lake-buluan',
    name: 'Lake Buluan',
    provinceId: 'maguindanao-del-sur',
    provinceName: 'Maguindanao del Sur',
    regionId: 'barmm',
    cityId: 'buluan',
    categoryId: 'nature',
    heroImageUrl: AppImages.boatOnLagoon,
    galleryImageUrls: [AppImages.boatOnLagoon, AppImages.greenValley, AppImages.mountainSunrise],
    rating: 0,
    reviewCount: 0,
    isHiddenGem: true,
    shortDescription: 'A broad, shallow lake of fishing villages and marshland.',
    longDescription:
        'Lake Buluan is one of the largest lakes in Mindanao, spreading across the border of '
        'Maguindanao del Sur and Sultan Kudarat. Its shallow, marshy waters support a major '
        'freshwater fishery, and the lakeshore offers quiet views of fishing boats, water '
        'hyacinth and distant mountains.',
    entranceFee: 'Free; boat rides arranged with local fishermen',
    bestTimeToVisit: 'December – May for drier weather',
    travelTips: [
      'Coordinate with the municipal tourism office in Buluan before visiting.',
      'Check current travel advisories for the area when planning.',
      'Try freshly caught tilapia and other lake fish in town.',
    ],
    highlights: const ['Lakeshore views', 'Fishing village life', 'Fresh lake fish'],
    nearbyDestinationIds: const ['baras-bird-sanctuary'],
    latitude: 6.6406,
    longitude: 124.8250,
  ),
  Destination(
    id: 'tulay-central-mosque',
    name: 'Tulay Central Mosque',
    provinceId: 'sulu',
    provinceName: 'Sulu',
    regionId: 'barmm',
    cityId: 'jolo',
    categoryId: 'historical',
    heroImageUrl: AppImages.vigenChurch,
    galleryImageUrls: [AppImages.vigenChurch, AppImages.intramurosWalls, AppImages.manilaSkyline],
    rating: 0,
    reviewCount: 0,
    shortDescription: 'The largest mosque in Sulu, at the center of the town of Jolo.',
    longDescription:
        'The Tulay Central Mosque is the largest mosque in the province of Sulu and the main '
        'landmark of Jolo, historic seat of the Sultanate of Sulu. Its domes and minarets rise '
        'above the town center, reflecting the deep Islamic heritage of the Tausug people.',
    entranceFee: 'Free',
    bestTimeToVisit: 'Year-round; outside prayer times',
    travelTips: [
      'Coordinate with the provincial tourism office before traveling to Sulu.',
      'Check current travel advisories carefully when planning.',
      'Dress modestly and ask permission before entering or taking photos.',
    ],
    highlights: const ['Domes and minarets', 'Tausug heritage', 'Jolo town center'],
    latitude: 6.0508,
    longitude: 120.9981,
  ),
  Destination(
    id: 'bud-bongao',
    name: 'Bud Bongao',
    provinceId: 'tawi-tawi',
    provinceName: 'Tawi-Tawi',
    regionId: 'barmm',
    cityId: 'bongao',
    categoryId: 'mountains',
    heroImageUrl: AppImages.mountainSunrise,
    galleryImageUrls: [AppImages.mountainSunrise, AppImages.greenValley, AppImages.tropicalIslandAerial],
    rating: 0,
    reviewCount: 0,
    isHiddenGem: true,
    shortDescription: 'A sacred forested peak overlooking the southernmost islands.',
    longDescription:
        'Bud Bongao is a forested mountain rising steeply above the capital of Tawi-Tawi, and is '
        'considered sacred by local communities. A stepped trail climbs through forest inhabited '
        'by long-tailed macaques to viewing platforms at the summit, with a panorama of the town, '
        'the surrounding islands and the Sulu and Celebes seas.',
    entranceFee: 'Small environmental fee at the trailhead',
    bestTimeToVisit: 'December – May; start early in the morning',
    travelTips: [
      'Bring bananas — by tradition, hikers offer them to the monkeys along the trail.',
      'Allow two to three hours for the round trip and carry plenty of water.',
      'Coordinate with the provincial tourism office and check current travel advisories.',
    ],
    highlights: const ['Summit viewing decks', 'Wild macaques on the trail', 'Island and sea panorama'],
    latitude: 5.0186,
    longitude: 119.7478,
  ),
];

Destination destinationById(String id) =>
    mockDestinations.firstWhere((d) => d.id == id, orElse: () => mockDestinations.first);
