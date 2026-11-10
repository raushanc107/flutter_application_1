import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../core/database/database.dart';
import 'card_face.dart';
import 'card_utils.dart';

/// Add a new card, or edit [card] when provided.
class CardFormDialog extends StatefulWidget {
  const CardFormDialog({super.key, this.card});

  final SavedCard? card;

  @override
  State<CardFormDialog> createState() => _CardFormDialogState();
}

class _CardFormDialogState extends State<CardFormDialog> {
  static const _indigo = Color(0xFF4F46E5);

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _issuer;
  late final TextEditingController _number;
  late final TextEditingController _expiry;
  late final TextEditingController _holder;
  late String _type;
  late String _network;
  late String _tone;
  late bool _isDefault;
  final _issuerFocus = FocusNode();
  final _numberFocus = FocusNode();
  final _expiryFocus = FocusNode();
  final _holderFocus = FocusNode();
  bool _saving = false;

  bool get _isEditing => widget.card != null;

  @override
  void initState() {
    super.initState();
    final c = widget.card;
    _name = TextEditingController(text: c?.name ?? '');
    _issuer = TextEditingController(text: c?.issuer ?? '');
    _number = TextEditingController(
      text: c == null ? '' : CardNumbers.format(c.cardNumber),
    );
    _expiry = TextEditingController(text: c?.expiry ?? '');
    _holder = TextEditingController(text: c?.holderName ?? '');
    _type = c?.cardType ?? CardTypes.debit;
    _network = c?.network ?? CardNetworks.visa;
    _tone = c?.colorTone ?? CardTones.keys.first;
    _isDefault = c?.isDefault ?? false;
    for (final controller in [_name, _issuer, _number, _expiry, _holder]) {
      controller.addListener(_refreshPreview);
    }
  }

  void _refreshPreview() => setState(() {});

  @override
  void dispose() {
    for (final controller in [_name, _issuer, _number, _expiry, _holder]) {
      controller.dispose();
    }
    for (final node in [
      _issuerFocus,
      _numberFocus,
      _expiryFocus,
      _holderFocus,
    ]) {
      node.dispose();
    }
    super.dispose();
  }

