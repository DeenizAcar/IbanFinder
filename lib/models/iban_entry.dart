import 'dart:convert';

class IbanEntry {
  final String id;
  final String name;
  final String iban;
  final String? bank;
  final String? note;

  const IbanEntry({
    required this.id,
    required this.name,
    required this.iban,
    this.bank,
    this.note,
  });

  IbanEntry copyWith({
    String? name,
    String? iban,
    String? bank,
    String? note,
  }) {
    return IbanEntry(
      id: id,
      name: name ?? this.name,
      iban: iban ?? this.iban,
      bank: bank ?? this.bank,
      note: note ?? this.note,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'iban': iban,
        if (bank != null && bank!.isNotEmpty) 'bank': bank,
        if (note != null && note!.isNotEmpty) 'note': note,
      };

  factory IbanEntry.fromJson(Map<String, dynamic> json) {
    return IbanEntry(
      id: (json['id'] ?? _newId()).toString(),
      name: (json['name'] ?? '').toString().trim(),
      iban: normalizeIban((json['iban'] ?? '').toString()),
      bank: (json['bank'] as String?)?.trim(),
      note: (json['note'] as String?)?.trim(),
    );
  }

  static String normalizeIban(String raw) {
    return raw.replaceAll(RegExp(r'\s+'), '').toUpperCase();
  }

  static String formatIban(String iban) {
    final clean = normalizeIban(iban);
    final buffer = StringBuffer();
    for (var i = 0; i < clean.length; i++) {
      if (i > 0 && i % 4 == 0) buffer.write(' ');
      buffer.write(clean[i]);
    }
    return buffer.toString();
  }

  static String _newId() =>
      DateTime.now().microsecondsSinceEpoch.toRadixString(36);

  static String newId() => _newId();
}

String encodeEntries(List<IbanEntry> entries) =>
    jsonEncode(entries.map((e) => e.toJson()).toList());

List<IbanEntry> decodeEntries(String source) {
  if (source.trim().isEmpty) return [];
  final decoded = jsonDecode(source);
  if (decoded is! List) return [];
  return decoded
      .whereType<Map>()
      .map((m) => IbanEntry.fromJson(m.cast<String, dynamic>()))
      .where((e) => e.iban.isNotEmpty)
      .toList();
}
