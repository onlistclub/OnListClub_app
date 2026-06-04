/// Micro-interazione di pressione condivisa in tutta l'app.
///
/// Scala leggermente il [child] mentre è premuto e invoca [onPressed] al
/// rilascio: è l'unico "linguaggio" di tap dell'app (lo stesso effetto è
/// incorporato in `OnlistPrimaryButton`). Estratto dalle copie locali di
/// `_AnimatedPressButton` per evitare duplicazione.
///
/// Performance (Samsung S7): anima solo `Transform.scale` via `ScaleTransition`
/// (nessun cambio di layout) → resta a 60fps. Se [onPressed] è null il widget è
/// disabilitato e non reagisce al tap.
library;

import 'package:flutter/material.dart';

class AnimatedPress extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final double pressedScale;
  final Duration duration;
  final HitTestBehavior behavior;

  const AnimatedPress({
    Key? key,
    required this.child,
    required this.onPressed,
    this.pressedScale = 0.96,
    this.duration = const Duration(milliseconds: 130),
    this.behavior = HitTestBehavior.opaque,
  }) : super(key: key);

  @override
  State<AnimatedPress> createState() => _AnimatedPressState();
}

class _AnimatedPressState extends State<AnimatedPress>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl =
      AnimationController(vsync: this, duration: widget.duration);
  late final Animation<double> _scale =
      Tween<double>(begin: 1.0, end: widget.pressedScale).animate(
    CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
  );

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disabled = widget.onPressed == null;
    return GestureDetector(
      behavior: widget.behavior,
      onTapDown: disabled ? null : (_) => _ctrl.forward(),
      onTapUp: disabled
          ? null
          : (_) {
              _ctrl.reverse();
              widget.onPressed!.call();
            },
      onTapCancel: disabled ? null : () => _ctrl.reverse(),
      child: ScaleTransition(scale: _scale, child: widget.child),
    );
  }
}
