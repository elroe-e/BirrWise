class EthiopianDate {
  const EthiopianDate(this.year, this.month, this.day);

  final int year;
  final int month;
  final int day;
}

const ethiopianMonthsEn = [
  'Meskerem',
  'Tikimt',
  'Hidar',
  'Tahsas',
  'Tir',
  'Yekatit',
  'Megabit',
  'Miyazya',
  'Ginbot',
  'Sene',
  'Hamle',
  'Nehasse',
  'Pagume',
];

const ethiopianMonthsAm = [
  'መስከረም',
  'ጥቅምት',
  'ኅዳር',
  'ታኅሣሥ',
  'ጥር',
  'የካቲት',
  'መጋቢት',
  'ሚያዝያ',
  'ግንቦት',
  'ሰኔ',
  'ሐምሌ',
  'ነሐሴ',
  'ጳጉሜ',
];

EthiopianDate toEthiopianDate(DateTime gregorian) {
  final candidateYear = gregorian.year - 7;
  final newYearInGregorian = DateTime(
    gregorian.year,
    9,
    candidateYear % 4 == 0 ? 12 : 11,
  );
  final year = gregorian.isBefore(newYearInGregorian)
      ? candidateYear - 1
      : candidateYear;
  // Count days in UTC so a daylight-saving change (outside Ethiopia) cannot
  // make a 23-hour day round down and shift the date by one.
  final start = DateTime.utc(year + 7, 9, year % 4 == 0 ? 12 : 11);
  final dayOfYear =
      DateTime.utc(gregorian.year, gregorian.month, gregorian.day)
          .difference(start)
          .inDays;
  return EthiopianDate(
    year,
    dayOfYear ~/ 30 + 1,
    dayOfYear % 30 + 1,
  );
}

DateTime ethiopianMonthStart(DateTime date) {
  final converted = toEthiopianDate(date);
  final startOfYear = DateTime(
    converted.year + 7,
    9,
    converted.year % 4 == 0 ? 12 : 11,
  );
  return DateTime(startOfYear.year, startOfYear.month,
      startOfYear.day + (converted.month - 1) * 30);
}

DateTime nextEthiopianMonthStart(DateTime date) {
  final converted = toEthiopianDate(date);
  final start = ethiopianMonthStart(date);
  final days = converted.month < 13 ? 30 : (converted.year % 4 == 3 ? 6 : 5);
  return DateTime(start.year, start.month, start.day + days);
}

String monthLabel(DateTime date,
    {required bool ethiopian, required String language}) {
  if (!ethiopian) {
    const en = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    return language == 'am'
        ? '${date.month.toString().padLeft(2, '0')}/${date.year}'
        : '${en[date.month - 1]} ${date.year}';
  }
  final converted = toEthiopianDate(date);
  final months = language == 'am' ? ethiopianMonthsAm : ethiopianMonthsEn;
  return '${months[converted.month - 1]} ${converted.year}';
}

String dateLabel(DateTime date,
    {required bool ethiopian, required String language}) {
  if (!ethiopian) return '${date.day}/${date.month}/${date.year}';
  final converted = toEthiopianDate(date);
  final months = language == 'am' ? ethiopianMonthsAm : ethiopianMonthsEn;
  return '${converted.day} ${months[converted.month - 1]} ${converted.year}';
}
