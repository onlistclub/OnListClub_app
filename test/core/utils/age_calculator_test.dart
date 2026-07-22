import 'package:flutter_test/flutter_test.dart';
import 'package:OnListClub/core/utils/age_calculator.dart';

void main() {
  group('AgeCalculator.isAdult', () {
    final ref = DateTime(2026, 1, 5);

    test('exactly 18 today is adult', () {
      final dob = DateTime(2008, 1, 5);
      expect(AgeCalculator.isAdult(dob, currentDate: ref), isTrue);
    });

    test('one day before 18th birthday is not adult', () {
      final dob = DateTime(2008, 1, 6);
      expect(AgeCalculator.isAdult(dob, currentDate: ref), isFalse);
    });

    test('one day after 18th birthday is adult', () {
      final dob = DateTime(2008, 1, 4);
      expect(AgeCalculator.isAdult(dob, currentDate: ref), isTrue);
    });

    test('leap year birthday Feb 29 not adult on Feb 28', () {
      final dob = DateTime(2008, 2, 29);
      final check = DateTime(2026, 2, 28);
      expect(AgeCalculator.isAdult(dob, currentDate: check), isFalse);
    });
    test('leap year birthday adult on Mar 1', () {
      final dob = DateTime(2008, 2, 29);
      final check = DateTime(2026, 3, 1);
      expect(AgeCalculator.isAdult(dob, currentDate: check), isTrue);
    });

    test('minor 17 years 11 months', () {
      final dob = DateTime(2008, 2, 6);
      final check = DateTime(2026, 1, 5);
      expect(AgeCalculator.isAdult(dob, currentDate: check), isFalse);
    });
  });
}
