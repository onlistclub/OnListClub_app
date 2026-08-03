import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../core/constants/image_constant.dart';
import '../core/utils/responsive.dart';
import '../theme/onlist_colors.dart';
import '../theme/onlist_text_styles.dart';
import 'glow_card.dart';
import 'onlist_wordmark.dart';

/// Card "Tu e OnList" dell'Account: il riepilogo fedeltà con la palla da
/// discoteca.
///
/// L'SVG di partenza (`riepilogo_fedelta.svg`, 712 KB) non si può spedire
/// così com'è: ha i testi convertiti in tracciati — il numero di serate
/// resterebbe congelato a quello del mockup invece di arrivare dal DB — e
/// quasi tutto il peso è un raster 3000×3000 usato per un logo di 67×21.
///
/// La card è quindi ricomposta da tre pezzi:
///  - **fondo e testi** in Flutter, così i dati restano vivi;
///  - **coriandoli** dai tracciati ufficiali ([ImageConstant.imgCoriandoli],
///    3 KB): sono curve bezier, riprodurle a mano sarebbe solo approssimarle;
///  - **palla e filo** disegnati in [_FedeltaPainter], perché devono girare.
///
/// Misure CONFERMATE dall'export Figma del `Group 426`
/// (`docs/riepilogo_Viola/Group 426.svg`), card 357×126 a (18, 250):
///  - `Vector 2` (filo): linea verticale a x=261.4 da y=250 a y=276.5
///    → relativa alla card: x=243.4, dal bordo alto fino a 26.5
///  - da lì la palla: centro (243.4, 68.5), raggio 42
///  - `filter0_i`: ombra interna bianca, stdDeviation 10
///  - testi: `Tu e` 20/w500, `50 serate` 32/bold, `da quando…` 12/w500,
///    tutti con letter-spacing -0.05em; il numero è RIENTRATO (x=47.3
///    contro i 22 delle altre due righe)
///
/// I coriandoli sono curve bezier, non forme regolari: si disegnano
/// dall'SVG ufficiale ([ImageConstant.imgCoriandoli], 3 KB) invece di
/// riprodurli a mano. La palla resta procedurale perché deve girare.
class FedeltaCard extends StatefulWidget {
  const FedeltaCard({
    super.key,
    required this.numeroSerate,
    this.animate = true,
  });

  /// Serate dell'utente: arriva dal DB, per questo la card non può essere
  /// l'SVG statico.
  final int numeroSerate;

  /// A false la card è ferma (palla non ruota, numero già al valore finale).
  /// Serve ai test e alle prove di rendering.
  final bool animate;

  // ── Misure design (card 357×126) ──────────────────────────────────────────
  static const double cardW = 357;
  static const double cardH = 126;

  /// x del filo nell'export (261.4) meno il bordo sinistro della card (18).
  static const double ballCx = 243.4;

  /// Il filo arriva a y=276.5, cioè 26.5 dal bordo card: + il raggio.
  static const double ballR = 42;
  static const double ballCy = 26.5 + ballR;

  @override
  State<FedeltaCard> createState() => _FedeltaCardState();
}

