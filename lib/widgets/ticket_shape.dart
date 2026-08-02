import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/utils/responsive.dart';
import '../theme/onlist_colors.dart';

/// Una tacca (semicerchio o semiellisse) scavata nei bordi di un [TicketShape].
///
/// Tutte le misure sono in px design (frame Figma 393×852) e vengono scalate
/// con [R.sp]; la posizione verticale è una FRAZIONE dell'altezza della card,
/// così su schermi diversi la tacca resta nella stessa posizione relativa.
class TicketNotch {
  /// Quota verticale (0..1) del centro della tacca rispetto all'altezza card.
  final double centerYFraction;

  /// Semiasse ORIZZONTALE in px design (es. Ø44 → 22, Ø41 → 20.5, Ø51 → 25.5).
  final double radiusDesign;

  /// Semiasse VERTICALE in px design. Se null la tacca è un cerchio.
  /// Il CSS del ticket aperto usa `Ellipse 18` 41×38, cioè 20.5 × 19.
  final double? radiusYDesign;

  /// Quali lati scavare (la card carrello ha la tacca solo a sinistra).
  final bool left;
  final bool right;

  /// Spostamento del centro verso l'ESTERNO del bordo, in px design:
  /// 0 = centro esattamente sul bordo (tacca = semicerchio pieno);
  /// >0 = tacca meno profonda (ticket aperto: 1.5; carrello: ~6.5).
  final double edgeOffsetDesign;

  const TicketNotch({
    required this.centerYFraction,
    required this.radiusDesign,
    this.radiusYDesign,
    this.left = true,
    this.right = true,
    this.edgeOffsetDesign = 0,
  });

  @override
  bool operator ==(Object other) =>
      other is TicketNotch &&
      other.centerYFraction == centerYFraction &&
      other.radiusDesign == radiusDesign &&
      other.radiusYDesign == radiusYDesign &&
      other.left == left &&
      other.right == right &&
      other.edgeOffsetDesign == edgeOffsetDesign;

  @override
  int get hashCode => Object.hash(centerYFraction, radiusDesign, radiusYDesign,
      left, right, edgeOffsetDesign);
}

/// Card a forma di "biglietto fisico" del design ufficiale (cartella
/// `docs/figma_screen/off/NUOVO`): rettangolo arrotondato con tacche scavate
/// geometricamente nei bordi, gradiente `#0000F7 → #0000A9 (94.71%)`, bordo
/// bianco e glow interno ciano `#00E6FF`.
///
/// Bordo e glow seguono SOLO il rettangolo arrotondato e si interrompono sulla
/// tacca: nel CSS la tacca è un'ellisse nera sovrapposta, quindi non ha né
/// contorno né alone. Tracciandoli sul profilo scavato (com'era prima) le
/// tacche si accendevano di un alone azzurrino che nel design non c'è.
///
/// Il glow è l'approssimazione dell'`inset box-shadow` CSS (0 2px 100px), che
/// Flutter non ha nativo: si riempie di ciano l'area ESTERNA al path, la si
/// sfoca (sigma = blur/2 = 50 design px) e la si clippa dentro la forma — è la
/// tecnica canonica dell'inner shadow.
///
/// Varianti coperte (tutte parametriche, px design → [R.sp]):
/// - carrello lista: raggio 21, bordo 2px bianco 41%, tacca Ø51 solo sinistra
///   centrata verticalmente e arretrata di ~6.5px;
/// - card ordini/conferma: raggio 32, bordo 2px 41%, coppia Ø44 a ~64%;
/// - ticket aperto: raggio 32, bordo 3px 44%, una o due coppie di tacche.
class TicketShape extends StatelessWidget {
  final Widget child;

  /// Tacche da scavare (vuota = semplice card arrotondata col glow).
  final List<TicketNotch> notches;

  /// Raggio degli angoli in px design (21 carrello lista, 32 altrove).
  final double cornerRadiusDesign;

  /// Spessore bordo in px design: 2 nelle card piccole, 3 nel ticket aperto.
  final double borderWidthDesign;

  /// Colore bordo: bianco 41% (card piccole) o bianco 44% (ticket aperto).
  final Color borderColor;

  const TicketShape({
    Key? key,
    required this.child,
    required this.notches,
    this.cornerRadiusDesign = 32,
    this.borderWidthDesign = 2,
    this.borderColor = OnlistColors.ticketCardBorder,
  }) : super(key: key);

