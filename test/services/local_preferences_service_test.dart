import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tripnest_ph/core/services/local_preferences_service.dart';

void main() {
  late LocalPreferencesService service;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    service = LocalPreferencesService();
  });

  group('offline itinerary ids', () {
    test('starts empty when nothing has been saved offline yet', () async {
      expect(await service.getOfflineItineraryIds(), isEmpty);
    });

    test('setItineraryAvailableOffline(true) adds the id, (false) removes it', () async {
      await service.setItineraryAvailableOffline('trip-1', true);
      await service.setItineraryAvailableOffline('trip-2', true);
      expect(await service.getOfflineItineraryIds(), {'trip-1', 'trip-2'});

      await service.setItineraryAvailableOffline('trip-1', false);
      expect(await service.getOfflineItineraryIds(), {'trip-2'});
    });
  });
}
