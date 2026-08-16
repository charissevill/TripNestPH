import 'package:flutter_test/flutter_test.dart';
import 'package:tripnest_ph/core/utils/chat_entity_matcher.dart';

void main() {
  group('extractBoldNames()', () {
    test('extracts bold names in first-mention order, lowercased and trimmed', () {
      const content = 'Try **Chocolate Hills** first, then **Loboc River Cruise**.';
      expect(extractBoldNames(content), ['chocolate hills', 'loboc river cruise']);
    });

    test('deduplicates a name mentioned more than once', () {
      const content = '**Panglao Beach** is great. Later, visit **Panglao Beach** again at sunset.';
      expect(extractBoldNames(content), ['panglao beach']);
    });

    test('caps at the given limit', () {
      const content = '**A** **B** **C** **D** **E**';
      expect(extractBoldNames(content, limit: 3), ['a', 'b', 'c']);
    });

    test('returns an empty list when nothing is bolded', () {
      expect(extractBoldNames('Just plain text, no bold names here.'), isEmpty);
    });

    test('ignores an empty bold marker', () {
      expect(extractBoldNames('Some text with **** empty bold.'), isEmpty);
    });
  });
}