class _FedeltaCardState extends State<FedeltaCard>
    with TickerProviderStateMixin {
  /// Giro completo della palla. Lento di proposito: deve leggersi come una
  /// palla da discoteca che gira, non come un caricamento.
  static const Duration _spinPeriod = Duration(seconds: 12);

  /// Conteggio del numero all'apertura: parte da 0 e sale al valore vero.
  static const Duration _countDuration = Duration(milliseconds: 800);

  late final AnimationController _spinCtrl;
  late final AnimationController _countCtrl;
  late Animation<double> _count;

  @override
  void initState() {
    super.initState();
    _spinCtrl = AnimationController(vsync: this, duration: _spinPeriod);
    _countCtrl = AnimationController(vsync: this, duration: _countDuration);
    _buildCountTween();
    if (widget.animate) {
      _spinCtrl.repeat();
      if (widget.numeroSerate > 0) _countCtrl.forward();
    } else {
      _countCtrl.value = 1;
    }
  }

  void _buildCountTween() {
    _count = Tween<double>(begin: 0, end: widget.numeroSerate.toDouble())
        .animate(
            CurvedAnimation(parent: _countCtrl, curve: Curves.easeOutCubic));
  }

  @override
  void didUpdateWidget(FedeltaCard old) {
    super.didUpdateWidget(old);
    // Il conteggio arriva dopo il primo build (fetch async): quando cambia,
    // rifà la salita dal valore mostrato finora.
    if (old.numeroSerate != widget.numeroSerate) {
      _buildCountTween();
      if (widget.animate && widget.numeroSerate > 0) {
        _countCtrl.forward(from: 0);
      } else {
        _countCtrl.value = 1;
      }
    }
  }

  @override
  void dispose() {
    _spinCtrl.dispose();
    _countCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: R.sp(18)),
      child: SizedBox(
        height: R.sp(FedeltaCard.cardH),
        width: double.infinity,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(R.sp(8)),
          child: GlowCard(
            // Fondo viola pieno #7300FF (nell'SVG è un fill, non un gradiente).
            gradient: const LinearGradient(
              colors: [Color(0xFF7300FF), Color(0xFF7300FF)],
            ),
            radius: R.sp(8),
            // `filter0_i` dell'SVG: ombra interna BIANCA, stdDeviation 10.
            glowColor: OnlistColors.white,
            glowSigma: R.sp(10),
            child: Stack(
              children: [
                // Coriandoli: tracciati ufficiali, fermi. Il viewBox dell'SVG
                // è il rettangolo della card, quindi basta stenderlo sopra.
                Positioned.fill(
                  child: SvgPicture.asset(
                    ImageConstant.imgCoriandoli,
                    fit: BoxFit.fill,
                  ),
                ),
                // Palla + filo: dentro un RepaintBoundary, così mentre gira si
                // ridipinge solo questo layer e non i coriandoli né i testi.
                Positioned.fill(
                  child: RepaintBoundary(
                    child: AnimatedBuilder(
                      animation: _spinCtrl,
                      builder: (context, _) => CustomPaint(
                        painter: _FedeltaPainter(spin: _spinCtrl.value),
                      ),
                    ),
                  ),
                ),
                _buildTesti(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Testi ai valori dell'export Figma. Le tre righe non sono allineate a
  /// sinistra fra loro: il numero è RIENTRATO di ~25px (x=65.3 contro 40).
  Widget _buildTesti() {
    return Padding(
      // 40 − 18 (bordo card) = 22 dal bordo; 27 = il top del logo (y=277).
      padding: EdgeInsets.fromLTRB(R.sp(22), R.sp(27), 0, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // "Tu e" 20/w500 + il wordmark OnList (`FINALE INTERO 1` nell'export
          // è un raster 3000² da 686 KB: qui si riusa l'asset già in app).
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Tu e ',
                style: OnlistTextStyles.hn(
                  fontSize: R.sp(20),
                  fontWeight: FontWeight.w500,
                  color: OnlistColors.white,
                  height: 20 / 20,
                  letterSpacing: -0.05 * 20,
                ),
              ),
              // Stesso wordmark ufficiale della navbar, con lo stesso
              // ritaglio: prima era un Image.asset diretto e la scritta usciva
              // alta un quarto del previsto (~8px su 32), persa nel canvas
              // trasparente. Vedi [OnlistWordmark].
              // 24 contro i 21 del Figma: "aumentare di tanto" (punto 23).
              OnlistWordmark(height: R.sp(24)),
            ],
          ),
          SizedBox(height: R.sp(9)),
          // Rientro del numero: x=65.33 nell'export, contro i 40 delle altre
          // due righe → 25.3 in più.
          Padding(
            padding: EdgeInsets.only(left: R.sp(25.3)),
            child: AnimatedBuilder(
              animation: _count,
              builder: (context, _) {
                final n = _count.value.round();
                return Text(
                  '$n ${n == 1 ? 'serata' : 'serate'}',
                  style: OnlistTextStyles.hn(
                    fontSize: R.sp(32),
                    fontWeight: FontWeight.w700,
                    color: OnlistColors.white,
                    height: 32 / 32,
                    letterSpacing: -0.05 * 32,
                  ),
                );
              },
            ),
          ),
          // 9 → 4: "alzare di poco la scritta" (punto 23 del doc correzioni).
          SizedBox(height: R.sp(4)),
          Text(
            'da quando ti sei unito al club',
            style: OnlistTextStyles.hn(
              fontSize: R.sp(12),
              fontWeight: FontWeight.w500,
              color: OnlistColors.white,
              height: 12 / 12,
              letterSpacing: -0.05 * 12,
            ),
          ),
        ],
      ),
    );
  }
}

/// Disegna la palla da discoteca e il suo filo.
///
/// I coriandoli NON stanno qui: sono i tracciati ufficiali di
/// `coriandoli.svg`, disegnati sotto come SvgPicture. Sono fermi, quindi
/// tenerli fuori da questo painter evita di ridisegnarli a ogni frame.
///
/// La palla è una sfera con la griglia di faccette: i paralleli sono ellissi
/// schiacciate, i meridiani ellissi verticali la cui larghezza dipende dal
/// coseno della longitudine. Facendo scorrere la fase dei meridiani la palla
/// sembra girare, senza ricalcolare nulla di pesante.
class _FedeltaPainter extends CustomPainter {
  const _FedeltaPainter({required this.spin});

  /// Avanzamento del giro, 0..1.
  final double spin;

  /// Quanti meridiani e paralleli (nel render ufficiale se ne contano ~8×6).
  static const int _meridians = 8;
  static const int _parallels = 6;

  @override
  void paint(Canvas canvas, Size size) {
    // Il painter lavora in px design e scala una volta sola sul canvas: così
    // le misure restano quelle misurate sul PNG ufficiale.
    final double k = size.width / FedeltaCard.cardW;
    canvas.save();
    canvas.scale(k);

    _paintString(canvas);
    _paintBall(canvas);

    canvas.restore();
  }

  void _paintString(Canvas canvas) {
    canvas.drawLine(
      const Offset(FedeltaCard.ballCx, 0),
      const Offset(FedeltaCard.ballCx, FedeltaCard.ballCy - FedeltaCard.ballR),
      Paint()
        ..color = OnlistColors.white.withValues(alpha: 0.55)
        ..strokeWidth = 1,
    );
  }

  void _paintBall(Canvas canvas) {
    const c = Offset(FedeltaCard.ballCx, FedeltaCard.ballCy);
    const r = FedeltaCard.ballR;
    final sphere = Rect.fromCircle(center: c, radius: r);

    // Corpo: più chiaro in alto a sinistra, come nel render ufficiale.
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.35, -0.4),
          radius: 0.95,
          colors: [Color(0xFFE6DAFF), Color(0xFF9B6BE8)],
        ).createShader(sphere),
    );

    canvas.save();
    canvas.clipPath(Path()..addOval(sphere));

    final grid = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = OnlistColors.white.withValues(alpha: 0.55);

    // Paralleli: ellissi orizzontali sempre più schiacciate verso i poli.
    for (int i = 1; i < _parallels; i++) {
      final t = i / _parallels; // 0..1 dal polo nord al polo sud
      final phi = (t - 0.5) * math.pi; // -π/2 .. π/2
      final y = c.dy + r * math.sin(phi);
      final rx = r * math.cos(phi);
      final ry = rx * 0.22; // prospettiva della sfera
      canvas.drawOval(
        Rect.fromCenter(center: Offset(c.dx, y), width: rx * 2, height: ry * 2),
        grid,
      );
    }

    // Meridiani: la fase scorre col giro. La larghezza dell'ellisse è
    // r·|cos(longitudine)|, cioè come si proietta un meridiano su una sfera.
    for (int i = 0; i < _meridians; i++) {
      final lon = (i / _meridians + spin) * 2 * math.pi;
      final rx = (r * math.cos(lon)).abs();
      canvas.drawOval(
        Rect.fromCenter(center: c, width: rx * 2, height: r * 2),
        grid,
      );
    }

    // Riflesso: una macchia chiara in alto a sinistra, per dare volume.
    canvas.drawCircle(
      Offset(c.dx - r * 0.35, c.dy - r * 0.4),
      r * 0.42,
      Paint()
        ..shader = RadialGradient(
          colors: [
            OnlistColors.white.withValues(alpha: 0.5),
            OnlistColors.white.withValues(alpha: 0),
          ],
        ).createShader(
          Rect.fromCircle(
            center: Offset(c.dx - r * 0.35, c.dy - r * 0.4),
            radius: r * 0.42,
          ),
        ),
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(_FedeltaPainter old) => old.spin != spin;
}
