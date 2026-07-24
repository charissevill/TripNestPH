/// Curated, stable Unsplash photo URLs used as stand-ins for real
/// destination/restaurant/festival photography in this mock-data phase.
///
/// Grouped by theme so mock-data files can pick images that match the
/// vibe of each entry (beach, mountain, waterfall, heritage street, food,
/// festival crowd, etc.) without hot-linking anything that could 404.
class AppImages {
  AppImages._();

  static const String _base = 'https://images.unsplash.com/photo-';
  static const String _params = '?auto=format&fit=crop&w=1200&q=80';

  static String _u(String id) => '$_base$id$_params';

  // ---- Beaches & islands ----
  static final String boracayBeach = _u('1519046904884-53103b34b206');
  static final String elNidoLagoon = _u('1552733407-5d5c46c3bb3b');
  static final String siargaoCloud9 = _u('1544551763-46a013bb70d5');
  static final String hundredIslands = _u('1439405326854-014607f694d7');
  static final String palawanCliffs = _u('1573790387438-4da905039392');
  static final String turquoiseWater = _u('1507525428034-b723cf961d3e');
  static final String tropicalIslandAerial = _u('1573843981267-be1999ff37cd');
  static final String boatOnLagoon = _u('1544644181-1484b3fdfc62');

  // ---- Mountains & nature ----
  static final String mayonVolcano = _u('1760876037275-a19e32a51047');
  static final String chocolateHills = _u('1500534623283-312aade485b7');
  static final String riceTerraces = _u('1500382017468-9049fed747ef');
  static final String mountainSunrise = _u('1470770841072-f978cf4d019e');
  static final String tinuyanFalls = _u('1780635823961-9dad96633019');
  static final String jungleWaterfall = _u('1432405972618-c60b0225b8f9');
  static final String greenValley = _u('1441974231531-c6227db76b6e');

  // ---- Heritage & city ----
  static final String calleCrisologo = _u('1523906834658-6e24ef2386f9');
  static final String intramurosWalls = _u('1766890411463-1ae640720e0c');
  static final String vigenChurch = _u('1782955733402-a15c021e64ba');
  static final String manilaSkyline = _u('1518877593221-1f28583780b4');
  static final String jeepneyStreet = _u('1596386461350-326ccb383e9f');

  // ---- Food & restaurants ----
  static final String filipinoFeast = _u('1555939594-58d7cb561ad1');
  static final String grilledSeafood = _u('1559847844-5315695dadae');
  static final String restaurantInterior = _u('1517248135467-4c7edcad34c4');
  static final String cafeInterior = _u('1554118811-1e0d58224f24');
  static final String streetFood = _u('1541014741259-de529411b96a');
  static final String friedChickenPlate = _u('1562967914-608f82629710');
  static final String noodleBowl = _u('1569718212165-3a8278d5f624');
  static final String coffeeLatteArt = _u('1509042239860-f550ce710b93');

  // ---- Festivals & culture ----
  static final String festivalDancers = _u('1533174072545-7a4b6ad7a6c3');
  static final String festivalConfetti = _u('1533174072545-7a4b6ad7a6c3');
  static final String streetParade = _u('1517457373958-b7bdd4587205');
  static final String fireworksNight = _u('1498931299472-f7a63a5a1cfa');
  static final String lanternFestival = _u('1573455494060-c5595004fb6c');
  static final String traditionalCostume = _u('1583225214464-9296029427aa');

  // ---- People / avatars ----
  static final String avatarWoman1 = _u('1494790108377-be9c29b29330');
  static final String avatarMan1 = _u('1507003211169-0a1dd7228f2d');
  static final String avatarWoman2 = _u('1544005313-94ddf0286df2');
  static final String avatarMan2 = _u('1500648767791-00dcc994a43e');
  static final String avatarWoman3 = _u('1517841905240-472988babdf9');

  // ---- Onboarding illustration-style hero shots ----
  static final String onboardingExplore = _u('1516815231560-8f41ec531527');
  static final String onboardingPlan = _u('1488646953014-85cb44e25828');
  static final String onboardingSave = _u('1476514525535-07fb3b4ae5f1');
}
