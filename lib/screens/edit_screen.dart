import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/iban_entry.dart';

class EditScreen extends StatefulWidget {
  final IbanEntry? existing;

  const EditScreen({super.key, this.existing});

  @override
  State<EditScreen> createState() => _EditScreenState();
}

class _EditScreenState extends State<EditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _iban;
  late final TextEditingController _bank;
  late final TextEditingController _note;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _iban = TextEditingController(
      text: e == null ? '' : IbanEntry.formatIban(e.iban),
    );
    _bank = TextEditingController(text: e?.bank ?? '');
    _note = TextEditingController(text: e?.note ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _iban.dispose();
    _bank.dispose();
    _note.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final entry = IbanEntry(
      id: widget.existing?.id ?? IbanEntry.newId(),
      name: _name.text.trim(),
      iban: IbanEntry.normalizeIban(_iban.text),
      bank: _bank.text.trim().isEmpty ? null : _bank.text.trim(),
      note: _note.text.trim().isEmpty ? null : _note.text.trim(),
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
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9 ]')),
                _IbanFormatter(),
              ],
              decoration: const InputDecoration(
                labelText: 'IBAN',
                hintText: 'TR00 0000 0000 0000 0000 0000 00',
                prefixIcon: Icon(Icons.credit_card),
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                final clean = IbanEntry.normalizeIban(v ?? '');
                if (clean.isEmpty) return 'IBAN gerekli';
                if (clean.length < 15) return 'IBAN çok kısa';
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
}

class _IbanFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final clean = IbanEntry.normalizeIban(newValue.text);
    final formatted = IbanEntry.formatIban(clean);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
