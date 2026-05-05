import 'package:flutter_test/flutter_test.dart';

import 'package:iban_finder/models/iban_entry.dart';

void main() {
  test('normalizeIban strips spaces and uppercases', () {
    expect(
      IbanEntry.normalizeIban('tr00 1234 5678 9012 3456 7890 12'),
      'TR0012345678901234567890 12'.replaceAll(' ', ''),
    );
  });

  test('formatIban groups in fours', () {
    expect(
      IbanEntry.formatIban('TR000012345678'),
      'TR00 0012 3456 78',
    );
  });

  test('encode/decode round-trip', () {
    final entries = [
      IbanEntry(id: '1', name: 'Mehmet', iban: 'TR000012345678'),
      IbanEntry(
        id: '2',
        name: 'Ayşe',
        iban: 'TR111122223333',
        bank: 'Enpara',
        note: 'iş',
      ),
    ];
    final json = encodeEntries(entries);
    final decoded = decodeEntries(json);
    expect(decoded.length, 2);
    expect(decoded[1].bank, 'Enpara');
    expect(decoded[0].iban, 'TR000012345678');
  });
}
