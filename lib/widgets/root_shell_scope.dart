import 'package:flutter/material.dart';

/// Segnala ai discendenti che si trovano dentro lo shell persistente, ed
/// espone il cambio-tab.
///
/// Serve a due cose:
///  - il "Torna indietro" di Ordini e Carrello, che deve tornare alla Home
///    come TAB (stato preservato) invece di renavigare;
///  - [TopBarSlot], per sapere che la navbar la monta già lo shell.
///
/// Se `RootShellScope.of(context)` è null la schermata NON è dentro lo shell
/// e i chiamanti applicano il loro ripiego.
///
/// Sta in `widgets/` e non in `presentation/root_shell/` perché lo usano
/// widget condivisi: al contrario lo shell dipenderebbe dai widget e i widget
/// dallo shell.
class RootShellScope extends InheritedWidget {
  const RootShellScope({
    Key? key,
    required this.switchToTab,
    required Widget child,
  }) : super(key: key, child: child);

  final void Function(int index) switchToTab;

  static RootShellScope? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<RootShellScope>();

  @override
  bool updateShouldNotify(RootShellScope oldWidget) => false;
}
