import 'package:flutter_test/flutter_test.dart';

import 'package:tripnest_ph/core/utils/permit_field_match.dart';

void main() {
  test('matchPermitName() ignores case, punctuation and extra words', () {
    expect(matchPermitName("Cha's Flowershop", 'chas flowershop'), PermitMatch.matches);
    expect(matchPermitName('CHARISSE D. VILLARAMA', 'Charisse Villarama'), PermitMatch.matches);
    expect(matchPermitName("Cha's Flowershop", "Cha's Flowershop and Gifts"), PermitMatch.matches);
  });

  test('matchPermitName() flags a different name', () {
    expect(matchPermitName("Cha's Flowershop", 'Kusina ni Aling Nena'), PermitMatch.differs);
    expect(matchPermitName('Charisse Villarama', 'Maria Villarama'), PermitMatch.differs);
  });

  test('matchPermitName() is unknown when either side is empty', () {
    expect(matchPermitName('', 'Charisse Villarama'), PermitMatch.unknown);
    expect(matchPermitName("Cha's Flowershop", ''), PermitMatch.unknown);
  });

  test('matchPermitAddress() matches on shared place words, not house number or postal code', () {
    expect(
      matchPermitAddress('126, Maligaya, Baliwag, Bulacan, Philippines, 3006', 'Maligaya, Baliwag, Bulacan'),
      PermitMatch.matches,
    );
    expect(
      matchPermitAddress('126, Maligaya, Baliwag, Bulacan, Philippines, 3006', 'Colon Street, Cebu City, Cebu'),
      PermitMatch.differs,
    );
    // Only the province in common isn't enough to call it the same place.
    expect(
      matchPermitAddress('126, Maligaya, Baliwag, Bulacan', 'Paseo del Congreso, Malolos, Bulacan'),
      PermitMatch.differs,
    );
    expect(matchPermitAddress('', 'Maligaya, Baliwag, Bulacan'), PermitMatch.unknown);
  });

  test('isPermitExpired() counts the last valid day itself as still valid', () {
    final validUntil = DateTime(2026, 12, 31);
    expect(isPermitExpired(validUntil, now: DateTime(2026, 12, 31, 23, 59)), isFalse);
    expect(isPermitExpired(validUntil, now: DateTime(2027, 1, 1)), isTrue);
    expect(isPermitExpired(validUntil, now: DateTime(2026, 10, 11)), isFalse);
  });
}
