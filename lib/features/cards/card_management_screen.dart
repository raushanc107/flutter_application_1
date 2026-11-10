import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/database/database.dart';
import 'card_face.dart';
import 'card_form_dialog.dart';
import 'card_utils.dart';

/// Settings → Card Management.
class CardManagementScreen extends StatefulWidget {
  const CardManagementScreen({super.key});

  @override
  State<CardManagementScreen> createState() => _CardManagementScreenState();
}

class _CardManagementScreenState extends State<CardManagementScreen> {
  static const _indigo = Color(0xFF4F46E5);
  static const _revealDuration = Duration(seconds: 20);

  final Set<String> _revealed = {};
  final Map<String, Timer> _revealTimers = {};
  String _filter = 'ALL';

  @override
  void dispose() {
    for (final t in _revealTimers.values) {
      t.cancel();
    }
    super.dispose();
  }

  void _toggleReveal(String id) {
    _revealTimers.remove(id)?.cancel();
    setState(() {
      if (_revealed.remove(id)) return;
      _revealed.add(id);
      // Hide the number again on its own.
      _revealTimers[id] = Timer(_revealDuration, () {
        if (mounted) setState(() => _revealed.remove(id));
      });
    });
  }

  void _hide(String id) {
    _revealTimers.remove(id)?.cancel();
    _revealed.remove(id);
  }

  Future<void> _copy(SavedCard card) async {
    // Digits only, so it pastes cleanly into other forms.
    await Clipboard.setData(ClipboardData(text: card.cardNumber));
    if (!mounted) return;
    _snack('Card number copied');
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
  }

