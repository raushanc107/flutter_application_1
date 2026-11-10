import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'card_utils.dart';

/// The visual credit/debit card. Used both in the list (interactive) and as the
/// live preview in the add/edit form (non-interactive).
///
/// The full number is only drawn when [revealed] is true; otherwise just the
/// last four digits show. Tapping the eye / copy buttons never triggers
/// [onLongPress], which is what opens the card options.
class CardFace extends StatefulWidget {
  const CardFace({
    super.key,
    required this.name,
    required this.issuer,
    required this.cardType,
    required this.network,
    required this.cardNumber,
    required this.expiry,
    required this.holderName,
    required this.tone,
    required this.isDefault,
    this.revealed = false,
    this.onToggleReveal,
    this.onCopy,
    this.onLongPress,
  });

  final String name;
  final String issuer;
  final String cardType;
  final String network;
  final String cardNumber;
  final String expiry;
  final String holderName;
  final String tone;
  final bool isDefault;
  final bool revealed;
  final VoidCallback? onToggleReveal;
  final VoidCallback? onCopy;
  final VoidCallback? onLongPress;

  @override
  State<CardFace> createState() => _CardFaceState();
}

class _CardFaceState extends State<CardFace> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value && mounted) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final colors = CardTones.colors(widget.tone);
    final interactive = widget.onToggleReveal != null;
    final shown = widget.revealed && interactive;
    final number = shown
        ? CardNumbers.format(widget.cardNumber)
        : CardNumbers.mask(widget.cardNumber);

    final face = AspectRatio(
      aspectRatio: 1.586,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: colors,
          ),
          boxShadow: [
            BoxShadow(
              color: colors.last.withValues(alpha: 0.45),
              blurRadius: 22,
              offset: const Offset(0, 10),
              spreadRadius: -6,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              const _Decoration(),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.issuer.isEmpty
                                    ? 'Bank name'
                                    : widget.issuer,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${CardTypes.label(widget.cardType)} card',
                                style: const TextStyle(
                                  color: Color(0xCCFFFFFF),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (widget.isDefault) const _DefaultPill(),
                        if (interactive) ...[
                          const SizedBox(width: 8),
                          _FaceButton(
                            icon: shown
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            tooltip: shown
                                ? 'Hide card number'
                                : 'Show full card number',
                            onTap: widget.onToggleReveal!,
                          ),
                        ],
                      ],
                    ),
                    const Spacer(),
                    SizedBox(
                      height: 34,
                      child: Row(
                        children: [
                          Expanded(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                number,
                                maxLines: 1,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: shown ? 19 : 22,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: shown ? 1.2 : 2,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          if (shown && widget.onCopy != null) ...[
                            const SizedBox(width: 10),
                            _FaceButton(
                              icon: Icons.copy_rounded,
                              tooltip: 'Copy card number',
                              onTap: widget.onCopy!,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const Spacer(),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: _Meta(
                            label: widget.name.isEmpty
                                ? 'Card name'
                                : widget.name,
                            value: widget.holderName.isEmpty
                                ? 'Name on card'
                                : widget.holderName,
                          ),
                        ),
                        const SizedBox(width: 12),
                        _Meta(
                          label: 'EXPIRES',
                          value: widget.expiry.isEmpty
                              ? 'MM/YY'
                              : widget.expiry,
                          alignEnd: true,
                        ),
                        const SizedBox(width: 14),
                        _NetworkMark(network: widget.network),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (!interactive) return face;

    return Semantics(
      container: true,
      label:
          '${widget.name}, ${CardTypes.label(widget.cardType)} card ending '
          '${CardNumbers.last4(widget.cardNumber)}. Press and hold for options.',
      onLongPress: widget.onLongPress,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        onLongPress: widget.onLongPress == null
            ? null
            : () {
                _setPressed(false);
                HapticFeedback.mediumImpact();
                widget.onLongPress!();
              },
        child: AnimatedScale(
          scale: _pressed ? 0.97 : 1,
          duration: Duration(milliseconds: _pressed ? 500 : 120),
          curve: Curves.easeOut,
          child: face,
        ),
      ),
    );
  }
}

class _Decoration extends StatelessWidget {
  const _Decoration();

  @override
  Widget build(BuildContext context) {
    Widget ring(double size, {Color? fill}) => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: fill,
        border: Border.all(color: const Color(0x26FFFFFF)),
      ),
    );
    return Stack(
      children: [
        Positioned(top: -90, right: -60, child: ring(220)),
        Positioned(top: -68, right: -38, child: ring(176)),
        Positioned(
          bottom: -120,
          right: -80,
          child: ring(250, fill: const Color(0x0DFFFFFF)),
        ),
      ],
    );
  }
}

class _DefaultPill extends StatelessWidget {
  const _DefaultPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0x26FFFFFF),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0x59FFFFFF)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_rounded, size: 13, color: Colors.white),
          SizedBox(width: 4),
          Text(
            'Default',
            style: TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _FaceButton extends StatelessWidget {
  const _FaceButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: const Color(0x26FFFFFF),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: Color(0x59FFFFFF)),
        ),
        child: InkWell(
          customBorder: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          onTap: onTap,
          // Absorbs a long-press so holding the button doesn't open the card
          // options that belong to the card itself.
          onLongPress: () {},
          child: SizedBox(
            width: 34,
            height: 34,
            child: Icon(icon, size: 18, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({
    required this.label,
    required this.value,
    this.alignEnd = false,
  });

  final String label;
  final String value;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xB3FFFFFF),
            fontSize: 9,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

class _NetworkMark extends StatelessWidget {
  const _NetworkMark({required this.network});

  final String network;

  @override
  Widget build(BuildContext context) {
    const white = TextStyle(color: Colors.white, fontWeight: FontWeight.w800);
    Widget child;
    switch (network) {
      case CardNetworks.visa:
        child = Text(
          'VISA',
          style: white.copyWith(
            fontSize: 20,
            fontStyle: FontStyle.italic,
            letterSpacing: -1,
          ),
        );
        break;
      case CardNetworks.mastercard:
        child = SizedBox(
          width: 42,
          height: 26,
          child: Stack(
            children: [
              Positioned(left: 0, child: _dot(const Color(0xFFEB001B))),
              Positioned(
                right: 0,
                child: _dot(const Color(0xFFF79E1B).withValues(alpha: 0.92)),
              ),
            ],
          ),
        );
        break;
      case CardNetworks.rupay:
        child = Text('RuPay', style: white.copyWith(fontSize: 15));
        break;
      case CardNetworks.amex:
        child = Text(
          'AMEX',
          style: white.copyWith(fontSize: 12, letterSpacing: 1),
        );
        break;
      default:
        child = Text(
          'CARD',
          style: white.copyWith(
            fontSize: 11,
            letterSpacing: 1.2,
            color: Colors.white70,
          ),
        );
    }
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 46),
      child: Align(alignment: Alignment.centerRight, child: child),
    );
  }

  Widget _dot(Color color) => Container(
    width: 24,
    height: 24,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}
