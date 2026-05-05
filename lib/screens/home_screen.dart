import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../models/iban_entry.dart';
import '../services/storage_service.dart';
import '../widgets/iban_tile.dart';
import 'edit_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  final _speech = SpeechToText();

  List<IbanEntry> _entries = [];
  String _query = '';
  bool _loading = true;

  bool _speechAvailable = false;
  bool _listening = false;
  String? _highlightedId;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _query = _searchController.text);
    });
    _bootstrap();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    _speech.cancel();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final loaded = await StorageService.instance.load();
    if (!mounted) return;
    setState(() {
      _entries = loaded;
      _loading = false;
    });
  }

  Future<void> _persist() async {
    await StorageService.instance.save(_entries);
  }

  List<IbanEntry> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _entries;
    final tokens = q.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
    return _entries.where((e) {
      final haystack = [
        e.name,
        e.iban,
        e.bank ?? '',
        e.note ?? '',
      ].join(' ').toLowerCase();
      return tokens.every(haystack.contains);
    }).toList();
  }

  // ---------- voice ----------

  Future<bool> _ensureSpeech() async {
    if (_speechAvailable) return true;
    final mic = await Permission.microphone.request();
    if (!mic.isGranted) {
      _toast('Mikrofon izni verilmedi.');
      return false;
    }
    _speechAvailable = await _speech.initialize(
      onError: (e) {
        if (!mounted) return;
        setState(() => _listening = false);
        _toast('Sesli komut hatası: ${e.errorMsg}');
      },
      onStatus: (status) {
        if (!mounted) return;
        if (status == 'done' || status == 'notListening') {
          setState(() => _listening = false);
        }
      },
    );
    if (!_speechAvailable) {
      _toast('Sesli komut bu cihazda kullanılamıyor.');
    }
    return _speechAvailable;
  }

  Future<void> _toggleListen() async {
    if (_listening) {
      await _speech.stop();
      setState(() => _listening = false);
      return;
    }
    final ok = await _ensureSpeech();
    if (!ok) return;

    _searchController.clear();
    setState(() => _listening = true);

    await _speech.listen(
      localeId: 'tr_TR',
      listenOptions: SpeechListenOptions(
        partialResults: true,
        cancelOnError: true,
        listenMode: ListenMode.search,
      ),
      onResult: (result) {
        _searchController.text = result.recognizedWords;
        _searchController.selection = TextSelection.collapsed(
          offset: _searchController.text.length,
        );
        if (result.finalResult) {
          _onVoiceFinal();
        }
      },
    );
  }

  void _onVoiceFinal() {
    setState(() => _listening = false);
    final matches = _filtered;
    if (matches.isEmpty) {
      _toast('Eşleşen IBAN bulunamadı.');
      return;
    }
    final top = matches.first;
    setState(() => _highlightedId = top.id);
    _copyIban(top, prefix: 'Sesli arama:');
    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;
      if (_highlightedId == top.id) {
        setState(() => _highlightedId = null);
      }
    });
  }

  // ---------- CRUD ----------

  Future<void> _addManual() async {
    final entry = await Navigator.of(context).push<IbanEntry>(
      MaterialPageRoute(builder: (_) => const EditScreen()),
    );
    if (entry == null) return;
    setState(() => _entries = [..._entries, entry]);
    await _persist();
    _toast('"${entry.name}" eklendi.');
  }

  Future<void> _edit(IbanEntry entry) async {
    final updated = await Navigator.of(context).push<IbanEntry>(
      MaterialPageRoute(builder: (_) => EditScreen(existing: entry)),
    );
    if (updated == null) return;
    setState(() {
      _entries = [
        for (final e in _entries) e.id == updated.id ? updated : e,
      ];
    });
    await _persist();
    _toast('"${updated.name}" güncellendi.');
  }

  Future<void> _delete(IbanEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Silinsin mi?'),
        content: Text('${entry.name} kalıcı olarak silinecek.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('VAZGEÇ'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('SİL'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final removed = entry;
    final index = _entries.indexWhere((e) => e.id == entry.id);
    setState(() => _entries = _entries.where((e) => e.id != entry.id).toList());
    await _persist();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('"${entry.name}" silindi.'),
        action: SnackBarAction(
          label: 'GERİ AL',
          onPressed: () async {
            final list = [..._entries];
            list.insert(index.clamp(0, list.length), removed);
            setState(() => _entries = list);
            await _persist();
          },
        ),
      ),
    );
  }

  Future<void> _copyIban(IbanEntry entry, {String? prefix}) async {
    await Clipboard.setData(ClipboardData(text: entry.iban));
    if (!mounted) return;
    final label = prefix == null ? '' : '$prefix ';
    _toast('$label${entry.name} IBAN panoya kopyalandı.');
  }

  // ---------- import ----------

  Future<void> _importJson() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (result == null || result.files.isEmpty) return;
    final path = result.files.single.path;
    if (path == null) {
      _toast('Dosya yolu okunamadı.');
      return;
    }
    try {
      final content = await File(path).readAsString();
      final imported = decodeEntries(content);
      if (imported.isEmpty) {
        _toast('Dosyada geçerli IBAN bulunamadı.');
        return;
      }
      final existingIbans = _entries.map((e) => e.iban).toSet();
      final fresh =
          imported.where((e) => !existingIbans.contains(e.iban)).toList();
      setState(() => _entries = [..._entries, ...fresh]);
      await _persist();
      _toast(
        '${fresh.length} yeni IBAN eklendi'
        '${imported.length - fresh.length > 0 ? ' (${imported.length - fresh.length} mükerrer atlandı)' : ''}.',
      );
    } catch (e) {
      _toast('İçe aktarma başarısız: $e');
    }
  }

  Future<void> _exportJson() async {
    if (_entries.isEmpty) {
      _toast('Dışa aktarılacak IBAN yok.');
      return;
    }
    final pretty = const JsonEncoder.withIndent('  ')
        .convert(_entries.map((e) => e.toJson()).toList());
    try {
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'IBAN listesini kaydet',
        fileName: 'ibans.json',
        type: FileType.custom,
        allowedExtensions: ['json'],
        bytes: utf8.encode(pretty),
      );
      if (path == null) return;
      // On platforms where saveFile doesn't accept bytes, write manually.
      final f = File(path);
      if (!await f.exists() || await f.length() == 0) {
        await f.writeAsString(pretty);
      }
      _toast('Kaydedildi: $path');
    } catch (e) {
      _toast('Dışa aktarma başarısız: $e');
    }
  }

  // ---------- UI helpers ----------

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _openAddSheet() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_note),
              title: const Text('Manuel ekle'),
              subtitle: const Text('İsim ve IBAN gir'),
              onTap: () => Navigator.pop(ctx, 'manual'),
            ),
            ListTile(
              leading: const Icon(Icons.upload_file),
              title: const Text('JSON dosyasından ekle'),
              subtitle: const Text('Mevcut listeye ekler'),
              onTap: () => Navigator.pop(ctx, 'import'),
            ),
            ListTile(
              leading: const Icon(Icons.download),
              title: const Text('JSON olarak dışa aktar'),
              subtitle: const Text('Mevcut listeyi kaydet'),
              onTap: () => Navigator.pop(ctx, 'export'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (action == 'manual') await _addManual();
    if (action == 'import') await _importJson();
    if (action == 'export') await _exportJson();
  }

  // ---------- build ----------

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('IBAN Finder'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocus,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'isim, IBAN veya banka ara…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_query.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.clear),
                        tooltip: 'Temizle',
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _highlightedId = null);
                        },
                      ),
                    IconButton(
                      tooltip: _listening ? 'Dinlemeyi durdur' : 'Sesli ara',
                      icon: Icon(
                        _listening ? Icons.stop_circle : Icons.mic_none,
                        color: _listening ? theme.colorScheme.error : null,
                      ),
                      onPressed: _toggleListen,
                    ),
                  ],
                ),
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          if (_listening)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 10),
                  Text('Dinleniyor…'),
                ],
              ),
            ),
          Expanded(child: _buildList(filtered)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddSheet,
        icon: const Icon(Icons.add),
        label: const Text('Ekle'),
      ),
    );
  }

  Widget _buildList(List<IbanEntry> filtered) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_entries.isEmpty) {
      return _emptyState(
        icon: Icons.account_balance_wallet_outlined,
        title: 'Henüz IBAN yok',
        message: 'Sağ alttaki + ile manuel ekleyebilir veya '
            'JSON dosyasından içe aktarabilirsin.',
      );
    }
    if (filtered.isEmpty) {
      return _emptyState(
        icon: Icons.search_off,
        title: 'Eşleşme yok',
        message: '"$_query" için sonuç bulunamadı.',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 96, top: 4),
      itemCount: filtered.length,
      itemBuilder: (ctx, i) {
        final e = filtered[i];
        return IbanTile(
          entry: e,
          highlighted: e.id == _highlightedId,
          onTap: () => _copyIban(e),
          onCopy: () => _copyIban(e),
          onEdit: () => _edit(e),
          onDelete: () => _delete(e),
        );
      },
    );
  }

  Widget _emptyState({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: Colors.grey),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
