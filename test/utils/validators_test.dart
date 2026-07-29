import 'package:flutter_test/flutter_test.dart';

import 'package:tripnest_ph/core/utils/validators.dart';

void main() {
  group('Validators.url', () {
    test('accepts a valid http/https URL', () {
      expect(Validators.url('https://example.com'), isNull);
      expect(Validators.url('http://example.com/path'), isNull);
    });

    test('accepts empty value when not required', () {
      expect(Validators.url(''), isNull);
      expect(Validators.url(null), isNull);
    });

    test('rejects empty value when required', () {
      expect(Validators.url('', required: true), isNotNull);
    });

    test('rejects a URL with no scheme or host', () {
      expect(Validators.url('not a url'), isNotNull);
      expect(Validators.url('ftp://example.com'), isNotNull);
      expect(Validators.url('http://'), isNotNull);
    });
  });

  group('Validators.phone', () {
    test('accepts plausible phone numbers with formatting', () {
      expect(Validators.phone('+63 917 123 4567'), isNull);
      expect(Validators.phone('(02) 8123-4567'), isNull);
    });

    test('accepts empty value when not required', () {
      expect(Validators.phone(''), isNull);
      expect(Validators.phone(null), isNull);
    });

    test('rejects empty value when required', () {
      expect(Validators.phone('', required: true), isNotNull);
    });

    test('rejects a number that is too short or has no digits', () {
      expect(Validators.phone('12345'), isNotNull);
      expect(Validators.phone('abcdefg'), isNotNull);
    });
  });

  group('Validators.maxLength', () {
    test('accepts a value at or under the max', () {
      expect(Validators.maxLength('hello', 5), isNull);
      expect(Validators.maxLength('', 5), isNull);
    });

    test('rejects a value over the max', () {
      expect(Validators.maxLength('hello world', 5), isNotNull);
    });

    test('includes the given label in the error message', () {
      expect(
        Validators.maxLength('too long', 3, label: 'Overview'),
        contains('Overview'),
      );
    });
  });
}
