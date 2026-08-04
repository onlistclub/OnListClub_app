import 'package:flutter/material.dart';

import 'custom_top_bar.dart';
import 'root_shell_scope.dart';

/// Posto della navbar in una schermata.
///
/// Dentro lo shell **non disegna niente**: lì la [CustomTopBar] è una sola,
/// montata sopra il Navigator, e non viene mai ricostruita — come la footer.
/// Prima invece ogni schermata si montava la sua, quindi a ogni navigazione ce
/// n'erano due sullo schermo (quella che esce e quella che entra) che si
/// incrociavano: da fuori sembrava che la barra si "ricaricasse" ogni volta.
///
/// Fuori dallo shell (schermate raggiunte dal navigator radice) la monta lei,
/// così nessuna resta senza.
class TopBarSlot extends StatelessWidget {
  const TopBarSlot({
    super.key,
    this.isHome = false,
    this.onProfileTap,
    this.onSearchTap,
  });

  /// Vedi [CustomTopBar.isHome]. Dentro lo shell decide lui, in base al tab.
  final bool isHome;

  /// Vedi [CustomTopBar.onProfileTap]. Dentro lo shell decide lui, in base
  /// alla rotta in cima.
  final VoidCallback? onProfileTap;

  /// Vedi [CustomTopBar.onSearchTap]. Come sopra.
  final VoidCallback? onSearchTap;

  @override
  Widget build(BuildContext context) {
    if (RootShellScope.of(context) != null) return const SizedBox.shrink();
    return CustomTopBar(
      isHome: isHome,
      onProfileTap: onProfileTap,
      onSearchTap: onSearchTap,
    );
  }
}
