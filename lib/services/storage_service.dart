import 'package:shared_preferences/shared_preferences.dart';

import '../models/iban_entry.dart';

class StorageService {
  StorageService._();
  static final StorageService instance = StorageService._();

  static const _key = 'iban_entries_v1';

  Future<List<IbanEntry>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    try {
      return decodeEntries(raw);
    } catch (_) {
      return [];
    }
  }

  Future<void> save(List<IbanEntry> entries) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, encodeEntries(entries));
  }
}