  // Glow interno (identico in tutti i CSS): inset 0px 2px 100px #00E6FF.
  static const double _designGlowSigma = 50; // blur CSS 100 → sigma ≈ 50
  static const double _designGlowOffsetY = 2;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _TicketPainter(
        cornerRadius: R.sp(cornerRadiusDesign),
        notches: notches,
        borderWidth: R.sp(borderWidthDesign),
        borderColor: borderColor,
        glowSigma: R.sp(_designGlowSigma),
        glowOffsetY: R.sp(_designGlowOffsetY),
      ),
      child: child,
    );
  }
}

class _TicketPainter extends CustomPainter {
  final double cornerRadius;
  final List<TicketNotch> notches;
  final double borderWidth;
  final Color borderColor;
  final double glowSigma;
  final double glowOffsetY;

  const _TicketPainter({
    required this.cornerRadius,
    required this.notches,
    required this.borderWidth,
    required this.borderColor,
    required this.glowSigma,
    required this.glowOffsetY,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // Path del biglietto: rettangolo arrotondato MENO le ellissi delle tacche
    // centrate sui bordi laterali → tacche scavate, identiche al design.
    final base = Path()
      ..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(cornerRadius)));
    final holes = Path();
    for (final n in notches) {
      final y = size.height * n.centerYFraction;
      final rx = R.sp(n.radiusDesign);
      final ry = R.sp(n.radiusYDesign ?? n.radiusDesign);
      final off = R.sp(n.edgeOffsetDesign);
      if (n.left) {
        holes.addOval(Rect.fromCenter(
            center: Offset(-off, y), width: rx * 2, height: ry * 2));
      }
      if (n.right) {
        holes.addOval(Rect.fromCenter(
            center: Offset(size.width + off, y),
            width: rx * 2,
            height: ry * 2));
      }
    }
    final ticket = notches.isEmpty
        ? base
        : Path.combine(PathOperation.difference, base, holes);

    // 1. Fill col gradiente ufficiale.
    canvas.drawPath(
      ticket,
      Paint()..shader = OnlistColors.ticketCard.createShader(rect),
    );

    // Glow e bordo si calcolano sul rettangolo BASE, non sulla forma scavata, e
    // vengono poi clippati dentro di essa. Nel CSS la tacca è un'ellisse NERA
    // sovrapposta (`Ellipse 18`, background #000000): il bordo segue solo il
    // rettangolo arrotondato e si INTERROMPE sulla tacca, che resta nera netta.
    // Usando la forma scavata (com'era prima) il bordo bianco tracciava anche
    // gli archi e il glow ciano ci si accendeva intorno → alone azzurrino.
    // 2. Glow interno ciano (inner shadow): area esterna al rettangolo base
    //    riempita di ciano, sfocata e tenuta dentro la forma del biglietto.
    canvas.save();
    canvas.clipPath(ticket);
    final outside = Path.combine(
      PathOperation.difference,
      Path()..addRect(rect.inflate(glowSigma * 3)),
      base.shift(Offset(0, glowOffsetY)),
    );
    canvas.drawPath(
      outside,
      Paint()
        ..color = OnlistColors.ticketCardGlow
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, glowSigma),
    );
    canvas.restore();

    // 3. Bordo del solo rettangolo arrotondato. Il clip toglie SOLO le tacche
    //    (non l'intera area esterna al biglietto): così il tratto conserva la
    //    sua metà esterna — clippando su `ticket` sarebbe uscito spesso metà —
    //    e si interrompe di netto dove c'è la tacca.
    canvas.save();
    if (notches.isNotEmpty) {
      canvas.clipPath(Path.combine(
        PathOperation.difference,
        Path()..addRect(rect.inflate(borderWidth * 2)),
        holes,
      ));
    }
    canvas.drawPath(
      base,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = borderWidth
        ..color = borderColor,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_TicketPainter oldDelegate) =>
      cornerRadius != oldDelegate.cornerRadius ||
      !listEquals(notches, oldDelegate.notches) ||
      borderWidth != oldDelegate.borderWidth ||
      borderColor != oldDelegate.borderColor ||
      glowSigma != oldDelegate.glowSigma ||
      glowOffsetY != oldDelegate.glowOffsetY;
}
