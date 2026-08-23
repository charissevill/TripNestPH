import '../../core/constants/app_images.dart';
import '../../domain/models/province.dart';

/// All 82 official Philippine provinces plus the `metro-manila`
/// NCR pseudo-province (see [Province]'s doc comment for why) — 83 docs
/// total, seeded once via `tool/seed_firestore.js`.
///
/// Every province gets real page copy (`hasContent: true`) — general,
/// well-established facts only (season timing, the nationwide 911 hotline,
/// well-known cultural notes), never invented business-level specifics.
/// ~15 also have real curated destination/restaurant/festival content (see
/// the migration table in the Phase 1 plan); the rest rely on
/// `province_details_screen.dart`'s live Places fallback for Things to
/// Do/Hotels/Getting Around, so the page still reads as complete without
/// curated entries.
const _nationalHotlines = [
  EmergencyHotline(label: 'National Emergency Hotline', number: '911'),
];

final List<Province> mockProvinces = [
  // ---- NCR — pseudo-province ----
  Province(
    id: 'metro-manila',
    name: 'Metro Manila',
    regionId: 'ncr',
    regionName: 'National Capital Region',
    islandGroup: 'Luzon',
    isPseudoProvince: true,
    hasContent: true,
    overview:
        "The country's capital region, anchored by Intramuros' Spanish-colonial walled city, Rizal Park, and a "
        'dense mix of historic, business and entertainment districts across its cities.',
    localCulture:
        'The most culturally diverse part of the country, drawing migrants from every region — Filipino and '
        'English are both widely spoken, alongside every regional language.',
    bestTimeToVisit:
        'November to February, the coolest and driest stretch, is most comfortable for walking tours.',
    estimatedDailyBudgetMin: 2000,
    estimatedDailyBudgetMax: 5000,
    travelTips: [
      'Traffic is often the single biggest time cost — factor in significant buffer between destinations.',
      'Intramuros is best explored on foot or by kalesa (horse-drawn calash) rather than by car.',
      'Use ride-hailing apps or the LRT/MRT for predictable travel times over street-hailed taxis.',
    ],
    emergencyHotlines: _nationalHotlines,
    heroImageUrl: AppImages.intramurosWalls,
    featuredDestinationIds: [],
  ),

  // ---- CAR — Cordillera Administrative Region ----
  Province(
    id: 'abra',
    name: 'Abra',
    regionId: 'car',
    regionName: 'Cordillera Administrative Region',
    islandGroup: 'Luzon',
    hasContent: true,
    overview:
        'A rugged, less-visited Cordillera province centered on the Abra River valley, and Tirad Pass, site of '
        'the historic 1899 Battle of Tirad Pass.',
    localCulture:
        'Home to the Itneg (Tinguian) indigenous people, known for backstrap-loom abel weaving and binakol '
        'blanket patterns.',
    bestTimeToVisit:
        'November to April, the dry season, for the most stable mountain road conditions.',
    estimatedDailyBudgetMin: 1000,
    estimatedDailyBudgetMax: 2500,
    travelTips: [
      'Mountain roads can be affected by landslides in the wet season — check conditions before traveling.',
      'Tirad Pass is reached via a multi-day trek from Cervantes, Ilocos Sur — arrange a guide in advance.',
      'Abel and binakol weaving make for meaningful, locally made souvenirs.',
    ],
    emergencyHotlines: _nationalHotlines,
    heroImageUrl: AppImages.greenValley,
    featuredDestinationIds: [],
  ),
  Province(
    id: 'apayao',
    name: 'Apayao',
    regionId: 'car',
    regionName: 'Cordillera Administrative Region',
    islandGroup: 'Luzon',
    hasContent: true,
    overview:
        "The Cordillera's most remote and least-developed province, covered in dense forest and centered on "
        'the Apayao River, popular for whitewater rafting.',
    localCulture:
        'Home to the Isnag indigenous people, whose river-based lifestyle remains closely tied to the Apayao '
        'River and its tributaries.',
    bestTimeToVisit:
        'November to May, avoiding the wet season when river levels and road conditions are less predictable.',
    estimatedDailyBudgetMin: 1000,
    estimatedDailyBudgetMax: 2500,
    travelTips: [
      'Apayao has limited tourism infrastructure — arrange transport and lodging in Luna or Kabugao ahead of time.',
      'Whitewater rafting on the Apayao River is best done with an experienced local outfitter.',
      'Cell signal is limited outside the main towns — plan accordingly.',
    ],
    emergencyHotlines: _nationalHotlines,
    heroImageUrl: AppImages.jungleWaterfall,
    featuredDestinationIds: [],
  ),
  Province(
    id: 'benguet',
    name: 'Benguet',
    regionId: 'car',
    regionName: 'Cordillera Administrative Region',
    islandGroup: 'Luzon',
    hasContent: true,
    overview:
        "The Cordillera's most visited province, home to Baguio City's cool-climate parks, strawberry farms, "
        'and the surrounding pine-forested highlands.',
    localCulture:
        'Home to the Ibaloi and Kankanaey indigenous peoples; Baguio itself grew as an American-era hill '
        "station and remains the Cordillera's main commercial and cultural hub.",
    bestTimeToVisit:
        'December to February for the coolest weather, or late February–March for the Panagbenga Flower Festival.',
    estimatedDailyBudgetMin: 1500,
    estimatedDailyBudgetMax: 3500,
    travelTips: [
      'Baguio gets genuinely cold at night by Philippine standards — pack a light jacket.',
      'Book accommodations early for Panagbenga Festival and Holy Week — the city fills up fast.',
      'Traffic into Baguio on weekends/holidays can be heavy; a weekday visit is far more relaxed.',
    ],
    emergencyHotlines: _nationalHotlines,
    heroImageUrl: AppImages.mountainSunrise,
    featuredDestinationIds: [],
  ),
  Province(
    id: 'ifugao',
    name: 'Ifugao',
    regionId: 'car',
    regionName: 'Cordillera Administrative Region',
    islandGroup: 'Luzon',
    hasContent: true,
    overview:
        'Home to the UNESCO World Heritage-listed Banaue and Batad Rice Terraces, carved into the Cordillera '
        'mountains over centuries.',
    localCulture:
        'Home to the Ifugao people, whose rice terrace farming, wood-carving (bulul figures), and indigenous '
        'rituals remain living traditions, not museum pieces.',
    bestTimeToVisit:
        'March to May (dry, clear mountain views) or November–December (post-harvest, terraces still green); '
        'the June–October wet season brings landslide risk on mountain roads.',
    estimatedDailyBudgetMin: 1200,
    estimatedDailyBudgetMax: 2800,
    travelTips: [
      "Batad's rice terraces are only reachable on foot from the saddle point — pack proper footwear.",
      'Mountain roads to Ifugao are winding; those prone to motion sickness should plan accordingly.',
      "Hire a local guide in Batad — trails aren't well signed and guiding income directly supports the community.",
    ],
    emergencyHotlines: _nationalHotlines,
    heroImageUrl: AppImages.riceTerraces,
    featuredDestinationIds: [],
  ),
  Province(
    id: 'kalinga',
    name: 'Kalinga',
    regionId: 'car',
    regionName: 'Cordillera Administrative Region',
    islandGroup: 'Luzon',
    hasContent: true,
    overview:
        'Best known for Buscalan village, home of centenarian tattoo artist Whang-od and the Butbut people\'s '
        'traditional batok (hand-tapped tattoo) art.',
    localCulture:
        'Home to several Kalinga indigenous groups; batok tattooing, brass gongs (gangsa), and rice-terrace '
        'farming remain living traditions, not tourist performances.',
    bestTimeToVisit:
        'November to April (dry season); the trek to Buscalan is far harder in wet-season mud.',
    estimatedDailyBudgetMin: 1000,
    estimatedDailyBudgetMax: 2500,
    travelTips: [
      'Buscalan is reached by a steep 1-2 hour hike from Tinglayan — proper footwear is essential.',
      "Getting a tattoo from Whang-od's apprentices means waiting your turn in the village — go in with flexible expectations.",
      'Homestays in Buscalan are the norm — bring cash, as there are no ATMs in the village.',
    ],
    emergencyHotlines: _nationalHotlines,
    heroImageUrl: AppImages.traditionalCostume,
    featuredDestinationIds: [],
  ),
  Province(
    id: 'mountain-province',
    name: 'Mountain Province',
    regionId: 'car',
    regionName: 'Cordillera Administrative Region',
    islandGroup: 'Luzon',
    hasContent: true,
    overview:
        "Home to Sagada, famous for its centuries-old hanging coffins, limestone caves, and Echo Valley, plus "
        "the provincial capital Bontoc's rice-terrace heritage.",
    localCulture:
        'Home to the Kankanaey and Bontoc peoples; hanging coffins on cliff faces in Sagada continue as a '
        'living burial tradition for some elders.',
    bestTimeToVisit:
        'November to April for clearer mountain views and drier caving/trekking conditions.',
    estimatedDailyBudgetMin: 1200,
    estimatedDailyBudgetMax: 2800,
    travelTips: [
      'Sumaguing Cave spelunking requires a registered local guide, arranged at the Sagada tourist office.',
      'Sagada restricts plastic bags in parts of town — bring a reusable bag.',
      'The mountain drive from Baguio to Sagada takes several hours — start early to arrive in daylight.',
    ],
    emergencyHotlines: _nationalHotlines,
    heroImageUrl: AppImages.mountainSunrise,
    featuredDestinationIds: [],
  ),

  // ---- Region I — Ilocos Region ----
  Province(
    id: 'ilocos-norte',
    name: 'Ilocos Norte',
    regionId: 'region-1',
    regionName: 'Ilocos Region',
    islandGroup: 'Luzon',
    hasContent: true,
    overview:
        'Home to the Bangui Bay wind turbines, Paoay Church (a UNESCO World Heritage Baroque church), and the '
        'Ilocos Norte sand dunes near Laoag.',
    localCulture:
        'Ilocano-speaking, sharing the region\'s thrift-minded, hardworking reputation; the Malacañang of the '
        "North in Paoay preserves the Marcos family's provincial residence as a museum.",
    bestTimeToVisit:
        'November to April, avoiding the wetter, typhoon-prone middle months.',
    estimatedDailyBudgetMin: 1200,
    estimatedDailyBudgetMax: 3000,
    travelTips: [
      'Sandboarding at the Ilocos Norte sand dunes is best booked through a registered 4x4 operator in Paoay.',
      'Paoay Church is built with distinctive earthquake-baroque buttresses — worth a slow walk around the exterior.',
      'Bangui wind turbines are most photogenic near sunset, with fewer crowds than midday.',
    ],
    emergencyHotlines: _nationalHotlines,
    heroImageUrl: AppImages.greenValley,
    featuredDestinationIds: [],
  ),
  Province(
    id: 'ilocos-sur',
    name: 'Ilocos Sur',
    regionId: 'region-1',
    regionName: 'Ilocos Region',
    islandGroup: 'Luzon',
    hasContent: true,
    overview:
        'Centers on Vigan, a UNESCO World Heritage-listed Spanish colonial town famous for Calle Crisologo\'s '
        'cobblestone streets and kalesa rides.',
    localCulture:
        'Ilocano culture and language dominate, known for a thrift-minded, hardworking reputation and dishes '
        'like bagnet and empanada.',
    bestTimeToVisit:
        'November to April, avoiding the wetter, typhoon-prone middle months.',
    estimatedDailyBudgetMin: 1200,
    estimatedDailyBudgetMax: 3000,
    travelTips: [
      "Explore Vigan's heritage core on foot or by kalesa rather than car — many streets restrict vehicle access.",
      'Try Vigan longganisa and empanada from a stall near the public market for the most authentic version.',
      'Pottery-making at Pagburnayan is a hands-on stop worth booking ahead for groups.',
    ],
    emergencyHotlines: _nationalHotlines,
    heroImageUrl: AppImages.calleCrisologo,
    featuredDestinationIds: [],
  ),
  Province(
    id: 'la-union',
    name: 'La Union',
    regionId: 'region-1',
    regionName: 'Ilocos Region',
    islandGroup: 'Luzon',
    hasContent: true,
    overview:
        "Known as the Philippines' surfing capital, centered on San Juan's beach breaks and a growing "
        'beach-and-café scene along the coast.',
    localCulture:
        'Ilocano-speaking, with a coastal fishing heritage now layered with a laid-back surf-town culture '
        'concentrated around San Juan.',
    bestTimeToVisit:
        'November to March for the biggest, most consistent surf swells.',
    estimatedDailyBudgetMin: 1200,
    estimatedDailyBudgetMax: 3000,
    travelTips: [
      'San Juan has surf schools for beginners — board and lesson packages are widely available by the hour.',
      'Elyu (as locals call it) gets busy on weekends with day-trippers from Manila — weekdays are quieter.',
      'Bring reef-safe sunscreen and a rash guard for longer sessions in the water.',
    ],
    emergencyHotlines: _nationalHotlines,
    heroImageUrl: AppImages.turquoiseWater,
    featuredDestinationIds: [],
  ),
  Province(
    id: 'pangasinan',
    name: 'Pangasinan',
    regionId: 'region-1',
    regionName: 'Ilocos Region',
    islandGroup: 'Luzon',
    hasContent: true,
    overview:
        'Known for Hundred Islands National Park and Manleluag Spring, a major Ilocano-Pangasinense coastal '
        'province in northwestern Luzon.',
    localCulture:
        'Home to the Pangasinense people and language, with strong Ilocano influence; bagoong (fish paste) and '
        'deep-sea fishing traditions run deep along its long coastline.',
    bestTimeToVisit:
        'November to May, avoiding the June–October typhoon-prone wet season — best for island hopping.',
    estimatedDailyBudgetMin: 1500,
    estimatedDailyBudgetMax: 3500,
    travelTips: [
      'Hundred Islands is best visited early morning before boat crowds build up.',
      "Bring cash — many small boat operators and beachside eateries in Alaminos don't accept cards.",
      'Typhoons are most likely June–October; check PAGASA advisories before booking island tours.',
    ],
    emergencyHotlines: _nationalHotlines,
    heroImageUrl: AppImages.hundredIslands,
    featuredDestinationIds: [],
  ),

  // ---- Region II — Cagayan Valley ----
  Province(
    id: 'batanes',
    name: 'Batanes',
    regionId: 'region-2',
    regionName: 'Cagayan Valley',
    islandGroup: 'Luzon',
    hasContent: true,
    overview:
        "The Philippines' northernmost province, known for the rolling green hills of Batan Island, "
        'stone-and-lime Ivatan houses, and dramatic clifftop views over the sea.',
    localCulture:
        'Home to the Ivatan people, whose thick stone houses evolved specifically to withstand the frequent '
        'typhoons that pass through the strait between Luzon and Taiwan.',
    bestTimeToVisit:
        'March to May, the calmest and driest window before the mid-year typhoon season.',
    estimatedDailyBudgetMin: 2500,
    estimatedDailyBudgetMax: 5000,
    travelTips: [
      'Flights to Batanes fill up fast and are frequently weather-delayed — build buffer days into your trip.',
      'Renting a scooter or hiring a tricycle is the standard way to see Batan Island\'s hills and viewpoints.',
      'Pack layers — it\'s noticeably cooler and windier here than the rest of the Cagayan Valley.',
    ],
    emergencyHotlines: _nationalHotlines,
    heroImageUrl: AppImages.greenValley,
    featuredDestinationIds: [],
  ),
  Province(
    id: 'cagayan',
    name: 'Cagayan',
    regionId: 'region-2',
    regionName: 'Cagayan Valley',
    islandGroup: 'Luzon',
    hasContent: true,
    overview:
        'Anchored by the Cagayan River, the longest river in the Philippines, with Callao Cave\'s '
        'chapel-in-a-cavern and the northern coastal town of Sta. Ana among its main draws.',
    localCulture:
        'Predominantly Ibanag- and Ilocano-speaking, with a river-and-farming way of life shaped by the '
        'Cagayan River, historically the region\'s main trade route.',
    bestTimeToVisit:
        'March to May, avoiding the typhoon-prone June–November stretch this coast is exposed to.',
    estimatedDailyBudgetMin: 1200,
    estimatedDailyBudgetMax: 3000,
    travelTips: [
      'Callao Cave has a chapel built into one of its chambers, lit naturally by a skylight opening.',
      'Cagayan sits directly in the typhoon belt — check PAGASA advisories before travel June–November.',
      'Sta. Ana and the Palaui Island area require a boat transfer — arrange this in advance with a local operator.',
    ],
    emergencyHotlines: _nationalHotlines,
    heroImageUrl: AppImages.riceTerraces,
    featuredDestinationIds: [],
  ),
  Province(
    id: 'isabela',
    name: 'Isabela',
    regionId: 'region-2',
    regionName: 'Cagayan Valley',
    islandGroup: 'Luzon',
    hasContent: true,
    overview:
        "The Cagayan Valley's largest and most agriculturally productive province, home to the Ilagan "
        'Sanctuary wetlands and the Palanan wilderness along its rugged eastern coast.',
    localCulture:
        'A mix of Ibanag, Ilocano, and Gaddang communities; the province is one of the country\'s largest rice '
        'and corn producers, and its farming calendar shapes local life.',
    bestTimeToVisit: 'March to May for the driest travel conditions.',
    estimatedDailyBudgetMin: 1000,
    estimatedDailyBudgetMax: 2500,
    travelTips: [
      "Palanan's coastline is remote and best visited with an organized local tour rather than independently.",
      'Isabela is a major agricultural province — expect long stretches of farmland between towns.',
      'Book accommodations in Ilagan or Santiago in advance, as options thin out outside the city centers.',
    ],
    emergencyHotlines: _nationalHotlines,
    heroImageUrl: AppImages.greenValley,
    featuredDestinationIds: [],
  ),
  Province(
    id: 'nueva-vizcaya',
    name: 'Nueva Vizcaya',
    regionId: 'region-2',
    regionName: 'Cagayan Valley',
    islandGroup: 'Luzon',
    hasContent: true,
    overview:
        'A mountain-ringed valley province known for citrus orchards, the Dalton Pass viewpoint, and its role '
        'as a gateway between the lowland Cagayan Valley and the Cordillera highlands.',
    localCulture:
        'Home to the Ifugao, Bugkalot (Ilongot), and Ilocano communities; citrus farming, especially calamansi '
        'and ponkan orange orchards, is a major local livelihood.',
    bestTimeToVisit:
        'November to April for the driest mountain-road conditions.',
    estimatedDailyBudgetMin: 1000,
    estimatedDailyBudgetMax: 2500,
    travelTips: [
      'Dalton Pass is a scenic but winding mountain crossing — those prone to motion sickness should plan accordingly.',
      'Roadside stalls along the highway sell fresh citrus in season — a common stop for travelers heading north.',
      'Bambang and Solano are the main jump-off towns for exploring the province.',
    ],
    emergencyHotlines: _nationalHotlines,
    heroImageUrl: AppImages.mountainSunrise,
    featuredDestinationIds: [],
  ),
  Province(
    id: 'quirino',
    name: 'Quirino',
    regionId: 'region-2',
    regionName: 'Cagayan Valley',
    islandGroup: 'Luzon',
    hasContent: true,
    overview:
        "One of the country's least-populated provinces, covered largely by the Northern Sierra Madre and "
        'Quirino Protected Landscape forest, with the Governor Rapids and Maddela caves among its natural draws.',
    localCulture:
        'A mix of Ilocano and Ifugao settlers alongside the indigenous Bugkalot (Ilongot) community, with a '
        'livelihood centered on farming and forest resources.',
    bestTimeToVisit:
        'March to May for the driest conditions for river and cave activities.',
    estimatedDailyBudgetMin: 1000,
    estimatedDailyBudgetMax: 2200,
    travelTips: [
      'Quirino has limited tourism infrastructure — arrange guides and transport in Cabarroguis ahead of time.',
      'The Governor Rapids are best visited in the dry season, when water levels are calmer.',
      'Cell signal is patchy outside the town centers — download offline maps beforehand.',
    ],
    emergencyHotlines: _nationalHotlines,
    heroImageUrl: AppImages.jungleWaterfall,
    featuredDestinationIds: [],
  ),

  // ---- Region III — Central Luzon ----
  Province(
    id: 'aurora',
    name: 'Aurora',
    regionId: 'region-3',
    regionName: 'Central Luzon',
    islandGroup: 'Luzon',
    hasContent: true,
    overview:
        'A quiet, forest-and-coast province on Luzon\'s Pacific side, known for Baler\'s surf breaks and its '
        'role as the site of the 1898 Battle of Baler.',
    localCulture:
        'Tagalog-speaking, historically isolated by the Sierra Madre mountains; Baler\'s surf-town culture has '
        'grown around its consistent Pacific swells since the 1970s.',
    bestTimeToVisit:
        'November to May for calmer seas and more consistent surf conditions.',
    estimatedDailyBudgetMin: 1200,
    estimatedDailyBudgetMax: 3000,
    travelTips: [
      'Baler is reached by a winding mountain road from Nueva Ecija — allow extra travel time.',
      'Surf lessons and board rentals are widely available along Sabang Beach.',
      'Aurora sits on the typhoon-exposed Pacific coast — check weather advisories before travel.',
    ],
    emergencyHotlines: _nationalHotlines,
    heroImageUrl: AppImages.turquoiseWater,
    featuredDestinationIds: [],
  ),
  Province(
    id: 'bataan',
    name: 'Bataan',
    regionId: 'region-3',
    regionName: 'Central Luzon',
    islandGroup: 'Luzon',
    hasContent: true,
    overview:
        'Best known for the Dambana ng Kagitingan (Shrine of Valor) atop Mt. Samat, commemorating World War '
        'II\'s Battle of Bataan and the Bataan Death March.',
    localCulture:
        'Tagalog-speaking, with the province\'s WWII history — the Death March route is now marked with '
        'kilometer markers — remaining central to local identity.',
    bestTimeToVisit: 'November to April, avoiding the wetter middle months.',
    estimatedDailyBudgetMin: 1000,
    estimatedDailyBudgetMax: 2500,
    travelTips: [
      'The Dambana ng Kagitingan shrine and its cross-topped mountain viewpoint are reached by a paved road up Mt. Samat.',
      'Las Casas Filipinas de Acuzar, a heritage-house park, is a popular half-day stop.',
      'Bataan is a short drive or ferry ride from Manila, making it feasible as a day trip.',
    ],
    emergencyHotlines: _nationalHotlines,
    heroImageUrl: AppImages.greenValley,
    featuredDestinationIds: [],
  ),
  Province(
    id: 'bulacan',
    name: 'Bulacan',
    regionId: 'region-3',
    regionName: 'Central Luzon',
    islandGroup: 'Luzon',
    hasContent: true,
    overview:
        "Home to Biak-na-Bato National Park's revolutionary-era caves, Malolos' role as the seat of the first "
        'Philippine Republic, and the Pulilan Carabao Festival each May.',
    localCulture:
        'Tagalog-speaking with deep ties to the 1898 Malolos Congress; Barasoain Church in Malolos remains one '
        "of the country's most historically significant heritage churches.",
    bestTimeToVisit:
        'November to April (dry season); the Pulilan Carabao Festival runs mid-May.',
    estimatedDailyBudgetMin: 1000,
    estimatedDailyBudgetMax: 2500,
    travelTips: [
      "Biak-na-Bato's caves are best explored with a local guide — trails aren't well signed.",
      "Malolos' heritage houses and Barasoain Church are best explored on foot over a couple of hours.",
      "Bulacan is known for puto (rice cakes) and pastillas — Malolos' market stalls are a good place to try both.",
    ],
    emergencyHotlines: _nationalHotlines,
    heroImageUrl: AppImages.vigenChurch,
    featuredDestinationIds: [],
  ),
  Province(
    id: 'nueva-ecija',
    name: 'Nueva Ecija',
    regionId: 'region-3',
    regionName: 'Central Luzon',
    islandGroup: 'Luzon',
    hasContent: true,
    overview:
        "Known as the country's rice granary, home to vast rice fields, the Minalungao National Park river "
        'canyon, and the cool-climate town of Gabaldon at the foot of the Sierra Madre.',
    localCulture:
        'Tagalog-speaking with a farming-centered way of life; the province is one of the country\'s top rice '
        'producers, and harvest seasons shape much of local life.',
    bestTimeToVisit: 'November to April for the driest travel conditions.',
    estimatedDailyBudgetMin: 1000,
    estimatedDailyBudgetMax: 2500,
    travelTips: [
      'Minalungao National Park offers river tubing and a short raft crossing at the base of its limestone cliffs.',
      'Rice fields are at their greenest a few months after planting — timing varies by local harvest cycle.',
      'Palayan City and Cabanatuan are the main jump-off points for exploring the province.',
    ],
    emergencyHotlines: _nationalHotlines,
    heroImageUrl: AppImages.greenValley,
    featuredDestinationIds: [],
  ),
  Province(
    id: 'pampanga',
    name: 'Pampanga',
    regionId: 'region-3',
    regionName: 'Central Luzon',
    islandGroup: 'Luzon',
    hasContent: true,
    overview:
        "Widely regarded as the Philippines' culinary capital for Kapampangan cuisine, home to San Fernando's "
        'Giant Lantern Festival and a jump-off point for Mt. Pinatubo crater treks.',
    localCulture:
        'Kapampangan-speaking, with a food culture (sisig, tocino) considered among the most influential in the '
        "country; San Fernando's giant lantern-making is a generations-old local craft.",
    bestTimeToVisit:
        'November to May (dry season); the Giant Lantern Festival is held in mid-December.',
    estimatedDailyBudgetMin: 1500,
    estimatedDailyBudgetMax: 3500,
    travelTips: [
      'Mt. Pinatubo treks require a 4x4 transfer and a registered guide — book slots ahead of your visit date.',
      'Giant Lantern Festival tickets sell out — reserve early if visiting in December.',
      'Try sisig at a local carinderia rather than a mall chain for the more traditional version.',
    ],
    emergencyHotlines: _nationalHotlines,
    heroImageUrl: AppImages.lanternFestival,
    featuredDestinationIds: [],
  ),
  Province(
    id: 'tarlac',
    name: 'Tarlac',
    regionId: 'region-3',
    regionName: 'Central Luzon',
    islandGroup: 'Luzon',
    hasContent: true,
    overview:
        "A farmland province known for Mt. Pinatubo's other crater-trek jump-off (via Sta. Juliana), Monasterio "
        'de Tarlac\'s hillside chapel, and the Aquino family\'s Hacienda Luisita.',
    localCulture:
        'Predominantly Tagalog and Kapampangan-speaking, with a large sugarcane- and rice-farming economy; '
        'Capas is home to the Capas National Shrine, honoring Bataan Death March victims.',
    bestTimeToVisit:
        'November to May, avoiding Mt. Pinatubo trail closures during the wet season.',
    estimatedDailyBudgetMin: 1200,
    estimatedDailyBudgetMax: 3000,
    travelTips: [
      'Mt. Pinatubo treks from Sta. Juliana require a 4x4 transfer across the lahar plain plus a guided hike.',
      'Monasterio de Tarlac is free to visit and offers wide views over the surrounding farmland.',
      'Bring cash for small vendors along the Pinatubo trailhead — card payment is uncommon there.',
    ],
    emergencyHotlines: _nationalHotlines,
    heroImageUrl: AppImages.mountainSunrise,
    featuredDestinationIds: [],
  ),
  Province(
    id: 'zambales',
    name: 'Zambales',
    regionId: 'region-3',
    regionName: 'Central Luzon',
    islandGroup: 'Luzon',
    hasContent: true,
    overview:
        "Known for Anawangin and Nagsasa Coves' pine-lined beaches, Capones Island's lighthouse, and Subic Bay's "
        'former US naval base turned freeport and eco-tourism area.',
    localCulture:
        'A mix of Sambal- and Tagalog-speaking communities along a coastline shaped by both fishing traditions '
        'and Subic Bay\'s decades as a US naval facility.',
    bestTimeToVisit:
        'November to May (dry season); coves are frequently closed to boats during typhoons.',
    estimatedDailyBudgetMin: 1200,
    estimatedDailyBudgetMax: 3000,
    travelTips: [
      'Anawangin and Nagsasa are reached by boat from Pundaquit — arrange this with a registered boatman.',
      'Camping overnight at the coves is common — bring your own tent or book a package that includes one.',
      'Subic Bay has its own entry protocol at the freeport gates — bring a valid ID.',
    ],
    emergencyHotlines: _nationalHotlines,
    heroImageUrl: AppImages.tropicalIslandAerial,
    featuredDestinationIds: [],
  ),

  // ---- Region IV-A — CALABARZON ----
  Province(
    id: 'batangas',
    name: 'Batangas',
    regionId: 'region-4a',
    regionName: 'CALABARZON',
    islandGroup: 'Luzon',
    hasContent: true,
    overview:
        'Home to Taal Volcano, one of the smallest active volcanoes in the world rising from Taal Lake, plus '
        "Anilao's renowned dive sites and Nasugbu's beach resorts.",
    localCulture:
        'Tagalog-speaking with a distinctive Batangueño accent; the province is the country\'s main producer '
        'of kapeng barako, a strong native coffee variety.',
    bestTimeToVisit:
        'November to May (dry season); Taal Volcano access is periodically restricted during heightened '
        'volcanic activity — check PHIVOLCS advisories.',
    estimatedDailyBudgetMin: 1200,
    estimatedDailyBudgetMax: 3000,
    travelTips: [
      'Check PHIVOLCS alert levels before planning a Taal Volcano trip — access opens and closes with activity.',
      "Anilao's dive sites are best visited on weekdays, away from Metro Manila weekend crowds.",
      'Try kapeng barako at a local café — it\'s noticeably stronger and more bitter than regular brewed coffee.',
    ],
    emergencyHotlines: _nationalHotlines,
    heroImageUrl: AppImages.boatOnLagoon,
    featuredDestinationIds: [],
  ),
  Province(
    id: 'cavite',
    name: 'Cavite',
    regionId: 'region-4a',
    regionName: 'CALABARZON',
    islandGroup: 'Luzon',
    hasContent: true,
    overview:
        "Home to Tagaytay's cool-climate ridge overlooking Taal Lake, alongside Kawit's Aguinaldo Shrine and a "
        'string of Philippine Revolution historical sites.',
    localCulture:
        'Widely regarded as the birthplace of the Philippine Revolution; Ternate town still speaks Caviteño '
        'Chabacano, one of the few Spanish-creole dialects left outside Zamboanga.',
    bestTimeToVisit: 'November to February for the coolest Tagaytay weather.',
    estimatedDailyBudgetMin: 1200,
    estimatedDailyBudgetMax: 3000,
    travelTips: [
      "Tagaytay's ridge road gets heavy traffic on weekends — a weekday visit is far more relaxed.",
      'Bulalo (beef marrow soup) is a Tagaytay specialty best eaten at one of the ridge-view restaurants.',
      "The Aguinaldo Shrine in Kawit is a short, worthwhile detour for the Revolution's history.",
    ],
    emergencyHotlines: _nationalHotlines,
    heroImageUrl: AppImages.mountainSunrise,
    featuredDestinationIds: [],
  ),
  Province(
    id: 'laguna',
    name: 'Laguna',
    regionId: 'region-4a',
    regionName: 'CALABARZON',
    islandGroup: 'Luzon',
    hasContent: true,
    overview:
        "Known for Pagsanjan Falls' boat-shooting rapids, Los Baños and Calamba's natural hot springs, and "
        "Calamba as José Rizal's birthplace.",
    localCulture:
        'Tagalog-speaking, home to the University of the Philippines Los Baños; hot-spring resort culture runs '
        'deep in Los Baños and Calamba, fed by the province\'s volcanic geology.',
    bestTimeToVisit:
        "November to May (dry season) for Pagsanjan Falls' shooting-the-rapids boat ride.",
    estimatedDailyBudgetMin: 1200,
    estimatedDailyBudgetMax: 2800,
    travelTips: [
      "Pagsanjan Falls' boat ride will get you soaked — bring a dry bag for phones and cameras.",
      'The Rizal Shrine in Calamba is free to visit and a quick, worthwhile historical stop.',
      'Los Baños hot-spring resorts range widely in price — day-use rates are cheaper than overnight stays.',
    ],
    emergencyHotlines: _nationalHotlines,
    heroImageUrl: AppImages.jungleWaterfall,
    featuredDestinationIds: [],
  ),
  Province(
    id: 'quezon',
    name: 'Quezon',
    regionId: 'region-4a',
    regionName: 'CALABARZON',
    islandGroup: 'Luzon',
    hasContent: true,
    overview:
        "A large CALABARZON province stretching from Lucban's heritage streets to Quezon National Park's "
        'forest trails, and the Pahiyas Festival each May.',
    localCulture:
        'Tagalog-speaking with a strong Catholic agricultural heritage; the Pahiyas Festival\'s harvest '
        'offerings (kiping rice wafers decorating housefronts) are the province\'s signature tradition.',
    bestTimeToVisit:
        'May for the Pahiyas Festival itself, or November–April generally for drier weather.',
    estimatedDailyBudgetMin: 1200,
    estimatedDailyBudgetMax: 3000,
    travelTips: [
      'Pahiyas Festival (May 15) draws huge crowds to Lucban — book accommodations well in advance.',
      'Try Lucban longganisa, a distinctly garlicky, herb-flecked local sausage.',
      "Quezon's coastline and mountain areas are far apart — plan for significant travel time between them.",
    ],
    emergencyHotlines: _nationalHotlines,
    heroImageUrl: AppImages.greenValley,
    featuredDestinationIds: [],
  ),
  Province(
    id: 'rizal',
    name: 'Rizal',
    regionId: 'region-4a',
    regionName: 'CALABARZON',
    islandGroup: 'Luzon',
    hasContent: true,
    overview:
        "A hill-and-lake province bordering Metro Manila, home to Antipolo's pilgrimage church, the Masungi "
        'Georeserve\'s rope-and-ladder trails, and Pinto Art Museum.',
    localCulture:
        'Tagalog-speaking, closely tied to Metro Manila as a weekend getaway; Antipolo\'s Our Lady of Peace '
        'and Good Voyage shrine draws pilgrims year-round, especially during May\'s Alay Lakad.',
    bestTimeToVisit:
        'November to April for the driest hiking and outdoor-activity conditions.',
    estimatedDailyBudgetMin: 1200,
    estimatedDailyBudgetMax: 3000,
    travelTips: [
      'Masungi Georeserve requires advance online booking — walk-in slots are rarely available.',
      'Weekend traffic from Manila into Antipolo and Tanay can be heavy — a weekday visit is smoother.',
      'Pinto Art Museum is best paired with a nearby Antipolo lunch spot for a half-day trip.',
    ],
    emergencyHotlines: _nationalHotlines,
    heroImageUrl: AppImages.greenValley,
    featuredDestinationIds: [],
  ),

  // ---- MIMAROPA ----
  Province(
    id: 'marinduque',
    name: 'Marinduque',
    regionId: 'region-4b',
    regionName: 'MIMAROPA',
    islandGroup: 'Luzon',
    hasContent: true,
    overview:
        "A small, quiet island province best known nationwide for the Moriones Festival's elaborately masked "
        'Holy Week street performances.',
    localCulture:
        'Tagalog-speaking with strong Holy Week religious traditions; the Moriones mask-making craft is a '
        'distinct local art form passed through generations.',
    bestTimeToVisit:
        'Holy Week (March/April, date varies yearly) for the Moriones Festival, or the dry season generally '
        'for beach-hopping.',
    estimatedDailyBudgetMin: 1200,
    estimatedDailyBudgetMax: 2800,
    travelTips: [
      'Moriones Festival draws large domestic crowds during Holy Week — book ferry and lodging early.',
      'Marinduque is reached by ferry from Batangas or Lucena — check schedules, as sailings can be weather-dependent.',
      'The island is compact enough to circle by rented motorbike or tricycle in a day or two.',
    ],
    emergencyHotlines: _nationalHotlines,
    heroImageUrl: AppImages.tropicalIslandAerial,
    featuredDestinationIds: [],
  ),
  Province(
    id: 'occidental-mindoro',
    name: 'Occidental Mindoro',
    regionId: 'region-4b',
    regionName: 'MIMAROPA',
    islandGroup: 'Luzon',
    hasContent: true,
    overview:
        "Home to Apo Reef, the world's second-largest contiguous coral reef system, and Mt. Iglit-Baco "
        "National Park, sanctuary of the endangered tamaraw.",
    localCulture:
        'Home to Mangyan indigenous communities alongside Tagalog and Visayan settlers; the tamaraw, found only '
        'on Mindoro, is a source of local pride and the animal on the Philippine peso coin.',
    bestTimeToVisit:
        'November to May, when Apo Reef\'s waters are calmest for diving and snorkeling.',
    estimatedDailyBudgetMin: 1500,
    estimatedDailyBudgetMax: 3500,
    travelTips: [
      'Apo Reef is reached by a multi-hour boat crossing from Sablayan — liveaboard trips are common.',
      'Mt. Iglit-Baco tamaraw sightings require a permit and registered guide from the park office.',
      'Sablayan is the main jump-off town — book boat transfers a few days ahead.',
    ],
    emergencyHotlines: _nationalHotlines,
    heroImageUrl: AppImages.turquoiseWater,
    featuredDestinationIds: [],
  ),
  Province(
    id: 'oriental-mindoro',
    name: 'Oriental Mindoro',
    regionId: 'region-4b',
    regionName: 'MIMAROPA',
    islandGroup: 'Luzon',
    hasContent: true,
    overview:
        'Home to Puerto Galera, a bay-side dive and beach destination frequently ranked among the world\'s '
        "best diving spots, plus the province's own share of Mangyan-inhabited highlands.",
    localCulture:
        'Home to Mangyan indigenous groups alongside Tagalog and Visayan settlers; Puerto Galera\'s decades as '
        'an international dive destination give it a distinctly cosmopolitan beach-town character.',
    bestTimeToVisit:
        'November to May (dry season); diving visibility is generally best outside the wet months.',
    estimatedDailyBudgetMin: 1500,
    estimatedDailyBudgetMax: 3500,
    travelTips: [
      'Puerto Galera is reached by ferry from Batangas Port — check schedules, as sailings can be weather-dependent.',
      'White Beach and Sabang each have a different vibe — White Beach is quieter, Sabang more nightlife-focused.',
      'PADI dive certification courses are widely available for beginners in Puerto Galera.',
    ],
    emergencyHotlines: _nationalHotlines,
    heroImageUrl: AppImages.boatOnLagoon,
    featuredDestinationIds: [],
  ),
  Province(
    id: 'palawan',
    name: 'Palawan',
    regionId: 'region-4b',
    regionName: 'MIMAROPA',
    islandGroup: 'Luzon',
    hasContent: true,
    overview:
        "Stretching from El Nido's limestone lagoons to Puerto Princesa's Underground River, one of the "
        "Philippines' most internationally recognized island provinces.",
    localCulture:
        "Home to the Palaw'an, Tagbanua and Cuyunon indigenous communities alongside migrant settlers; a "
        "strong marine-conservation ethic given the province's reliance on reef tourism.",
    bestTimeToVisit:
        'November to May (dry season); island-hopping tours are frequently suspended during typhoons/rough '
        'seas from June–October.',
    estimatedDailyBudgetMin: 2000,
    estimatedDailyBudgetMax: 5000,
    travelTips: [
      'El Nido and Coron are both in Palawan but far apart by road — most visitors fly into one and boat/fly '
          'to the other rather than drive.',
      'Book Underground River slots in advance; daily visitor numbers are capped.',
      'Bring reef-safe sunscreen — regular sunscreen is discouraged or banned in several marine protected areas.',
    ],
    emergencyHotlines: _nationalHotlines,
    heroImageUrl: AppImages.elNidoLagoon,
    featuredDestinationIds: [],
  ),
  Province(
    id: 'romblon',
    name: 'Romblon',
    regionId: 'region-4b',
    regionName: 'MIMAROPA',
    islandGroup: 'Luzon',
    hasContent: true,
    overview:
        "An island-cluster province known nationwide as the country's marble-producing center, plus Carabao "
        "Island's Bounty Beach and Cobrador Island's clear waters.",
    localCulture:
        'Romblomanon, Onhan and Asi are the local languages across its three main islands; marble carving is a '
        'generations-old craft, with workshops still active around Romblon town.',
    bestTimeToVisit:
        'November to May (dry season), avoiding rougher inter-island boat crossings in the wet months.',
    estimatedDailyBudgetMin: 1200,
    estimatedDailyBudgetMax: 2800,
    travelTips: [
      'Romblon is made up of several islands connected by boat — plan inter-island transfers with buffer time.',
      'Marble souvenirs are sold directly by workshops in Romblon town, often cheaper than in Manila.',
      'Carabao Island (Bounty Beach) is quieter and less developed than nearby Boracay, a common comparison point.',
    ],
    emergencyHotlines: _nationalHotlines,
    heroImageUrl: AppImages.tropicalIslandAerial,
    featuredDestinationIds: [],
  ),

  // ---- Region V — Bicol Region ----
  Province(
    id: 'albay',
    name: 'Albay',
    regionId: 'region-5',
    regionName: 'Bicol Region',
    islandGroup: 'Luzon',
    hasContent: true,
    overview:
        "Home to the almost-perfect cone of Mayon Volcano, ATV and adventure tourism, and Bicol's famously "
        'spicy cuisine.',
    localCulture:
        'Bicolano cooking centers on coconut milk and chili (Bicol Express, laing), alongside deep local '
        'reverence for Mayon as a natural landmark.',
    bestTimeToVisit:
        'December to May (dry season); Mayon can be obscured by clouds and rain in the wet months.',
    estimatedDailyBudgetMin: 1500,
    estimatedDailyBudgetMax: 3500,
    travelTips: [
      "Mayon Volcano's alert level can change — check PHIVOLCS advisories before trekking near it.",
      "Bicolano food is genuinely spicy by Filipino standards — ask for 'hindi maanghang' if you prefer mild.",
      'Legazpi is the main jump-off point for Cagsawa Ruins and ATV rides on Mayon\'s slopes.',
    ],
    emergencyHotlines: _nationalHotlines,
    heroImageUrl: AppImages.mayonVolcano,
    featuredDestinationIds: [],
  ),
  Province(
    id: 'camarines-norte',
    name: 'Camarines Norte',
    regionId: 'region-5',
    regionName: 'Bicol Region',
    islandGroup: 'Luzon',
    hasContent: true,
    overview:
        'Known for Bagasbas Beach\'s surf breaks in Daet, and Calaguas Islands\' white-sand beaches, often '
        'compared to more developed island destinations further south.',
    localCulture:
        'Bicolano-speaking, sharing the region\'s coconut-and-chili cuisine; Daet holds the distinction of '
        'building the first monument to José Rizal in the country, in 1898.',
    bestTimeToVisit:
        'December to May (dry season), avoiding rougher boat crossings to Calaguas in the wet months.',
    estimatedDailyBudgetMin: 1200,
    estimatedDailyBudgetMax: 3000,
    travelTips: [
      'Calaguas is reached by boat from Vinzons or Paracale — arrange camping gear in advance, as the islands are undeveloped.',
      'Bagasbas Beach has surf schools offering board rentals and lessons for beginners.',
      'Bring cash — ATMs are limited outside Daet town proper.',
    ],
    emergencyHotlines: _nationalHotlines,
    heroImageUrl: AppImages.tropicalIslandAerial,
    featuredDestinationIds: [],
  ),
  Province(
    id: 'camarines-sur',
    name: 'Camarines Sur',
    regionId: 'region-5',
    regionName: 'Bicol Region',
    islandGroup: 'Luzon',
    hasContent: true,
    overview:
        'Home to the CamSur Watersports Complex, a world-class wakeboarding park, and the limestone-studded '
        'Caramoan Islands.',
    localCulture:
        "Bicolano, sharing the region's coconut-and-chili cuisine; provincial capital Naga City hosts the "
        'Peñafrancia Festival, one of the largest Marian devotions in the country, each September.',
    bestTimeToVisit:
        'December to May (dry season); the Peñafrancia Festival is held in mid-September.',
    estimatedDailyBudgetMin: 1200,
    estimatedDailyBudgetMax: 3000,
    travelTips: [
      'CWC wakeboarding packages include gear and instruction — book weekend slots ahead of time.',
      'Caramoan is reached by boat from Sabang port — check sea conditions before traveling in the wet season.',
      'Peñafrancia Festival draws large pilgrim crowds to Naga — expect heavier traffic and fuller lodging.',
    ],
    emergencyHotlines: _nationalHotlines,
    heroImageUrl: AppImages.palawanCliffs,
    featuredDestinationIds: [],
  ),
  Province(
    id: 'catanduanes',
    name: 'Catanduanes',
    regionId: 'region-5',
    regionName: 'Bicol Region',
    islandGroup: 'Luzon',
    hasContent: true,
    overview:
        'Known as the "Land of the Howling Winds" for its frequent typhoon exposure, home to Puraran Beach\'s '
        'surf break and Maribina Falls.',
    localCulture:
        'Bicolano-speaking, with a resilient, storm-hardened local identity shaped by the province\'s position '
        'directly in the Pacific typhoon corridor.',
    bestTimeToVisit:
        'March to May, the calmest stretch outside the peak June–December typhoon season.',
    estimatedDailyBudgetMin: 1000,
    estimatedDailyBudgetMax: 2500,
    travelTips: [
      'Check typhoon advisories closely before booking — Catanduanes is among the most frequently hit provinces.',
      'Puraran Beach has a right-hand surf break known locally as "Majestic," popular with intermediate surfers.',
      'Virac is the main jump-off point, reached by ferry from Tabaco, Albay, or by direct flight.',
    ],
    emergencyHotlines: _nationalHotlines,
    heroImageUrl: AppImages.turquoiseWater,
    featuredDestinationIds: [],
  ),
  Province(
    id: 'masbate',
    name: 'Masbate',
    regionId: 'region-5',
    regionName: 'Bicol Region',
    islandGroup: 'Luzon',
    hasContent: true,
    overview:
        'An island province known nationwide as a cattle-ranching center, plus the Ticao and Burias Pass '
        'whale shark and manta ray migration route.',
    localCulture:
        'Predominantly Cebuano- and Bicolano-speaking; the province\'s cattle-raising tradition has earned it '
        'the nickname "Rodeo Capital of the Philippines," celebrated in the Rodeo Masbateño festival each April.',
    bestTimeToVisit:
        'November to May (dry season); manta ray and whale shark sightings peak around February–May.',
    estimatedDailyBudgetMin: 1000,
    estimatedDailyBudgetMax: 2500,
    travelTips: [
      'Ticao Pass manta ray encounters are best arranged through a registered dive or snorkel operator.',
      'Masbate is reached by ferry from Bulan, Sorsogon, or Pilar, Cebu — check schedules ahead of travel.',
      'Rodeo Masbateño draws large crowds in April — book accommodations early if visiting then.',
    ],
    emergencyHotlines: _nationalHotlines,
    heroImageUrl: AppImages.boatOnLagoon,
    featuredDestinationIds: [],
  ),
  Province(
    id: 'sorsogon',
    name: 'Sorsogon',
    regionId: 'region-5',
    regionName: 'Bicol Region',
    islandGroup: 'Luzon',
    hasContent: true,
    overview:
        "Known for Donsol's whale shark (butanding) interaction site, one of the most reliable in the world, "
        'plus the Bulusan Volcano National Park.',
    localCulture:
        'Bicolano-speaking, with a coastal fishing heritage now shaped heavily by community-based whale shark '
        'ecotourism, which Donsol pioneered in the late 1990s.',
    bestTimeToVisit: 'November to June, the peak whale shark season in Donsol.',
    estimatedDailyBudgetMin: 1500,
    estimatedDailyBudgetMax: 3500,
    travelTips: [
      'Whale shark interactions in Donsol follow a strict no-touch code of conduct, briefed before every trip.',
      'Book Donsol whale shark tours through the official interaction center to support regulated ecotourism.',
      'Bulusan Volcano trekking requires registration at the park office and, at times, a guide.',
    ],
    emergencyHotlines: _nationalHotlines,
    heroImageUrl: AppImages.turquoiseWater,
    featuredDestinationIds: [],
  ),

  // ---- Region VI — Western Visayas ----
  Province(
    id: 'aklan',
    name: 'Aklan',
    regionId: 'region-6',
    regionName: 'Western Visayas',
    islandGroup: 'Visayas',
    hasContent: true,
    overview:
        "Home to Boracay, one of the world's most awarded beach destinations, along with the Ati-Atihan "
        'Festival in Kalibo every January.',
    localCulture:
        'Akeanon is the local language; Kalibo\'s Ati-Atihan is considered the "Mother of All Philippine '
        'Festivals," honoring the indigenous Ati people.',
    bestTimeToVisit:
        'November to May (dry season); Boracay periodically enforces environmental carrying-capacity limits, '
        'so booking ahead matters.',
    estimatedDailyBudgetMin: 2000,
    estimatedDailyBudgetMax: 5000,
    travelTips: [
      'Boracay requires an environmental fee on arrival — keep a valid ID and some cash ready.',
      'White Beach gets busy at sunset — Station 1 and the northern end are generally quieter.',
      'Kalibo (not Caticlan) is the airport some flights use — check which one your flight actually uses '
          'before booking a transfer.',
    ],
    emergencyHotlines: _nationalHotlines,
    heroImageUrl: AppImages.boracayBeach,
    featuredDestinationIds: [],
  ),
  Province(
    id: 'antique',
    name: 'Antique',
    regionId: 'region-6',
    regionName: 'Western Visayas',
    islandGroup: 'Visayas',
    hasContent: true,
    overview:
        'A mountain-and-coast province on Panay\'s western side, known for Mt. Madja-as trekking, Malumpati '
        'Cold Spring, and the annual Binirayan Festival honoring Panay\'s Malay settlers.',
    localCulture:
        'Kinaray-a is the dominant local language, distinct from the Hiligaynon spoken elsewhere on Panay; '
        'local legend holds that Malay datus first landed here, a story celebrated in the Binirayan Festival.',
    bestTimeToVisit:
        'December to May (dry season) for the most reliable trekking and river conditions.',
    estimatedDailyBudgetMin: 1000,
    estimatedDailyBudgetMax: 2500,
    travelTips: [
      'Mt. Madja-as is a multi-day climb — arrange a registered guide well in advance.',
      'Malumpati Cold Spring gets crowded on weekends and summer — a weekday visit is quieter.',
      'Antique\'s coastal road offers some of Panay\'s best sunset views, especially near Culasi.',
    ],
    emergencyHotlines: _nationalHotlines,
    heroImageUrl: AppImages.greenValley,
    featuredDestinationIds: [],
  ),
  Province(
    id: 'capiz',
    name: 'Capiz',
    regionId: 'region-6',
    regionName: 'Western Visayas',
    islandGroup: 'Visayas',
    hasContent: true,
    overview:
        'Known nationwide as the "Seafood Capital of the Philippines," home to the historic Panay Church and '
        'the translucent capiz shell industry that gave the province its name.',
    localCulture:
        'Hiligaynon-speaking, with a fishing- and aquaculture-based economy; capiz shells, once widely used '
        'for traditional window panes across the country, are still crafted into decor and souvenirs here.',
    bestTimeToVisit:
        'November to May (dry season) for the most comfortable travel conditions.',
    estimatedDailyBudgetMin: 1000,
    estimatedDailyBudgetMax: 2500,
    travelTips: [
      'Roxas City\'s Baybay Beach seafood strip is the go-to spot for fresh catch in the evening.',
      'Capiz shell products make for lightweight, distinctly local souvenirs.',
      'Panay Church, one of the largest in the region, is worth a stop for its coral-stone construction.',
    ],
    emergencyHotlines: _nationalHotlines,
    heroImageUrl: AppImages.grilledSeafood,
    featuredDestinationIds: [],
  ),
  Province(
    id: 'guimaras',
    name: 'Guimaras',
    regionId: 'region-6',
    regionName: 'Western Visayas',
    islandGroup: 'Visayas',
    hasContent: true,
    overview:
        "A small island province famous nationwide for growing what's widely considered the sweetest mangoes "
        "in the world, alongside quiet beaches like Alubihod and Guisi Lighthouse.",
    localCulture:
        'Hiligaynon-speaking, with an economy built around mango orchards; the annual Manggahan Festival each '
        'April celebrates the harvest with food fairs and cultural events.',
    bestTimeToVisit:
        'March to June for peak mango season, or November–May generally for drier weather.',
    estimatedDailyBudgetMin: 1000,
    estimatedDailyBudgetMax: 2500,
    travelTips: [
      'Guimaras is a short pump-boat ride from Iloilo City — ferries run frequently throughout the day.',
      'Buy mangoes directly from roadside stalls or farms for the freshest, best-priced fruit.',
      'Renting a motorbike or habal-habal is the easiest way to explore the island\'s beaches and viewpoints.',
    ],
    emergencyHotlines: _nationalHotlines,
    heroImageUrl: AppImages.tropicalIslandAerial,
    featuredDestinationIds: [],
  ),
  Province(
    id: 'iloilo',
    name: 'Iloilo',
    regionId: 'region-6',
    regionName: 'Western Visayas',
    islandGroup: 'Visayas',
    hasContent: true,
    overview:
        "Anchored by Iloilo City's restored Calle Real heritage district and the UNESCO-listed Miagao Church, "
        'with the Dinagyang Festival held every January.',
    localCulture:
        'Hiligaynon (Ilonggo)-speaking, known nationally for a gentle, hospitable reputation and La Paz batchoy, '
        "the pork-noodle soup that originated in the city's La Paz district.",
    bestTimeToVisit:
        'November to May (dry season); the Dinagyang Festival is held in late January.',
    estimatedDailyBudgetMin: 1200,
    estimatedDailyBudgetMax: 3000,
    travelTips: [
      'Dinagyang Festival draws heavy crowds — book accommodations months ahead if visiting in January.',
      "Try La Paz batchoy at its namesake district for the most authentic version.",
      "Miagao Church's carved coral-stone facade photographs best in late-afternoon light.",
    ],
    emergencyHotlines: _nationalHotlines,
    heroImageUrl: AppImages.streetParade,
    featuredDestinationIds: [],
  ),
  Province(
    id: 'negros-occidental',
    name: 'Negros Occidental',
    regionId: 'region-6',
    regionName: 'Western Visayas',
    islandGroup: 'Visayas',
    hasContent: true,
    overview:
        'Known as the "Sugar Bowl of the Philippines," home to Bacolod\'s MassKara Festival and the '
        'heritage haciendas and ancestral houses left by the province\'s sugar-baron era.',
    localCulture:
        'Hiligaynon-speaking; Bacolod is nicknamed the "City of Smiles," a reputation tied to the colorful, '
        'masked MassKara Festival first held in 1980 to lift spirits during a local economic crisis.',
    bestTimeToVisit:
        'November to May (dry season); MassKara Festival runs around October 19, Bacolod\'s Charter Day.',
    estimatedDailyBudgetMin: 1200,
    estimatedDailyBudgetMax: 3000,
    travelTips: [
      'MassKara Festival draws large crowds to Bacolod — book accommodations well ahead if visiting in October.',
      'Try Bacolod chicken inasal, a grilled-chicken dish distinct from other regional versions.',
      'The Ruins in Talisay, a preserved sugar-baron mansion, is a popular heritage stop just outside the city.',
    ],
    emergencyHotlines: _nationalHotlines,
    heroImageUrl: AppImages.festivalDancers,
    featuredDestinationIds: [],
  ),

  // ---- Region VII — Central Visayas ----
  Province(
    id: 'bohol',
    name: 'Bohol',
    regionId: 'region-7',
    regionName: 'Central Visayas',
    islandGroup: 'Visayas',
    hasContent: true,
    overview:
        "Home to the Chocolate Hills, tarsier sanctuaries, and the Loboc River, plus Panglao Island's "
        'white-sand beaches and dive sites.',
    localCulture:
        'Boholano-Cebuano culture with a strong Spanish-colonial church heritage — Baclayon Church is among '
        'the oldest in the country.',
    bestTimeToVisit:
        'December to May; for diving specifically, avoid the amihan-driven rough seas of December–February.',
    estimatedDailyBudgetMin: 1500,
    estimatedDailyBudgetMax: 3500,
    travelTips: [
      'Visit the Chocolate Hills early morning for cooler weather and better light.',
      'Tarsiers are nocturnal and easily stressed — keep voices low and never use flash photography at the sanctuary.',
      'Panglao and mainland Bohol are connected by bridge, so a single-base itinerary covering both is easy.',
    ],
    emergencyHotlines: _nationalHotlines,
    heroImageUrl: AppImages.chocolateHills,
    featuredDestinationIds: [],
  ),
  Province(
    id: 'cebu',
    name: 'Cebu',
    regionId: 'region-7',
    regionName: 'Central Visayas',
    islandGroup: 'Visayas',
    hasContent: true,
    overview:
        "A major island province blending Cebu City's urban energy with Moalboal's turtles, Kawasan Falls' "
        "canyoneering, and Oslob's whale sharks.",
    localCulture:
        'Cebuano (Bisaya) is the dominant language; Cebu is one of the oldest Spanish colonial settlements in '
        "the country, centered on the Basilica del Santo Niño and Magellan's Cross.",
    bestTimeToVisit:
        "December to May; the Sinulog Festival (January) is the province's biggest cultural draw.",
    estimatedDailyBudgetMin: 1500,
    estimatedDailyBudgetMax: 4000,
    travelTips: [
      'Book Kawasan Falls canyoneering with a certified guide — the route involves cliff jumps not suited to '
          'non-swimmers.',
      'Whale shark encounters in Oslob are best done early morning; follow the no-touch, no-flash guidelines.',
      'Cebu City traffic can be heavy — build in extra travel time between south Cebu spots.',
    ],
    emergencyHotlines: _nationalHotlines,
    heroImageUrl: AppImages.turquoiseWater,
    featuredDestinationIds: [],
  ),
  Province(
    id: 'negros-oriental',
    name: 'Negros Oriental',
    regionId: 'region-7',
    regionName: 'Central Visayas',
    islandGroup: 'Visayas',
    hasContent: true,
    overview:
        "Anchored by Dumaguete, the laid-back 'City of Gentle People,' with Apo Island's marine sanctuary and "
        'Casaroro Falls nearby.',
    localCulture:
        'Cebuano (Bisaya)-speaking; home to Silliman University, one of the oldest American-founded '
        "universities in Asia, giving Dumaguete a distinct academic-town character.",
    bestTimeToVisit:
        'March to May for the calmest diving conditions at Apo Island.',
    estimatedDailyBudgetMin: 1200,
    estimatedDailyBudgetMax: 3000,
    travelTips: [
      'Apo Island charges a marine sanctuary fee and caps daily diver/snorkeler numbers.',
      'Casaroro Falls requires a steep descent of roughly 200 steps each way.',
      "Rizal Boulevard along Dumaguete's waterfront is the local spot for an evening walk.",
    ],
    emergencyHotlines: _nationalHotlines,
    heroImageUrl: AppImages.tropicalIslandAerial,
    featuredDestinationIds: [],
  ),
  Province(
    id: 'siquijor',
    name: 'Siquijor',
    regionId: 'region-7',
    regionName: 'Central Visayas',
    islandGroup: 'Visayas',
    hasContent: true,
    overview:
        'A small island long associated with folk healing and mysticism, now also known for Cambugahay Falls\' '
        'tiered pools and its laid-back, largely undeveloped coastline.',
    localCulture:
        'Cebuano (Bisaya)-speaking; the island\'s reputation for traditional healers (mananambal) and folk '
        'medicine remains a distinct part of local identity, alongside a growing quiet-tourism scene.',
    bestTimeToVisit: 'March to May for the calmest seas and driest conditions.',
    estimatedDailyBudgetMin: 1000,
    estimatedDailyBudgetMax: 2500,
    travelTips: [
      'Siquijor is reached by ferry from Dumaguete or Cebu — check schedules ahead, especially in the wet season.',
      'Renting a motorbike is the easiest way to circle the island and its waterfalls.',
      'Cambugahay Falls has a rope swing into its lower pool — footwear with grip helps on the wet rocks.',
    ],
    emergencyHotlines: _nationalHotlines,
    heroImageUrl: AppImages.jungleWaterfall,
    featuredDestinationIds: [],
  ),

  // ---- Region VIII — Eastern Visayas ----
  Province(
    id: 'biliran',
    name: 'Biliran',
    regionId: 'region-8',
    regionName: 'Eastern Visayas',
    islandGroup: 'Visayas',
    hasContent: true,
    overview:
        'A small island province known for its natural hot and cold springs, plus the Sambawan Island '
        'day-trip destination just off its coast.',
    localCulture:
        'Waray- and Cebuano-speaking, connected to Leyte by a causeway bridge; local livelihoods center on '
        'fishing and small-scale farming.',
    bestTimeToVisit:
        'March to May, avoiding the wetter, typhoon-exposed later months.',
    estimatedDailyBudgetMin: 1000,
    estimatedDailyBudgetMax: 2500,
    travelTips: [
      'Biliran is reached by land from Tacloban via the causeway bridge — no ferry needed.',
      'Sambawan Island requires a short boat ride and charges a small environmental fee.',
      'Hot spring resorts near Biliran town make for an easy half-day stop.',
    ],
    emergencyHotlines: _nationalHotlines,
    heroImageUrl: AppImages.tropicalIslandAerial,
    featuredDestinationIds: [],
  ),
  Province(
    id: 'eastern-samar',
    name: 'Eastern Samar',
    regionId: 'region-8',
    regionName: 'Eastern Visayas',
    islandGroup: 'Visayas',
    hasContent: true,
    overview:
        'A rugged, Pacific-facing province best known as the first landfall of Ferdinand Magellan\'s 1521 '
        'expedition at Homonhon Island, and for its dramatic, largely undeveloped coastline.',
    localCulture:
        'Waray-speaking, with a fishing-based coastal economy shaped by frequent exposure to Pacific typhoons '
        '— the province was among the hardest hit by Typhoon Haiyan in 2013.',
    bestTimeToVisit:
        'March to May, the calmest stretch outside typhoon season.',
    estimatedDailyBudgetMin: 1000,
    estimatedDailyBudgetMax: 2500,
    travelTips: [
      'Eastern Samar has limited tourism infrastructure — arrange transport and lodging in Borongan ahead of time.',
      'Check typhoon advisories closely, as this coast is one of the country\'s most exposed.',
      'Borongan\'s Guiuan and Sulangan areas have quieter, less-visited beaches worth the extra travel time.',
    ],
    emergencyHotlines: _nationalHotlines,
    heroImageUrl: AppImages.boatOnLagoon,
    featuredDestinationIds: [],
  ),
  Province(
    id: 'leyte',
    name: 'Leyte',
    regionId: 'region-8',
    regionName: 'Eastern Visayas',
    islandGroup: 'Visayas',
    hasContent: true,
    overview:
        'Anchored by Tacloban City, site of General Douglas MacArthur\'s 1944 Leyte Landing, with the '
        'MacArthur Landing Memorial and Kalanggaman Island among its main draws.',
    localCulture:
        'Waray-speaking, with WWII history — the Leyte Landing marked the start of the Philippines\' liberation '
        '— remaining a strong part of local identity, alongside the Pintados-Kasadyaan Festival each June.',
    bestTimeToVisit:
        'March to May, the calmest stretch outside typhoon season.',
    estimatedDailyBudgetMin: 1000,
    estimatedDailyBudgetMax: 2500,
    travelTips: [
      'Kalanggaman Island requires a boat transfer from Palompon — arrange this a day ahead.',
      'The MacArthur Landing Memorial in Palo is free to visit and a quick historical stop.',
      'Leyte is prone to typhoons — check weather advisories, especially June–December.',
    ],
    emergencyHotlines: _nationalHotlines,
    heroImageUrl: AppImages.turquoiseWater,
    featuredDestinationIds: [],
  ),
  Province(
    id: 'northern-samar',
    name: 'Northern Samar',
    regionId: 'region-8',
    regionName: 'Eastern Visayas',
    islandGroup: 'Visayas',
    hasContent: true,
    overview:
        'A quiet, largely rural province known for the Biri Rock Formations\' wave-carved limestone islets '
        'along its northern coast.',
    localCulture:
        'Waray-speaking, with a fishing- and farming-based economy along a coastline shaped by constant '
        'exposure to Pacific waves and typhoons.',
    bestTimeToVisit:
        'March to May, the calmest stretch outside typhoon season.',
    estimatedDailyBudgetMin: 1000,
    estimatedDailyBudgetMax: 2500,
    travelTips: [
      'Biri Rock Formations are reached by boat from Biri town — go early, as waves build through the day.',
      'Northern Samar has limited tourism infrastructure — arrange transport and lodging in Catarman ahead of time.',
      'Check typhoon advisories before travel, especially June–December.',
    ],
    emergencyHotlines: _nationalHotlines,
    heroImageUrl: AppImages.boatOnLagoon,
    featuredDestinationIds: [],
  ),
  Province(
    id: 'samar',
    name: 'Samar',
    regionId: 'region-8',
    regionName: 'Eastern Visayas',
    islandGroup: 'Visayas',
    hasContent: true,
    overview:
        'Home to Sohoton Natural Bridge National Park\'s cave system and underground rivers, among the '
        'largest cave networks in the country.',
    localCulture:
        'Waray-speaking, with a farming and fishing economy; the province\'s extensive limestone karst terrain '
        'has made caving and spelunking a growing part of local tourism.',
    bestTimeToVisit:
        'March to May, when river levels inside the caves are calmest for exploration.',
    estimatedDailyBudgetMin: 1000,
    estimatedDailyBudgetMax: 2500,
    travelTips: [
      'Sohoton Caves require a registered guide and a boat transfer — arrange both through the Basey tourism office.',
      'Bring a dry bag — several of the cave routes involve wading or a short swim.',
      'Catbalogan is the main jump-off town for exploring the rest of the province.',
    ],
    emergencyHotlines: _nationalHotlines,
    heroImageUrl: AppImages.jungleWaterfall,
    featuredDestinationIds: [],
  ),
  Province(
    id: 'southern-leyte',
    name: 'Southern Leyte',
    regionId: 'region-8',
    regionName: 'Eastern Visayas',
    islandGroup: 'Visayas',
    hasContent: true,
    overview:
        'Known for Sogod Bay\'s whale shark encounters and the Limasawa Island site of the first recorded '
        'Catholic Mass in the Philippines in 1521.',
    localCulture:
        'Waray- and Cebuano-speaking, with a coastal fishing economy increasingly shaped by whale shark and '
        'diving ecotourism around Sogod Bay.',
    bestTimeToVisit:
        'November to May, with whale shark sightings most reliable November–May.',
    estimatedDailyBudgetMin: 1200,
    estimatedDailyBudgetMax: 3000,
    travelTips: [
      'Whale shark encounters in Sogod Bay follow a strict no-touch code of conduct, briefed before every trip.',
      'Limasawa Island requires a boat transfer — arrange this through a Sogod Bay-based operator.',
      'Padre Burgos and Panaon Island are the main jump-off points for diving and whale shark tours.',
    ],
    emergencyHotlines: _nationalHotlines,
    heroImageUrl: AppImages.turquoiseWater,
    featuredDestinationIds: [],
  ),

  // ---- Region IX — Zamboanga Peninsula ----
  Province(
    id: 'zamboanga-del-norte',
    name: 'Zamboanga del Norte',
    regionId: 'region-9',
    regionName: 'Zamboanga Peninsula',
    islandGroup: 'Mindanao',
    hasContent: true,
    overview:
        'Known for Dapitan City, where national hero José Rizal spent four years in exile, and the Dakak '
        'Beach Resort area on the province\'s northern coast.',
    localCulture:
        'Cebuano (Chavacano-influenced) and Subanen communities share the province; Dapitan\'s Rizal Shrine '
        'preserves the house and clinic where Rizal lived and practiced medicine during his exile.',
    bestTimeToVisit:
        'November to May (dry season) for the most comfortable travel conditions.',
    estimatedDailyBudgetMin: 1200,
    estimatedDailyBudgetMax: 3000,
    travelTips: [
      "Rizal Shrine in Dapitan is a worthwhile half-day stop for its historical detail.",
      'Dakak Beach Resort area has some of the province\'s best-developed tourism infrastructure.',
      'Dipolog City is the main airport gateway for the province.',
    ],
    emergencyHotlines: _nationalHotlines,
    heroImageUrl: AppImages.turquoiseWater,
    featuredDestinationIds: [],
  ),
  Province(
    id: 'zamboanga-del-sur',
    name: 'Zamboanga del Sur',
    regionId: 'region-9',
    regionName: 'Zamboanga Peninsula',
    islandGroup: 'Mindanao',
    hasContent: true,
    overview:
        'Home to Pagadian City, the province\'s commercial hub built around Pagadian Bay, and a mix of '
        'lowland farming towns and coastal fishing communities.',
    localCulture:
        'Cebuano-speaking, with Subanen indigenous communities in the interior highlands; the province\'s '
        'economy centers on farming, fishing, and Pagadian Bay\'s port trade.',
    bestTimeToVisit:
        'November to May (dry season) for the most comfortable travel conditions.',
    estimatedDailyBudgetMin: 1000,
    estimatedDailyBudgetMax: 2500,
    travelTips: [
      'Pagadian City is the main jump-off point for exploring the rest of the province.',
      'Tourism infrastructure outside Pagadian is limited — arrange transport ahead of time.',
      'Check current travel advisories for the region before planning a trip.',
    ],
    emergencyHotlines: _nationalHotlines,
    heroImageUrl: AppImages.greenValley,
    featuredDestinationIds: [],
  ),
  Province(
    id: 'zamboanga-sibugay',
    name: 'Zamboanga Sibugay',
    regionId: 'region-9',
    regionName: 'Zamboanga Peninsula',
    islandGroup: 'Mindanao',
    hasContent: true,
    overview:
        'One of the country\'s newer provinces, created in 2001, known for Sibuguey Bay\'s mangrove areas and '
        'quiet, less-touristed coastal towns.',
    localCulture:
        'Cebuano-speaking, with a fishing- and farming-based economy; the province was carved from '
        'Zamboanga del Sur to bring local governance closer to its coastal communities.',
    bestTimeToVisit:
        'November to May (dry season) for the most comfortable travel conditions.',
    estimatedDailyBudgetMin: 1000,
    estimatedDailyBudgetMax: 2500,
    travelTips: [
      'Zamboanga Sibugay has limited tourism infrastructure — arrange transport and lodging in Ipil ahead of time.',
      'Mangrove areas around Sibuguey Bay are best explored with a local boat guide.',
      'Check current travel advisories for the region before planning a trip.',
    ],
    emergencyHotlines: _nationalHotlines,
    heroImageUrl: AppImages.boatOnLagoon,
    featuredDestinationIds: [],
  ),

  // ---- Region X — Northern Mindanao ----
  Province(
    id: 'bukidnon',
    name: 'Bukidnon',
    regionId: 'region-10',
    regionName: 'Northern Mindanao',
    islandGroup: 'Mindanao',
    hasContent: true,
    overview:
        'A cool-climate plateau province known for Dahilayan Adventure Park\'s zipline, pineapple and '
        'vegetable farms, and the Kaamulan Festival honoring its indigenous Lumad groups.',
    localCulture:
        'Home to several Lumad indigenous groups, including the Bukidnon, Higaonon, and Talaandig; the '
        'Kaamulan Festival each March is one of the few Philippine festivals rooted directly in indigenous '
        'ritual rather than Catholic tradition.',
    bestTimeToVisit:
        'December to May, the coolest and driest stretch on the plateau.',
    estimatedDailyBudgetMin: 1200,
    estimatedDailyBudgetMax: 3000,
    travelTips: [
      'Bukidnon nights get noticeably cool — pack a light jacket even in the dry season.',
      'Dahilayan Adventure Park is best visited on weekdays to avoid the longest zipline queues.',
      'Kaamulan Festival in March features genuine indigenous rituals, not staged reenactments — dress and act respectfully.',
    ],
    emergencyHotlines: _nationalHotlines,
    heroImageUrl: AppImages.greenValley,
    featuredDestinationIds: [],
  ),
  Province(
    id: 'camiguin',
    name: 'Camiguin',
    regionId: 'region-10',
    regionName: 'Northern Mindanao',
    islandGroup: 'Mindanao',
    hasContent: true,
    overview:
        'A small volcanic island known as the "Island Born of Fire," home to the Sunken Cemetery, White '
        'Island sandbar, and more volcanoes per square kilometer than any other Philippine island.',
    localCulture:
        'Cebuano (Bisaya)-speaking; the Sunken Cemetery, submerged after a 1871 volcanic eruption, remains a '
        'marked, respected site rather than just a photo stop for locals.',
    bestTimeToVisit: 'March to May for the calmest seas and clearest skies.',
    estimatedDailyBudgetMin: 1200,
    estimatedDailyBudgetMax: 3000,
    travelTips: [
      'White Island is a bare sandbar with no shade — bring water, sun protection, and go early.',
      'Camiguin is reached by ferry from Balingoan (mainland Mindanao) or Cebu — check schedules ahead.',
      'Renting a motorbike is the easiest way to circle the island in a day.',
    ],
    emergencyHotlines: _nationalHotlines,
    heroImageUrl: AppImages.tropicalIslandAerial,
    featuredDestinationIds: [],
  ),
  Province(
    id: 'lanao-del-norte',
    name: 'Lanao del Norte',
    regionId: 'region-10',
    regionName: 'Northern Mindanao',
    islandGroup: 'Mindanao',
    hasContent: true,
    overview:
        'Home to Maria Cristina Falls, a major hydroelectric-power source known locally as the "Twin Falls" '
        'near Iligan City, one of the country\'s largest waterfall systems.',
    localCulture:
        'A mix of Cebuano-speaking settlers and Maranao communities; Iligan is nicknamed the "City of '
        'Majestic Waterfalls" for the dozens of falls within its jurisdiction.',
    bestTimeToVisit:
        'November to May (dry season) for the most comfortable travel conditions.',
    estimatedDailyBudgetMin: 1000,
    estimatedDailyBudgetMax: 2500,
    travelTips: [
      'Maria Cristina Falls has a public viewing deck reached by a short walk from the parking area.',
      "Iligan's other waterfalls (Tinago, Mimbalot) are best visited with a local guide, as some require a hike.",
      'Iligan is the main jump-off town for exploring the rest of the province.',
    ],
    emergencyHotlines: _nationalHotlines,
    heroImageUrl: AppImages.jungleWaterfall,
    featuredDestinationIds: [],
  ),
  Province(
    id: 'misamis-occidental',
    name: 'Misamis Occidental',
    regionId: 'region-10',
    regionName: 'Northern Mindanao',
    islandGroup: 'Mindanao',
    hasContent: true,
    overview:
        'A coastal province on Panguil Bay, home to the historic Tangub City and quiet fishing towns along '
        'the Mindanao mainland\'s northwestern edge.',
    localCulture:
        'Cebuano-speaking, with an economy centered on fishing and coconut farming along Panguil and Iligan '
        'Bays.',
    bestTimeToVisit:
        'November to May (dry season) for the most comfortable travel conditions.',
    estimatedDailyBudgetMin: 1000,
    estimatedDailyBudgetMax: 2500,
    travelTips: [
      'Oroquieta City is the provincial capital and main jump-off point for the province.',
      'Tourism infrastructure is limited outside the main towns — arrange transport ahead of time.',
      'Check current travel advisories for the region before planning a trip.',
    ],
    emergencyHotlines: _nationalHotlines,
    heroImageUrl: AppImages.boatOnLagoon,
    featuredDestinationIds: [],
  ),
  Province(
    id: 'misamis-oriental',
    name: 'Misamis Oriental',
    regionId: 'region-10',
    regionName: 'Northern Mindanao',
    islandGroup: 'Mindanao',
    hasContent: true,
    overview:
        'Anchored by Cagayan de Oro, Mindanao\'s "City of Golden Friendship" and a major whitewater rafting '
        'destination on the Cagayan de Oro River.',
    localCulture:
        'Cebuano-speaking, with Cagayan de Oro serving as a major commercial and university hub for '
        'northern Mindanao.',
    bestTimeToVisit:
        'November to May (dry season) for the most comfortable travel and rafting conditions.',
    estimatedDailyBudgetMin: 1200,
    estimatedDailyBudgetMax: 3000,
    travelTips: [
      'Whitewater rafting on the Cagayan de Oro River is offered in beginner and advanced routes — book through a licensed operator.',
      'Cagayan de Oro is a common jump-off point for trips to Camiguin and Bukidnon.',
      'Water levels for rafting are best after rainfall but can also close routes if too high — check with operators first.',
    ],
    emergencyHotlines: _nationalHotlines,
    heroImageUrl: AppImages.jungleWaterfall,
    featuredDestinationIds: [],
  ),

  // ---- Region XI — Davao Region ----
  Province(
    id: 'davao-de-oro',
    name: 'Davao de Oro',
    regionId: 'region-11',
    regionName: 'Davao Region',
    islandGroup: 'Mindanao',
    hasContent: true,
    overview:
        'A mineral-rich mountain province known for Mt. Diwata\'s (Mt. Diwalwal) small-scale gold mining, and '
        'Aliwagwag Falls, one of the tallest multi-tiered waterfalls in the country.',
    localCulture:
        'A mix of Cebuano-speaking settlers and Mansaka and other Lumad indigenous groups; small-scale mining '
        'has shaped much of the province\'s modern economy since the 1980s.',
    bestTimeToVisit:
        'March to May for the driest travel and trekking conditions.',
    estimatedDailyBudgetMin: 1000,
    estimatedDailyBudgetMax: 2500,
    travelTips: [
      'Aliwagwag Falls is reached via a stepped trail with multiple viewing platforms along the way.',
      'Tourism infrastructure is limited outside the main towns — arrange transport ahead of time.',
      'Nabunturan is the provincial capital and main jump-off point for the province.',
    ],
    emergencyHotlines: _nationalHotlines,
    heroImageUrl: AppImages.jungleWaterfall,
    featuredDestinationIds: [],
  ),
  Province(
    id: 'davao-del-norte',
    name: 'Davao del Norte',
    regionId: 'region-11',
    regionName: 'Davao Region',
    islandGroup: 'Mindanao',
    hasContent: true,
    overview:
        'Home to Tagum City and one of the country\'s largest banana-growing regions, alongside the '
        'Pangi Falls and New Corella cave system.',
    localCulture:
        'Cebuano-speaking, with an economy built heavily around banana, cacao, and other export-crop farming; '
        'Tagum is known for its clean, well-organized city planning.',
    bestTimeToVisit:
        'November to May (dry season) for the most comfortable travel conditions.',
    estimatedDailyBudgetMin: 1000,
    estimatedDailyBudgetMax: 2500,
    travelTips: [
      'Tagum City is the main jump-off point for exploring the rest of the province.',
      'Cacao and banana plantation tours are a distinctive local activity worth arranging in advance.',
      'Tourism infrastructure outside Tagum is still developing — plan accordingly.',
    ],
    emergencyHotlines: _nationalHotlines,
    heroImageUrl: AppImages.greenValley,
    featuredDestinationIds: [],
  ),
  Province(
    id: 'davao-del-sur',
    name: 'Davao del Sur',
    regionId: 'region-11',
    regionName: 'Davao Region',
    islandGroup: 'Mindanao',
    hasContent: true,
    overview:
        "Anchored by Davao City, one of Mindanao's major urban centers, and Mt. Apo, the Philippines' highest "
        'peak, on its western border.',
    localCulture:
        'An ethnically diverse mix of Cebuano-speaking settlers, Bagobo and other Lumad indigenous groups, '
        "and one of the country's most prominent Islamic communities.",
    bestTimeToVisit:
        'March to May for Mt. Apo trekking (avoiding wet-season trail closures); the Kadayawan Festival runs '
        'in August.',
    estimatedDailyBudgetMin: 1500,
    estimatedDailyBudgetMax: 3500,
    travelTips: [
      'Mt. Apo requires a permit and registered guide — arrange this well ahead of a climb.',
      'Davao City is known for strict public-safety ordinances (e.g. smoking bans in public areas) — they\'re '
          'enforced.',
      "Try durian at the Magsaysay Fruit Market if you're curious — it's a genuinely divisive local specialty.",
    ],
    emergencyHotlines: _nationalHotlines,
    heroImageUrl: AppImages.greenValley,
    featuredDestinationIds: [],
  ),
  Province(
    id: 'davao-occidental',
    name: 'Davao Occidental',
    regionId: 'region-11',
    regionName: 'Davao Region',
    islandGroup: 'Mindanao',
    hasContent: true,
    overview:
        'The Davao Region\'s newest province, created in 2013, known for the Punta Dumalag viewpoint and '
        'Sarangani Bay-facing coastal towns.',
    localCulture:
        'A mix of Cebuano-speaking settlers and Sama-Bajau and other indigenous coastal communities; the '
        'province was separated from Davao del Sur to give its island and coastal towns closer governance.',
    bestTimeToVisit:
        'November to May (dry season) for the most comfortable travel conditions.',
    estimatedDailyBudgetMin: 1000,
    estimatedDailyBudgetMax: 2500,
    travelTips: [
      'Malita is the provincial capital and main jump-off point for the province.',
      'Tourism infrastructure is still developing here — arrange transport and lodging ahead of time.',
      'Check current travel advisories for the region before planning a trip.',
    ],
    emergencyHotlines: _nationalHotlines,
    heroImageUrl: AppImages.boatOnLagoon,
    featuredDestinationIds: [],
  ),
  Province(
    id: 'davao-oriental',
    name: 'Davao Oriental',
    regionId: 'region-11',
    regionName: 'Davao Region',
    islandGroup: 'Mindanao',
    hasContent: true,
    overview:
        'Home to Mt. Hamiguitan, a UNESCO World Heritage-listed wildlife sanctuary, and Pujada Bay\'s '
        'protected marine seascape near Mati City.',
    localCulture:
        'A mix of Cebuano-speaking settlers and Mandaya and Kalagan indigenous groups; the province is known '
        'for a strong local conservation ethic tied to Mt. Hamiguitan\'s protected status.',
    bestTimeToVisit:
        'March to May for the driest trekking and diving conditions.',
    estimatedDailyBudgetMin: 1200,
    estimatedDailyBudgetMax: 3000,
    travelTips: [
      'Mt. Hamiguitan treks require a permit and registered guide from the park office in San Isidro.',
      'Dahican Beach near Mati is a popular surf and longboard spot with a laid-back local scene.',
      'Mati City is the main jump-off point for exploring the province.',
    ],
    emergencyHotlines: _nationalHotlines,
    heroImageUrl: AppImages.turquoiseWater,
    featuredDestinationIds: [],
  ),

  // ---- Region XII — SOCCSKSARGEN ----
  Province(
    id: 'cotabato',
    name: 'Cotabato',
    regionId: 'region-12',
    regionName: 'SOCCSKSARGEN',
    islandGroup: 'Mindanao',
    hasContent: true,
    overview:
        'Home to Asik-Asik Falls\' curtain-like cascade over a wide rock face, and Kidapawan City at the '
        'northern foot of Mt. Apo.',
    localCulture:
        'A mix of Cebuano-speaking settlers and Manobo and other Lumad indigenous groups; farming, '
        'particularly corn and rice, anchors much of the provincial economy.',
    bestTimeToVisit:
        'November to May (dry season) for the most comfortable travel conditions.',
    estimatedDailyBudgetMin: 1000,
    estimatedDailyBudgetMax: 2500,
    travelTips: [
      'Asik-Asik Falls involves a short hike and a series of steps down to the viewing area.',
      'Kidapawan is a common alternate jump-off point for Mt. Apo climbs.',
      'Tourism infrastructure outside Kidapawan is limited — plan transport ahead of time.',
    ],
    emergencyHotlines: _nationalHotlines,
    heroImageUrl: AppImages.jungleWaterfall,
    featuredDestinationIds: [],
  ),
  Province(
    id: 'sarangani',
    name: 'Sarangani',
    regionId: 'region-12',
    regionName: 'SOCCSKSARGEN',
    islandGroup: 'Mindanao',
    hasContent: true,
    overview:
        'A coastal province on Sarangani Bay known for Gumasa Beach\'s white sand, tuna fishing, and as the '
        'hometown province of boxer-turned-senator Manny Pacquiao.',
    localCulture:
        'A mix of Cebuano-speaking settlers and B\'laan and other indigenous groups; the province is one of '
        'the country\'s largest tuna-producing areas, centered on General Santos\' fishing port nearby.',
    bestTimeToVisit:
        'November to May (dry season) for the calmest bay conditions.',
    estimatedDailyBudgetMin: 1200,
    estimatedDailyBudgetMax: 3000,
    travelTips: [
      'Gumasa Beach in Glan is the main beach destination, a few hours from General Santos City.',
      'Fresh tuna is a local specialty — try it grilled or as sashimi near the coast.',
      'General Santos City is the main airport gateway for the province.',
    ],
    emergencyHotlines: _nationalHotlines,
    heroImageUrl: AppImages.turquoiseWater,
    featuredDestinationIds: [],
  ),
  Province(
    id: 'south-cotabato',
    name: 'South Cotabato',
    regionId: 'region-12',
    regionName: 'SOCCSKSARGEN',
    islandGroup: 'Mindanao',
    hasContent: true,
    overview:
        'Home to Lake Sebu, a highland lake town known for T\'boli weaving and the Seven Falls zipline '
        'circuit, plus Koronadal City, the region\'s capital.',
    localCulture:
        'Home to the T\'boli and B\'laan indigenous peoples; T\'boli t\'nalak weaving, made from abaca fiber '
        'and dyed using traditional ikat techniques, is a UNESCO-recognized living tradition.',
    bestTimeToVisit:
        'November to May (dry season) for the driest highland travel conditions.',
    estimatedDailyBudgetMin: 1200,
    estimatedDailyBudgetMax: 3000,
    travelTips: [
      'Lake Sebu\'s Seven Falls zipline connects several of the falls — book at the park entrance.',
      'T\'nalak cloth is a meaningful, locally made souvenir — buy directly from T\'boli weaving centers.',
      'Lake Sebu gets cool in the evenings — pack a light jacket.',
    ],
    emergencyHotlines: _nationalHotlines,
    heroImageUrl: AppImages.greenValley,
    featuredDestinationIds: [],
  ),
  Province(
    id: 'sultan-kudarat',
    name: 'Sultan Kudarat',
    regionId: 'region-12',
    regionName: 'SOCCSKSARGEN',
    islandGroup: 'Mindanao',
    hasContent: true,
    overview:
        'Home to the Lake Buluan wetlands and Bagas Falls, a farming-and-fishing province named after the '
        'historic Sultan Muhammad Kudarat of Maguindanao.',
    localCulture:
        'A mix of Maguindanaon, Cebuano, and Ilocano settlers alongside indigenous Dulangan Manobo '
        'communities; farming and freshwater fishing around Lake Buluan anchor much of local life.',
    bestTimeToVisit:
        'November to May (dry season) for the most comfortable travel conditions.',
    estimatedDailyBudgetMin: 1000,
    estimatedDailyBudgetMax: 2500,
    travelTips: [
      'Isulan is the provincial capital and main jump-off point for the province.',
      'Tourism infrastructure is still developing here — arrange transport and lodging ahead of time.',
      'Check current travel advisories for the region before planning a trip.',
    ],
    emergencyHotlines: _nationalHotlines,
    heroImageUrl: AppImages.greenValley,
    featuredDestinationIds: [],
  ),

  // ---- Region XIII — Caraga ----
  Province(
    id: 'agusan-del-norte',
    name: 'Agusan del Norte',
    regionId: 'region-13',
    regionName: 'Caraga',
    islandGroup: 'Mindanao',
    hasContent: true,
    overview:
        'Home to Butuan City, one of the oldest settlements in the Philippines and a center of pre-colonial '
        'balangay (plank boat) archaeology, plus the Agusan River delta.',
    localCulture:
        'Cebuano-speaking, with a strong sense of pre-colonial history — Butuan\'s balangay boat finds are '
        'among the oldest watercraft discovered in Southeast Asia.',
    bestTimeToVisit:
        'March to May, the calmest stretch outside typhoon season.',
    estimatedDailyBudgetMin: 1000,
    estimatedDailyBudgetMax: 2500,
    travelTips: [
      'The Balangay Shrine Museum in Butuan houses excavated boat remains dating back over a thousand years.',
      'Butuan is the main airport gateway and jump-off point for the Caraga region.',
      'Agusan Marsh Wildlife Sanctuary tours are best arranged through the local tourism office.',
    ],
    emergencyHotlines: _nationalHotlines,
    heroImageUrl: AppImages.greenValley,
    featuredDestinationIds: [],
  ),
  Province(
    id: 'agusan-del-sur',
    name: 'Agusan del Sur',
    regionId: 'region-13',
    regionName: 'Caraga',
    islandGroup: 'Mindanao',
    hasContent: true,
    overview:
        'Home to the Agusan Marsh Wildlife Sanctuary, one of the largest freshwater wetlands in the country '
        'and a haven for migratory birds and the endangered Philippine crocodile.',
    localCulture:
        'A mix of Cebuano-speaking settlers and Manobo indigenous communities, many of whom live in floating '
        'or stilt houses within the marsh itself.',
    bestTimeToVisit:
        'March to May, the driest stretch for exploring the marsh by boat.',
    estimatedDailyBudgetMin: 1000,
    estimatedDailyBudgetMax: 2500,
    travelTips: [
      'Agusan Marsh boat tours are best arranged through the local tourism office in San Francisco or Bunawan.',
      'Bring insect repellent — the wetland environment has a significant mosquito presence.',
      'Water levels in the marsh vary seasonally, affecting which areas are accessible by boat.',
    ],
    emergencyHotlines: _nationalHotlines,
    heroImageUrl: AppImages.jungleWaterfall,
    featuredDestinationIds: [],
  ),
  Province(
    id: 'dinagat-islands',
    name: 'Dinagat Islands',
    regionId: 'region-13',
    regionName: 'Caraga',
    islandGroup: 'Mindanao',
    hasContent: true,
    overview:
        'A cluster of islands off Mindanao\'s northeastern tip, known for limestone rock formations, '
        'mangrove forests, and largely undeveloped beaches.',
    localCulture:
        'Cebuano- and Surigaonon-speaking, with a fishing- and mining-based economy; the province was '
        'formally established through a plebiscite in 2006, one of the country\'s newest.',
    bestTimeToVisit:
        'March to May, the calmest stretch outside typhoon season.',
    estimatedDailyBudgetMin: 1000,
    estimatedDailyBudgetMax: 2500,
    travelTips: [
      'Dinagat Islands are reached by boat from Surigao City — check schedules ahead of travel.',
      'Tourism infrastructure is still developing here — arrange transport and lodging in advance.',
      'Britania Group of Islands, technically in Surigao del Sur, is often combined with a Dinagat itinerary.',
    ],
    emergencyHotlines: _nationalHotlines,
    heroImageUrl: AppImages.tropicalIslandAerial,
    featuredDestinationIds: [],
  ),
  Province(
    id: 'surigao-del-norte',
    name: 'Surigao del Norte',
    regionId: 'region-13',
    regionName: 'Caraga',
    islandGroup: 'Mindanao',
    hasContent: true,
    overview:
        'The "surfing capital of the Philippines," anchored by Siargao\'s Cloud 9 break, alongside '
        'lagoon-hopping and island-hopping around General Luna.',
    localCulture:
        'A laid-back surf-town culture layered over traditional Surigaonon fishing communities; increasingly '
        'shaped by a growing digital-nomad and eco-tourism scene.',
    bestTimeToVisit:
        'Surf season (bigger swells) runs roughly August–November; calmer, more beginner-friendly water '
        'conditions run March–May.',
    estimatedDailyBudgetMin: 1500,
    estimatedDailyBudgetMax: 4000,
    travelTips: [
      "Cloud 9's reef break is for experienced surfers — beginners should start at gentler breaks nearby.",
      'Rent a scooter to get around General Luna; distances between spots are longer than they look on a map.',
      'Siargao sits on a typhoon-prone stretch — check weather before travel during the wet season.',
    ],
    emergencyHotlines: _nationalHotlines,
    heroImageUrl: AppImages.siargaoCloud9,
    featuredDestinationIds: [],
  ),
  Province(
    id: 'surigao-del-sur',
    name: 'Surigao del Sur',
    regionId: 'region-13',
    regionName: 'Caraga',
    islandGroup: 'Mindanao',
    hasContent: true,
    overview:
        "Known for Tinuy-an Falls' wide tiered cascades and Britania Islands' hidden lagoons, a quieter "
        'alternative to nearby Siargao.',
    localCulture:
        'A mix of Surigaonon and Boholano-descended coastal communities; livelihoods center on fishing and, '
        'increasingly, ecotourism around Bislig.',
    bestTimeToVisit:
        'March to May for calmer seas and fuller falls without peak wet-season flooding.',
    estimatedDailyBudgetMin: 1200,
    estimatedDailyBudgetMax: 3000,
    travelTips: [
      "Tinuy-an Falls' flow is strongest just after the wet season — expect a more turquoise, gentler flow in "
          'summer.',
      'Britania Islands requires a boat transfer from Hinatuan — arrange this a day ahead.',
      'Cell signal is patchy outside Bislig proper; download offline maps beforehand.',
    ],
    emergencyHotlines: _nationalHotlines,
    heroImageUrl: AppImages.tinuyanFalls,
    featuredDestinationIds: [],
  ),

  // ---- BARMM — Bangsamoro Autonomous Region in Muslim Mindanao ----
  Province(
    id: 'basilan',
    name: 'Basilan',
    regionId: 'barmm',
    regionName: 'Bangsamoro Autonomous Region in Muslim Mindanao',
    islandGroup: 'Mindanao',
    hasContent: true,
    overview:
        "An island province off Zamboanga City known for Malamawi Island's beaches and the Yakan people's "
        'distinctive handwoven textiles.',
    localCulture:
        'Home to the Yakan people, whose intricately patterned handloom weaving remains a defining local '
        'craft, alongside Tausug and Chavacano-influenced communities.',
    bestTimeToVisit: 'November to May (dry season).',
    estimatedDailyBudgetMin: 1000,
    estimatedDailyBudgetMax: 2500,
    travelTips: [
      'Check current travel advisories before planning a visit — parts of the province have limited tourism infrastructure.',
      'Malamawi Island is reached by a short boat ride from Isabela City.',
      'Yakan weaving is sold at the Yakan Weaving Village in Lamitan — a meaningful, locally made souvenir.',
    ],
    emergencyHotlines: _nationalHotlines,
    heroImageUrl: AppImages.traditionalCostume,
    featuredDestinationIds: [],
  ),
  Province(
    id: 'lanao-del-sur',
    name: 'Lanao del Sur',
    regionId: 'barmm',
    regionName: 'Bangsamoro Autonomous Region in Muslim Mindanao',
    islandGroup: 'Mindanao',
    hasContent: true,
    overview:
        "Centered on Lake Lanao, the country's second-largest lake, and Marawi City, the cultural heart of "
        'the Maranao people.',
    localCulture:
        'Home to the Maranao people, known for brass and silver craftsmanship and malong weaving, alongside '
        'the Darangen, a UNESCO-recognized sung epic passed down through generations.',
    bestTimeToVisit: 'November to May (dry season).',
    estimatedDailyBudgetMin: 1000,
    estimatedDailyBudgetMax: 2500,
    travelTips: [
      'Check current travel advisories before planning a visit, particularly around Marawi.',
      'Maranao brassware and malong cloth are available at local markets and make distinctive souvenirs.',
      "Lake Lanao's cooler highland climate is a contrast to lowland Mindanao — pack accordingly.",
    ],
    emergencyHotlines: _nationalHotlines,
    heroImageUrl: AppImages.greenValley,
    featuredDestinationIds: [],
  ),
  Province(
    id: 'maguindanao-del-norte',
    name: 'Maguindanao del Norte',
    regionId: 'barmm',
    regionName: 'Bangsamoro Autonomous Region in Muslim Mindanao',
    islandGroup: 'Mindanao',
    hasContent: true,
    overview:
        'One of two provinces formed from the 2022 split of Maguindanao, centered on the Rio Grande de '
        'Mindanao and its surrounding rice-farming plains.',
    localCulture:
        "Home to the Maguindanaon people, whose sultanate history and kulintang gong ensemble music remain "
        'central to local cultural identity.',
    bestTimeToVisit: 'November to May (dry season).',
    estimatedDailyBudgetMin: 1000,
    estimatedDailyBudgetMax: 2500,
    travelTips: [
      'Check current travel advisories before planning a visit.',
      'Kulintang gong music is a distinctive Maguindanaon art form, often performed at community celebrations.',
      'Tourism infrastructure is still developing here — arrange transport and lodging in advance.',
    ],
    emergencyHotlines: _nationalHotlines,
    heroImageUrl: AppImages.greenValley,
    featuredDestinationIds: [],
  ),
  Province(
    id: 'maguindanao-del-sur',
    name: 'Maguindanao del Sur',
    regionId: 'barmm',
    regionName: 'Bangsamoro Autonomous Region in Muslim Mindanao',
    islandGroup: 'Mindanao',
    hasContent: true,
    overview:
        "The southern half of the 2022 Maguindanao split, covering rice-farming plains and Liguasan Marsh's "
        'wetlands along the Rio Grande de Mindanao.',
    localCulture:
        'Home to the Maguindanaon people, sharing the region\'s sultanate history and kulintang gong musical '
        'tradition.',
    bestTimeToVisit: 'November to May (dry season).',
    estimatedDailyBudgetMin: 1000,
    estimatedDailyBudgetMax: 2500,
    travelTips: [
      'Check current travel advisories before planning a visit.',
      "Liguasan Marsh is one of Mindanao's largest wetlands, home to significant birdlife.",
      'Tourism infrastructure is still developing here — arrange transport and lodging in advance.',
    ],
    emergencyHotlines: _nationalHotlines,
    heroImageUrl: AppImages.greenValley,
    featuredDestinationIds: [],
  ),
  Province(
    id: 'sulu',
    name: 'Sulu',
    regionId: 'barmm',
    regionName: 'Bangsamoro Autonomous Region in Muslim Mindanao',
    islandGroup: 'Mindanao',
    hasContent: true,
    overview:
        'An island province historically the seat of the Sulu Sultanate, known for pearl and seaweed farming '
        "and the Tausug people's seafaring heritage.",
    localCulture:
        'Home to the Tausug people, whose sultanate — once a major regional power trading across the Sulu '
        'and Celebes Seas — remains a defining part of local identity.',
    bestTimeToVisit: 'November to May (dry season).',
    estimatedDailyBudgetMin: 1000,
    estimatedDailyBudgetMax: 2500,
    travelTips: [
      'Check current travel advisories before planning a visit — Sulu has had limited independent tourism access.',
      "Sulu was historically one of the world's major sources of South Sea pearls.",
      'Jolo is the provincial capital and main entry point for the province.',
    ],
    emergencyHotlines: _nationalHotlines,
    heroImageUrl: AppImages.boatOnLagoon,
    featuredDestinationIds: [],
  ),
  Province(
    id: 'tawi-tawi',
    name: 'Tawi-Tawi',
    regionId: 'barmm',
    regionName: 'Bangsamoro Autonomous Region in Muslim Mindanao',
    islandGroup: 'Mindanao',
    hasContent: true,
    overview:
        "The Philippines' southernmost province, home to the Turtle Islands Wildlife Sanctuary, a major "
        'green and hawksbill sea turtle nesting site.',
    localCulture:
        'Home to the Sama-Bajau people, renowned seafarers whose traditional houseboats and stilt-house '
        'communities reflect a deeply ocean-based way of life.',
    bestTimeToVisit: 'November to May (dry season).',
    estimatedDailyBudgetMin: 1200,
    estimatedDailyBudgetMax: 3000,
    travelTips: [
      'Check current travel advisories before planning a visit.',
      'Turtle Islands access is regulated for conservation — arrange visits through the wildlife sanctuary office.',
      'Bud Bongao, a mountain considered sacred locally, offers a trek with panoramic island views.',
    ],
    emergencyHotlines: _nationalHotlines,
    heroImageUrl: AppImages.turquoiseWater,
    featuredDestinationIds: [],
  ),
];