  Future<void> _openForm([SavedCard? card]) async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => CardFormDialog(card: card),
    );
    if (!mounted || result == null) return;
    _snack(result == 'added' ? 'Card added' : 'Card updated');
  }

  Future<void> _openOptions(SavedCard card) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _CardOptionsSheet(card: card, isDark: isDark),
    );
    if (!mounted || action == null) return;
    final database = Provider.of<AppDatabase>(context, listen: false);
    switch (action) {
      case 'default':
        await database.setDefaultSavedCard(card.id);
        if (mounted) _snack('Default card updated');
      case 'edit':
        await _openForm(card);
      case 'delete':
        await _confirmDelete(card, database);
    }
  }

  Future<void> _confirmDelete(SavedCard card, AppDatabase database) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete card?'),
        content: Text(
          'Remove ${card.name} from your saved cards? This can’t be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    _hide(card.id);
    await database.deleteSavedCard(card.id);
    if (mounted) _snack('Card deleted');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final database = Provider.of<AppDatabase>(context, listen: false);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? const [Color(0xFF0F172A), Color(0xFF1E293B)]
                : const [Color(0xFFF8FAFC), Color(0xFFEEF2FF)],
          ),
        ),
        child: Column(
          children: [
            _buildHeader(context, isDark),
            Expanded(
              child: StreamBuilder<List<SavedCard>>(
                stream: database.watchAllSavedCards(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Could not load cards: ${snapshot.error}',
                        style: const TextStyle(color: Color(0xFFEF4444)),
                      ),
                    );
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  return _buildBody(snapshot.data!, isDark);
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        backgroundColor: _indigo,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_card_outlined),
        label: const Text(
          'Add Card',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark) {
    return Container(
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE5E7EB),
          ),
        ),
      ),
      child: SizedBox(
        height: 60,
        child: Row(
          children: [
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.pop(context),
              color: isDark ? Colors.white : const Color(0xFF111827),
            ),
            const SizedBox(width: 4),
            Text(
              'Card Management',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF111827),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(List<SavedCard> cards, bool isDark) {
    final muted = isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280);
    final counts = {
      for (final t in CardTypes.all)
        t: cards.where((c) => c.cardType == t).length,
    };
    // A filter whose cards were all deleted falls back to "all".
    final filter = _filter == 'ALL' || (counts[_filter] ?? 0) > 0
        ? _filter
        : 'ALL';
    final shown = cards
        .where((c) => filter == 'ALL' || c.cardType == filter)
        .toList();
    final attention = cards
        .where((c) => CardExpiry.status(c.expiry) != ExpiryStatus.ok)
        .length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 24, 0, 110),
      children: [
        if (cards.isNotEmpty) ...[
          _Tile(
            isDark: isDark,
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SAVED CARDS',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1.4,
                    color: muted,
                  ),
                ),
                const SizedBox(height: 6),
                Text.rich(
                  TextSpan(
                    text: '${cards.length}',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF111827),
                    ),
                    children: [
                      TextSpan(
                        text:
                            '  ${cards.length == 1 ? 'card' : 'cards'} · '
                            '${counts[CardTypes.credit]} credit · '
                            '${counts[CardTypes.debit]} debit',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: muted,
                        ),
                      ),
                    ],
                  ),
                ),
                if (attention > 0) ...[
                  const SizedBox(height: 14),
                  Divider(
                    height: 1,
                    color: isDark
                        ? const Color(0xFF334155)
                        : const Color(0xFFE5E7EB),
                  ),
                  const SizedBox(height: 14),
                  Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFFF59E0B),
                              width: 1.5,
                            ),
                          ),
                          child: Text(
                            '$attention',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFF59E0B),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          attention == 1
                              ? 'card needs attention'
                              : 'cards need attention',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFF59E0B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
        if (cards.length >= 2) ...[
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _FilterChip(
                  label: 'All · ${cards.length}',
                  selected: filter == 'ALL',
                  onTap: () => setState(() => _filter = 'ALL'),
                ),
                for (final t in CardTypes.all)
                  if (counts[t]! > 0)
                    _FilterChip(
                      label: '${CardTypes.label(t)} · ${counts[t]}',
                      selected: filter == t,
                      onTap: () => setState(() => _filter = t),
                    ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
        if (cards.isEmpty)
          _buildEmpty(isDark, muted)
        else ...[
          Padding(
            padding: const EdgeInsets.only(left: 32, bottom: 12),
            child: Text(
              '${shown.length} ${shown.length == 1 ? 'CARD' : 'CARDS'}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: muted,
              ),
            ),
          ),
          for (final card in shown)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              child: _buildCard(card, isDark, muted),
            ),
        ],
      ],
    );
  }

  Widget _buildCard(SavedCard card, bool isDark, Color muted) {
    final status = CardExpiry.status(card.expiry);
    final (String label, Color color) = switch (status) {
      ExpiryStatus.expired => ('Expired', const Color(0xFFEF4444)),
      ExpiryStatus.expiringSoon => ('Expiring soon', const Color(0xFFF59E0B)),
      ExpiryStatus.ok => ('Active', muted),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CardFace(
          name: card.name,
          issuer: card.issuer,
          cardType: card.cardType,
          network: card.network,
          cardNumber: card.cardNumber,
          expiry: card.expiry,
          holderName: card.holderName,
          tone: card.colorTone,
          isDefault: card.isDefault,
          revealed: _revealed.contains(card.id),
          onToggleReveal: () => _toggleReveal(card.id),
          onCopy: () => _copy(card),
          onLongPress: () => _openOptions(card),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: status == ExpiryStatus.ok
                      ? null
                      : color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: status == ExpiryStatus.ok
                        ? (isDark
                              ? const Color(0xFF334155)
                              : const Color(0xFFE5E7EB))
                        : color.withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                'Hold for options',
                style: TextStyle(fontSize: 13, color: muted),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmpty(bool isDark, Color muted) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(vertical: 44, horizontal: 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.credit_card_outlined,
            size: 44,
            color: isDark ? const Color(0xFF475569) : const Color(0xFFC4C8D0),
          ),
          const SizedBox(height: 12),
          Text(
            'No cards yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : const Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tap “Add Card” to save your first one.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: muted),
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.isDark,
    required this.child,
    required this.padding,
  });

  final bool isDark;
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: padding,
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1E293B).withValues(alpha: 0.6)
            : Colors.white.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? const Color(0xFF334155).withValues(alpha: 0.3)
              : Colors.white.withValues(alpha: 0.4),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.2)
                : Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: selected
            ? accent.withValues(alpha: 0.15)
            : (isDark
                  ? const Color(0xFF1E293B).withValues(alpha: 0.6)
                  : Colors.white.withValues(alpha: 0.6)),
        shape: StadiumBorder(
          side: BorderSide(
            color: selected
                ? accent
                : (isDark ? const Color(0xFF334155) : const Color(0xFFE5E7EB)),
          ),
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected
                      ? accent
                      : (isDark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF6B7280)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CardOptionsSheet extends StatelessWidget {
  const _CardOptionsSheet({required this.card, required this.isDark});

  final SavedCard card;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final muted = isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280);
    final text = isDark ? Colors.white : const Color(0xFF111827);
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 34,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(7),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: CardTones.colors(card.colorTone),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        card.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: text,
                        ),
                      ),
                      Text(
                        '${CardTypes.label(card.cardType)} · ${card.issuer} · '
                        '•••• ${CardNumbers.last4(card.cardNumber)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, color: muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (!card.isDefault)
            _SheetOption(
              icon: Icons.star_outline_rounded,
              label: 'Set as default',
              color: text,
              iconColor: muted,
              onTap: () => Navigator.pop(context, 'default'),
            ),
          _SheetOption(
            icon: Icons.edit_outlined,
            label: 'Edit card',
            color: text,
            iconColor: muted,
            onTap: () => Navigator.pop(context, 'edit'),
          ),
          _SheetOption(
            icon: Icons.delete_outline,
            label: 'Delete card',
            color: const Color(0xFFEF4444),
            iconColor: const Color(0xFFEF4444),
            onTap: () => Navigator.pop(context, 'delete'),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _SheetOption extends StatelessWidget {
  const _SheetOption({
    required this.icon,
    required this.label,
    required this.color,
    required this.iconColor,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Color iconColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            Icon(icon, size: 24, color: iconColor),
            const SizedBox(width: 16),
            Text(label, style: TextStyle(fontSize: 16, color: color)),
          ],
        ),
      ),
    );
  }
}
