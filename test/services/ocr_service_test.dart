import 'package:flutter_test/flutter_test.dart';
import 'package:tripnest_ph/core/services/ocr_service.dart';
import 'package:tripnest_ph/domain/models/business_owner_application.dart';

void main() {
  group('OcrService.readApplicationDocs', () {
    test('sends only the given URL and parses what was read', () async {
      String? calledName;
      Map<String, dynamic>? sent;
      final service = OcrService(
        caller: (name, data) async {
          calledName = name;
          sent = data;
          return {
            'permitFields': {
              'businessName': 'Cha\'s Flowershop',
              'ownerName': 'Charisse Villarama',
              'address': 'Poblacion, Baliwag, Bulacan',
              'permitNo': '2026-00123',
              'validUntil': '2026-12-31',
              'issuingLgu': 'Municipality of Baliwag, Bulacan',
            },
            'idName': '',
          };
        },
      );

      final result = await service.readApplicationDocs(permitUrl: 'https://example.com/permit.jpg');

      expect(calledName, 'readApplicationDocs');
      expect(sent, {'permitUrl': 'https://example.com/permit.jpg', 'idUrl': ''});
      expect(result.permitFields.businessName, 'Cha\'s Flowershop');
      expect(result.permitFields.validUntil, DateTime(2026, 12, 31));
      expect(result.idName, '');
    });

    test('a photo nothing was read from comes back empty, not as an error', () async {
      final service = OcrService(caller: (name, data) async => {});

      final result = await service.readApplicationDocs(idUrl: 'https://example.com/id.jpg');

      expect(result.permitFields.isEmpty, isTrue);
      expect(result.idName, '');
    });
  });

  group('PermitFields.toMap', () {
    test('round-trips through fromMap, with validUntil as YYYY-MM-DD', () {
      final fields = PermitFields(
        businessName: 'Cha\'s Flowershop',
        ownerName: 'Charisse Villarama',
        address: 'Poblacion, Baliwag, Bulacan',
        permitNo: '2026-00123',
        validUntil: DateTime(2026, 12, 31),
        issuingLgu: 'Municipality of Baliwag, Bulacan',
      );

      final map = fields.toMap();
      final back = PermitFields.fromMap(map);

      expect(map['validUntil'], '2026-12-31');
      expect(back.businessName, fields.businessName);
      expect(back.ownerName, fields.ownerName);
      expect(back.address, fields.address);
      expect(back.permitNo, fields.permitNo);
      expect(back.validUntil, fields.validUntil);
      expect(back.issuingLgu, fields.issuingLgu);
    });

    test('no date is stored as an empty string', () {
      expect(const PermitFields().toMap()['validUntil'], '');
      expect(PermitFields.fromMap(const PermitFields().toMap()).isEmpty, isTrue);
    });
  });
}
