import 'package:flutter/material.dart';

/// Rettangolo arrotondato con gradiente e OMBRA INTERNA (inset box-shadow del
/// CSS, che Flutter non ha nativo): l'area esterna al rettangolo viene
/// riempita del colore del glow, sfocata e clippata dentro la forma — stessa
/// tecnica canonica usata da TicketShape.
///
/// Usato dal nuovo design NUOVO per la CTA "RISERVA IL TUO POSTO ORA"
/// (radial blu + glow ciano) e per le card club della Home (linear blu +
/// ombra interna nera).
///
/// NB: tutti i valori sono in px REALI (già scalati dal chiamante con R.sp
/// quando serve): dentro un FittedBox/scale-to-width i valori design vanno
/// passati così come sono, senza doppia scalatura.
class GlowCard extends StatelessWidget {
  final Widget? child;
  final Gradient gradient;
  final double radius;
  final Color glowColor;

  /// Sigma della sfocatura (CSS: blur/2).
  final double glowSigma;
  final Offset glowOffset;

  const GlowCard({
    Key? key,
    required this.gradient,
    required this.radius,
    required this.glowColor,
    required this.glowSigma,
    this.glowOffset = Offset.zero,
    this.child,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _GlowCardPainter(
        gradient: gradient,
        radius: radius,
        glowColor: glowColor,
        glowSigma: glowSigma,
        glowOffset: glowOffset,
      ),
      child: child,
    );
  }
}

class _GlowCardPainter extends CustomPainter {
  final Gradient gradient;
  final double radius;
  final Color glowColor;
  final double glowSigma;
  final Offset glowOffset;

  const _GlowCardPainter({
    required this.gradient,
    required this.radius,
    required this.glowColor,
    required this.glowSigma,
    required this.glowOffset,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    final shape = Path()..addRRect(rrect);

    // 1. Fill col gradiente.
    canvas.drawPath(shape, Paint()..shader = gradient.createShader(rect));

    // 2. Ombra/glow interno: inverso del path sfocato e clippato dentro.
    canvas.save();
    canvas.clipPath(shape);
    final outside = Path.combine(
      PathOperation.difference,
      Path()..addRect(rect.inflate(glowSigma * 3)),
      shape.shift(glowOffset),
    );
    canvas.drawPath(
      outside,
      Paint()
        ..color = glowColor
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, glowSigma),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GlowCardPainter oldDelegate) =>
      gradient != oldDelegate.gradient ||
      radius != oldDelegate.radius ||
      glowColor != oldDelegate.glowColor ||
      glowSigma != oldDelegate.glowSigma ||
      glowOffset != oldDelegate.glowOffset;
}
