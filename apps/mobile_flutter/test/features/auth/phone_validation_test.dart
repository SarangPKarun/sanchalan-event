import 'package:flutter_test/flutter_test.dart';
import 'package:sanchalan/features/auth/country_codes.dart';
import 'package:sanchalan/features/auth/phone_validation.dart';

Country country(String iso) => countries.firstWhere((c) => c.iso2 == iso);

void main() {
  group('checkPhone', () {
    test('a valid Indian mobile number, with spaces', () {
      final c = checkPhone(defaultCountry, '98765 43210');
      expect(c.isValid, isTrue);
      expect(c.e164, '+919876543210');
      expect(c.digits, '9876543210');
      expect(c.showInvalidHint, isFalse);
    });

    test('too short is invalid and shows the hint once typing starts', () {
      final c = checkPhone(defaultCountry, '98765');
      expect(c.isValid, isFalse);
      expect(c.showInvalidHint, isTrue);
    });

    test('a number that does not start like an Indian mobile is invalid', () {
      expect(checkPhone(defaultCountry, '1234567890').isValid, isFalse);
    });

    test('too long is invalid', () {
      expect(checkPhone(defaultCountry, '98765432101').isValid, isFalse);
    });

    test('empty input is invalid but shows no hint', () {
      final c = checkPhone(defaultCountry, '');
      expect(c.isValid, isFalse);
      expect(c.showInvalidHint, isFalse);
      expect(checkPhone(defaultCountry, '  ').showInvalidHint, isFalse);
    });

    test('non-digits are stripped', () {
      expect(checkPhone(defaultCountry, '(98765) 43-210').e164, '+919876543210');
    });

    test('other countries use their own rules', () {
      expect(checkPhone(country('AE'), '50 123 4567').isValid, isTrue);
      expect(checkPhone(country('US'), '415 555 2671').isValid, isTrue);
      expect(checkPhone(country('GB'), '7400 123456').isValid, isTrue);
      expect(checkPhone(country('AE'), '98765 43210').isValid, isFalse);
    });

    test('the same digits are judged per country', () {
      expect(checkPhone(defaultCountry, '9876543210').isValid, isTrue);
      expect(checkPhone(country('US'), '9876543210').isValid, isFalse);
    });
  });

  group('countries', () {
    test('India is the default and listed first', () {
      expect(defaultCountry.iso2, 'IN');
      expect(countries.first, defaultCountry);
    });

    test('flag emoji from the country code', () {
      expect(defaultCountry.flag, '\u{1F1EE}\u{1F1F3}');
      expect(country('US').flag, '\u{1F1FA}\u{1F1F8}');
    });

    test('search matches name or dial code, case-insensitively', () {
      expect(searchCountries('united').map((c) => c.iso2), containsAll(['US', 'GB', 'AE']));
      expect(searchCountries('+971').single.iso2, 'AE');
      expect(searchCountries('  INDIA ').map((c) => c.iso2), contains('IN'));
      expect(searchCountries('zzz'), isEmpty);
      expect(searchCountries(''), countries);
    });

    test('iso codes are unique', () {
      expect(countries.map((c) => c.iso2).toSet().length, countries.length);
    });
  });
}
