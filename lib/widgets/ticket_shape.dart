import 'package:flutter/material.dart';

import '../core/utils/responsive.dart';
import '../theme/onlist_colors.dart';

/// Forma "biglietto fisico" del nuovo design ufficiale
/// (CSS `(NUOVO) - Riepilogo Ticket.css`, Rectangle 265 + Ellipse 20/21):
/// rettangolo arrotondato (raggio 32 design px) con due TACCHE semicircolari
/// (Ø44 design px) scavate geometricamente nei bordi laterali, gradiente
/// `#0000F7 → #0000A9 (94.71%)`, bordo 2px bianco 41% che segue anche il
/// profilo delle tacche, glow interno ciano `#00E6FF`.
///
/// Il glow è l'approssimazione dell'`inset box-shadow` CSS (0 2px 100px), che
/// Flutter non ha nativo: si riempie di ciano l'area ESTERNA al path, la si
/// sfoca (sigma = blur/2 = 50 design px) e la si clippa dentro la forma — è la
/// tecnica canonica dell'inner shadow.
///
/// [notchCenterYFraction] è la quota verticale del centro delle tacche come
/// frazione dell'altezza (0..1): ~0.64 nella card della lista ordini, più in
/// basso nel ticket aperto (schermata dettaglio). Tutte le misure design
/// passano da [R.sp]: la forma scala identica su qualsiasi schermo.
class TicketShape extends StatelessWidget {
  final Widget child;

  /// Quota verticale (0..1) del centro delle tacche laterali.
  final double notchCenterYFraction;

  const TicketShape({
    Key? key,
    required this.child,
    required this.notchCenterYFraction,
  }) : super(key: key);

  // Valori design (px Figma, frame 393×852) dal CSS ufficiale.
  static const double _designCornerRadius = 32;
  static const double _designNotchRadius = 22; // Ellipse 20/21: Ø44
  static const double _designBorderWidth = 2;
  static const double _designGlowSigma = 50; // blur CSS 100 → sigma ≈ 50
  static const double _designGlowOffsetY = 2;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _TicketPainter(
        cornerRadius: R.sp(_designCornerRadius),
        notchRadius: R.sp(_designNotchRadius),
        notchCenterYFraction: notchCenterYFraction,
        borderWidth: R.sp(_designBorderWidth),
        glowSigma: R.sp(_designGlowSigma),
        glowOffsetY: R.sp(_designGlowOffsetY),
      ),
      child: child,
    );
  }
}

class _TicketPainter extends CustomPainter {
  final double cornerRadius;
  final double notchRadius;
  final double notchCenterYFraction;
  final double borderWidth;
  final double glowSigma;
  final double glowOffsetY;

  const _TicketPainter({
    required this.cornerRadius,
    required this.notchRadius,
    required this.notchCenterYFraction,
    required this.borderWidth,
    required this.glowSigma,
    required this.glowOffsetY,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final notchY = size.height * notchCenterYFraction;

    // Path del biglietto: rettangolo arrotondato MENO i due cerchi centrati
    // esattamente sui bordi laterali → tacche scavate, identiche al design.
    final base = Path()
      ..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(cornerRadius)));
    final notches = Path()
      ..addOval(Rect.fromCircle(center: Offset(0, notchY), radius: notchRadius))
      ..addOval(Rect.fromCircle(
          center: Offset(size.width, notchY), radius: notchRadius));
    final ticket = Path.combine(PathOperation.difference, base, notches);

    // 1. Fill col gradiente ufficiale.
    canvas.drawPath(
      ticket,
      Paint()..shader = OnlistColors.ticketCard.createShader(rect),
    );

    // 2. Glow interno ciano (inner shadow): area esterna al path riempita di
    //    ciano, sfocata e clippata dentro la forma.
    canvas.save();
    canvas.clipPath(ticket);
    final outside = Path.combine(
      PathOperation.difference,
      Path()..addRect(rect.inflate(glowSigma * 3)),
      ticket.shift(Offset(0, glowOffsetY)),
    );
    canvas.drawPath(
      outside,
      Paint()
        ..color = OnlistColors.ticketCardGlow
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, glowSigma),
    );
    canvas.restore();

    // 3. Bordo che segue anche il profilo delle tacche.
    canvas.drawPath(
      ticket,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = borderWidth
        ..color = OnlistColors.ticketCardBorder,
    );
  }

  @override
  bool shouldRepaint(_TicketPainter oldDelegate) =>
      cornerRadius != oldDelegate.cornerRadius ||
      notchRadius != oldDelegate.notchRadius ||
      notchCenterYFraction != oldDelegate.notchCenterYFraction ||
      borderWidth != oldDelegate.borderWidth ||
      glowSigma != oldDelegate.glowSigma ||
      glowOffsetY != oldDelegate.glowOffsetY;
}
