import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/iban_entry.dart';

class EditScreen extends StatefulWidget {
  final IbanEntry? existing;
  final List<String> existingCategories;

  const EditScreen({
    super.key,
    this.existing,
    this.existingCategories = const [],
  });

  @override
  State<EditScreen> createState() => _EditScreenState();
}

class _EditScreenState extends State<EditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _iban;
  late final TextEditingController _bank;
  late final TextEditingController _note;
  late final TextEditingController _newCategory;

  String? _category;
  late List<String> _availableCategories;
  bool _addingNewCategory = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _iban = TextEditingController(text: e?.iban ?? '');
    _bank = TextEditingController(text: e?.bank ?? '');
    _note = TextEditingController(text: e?.note ?? '');
    _newCategory = TextEditingController();
    _category = e?.category;
    _availableCategories = [...widget.existingCategories];
    if (_category != null && !_availableCategories.contains(_category)) {
      _availableCategories = [..._availableCategories, _category!]..sort();
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _iban.dispose();
    _bank.dispose();
    _note.dispose();
    _newCategory.dispose();
    super.dispose();
  }

  void _commitNewCategory() {
    final v = _newCategory.text.trim();
    if (v.isEmpty) {
      setState(() => _addingNewCategory = false);
      return;
    }
    setState(() {
      if (!_availableCategories.contains(v)) {
        _availableCategories = [..._availableCategories, v]..sort();
      }
      _category = v;
      _addingNewCategory = false;
      _newCategory.clear();
    });
  }

  void _save() {
    if (_addingNewCategory && _newCategory.text.trim().isNotEmpty) {
      _commitNewCategory();
    }
    if (!_formKey.currentState!.validate()) return;
    final entry = IbanEntry(
      id: widget.existing?.id ?? IbanEntry.newId(),
      name: _name.text.trim(),
      iban: IbanEntry.normalizeIban(_iban.text),
      bank: _bank.text.trim().isEmpty ? null : _bank.text.trim(),
      note: _note.text.trim().isEmpty ? null : _note.text.trim(),
      category: (_category == null || _category!.trim().isEmpty)
          ? null
          : _category!.trim(),
    );
    Navigator.of(context).pop(entry);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'IBAN Düzenle' : 'IBAN Ekle'),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('KAYDET'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _name,
              autofocus: !isEdit,
              textInputAction: TextInputAction.next,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'İsim',
                hintText: 'Mehmet',
                prefixIcon: Icon(Icons.person_outline),
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'İsim gerekli' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _iban,
              textInputAction: TextInputAction.next,
              textCapitalization: TextCapitalization.characters,
              maxLength: 26,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                LengthLimitingTextInputFormatter(26),
                TextInputFormatter.withFunction((oldValue, newValue) {
                  return TextEditingValue(
                    text: newValue.text.toUpperCase(),
                    selection: newValue.selection,
                  );
                }),
              ],
              decoration: const InputDecoration(
                labelText: 'IBAN',
                hintText: 'TR000000000000000000000000',
                helperText: 'TR + 24 rakam (toplam 26 karakter)',
                prefixIcon: Icon(Icons.credit_card),
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                final value = (v ?? '').trim();
                if (value.isEmpty) return 'IBAN gerekli';
                if (value.length != 26) {
                  return 'IBAN 26 karakter olmalı (girilen: ${value.length})';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _bank,
              textInputAction: TextInputAction.next,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Banka (opsiyonel)',
                hintText: 'Enpara',
                prefixIcon: Icon(Icons.account_balance_outlined),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _note,
              textInputAction: TextInputAction.done,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Not (opsiyonel)',
                prefixIcon: Icon(Icons.notes),
                border: OutlineInputBorder(),
              ),
              minLines: 1,
              maxLines: 3,
            ),
            const SizedBox(height: 20),
            _buildCategorySection(),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save),
              label: const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategorySection() {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.label_outline, color: theme.colorScheme.outline),
            const SizedBox(width: 8),
            Text('Kategori', style: theme.textTheme.titleSmall),
            const Spacer(),
            if (_category != null)
              TextButton.icon(
                icon: const Icon(Icons.close, size: 16),
                label: const Text('Kategorisiz'),
                onPressed: () => setState(() => _category = null),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final c in _availableCategories)
              ChoiceChip(
                label: Text(c),
                selected: _category == c,
                onSelected: (selected) =>
                    setState(() => _category = selected ? c : null),
              ),
            ActionChip(
              avatar: const Icon(Icons.add, size: 18),
              label: const Text('Yeni'),
              onPressed: () => setState(() => _addingNewCategory = true),
            ),
          ],
        ),
        if (_addingNewCategory)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _newCategory,
                    autofocus: true,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _commitNewCategory(),
                    decoration: const InputDecoration(
                      labelText: 'Yeni kategori',
                      hintText: 'Aile, İş, Borç…',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.tonal(
                  onPressed: _commitNewCategory,
                  child: const Text('Ekle'),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Vazgeç',
                  onPressed: () => setState(() {
                    _addingNewCategory = false;
                    _newCategory.clear();
                  }),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

