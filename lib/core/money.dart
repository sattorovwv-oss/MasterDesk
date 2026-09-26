class Money {
  const Money._();

  static int parseMinor(String raw) {
    final cleaned = raw
        .trim()
        .replaceAll(RegExp(r'\s+'), '')
        .replaceAll(',', '.');
    if (cleaned.isEmpty) return 0;
    final match = RegExp(r'^(-?)(\d+)(?:\.(\d{0,2}))?$').firstMatch(cleaned);
    if (match == null) throw const FormatException('Invalid money value');
    final negative = match.group(1) == '-';
    final major = int.parse(match.group(2)!);
    final fraction = (match.group(3) ?? '').padRight(2, '0');
    final result = major * 100 + int.parse(fraction.isEmpty ? '0' : fraction);
    return negative ? -result : result;
  }

  static int percentDiscount(int subtotalMinor, int hundredthsPercent) {
    if (subtotalMinor <= 0 || hundredthsPercent <= 0) return 0;
    // subtotal * percent/100. Percentage is stored in hundredths of a percent.
    // Adding half the divisor implements positive half-up rounding.
    return (subtotalMinor * hundredthsPercent + 5000) ~/ 10000;
  }

  static String format(int minor, String currency, String localeCode) {
    final negative = minor < 0;
    final absolute = minor.abs();
    final major = absolute ~/ 100;
    final cents = absolute % 100;
    final raw = major.toString();
    final chunks = <String>[];
    for (var end = raw.length; end > 0; end -= 3) {
      final start = end - 3 < 0 ? 0 : end - 3;
      chunks.insert(0, raw.substring(start, end));
    }
    final separator = localeCode == 'ru' ? ' ' : ',';
    final decimal = localeCode == 'ru' ? ',' : '.';
    return '${negative ? '−' : ''}${chunks.join(separator)}$decimal${cents.toString().padLeft(2, '0')} $currency';
  }
}
