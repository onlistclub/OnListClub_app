/// Skeleton shimmer nativo (zero dipendenze) per gli stati di caricamento.
///
/// Sostituisce gli spinner su sfondo scuro con uno scheletro della UI che
/// "luccica" — coerente con la palette CLAUDE.md (sfondi blu profondo) e con il
/// carattere premium dell'app.
///
/// Performance (Samsung S7):
/// - un SOLO `AnimationController` per scheletro: il widget [Shimmer] fa da host
///   e con un `ShaderMask` spazza tutta la sotto-UI in un colpo solo;
/// - i [ShimmerBox] sono semplici rettangoli opachi (nessuna animazione propria);
/// - si anima solo lo shader (puro paint), niente layout; il tutto è isolato in
///   un `RepaintBoundary` per non invalidare il resto della schermata.
library;

import 'package:flutter/material.dart';

/// Host dello shimmer: avvolge uno scheletro di [ShimmerBox] e ci fa scorrere
/// sopra una banda chiara.
class Shimmer extends StatefulWidget {
  final Widget child;
  final Color baseColor;
  final Color highlightColor;
  final Duration period;

  const Shimmer({
    Key? key,
    required this.child,
    this.baseColor = const Color(0xFF1A1A2E),
    this.highlightColor = const Color(0xFF2E2E55),
    this.period = const Duration(milliseconds: 1400),
  }) : super(key: key);

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl =
      AnimationController(vsync: this, duration: widget.period)..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, child) {
          return ShaderMask(
            blendMode: BlendMode.srcATop,
            shaderCallback: (bounds) {
              // Banda chiara centrata che scorre da sinistra a destra.
              final dx = (_ctrl.value * 2 - 1) * bounds.width * 1.5;
              return LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  widget.baseColor,
                  widget.highlightColor,
                  widget.baseColor,
                ],
                stops: const [0.30, 0.50, 0.70],
                transform: _SlideGradient(dx),
              ).createShader(bounds);
            },
            child: child,
          );
        },
        child: widget.child,
      ),
    );
  }
}

/// Traslazione orizzontale del gradiente (la "spazzata" dello shimmer).
class _SlideGradient extends GradientTransform {
  final double dx;
  const _SlideGradient(this.dx);

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) =>
      Matrix4.translationValues(dx, 0, 0);
}

/// Singolo blocco-scheletro. Il colore è irrilevante: lo shader di [Shimmer] lo
/// rimpiazza. Serve solo a definire forma e raggio del placeholder.
class ShimmerBox extends StatelessWidget {
  final double? width;
  final double? height;
  final double radius;
  final EdgeInsetsGeometry margin;

  const ShimmerBox({
    Key? key,
    this.width,
    this.height,
    this.radius = 10,
    this.margin = EdgeInsets.zero,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        color: Colors.white, // sostituito dallo ShaderMask
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
