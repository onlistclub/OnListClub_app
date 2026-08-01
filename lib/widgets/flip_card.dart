import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Rotazione 3D sull'asse Y per mostrare le due facce di un biglietto.
///
/// Porta in Flutter la meccanica della flip card CSS di riferimento:
/// `perspective: 2000px` → [Matrix4.setEntry] (3,2, 1/2000 = 0.0005),
/// `transform: rotateY(180deg)` → [Matrix4.rotateY],
/// `backface-visibility: hidden` → a metà corsa si scambia la faccia
/// mostrata e il retro viene contro-ruotato di π, così il suo contenuto non
/// appare mai specchiato.
///
/// Differenza voluta rispetto al riferimento web: il trigger NON è l'hover
/// (inesistente su mobile) ma [showBack], pilotato dai bottoni
/// "VISUALIZZA QR CODE" / "NASCONDI".
///
/// Solo la faccia visibile viene costruita (l'altra non è nell'albero):
/// nessun doppio layout, nessun QR renderizzato quando non serve — conta su
/// device datati (Galaxy S7). [AnimatedSize] assorbe la differenza di altezza
/// tra fronte e retro, così il contenuto sotto la card non "salta".
class FlipCard extends StatefulWidget {
  /// Faccia mostrata a riposo.
  final Widget front;

  /// Faccia mostrata dopo la rotazione.
  final Widget back;

  /// true = mostra [back]. Cambiandolo parte l'animazione.
  final bool showBack;

  /// Durata di mezza rotazione completa (default 700ms, come il riferimento).
  final Duration duration;

  /// Tap su TUTTA la card (non solo sui bottoni): tipicamente inverte
  /// [showBack]. I GestureDetector interni alle facce (VISUALIZZA QR CODE,
  /// NASCONDI, ANNULLA PREVENDITA…) vincono l'arena dei gesti, quindi
  /// continuano a fare la loro azione senza scatenare il flip.
  final VoidCallback? onTap;

  const FlipCard({
    Key? key,
    required this.front,
    required this.back,
    required this.showBack,
    this.duration = const Duration(milliseconds: 700),
    this.onTap,
  }) : super(key: key);

  @override
  State<FlipCard> createState() => _FlipCardState();
}

class _FlipCardState extends State<FlipCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _turn;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: widget.duration,
      // Se la card nasce già girata (es. si torna sulla schermata col QR
      // aperto) parte dalla posizione finale, senza animazione iniziale.
      value: widget.showBack ? 1 : 0,
    );
    _turn = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void didUpdateWidget(covariant FlipCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.showBack != oldWidget.showBack) {
      widget.showBack ? _ctrl.forward() : _ctrl.reverse();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _turn,
        builder: (context, _) {
          final t = _turn.value; // 0 = fronte, 1 = retro
          final isBack = t >= 0.5;
          final face = isBack
              // Contro-rotazione del retro: senza questa il contenuto si
              // vedrebbe specchiato (è l'equivalente del backface-visibility).
              ? Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()..rotateY(math.pi),
                  child: widget.back,
                )
              : widget.front;

          final content = AnimatedSize(
            duration: widget.duration,
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: face,
          );

          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0005) // perspective 2000px
              ..rotateY(t * math.pi),
            // Il GestureDetector sta DENTRO il Transform: l'area sensibile
            // ruota con la card invece di restare un rettangolo fisso.
            child: widget.onTap == null
                ? content
                : GestureDetector(
                    onTap: widget.onTap,
                    behavior: HitTestBehavior.opaque,
                    child: content,
                  ),
          );
        },
      ),
    );
  }
}
