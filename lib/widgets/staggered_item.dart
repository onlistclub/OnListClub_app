/// Entrata "staggered" per gli item di lista: fade-in + lieve slide-up con un
/// ritardo crescente per indice. È lo stesso linguaggio di movimento delle
/// schermate con stagger (home, club detail), riportato sulle liste.
///
/// Solo i primi [maxStaggered] item animano; gli altri compaiono subito. Questo
/// evita ritardi fastidiosi su liste lunghe e ri-animazioni strane durante lo
/// scroll (gli item in coda non aspettano un delay proporzionale all'indice).
///
/// Performance (Samsung S7): anima solo `Opacity` + `Transform` (slide), nessun
/// cambio di layout → 60fps. Gli item oltre la soglia non creano nemmeno il
/// controller.
library;

import 'package:flutter/material.dart';

class StaggeredItem extends StatefulWidget {
  final int index;
  final Widget child;
  final int maxStaggered;
  final Duration step;
  final Duration duration;

  const StaggeredItem({
    Key? key,
    required this.index,
    required this.child,
    this.maxStaggered = 8,
    this.step = const Duration(milliseconds: 45),
    this.duration = const Duration(milliseconds: 320),
  }) : super(key: key);

  @override
  State<StaggeredItem> createState() => _StaggeredItemState();
}

class _StaggeredItemState extends State<StaggeredItem>
    with SingleTickerProviderStateMixin {
  AnimationController? _ctrl;
  Animation<double>? _fade;
  Animation<Offset>? _slide;

  @override
  void initState() {
    super.initState();
    // Oltre la soglia niente animazione: l'item compare subito.
    if (widget.index >= widget.maxStaggered) return;

    final ctrl = AnimationController(vsync: this, duration: widget.duration);
    _ctrl = ctrl;
    _fade = CurvedAnimation(parent: ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(CurvedAnimation(parent: ctrl, curve: Curves.easeOutCubic));

    Future.delayed(widget.step * widget.index, () {
      if (mounted) ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fade = _fade;
    final slide = _slide;
    if (fade == null || slide == null) return widget.child;
    return FadeTransition(
      opacity: fade,
      child: SlideTransition(position: slide, child: widget.child),
    );
  }
}
