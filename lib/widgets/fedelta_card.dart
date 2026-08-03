import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/constants/image_constant.dart';
import '../core/utils/responsive.dart';
import '../theme/onlist_colors.dart';
import '../theme/onlist_text_styles.dart';
import 'glow_card.dart';

/// Card "Tu e OnList" dell'Account: il riepilogo fedeltà con la palla da
/// discoteca (design ufficiale `assets/svg/ufficiali/riepilogo_fedelta.svg`).
///
/// L'SVG NON viene usato direttamente, di proposito:
///  - ha i testi convertiti in tracciati, quindi il numero di serate sarebbe
///    congelato a quello del mockup invece di arrivare dal database;
///  - pesa 712 KB, quasi tutti di un raster 3000×3000 usato per disegnare il
///    logo in un riquadro di 67×21;
///  - usa undici filtri `drop-shadow`, che `flutter_svg` supporta solo in
///    parte e renderebbe comunque in modo diverso dal Figma.
///
/// Qui la stessa grafica è ridisegnata in Flutter: costa qualche KB, i dati
/// restano vivi e in più si può animare.
///
/// Misure prese dal PNG ufficiale (`Account aggiornato ma solo parte sopra`),
/// in px design su una card 357×126:
///  - palla: centro (244, 68), raggio 42
///  - filo: dal bordo alto della card fino alla cima della palla
///  - coriandoli: losanghe chiare, posizioni approssimate dal render
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
  static const double ballCx = 244;
  static const double ballCy = 68;
  static const double ballR = 42;

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
                // Palla + filo + coriandoli: un solo painter, così è un solo
                // layer che si ridipinge mentre la palla gira.
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

  Widget _buildTesti() {
    return Padding(
      padding: EdgeInsets.fromLTRB(R.sp(22), R.sp(27), 0, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // "Tu e" + il wordmark OnList, come nel design (nell'SVG il logo è
          // un raster da 3000² incorporato: qui si riusa l'asset già in app).
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Tu e ',
                style: OnlistTextStyles.hn(
                  fontSize: R.sp(20),
                  fontWeight: FontWeight.w700,
                  color: OnlistColors.white,
                  height: 20 / 20,
                ),
              ),
              Image.asset(
                ImageConstant.imgLogoOnlistWordmark,
                height: R.sp(20),
                fit: BoxFit.contain,
              ),
            ],
          ),
          SizedBox(height: R.sp(9)),
          AnimatedBuilder(
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
                ),
              );
            },
          ),
          SizedBox(height: R.sp(9)),
          Text(
            'da quando ti sei unito al club',
            style: OnlistTextStyles.hn(
              fontSize: R.sp(12),
              fontWeight: FontWeight.w700,
              color: OnlistColors.white,
              height: 12 / 12,
            ),
          ),
        ],
      ),
    );
  }
}

/// Disegna palla da discoteca, filo e coriandoli.
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

  /// Losanghe: (x, y, semi-lato, rotazione in giri, opacità) in px design.
  static const List<List<double>> _confetti = [
    [160, 29, 7, 0.06, 0.55],
    [320, 24, 9, -0.04, 0.65],
    [352, 51, 6, 0.10, 0.40],
    [150, 116, 6, -0.08, 0.35],
    [332, 111, 7, 0.05, 0.45],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    // Il painter lavora in px design e scala una volta sola sul canvas: così
    // le misure restano quelle misurate sul PNG ufficiale.
    final double k = size.width / FedeltaCard.cardW;
    canvas.save();
    canvas.scale(k);

    _paintConfetti(canvas);
    _paintString(canvas);
    _paintBall(canvas);

    canvas.restore();
  }

  void _paintConfetti(Canvas canvas) {
    for (final c in _confetti) {
      canvas.save();
      canvas.translate(c[0], c[1]);
      canvas.rotate(c[3] * 2 * math.pi);
      final r = c[2];
      final path = Path()
        ..moveTo(0, -r)
        ..lineTo(r * 0.62, 0)
        ..lineTo(0, r)
        ..lineTo(-r * 0.62, 0)
        ..close();
      canvas.drawPath(
        path,
        Paint()..color = OnlistColors.white.withValues(alpha: c[4]),
      );
      canvas.restore();
    }
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