  InputDecoration _decoration(String label, {String? hint}) => InputDecoration(
    labelText: label,
    hintText: hint,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
  );

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280);

    return AlertDialog(
      backgroundColor: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      scrollable: true,
      title: Text(
        _isEditing ? 'Edit Card' : 'Add Card',
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white : const Color(0xFF111827),
        ),
      ),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CardFace(
                name: _name.text.trim(),
                issuer: _issuer.text.trim(),
                cardType: _type,
                network: _network,
                cardNumber: _number.text,
                expiry: _expiry.text,
                holderName: _holder.text.trim(),
                tone: _tone,
                isDefault: _isDefault,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _name,
                onEditingComplete: _issuerFocus.requestFocus,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                textInputAction: TextInputAction.next,
                decoration: _decoration(
                  'Card name',
                  hint: 'e.g. Everyday spends',
                ),
                textCapitalization: TextCapitalization.sentences,
                maxLength: 28,
                buildCounter: _noCounter,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Give this card a name'
                    : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _issuer,
                focusNode: _issuerFocus,
                onEditingComplete: _numberFocus.requestFocus,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                textInputAction: TextInputAction.next,
                decoration: _decoration(
                  'Bank / issuer',
                  hint: 'e.g. HDFC Bank',
                ),
                textCapitalization: TextCapitalization.words,
                maxLength: 30,
                buildCounter: _noCounter,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Enter the bank or issuer'
                    : null,
              ),
              const SizedBox(height: 14),
              Text('Card type', style: TextStyle(fontSize: 12, color: muted)),
              const SizedBox(height: 8),
              // Keep the chips out of keyboard traversal so "next" on the issuer
              // field moves straight on to the card number.
              ExcludeFocus(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final t in CardTypes.all)
                      ChoiceChip(
                        label: Text(CardTypes.label(t)),
                        selected: _type == t,
                        selectedColor: _indigo,
                        labelStyle: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: _type == t ? Colors.white : null,
                        ),
                        showCheckmark: false,
                        onSelected: (_) => setState(() => _type = t),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _number,
                focusNode: _numberFocus,
                onEditingComplete: _expiryFocus.requestFocus,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                textInputAction: TextInputAction.next,
                decoration: _decoration(
                  'Card number',
                  hint: '0000 0000 0000 0000',
                ),
                keyboardType: TextInputType.number,
                autocorrect: false,
                enableSuggestions: false,
                enableIMEPersonalizedLearning: false,
                inputFormatters: [CardNumberInputFormatter()],
                onChanged: (v) {
                  final guess = CardNetworks.detect(CardNumbers.digitsOnly(v));
                  if (guess != null && guess != _network) {
                    setState(() => _network = guess);
                  }
                },
                validator: (v) => CardNumbers.isValidLength(v ?? '')
                    ? null
                    : 'Enter 13–19 digits',
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _expiry,
                      focusNode: _expiryFocus,
                      onEditingComplete: _holderFocus.requestFocus,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      textInputAction: TextInputAction.next,
                      decoration: _decoration('Expiry', hint: 'MM/YY'),
                      keyboardType: TextInputType.number,
                      autocorrect: false,
                      enableSuggestions: false,
                      inputFormatters: [ExpiryInputFormatter()],
                      validator: (v) =>
                          CardExpiry.isValid(v ?? '') ? null : 'Use MM/YY',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 3,
                    child: DropdownButtonFormField<String>(
                      initialValue: _network,
                      isExpanded: true,
                      decoration: _decoration('Network'),
                      items: [
                        for (final n in CardNetworks.all)
                          DropdownMenuItem(
                            value: n,
                            child: Text(CardNetworks.label(n)),
                          ),
                      ],
                      onChanged: (v) {
                        if (v != null) setState(() => _network = v);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _holder,
                focusNode: _holderFocus,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                textInputAction: TextInputAction.done,
                decoration: _decoration('Name on card'),
                textCapitalization: TextCapitalization.words,
                maxLength: 26,
                buildCounter: _noCounter,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Enter the name on card'
                    : null,
              ),
              const SizedBox(height: 14),
              Text('Card colour', style: TextStyle(fontSize: 12, color: muted)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 12,
                runSpacing: 10,
                children: [
                  for (final tone in CardTones.keys)
                    _Swatch(
                      colors: CardTones.colors(tone),
                      selected: _tone == tone,
                      label: tone,
                      onTap: () => setState(() => _tone = tone),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Set as default',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  'Shown first in your list',
                  style: TextStyle(fontSize: 12, color: muted),
                ),
                value: _isDefault,
                onChanged: (v) => setState(() => _isDefault = v),
                activeThumbColor: _indigo,
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _indigo.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.shield_outlined, size: 18, color: _indigo),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Only the last 4 digits show on your card. Tap the eye '
                        'to reveal the full number. CVV and PIN are never asked '
                        'for or stored.',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.5,
                          color: muted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: _indigo,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: _saving ? null : _submit,
          child: Text(_isEditing ? 'Save Changes' : 'Add Card'),
        ),
      ],
    );
  }

  static Widget? _noCounter(
    BuildContext context, {
    required int currentLength,
    required int? maxLength,
    required bool isFocused,
  }) => null;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final database = Provider.of<AppDatabase>(context, listen: false);
    final existing = widget.card;

    try {
      await database.saveCard(
        SavedCardsCompanion(
          id: drift.Value(existing?.id ?? const Uuid().v4()),
          name: drift.Value(_name.text.trim()),
          issuer: drift.Value(_issuer.text.trim()),
          cardType: drift.Value(_type),
          network: drift.Value(_network),
          cardNumber: drift.Value(CardNumbers.digitsOnly(_number.text)),
          expiry: drift.Value(_expiry.text),
          holderName: drift.Value(_holder.text.trim()),
          colorTone: drift.Value(_tone),
          isDefault: drift.Value(_isDefault),
        ),
      );
      if (mounted) Navigator.pop(context, _isEditing ? 'updated' : 'added');
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not save card: $e')));
    }
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.colors,
    required this.selected,
    required this.label,
    required this.onTap,
  });

  final List<Color> colors;
  final bool selected;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '$label colour',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? const Color(0xFF818CF8) : Colors.transparent,
              width: 2,
            ),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: colors,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
