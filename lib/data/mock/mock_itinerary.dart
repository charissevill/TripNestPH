import '../../core/constants/app_images.dart';
import '../../domain/models/itinerary.dart';

/// A single mock itinerary returned by the (non-AI, Phase 1/2) trip planner
/// form. AI-generated itineraries arrive in Phase 3.
final Itinerary mockItinerary = Itinerary(
  destinationName: 'El Nido, Palawan',
  coverImageUrl: AppImages.elNidoLagoon,
  totalDays: 3,
  travelers: 2,
  totalBudget: 24500,
  budgetBreakdown: [
    const BudgetItem(label: 'Accommodation', amount: 8400, iconKey: 'hotel', colorKey: 'primary'),
    const BudgetItem(label: 'Food & Dining', amount: 6200, iconKey: 'restaurant', colorKey: 'accent'),
    const BudgetItem(label: 'Transportation', amount: 5400, iconKey: 'directions_boat', colorKey: 'secondary'),
    const BudgetItem(label: 'Activities & Tours', amount: 4500, iconKey: 'hiking', colorKey: 'primaryDark'),
  ],
  weather: const [
    WeatherForecast(dayLabel: 'Day 1', condition: 'Sunny', iconKey: 'wb_sunny', highTemp: 31, lowTemp: 25),
    WeatherForecast(dayLabel: 'Day 2', condition: 'Partly Cloudy', iconKey: 'wb_cloudy', highTemp: 29, lowTemp: 24),
    WeatherForecast(dayLabel: 'Day 3', condition: 'Sunny', iconKey: 'wb_sunny', highTemp: 30, lowTemp: 25),
  ],
  travelTips: const [
    'Bring cash — most El Nido boat operators and beach cafes are cash-only.',
    'Book Tour A (Big/Small Lagoon) a day ahead during peak season.',
    'Pack reef-safe sunscreen to help protect the coral reefs you\'ll be snorkeling over.',
  ],
  recommendedRestaurantIds: const ['altrove-el-nido'],
  nearbyAttractionIds: const ['el-nido-lagoons', 'hundred-islands'],
  days: const [
    ItineraryDay(
      dayNumber: 1,
      dateLabel: 'Day 1 · Arrival & Town Exploration',
      activities: [
        ItineraryActivity(
          time: '10:00 AM',
          title: 'Arrive at El Nido Airport',
          description: 'Transfer to your hotel in El Nido town, roughly 20 minutes by van.',
          iconKey: 'flight_land',
          location: 'El Nido Airport (Lio)',
        ),
        ItineraryActivity(
          time: '1:00 PM',
          title: 'Lunch at Altrove El Nido',
          description: 'Settle in with a relaxed Italian lunch before exploring the town.',
          iconKey: 'restaurant',
          location: 'El Nido town proper',
        ),
        ItineraryActivity(
          time: '3:30 PM',
          title: 'Las Cabanas Beach sunset',
          description: 'Walk or tricycle over for a swim and one of the best sunset views in town.',
          iconKey: 'beach_access',
          location: 'Las Cabanas Beach',
        ),
      ],
    ),
    ItineraryDay(
      dayNumber: 2,
      dateLabel: 'Day 2 · Island Hopping Tour A',
      activities: [
        ItineraryActivity(
          time: '8:00 AM',
          title: 'Island Hopping Tour A',
          description: 'Big Lagoon, Small Lagoon, Secret Beach and Shimizu Island by boat.',
          iconKey: 'directions_boat',
          location: 'Bacuit Archipelago',
        ),
        ItineraryActivity(
          time: '12:30 PM',
          title: 'Beach picnic lunch',
          description: 'Fresh grilled seafood lunch served on the boat or a stopover beach.',
          iconKey: 'lunch_dining',
          location: 'Secret Lagoon Beach',
        ),
        ItineraryActivity(
          time: '6:30 PM',
          title: 'Dinner at Altrove El Nido',
          description: 'Wood-fired pizza to recharge after a full day of kayaking and swimming.',
          iconKey: 'local_pizza',
          location: 'El Nido town proper',
        ),
      ],
    ),
    ItineraryDay(
      dayNumber: 3,
      dateLabel: 'Day 3 · Leisure & Departure',
      activities: [
        ItineraryActivity(
          time: '9:00 AM',
          title: 'Free morning at Nacpan Beach',
          description: 'A 4km stretch of golden sand, far quieter than the town beaches.',
          iconKey: 'beach_access',
          location: 'Nacpan Beach',
        ),
        ItineraryActivity(
          time: '1:00 PM',
          title: 'Souvenir shopping & lunch',
          description: 'Pick up woven crafts and pearl jewelry along the town market strip.',
          iconKey: 'shopping_bag',
          location: 'El Nido town market',
        ),
        ItineraryActivity(
          time: '4:00 PM',
          title: 'Transfer to airport & departure',
          description: 'Van transfer back to El Nido Airport for your flight home.',
          iconKey: 'flight_takeoff',
          location: 'El Nido Airport (Lio)',
        ),
      ],
    ),
  ],
);
