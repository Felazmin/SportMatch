import 'package:flutter_test/flutter_test.dart';
import 'package:test_do_an/demo/demo_operations.dart';

void main() {
  final first = DateTime(2026, 10, 8), last = DateTime(2026, 10, 9);
  CourtTariff tariff({
    DateTime? until,
    int surcharge = 10000,
    DateTime? from,
  }) => CourtTariff(
    court: 1,
    weekend: false,
    fromHour: 6,
    toHour: 12,
    rate: 120000,
    effectiveFrom: from ?? first,
    effectiveUntil: until,
    surcharge: surcharge,
  );
  test('Expiry is inclusive and surcharge is part of each hour quote', () {
    final settings = CourtSettings(
      rates: [120000, 120000, 120000],
      enabled: [true, true, true],
      tariffs: [tariff(until: last)],
    );
    expect(settings.rateAt(1, first.add(const Duration(hours: 6))), 130000);
    expect(settings.rateAt(1, last.add(const Duration(hours: 11))), 130000);
    expect(settings.rateAt(1, DateTime(2026, 10, 12, 11)), 120000);
  });
  test('Disjoint date windows can reuse the same hour band', () {
    final settings = CourtSettings(
      rates: [120000, 120000, 120000],
      enabled: [true, true, true],
      tariffs: [
        tariff(until: last),
        tariff(from: DateTime(2026, 10, 10), surcharge: 20000),
      ],
    );
    expect(settings.tariffs.length, 2);
    expect(settings.rateAt(1, DateTime(2026, 10, 12, 8)), 140000);
    expect(
      () => CourtSettings(
        rates: [120000, 120000, 120000],
        enabled: [true, true, true],
        tariffs: [
          tariff(until: last),
          tariff(from: last),
        ],
      ),
      throwsFormatException,
    );
  });
  test('Invalid expiry, surcharge and combined ceiling reject', () {
    expect(
      () => tariff(until: first.subtract(const Duration(days: 1))),
      throwsFormatException,
    );
    expect(
      () => tariff(until: last.add(const Duration(hours: 1))),
      throwsFormatException,
    );
    for (final fee in [-1000, 1, 101000]) {
      expect(() => tariff(surcharge: fee), throwsFormatException);
    }
    expect(
      () => CourtTariff(
        court: 1,
        weekend: false,
        fromHour: 6,
        toHour: 12,
        rate: 1000000,
        effectiveFrom: first,
        surcharge: 1000,
      ),
      throwsFormatException,
    );
  });
  test('Legacy and new tariffs round trip without changing base prices', () {
    final t = tariff(until: last);
    final restored = CourtTariff.fromJson(t.toJson());
    expect(restored.effectiveUntil, last);
    expect(restored.quotedRate, 130000);
    final old = t.toJson()
      ..remove('effectiveUntil')
      ..remove('surcharge');
    final legacy = CourtTariff.fromJson(old);
    expect(legacy.effectiveUntil, isNull);
    expect(legacy.quotedRate, 120000);
  });
}
