import 'package:flutter_test/flutter_test.dart';
import 'package:tripnest_ph/core/utils/personalized_ranking.dart';
import 'package:tripnest_ph/domain/models/place.dart';

Place _place(String id, List<String> types) =>
    Place(id: id, name: id, types: types);

void main() {
  group('rankByFavoriteCategories()', () {
    test('returns the same list unchanged when there are no favorite categories', () {
      final places = [_place('a', const ['restaurant']), _place('b', const ['beach'])];
      expect(rankByFavoriteCategories(places, const []), same(places));
    });

    test('floats matching places to the front, preserving relative order within each group', () {
      final restaurant1 = _place('restaurant-1', const ['restaurant']);
      final beach1 = _place('beach-1', const ['beach']);
      final museum1 = _place('museum-1', const ['museum']);
      final beach2 = _place('beach-2', const ['beach']);

      final ranked = rankByFavoriteCategories(
        [restaurant1, beach1, museum1, beach2],
        const ['beaches'],
      );

      expect(ranked.map((p) => p.id), [
        'beach-1',
        'beach-2',
        'restaurant-1',
        'museum-1',
      ]);
    });

    test('a category with no Places-type mapping (festivals) never boosts anything', () {
      final places = [_place('a', const ['restaurant']), _place('b', const ['beach'])];
      final ranked = rankByFavoriteCategories(places, const ['festivals']);
      expect(ranked.map((p) => p.id), ['a', 'b']);
    });

    test('multiple favorite categories combine their matching types', () {
      final food = _place('food', const ['cafe']);
      final history = _place('history', const ['historical_landmark']);
      final other = _place('other', const ['shopping_mall']);

      final ranked = rankByFavoriteCategories(
        [other, food, history],
        const ['food', 'historical'],
      );

      expect(ranked.last.id, 'other');
      expect(ranked.take(2).map((p) => p.id).toSet(), {'food', 'history'});
    });
  });
}
