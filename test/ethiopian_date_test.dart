import 'package:birrwise/ethiopian_date.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('converts Gregorian dates to the Ethiopian calendar', () {
    expect(toEthiopianDate(DateTime(2024, 1, 10)).year, 2016);
    expect(toEthiopianDate(DateTime(2024, 1, 10)).month, 5);
    expect(toEthiopianDate(DateTime(2024, 1, 10)).day, 1);
    expect(toEthiopianDate(DateTime(2023, 9, 11)).year, 2015);
    expect(toEthiopianDate(DateTime(2023, 9, 11)).month, 13);
    expect(toEthiopianDate(DateTime(2023, 9, 11)).day, 6);
  });

  test('finds Ethiopian month boundaries', () {
    final date = DateTime(2024, 1, 20);
    expect(ethiopianMonthStart(date), DateTime(2024, 1, 10));
    expect(nextEthiopianMonthStart(date), DateTime(2024, 2, 9));
  });
}
