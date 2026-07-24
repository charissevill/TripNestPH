import '../../core/constants/app_images.dart';
import '../../domain/models/province.dart';

/// All 82 official Philippine provinces plus the `metro-manila`
/// NCR pseudo-province (see [Province]'s doc comment for why) — 83 docs
/// total, seeded once via `tool/seed_firestore.js`.
///
/// Only the ~15 provinces this app already has real destination/restaurant/
/// festival content for (see the migration table in the Phase 1 plan) get
/// real page copy (`hasContent: true`) — general, well-established facts
/// only (season timing, the nationwide 911 hotline, well-known cultural
/// notes), never invented business-level specifics. Every other province is
/// taxonomy-only (`hasContent: false`) and renders a "content coming soon"
/// state on its province page until real copy is added, e.g. via a future
/// Admin/LGU Portal.
const _nationalHotlines = [EmergencyHotline(label: 'National Emergency Hotline', number: '911')];

/// A taxonomy-only province — id/name/region, no page content yet.
Province _bare(String id, String name, String regionId, String regionName, String islandGroup) {
  return Province(id: id, name: name, regionId: regionId, regionName: regionName, islandGroup: islandGroup);
}

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
    bestTimeToVisit: 'November to February, the coolest and driest stretch, is most comfortable for walking tours.',
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
  _bare('abra', 'Abra', 'car', 'Cordillera Administrative Region', 'Luzon'),
  _bare('apayao', 'Apayao', 'car', 'Cordillera Administrative Region', 'Luzon'),
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
  _bare('kalinga', 'Kalinga', 'car', 'Cordillera Administrative Region', 'Luzon'),
  _bare('mountain-province', 'Mountain Province', 'car', 'Cordillera Administrative Region', 'Luzon'),

  // ---- Region I — Ilocos Region ----
  _bare('ilocos-norte', 'Ilocos Norte', 'region-1', 'Ilocos Region', 'Luzon'),
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
    bestTimeToVisit: 'November to April, avoiding the wetter, typhoon-prone middle months.',
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
  _bare('la-union', 'La Union', 'region-1', 'Ilocos Region', 'Luzon'),
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
  _bare('batanes', 'Batanes', 'region-2', 'Cagayan Valley', 'Luzon'),
  _bare('cagayan', 'Cagayan', 'region-2', 'Cagayan Valley', 'Luzon'),
  _bare('isabela', 'Isabela', 'region-2', 'Cagayan Valley', 'Luzon'),
  _bare('nueva-vizcaya', 'Nueva Vizcaya', 'region-2', 'Cagayan Valley', 'Luzon'),
  _bare('quirino', 'Quirino', 'region-2', 'Cagayan Valley', 'Luzon'),

  // ---- Region III — Central Luzon ----
  _bare('aurora', 'Aurora', 'region-3', 'Central Luzon', 'Luzon'),
  _bare('bataan', 'Bataan', 'region-3', 'Central Luzon', 'Luzon'),
  _bare('bulacan', 'Bulacan', 'region-3', 'Central Luzon', 'Luzon'),
  _bare('nueva-ecija', 'Nueva Ecija', 'region-3', 'Central Luzon', 'Luzon'),
  _bare('pampanga', 'Pampanga', 'region-3', 'Central Luzon', 'Luzon'),
  _bare('tarlac', 'Tarlac', 'region-3', 'Central Luzon', 'Luzon'),
  _bare('zambales', 'Zambales', 'region-3', 'Central Luzon', 'Luzon'),

  // ---- Region IV-A — CALABARZON ----
  _bare('batangas', 'Batangas', 'region-4a', 'CALABARZON', 'Luzon'),
  _bare('cavite', 'Cavite', 'region-4a', 'CALABARZON', 'Luzon'),
  _bare('laguna', 'Laguna', 'region-4a', 'CALABARZON', 'Luzon'),
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
    bestTimeToVisit: 'May for the Pahiyas Festival itself, or November–April generally for drier weather.',
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
  _bare('rizal', 'Rizal', 'region-4a', 'CALABARZON', 'Luzon'),

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
  _bare('occidental-mindoro', 'Occidental Mindoro', 'region-4b', 'MIMAROPA', 'Luzon'),
  _bare('oriental-mindoro', 'Oriental Mindoro', 'region-4b', 'MIMAROPA', 'Luzon'),
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
  _bare('romblon', 'Romblon', 'region-4b', 'MIMAROPA', 'Luzon'),

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
    bestTimeToVisit: 'December to May (dry season); Mayon can be obscured by clouds and rain in the wet months.',
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
  _bare('camarines-norte', 'Camarines Norte', 'region-5', 'Bicol Region', 'Luzon'),
  _bare('camarines-sur', 'Camarines Sur', 'region-5', 'Bicol Region', 'Luzon'),
  _bare('catanduanes', 'Catanduanes', 'region-5', 'Bicol Region', 'Luzon'),
  _bare('masbate', 'Masbate', 'region-5', 'Bicol Region', 'Luzon'),
  _bare('sorsogon', 'Sorsogon', 'region-5', 'Bicol Region', 'Luzon'),

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
  _bare('antique', 'Antique', 'region-6', 'Western Visayas', 'Visayas'),
  _bare('capiz', 'Capiz', 'region-6', 'Western Visayas', 'Visayas'),
  _bare('guimaras', 'Guimaras', 'region-6', 'Western Visayas', 'Visayas'),
  _bare('iloilo', 'Iloilo', 'region-6', 'Western Visayas', 'Visayas'),
  _bare('negros-occidental', 'Negros Occidental', 'region-6', 'Western Visayas', 'Visayas'),

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
    bestTimeToVisit: "December to May; the Sinulog Festival (January) is the province's biggest cultural draw.",
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
  _bare('negros-oriental', 'Negros Oriental', 'region-7', 'Central Visayas', 'Visayas'),
  _bare('siquijor', 'Siquijor', 'region-7', 'Central Visayas', 'Visayas'),

  // ---- Region VIII — Eastern Visayas ----
  _bare('biliran', 'Biliran', 'region-8', 'Eastern Visayas', 'Visayas'),
  _bare('eastern-samar', 'Eastern Samar', 'region-8', 'Eastern Visayas', 'Visayas'),
  _bare('leyte', 'Leyte', 'region-8', 'Eastern Visayas', 'Visayas'),
  _bare('northern-samar', 'Northern Samar', 'region-8', 'Eastern Visayas', 'Visayas'),
  _bare('samar', 'Samar', 'region-8', 'Eastern Visayas', 'Visayas'),
  _bare('southern-leyte', 'Southern Leyte', 'region-8', 'Eastern Visayas', 'Visayas'),

  // ---- Region IX — Zamboanga Peninsula ----
  _bare('zamboanga-del-norte', 'Zamboanga del Norte', 'region-9', 'Zamboanga Peninsula', 'Mindanao'),
  _bare('zamboanga-del-sur', 'Zamboanga del Sur', 'region-9', 'Zamboanga Peninsula', 'Mindanao'),
  _bare('zamboanga-sibugay', 'Zamboanga Sibugay', 'region-9', 'Zamboanga Peninsula', 'Mindanao'),

  // ---- Region X — Northern Mindanao ----
  _bare('bukidnon', 'Bukidnon', 'region-10', 'Northern Mindanao', 'Mindanao'),
  _bare('camiguin', 'Camiguin', 'region-10', 'Northern Mindanao', 'Mindanao'),
  _bare('lanao-del-norte', 'Lanao del Norte', 'region-10', 'Northern Mindanao', 'Mindanao'),
  _bare('misamis-occidental', 'Misamis Occidental', 'region-10', 'Northern Mindanao', 'Mindanao'),
  _bare('misamis-oriental', 'Misamis Oriental', 'region-10', 'Northern Mindanao', 'Mindanao'),

  // ---- Region XI — Davao Region ----
  _bare('davao-de-oro', 'Davao de Oro', 'region-11', 'Davao Region', 'Mindanao'),
  _bare('davao-del-norte', 'Davao del Norte', 'region-11', 'Davao Region', 'Mindanao'),
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
  _bare('davao-occidental', 'Davao Occidental', 'region-11', 'Davao Region', 'Mindanao'),
  _bare('davao-oriental', 'Davao Oriental', 'region-11', 'Davao Region', 'Mindanao'),

  // ---- Region XII — SOCCSKSARGEN ----
  _bare('cotabato', 'Cotabato', 'region-12', 'SOCCSKSARGEN', 'Mindanao'),
  _bare('sarangani', 'Sarangani', 'region-12', 'SOCCSKSARGEN', 'Mindanao'),
  _bare('south-cotabato', 'South Cotabato', 'region-12', 'SOCCSKSARGEN', 'Mindanao'),
  _bare('sultan-kudarat', 'Sultan Kudarat', 'region-12', 'SOCCSKSARGEN', 'Mindanao'),

  // ---- Region XIII — Caraga ----
  _bare('agusan-del-norte', 'Agusan del Norte', 'region-13', 'Caraga', 'Mindanao'),
  _bare('agusan-del-sur', 'Agusan del Sur', 'region-13', 'Caraga', 'Mindanao'),
  _bare('dinagat-islands', 'Dinagat Islands', 'region-13', 'Caraga', 'Mindanao'),
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
    bestTimeToVisit: 'March to May for calmer seas and fuller falls without peak wet-season flooding.',
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
  _bare('basilan', 'Basilan', 'barmm', 'Bangsamoro Autonomous Region in Muslim Mindanao', 'Mindanao'),
  _bare('lanao-del-sur', 'Lanao del Sur', 'barmm', 'Bangsamoro Autonomous Region in Muslim Mindanao', 'Mindanao'),
  _bare(
    'maguindanao-del-norte',
    'Maguindanao del Norte',
    'barmm',
    'Bangsamoro Autonomous Region in Muslim Mindanao',
    'Mindanao',
  ),
  _bare(
    'maguindanao-del-sur',
    'Maguindanao del Sur',
    'barmm',
    'Bangsamoro Autonomous Region in Muslim Mindanao',
    'Mindanao',
  ),
  _bare('sulu', 'Sulu', 'barmm', 'Bangsamoro Autonomous Region in Muslim Mindanao', 'Mindanao'),
  _bare('tawi-tawi', 'Tawi-Tawi', 'barmm', 'Bangsamoro Autonomous Region in Muslim Mindanao', 'Mindanao'),
];
