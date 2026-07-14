import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../core/app_export.dart';

/// Bottom navigation bar condivisa dalle schermate principali.
///
/// Usa gli asset UFFICIALI del design (`assets/svg/ufficiali/`):
/// - capsula: `Rectangle 261.svg`, resa "vetro smerigliato" con
///   `BackdropFilter` (sfoca il contenuto sotto) invece di un fill piatto
/// - icone: `Ticket_Voucher.svg` / `Vector.svg` (home) / `Shopping_Cart_01.svg`,
///   tutte renderizzate alla stessa dimensione (bianche)
///
/// Ordine icone: 0 = Ticket (riepilogo ordini), 1 = Home, 2 = Carrello.
/// Le notifiche non sono più una tab della footer — si raggiungono dalla
/// pagina Profilo. Il Profilo stesso NON è qui — si raggiunge dall'icona
/// persona del `CustomTopBar`.
/// Tutte le misure passano da [R.sp] (sistema responsive dell'app), mai px
/// fissi. Passare `-1` per nessuna tab attiva.
class SharedFooter extends StatelessWidget {
  final int currentIndex;

  const SharedFooter({
    Key? key,
    required this.currentIndex,
  }) : super(key: key);

  // Dimensioni design (px Figma) — dimensioni NATIVE dell'asset
  // `Rectangle 261.svg` (213×48), scalate con R.sp. Niente calcolo da
  // margine/larghezza schermo: la capsula è larga esattamente quanto
  // l'asset, centrata (il margine laterale è quello che ne risulta).
  static const double _designCapsuleW = 213;
  static const double _designCapsuleH = 48;
  static const double _designIconSize = 33; // icone grandi come nel Figma
  static const double _designClearanceExtra = 28; // spazio sopra/sotto la pillola

  /// Altezza di "clearance" usata dalle schermate con `extendBody: true` come
  /// padding di fondo, così l'ultimo contenuto scrollabile supera la capsula.
  /// Non è più una costante fissa: scala con R.sp come tutto il resto.
  static double get height => R.sp(_designCapsuleH) + R.sp(_designClearanceExtra);

  @override
  Widget build(BuildContext context) {
    // Capsula larga esattamente quanto l'asset ufficiale (213×48 design px),
    // scalata con R.sp — nessun calcolo derivato da R.width/margini: R.sp
    // ha già il proprio tetto per i tablet (scale clampato a 1.30).
    final capsuleW = R.sp(_designCapsuleW);
    final capsuleH = R.sp(_designCapsuleH);
    final iconSize = R.sp(_designIconSize);

    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Material(
      type: MaterialType.transparency,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: height,
          child: Padding(
            // Spinge leggermente la capsula in basso (Figma 07-aggiornato:
            // capsula a top 781 / altezza schermo 852, margine sotto ridotto).
            padding: EdgeInsets.only(bottom: bottomInset == 0 ? R.sp(6) : 0),
            child: Center(
              child: SizedBox(
                width: capsuleW,
                height: capsuleH,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Capsula "vetro smerigliato": sfoca il contenuto che
                    // scorre sotto (BackdropFilter) e ci stende sopra il fill
                    // ufficiale (Rectangle 261.svg) — così la capsula resta
                    // realmente trasparente/traslucida come nel Figma, non un
                    // riquadro opaco. Raggio = metà altezza, pillola piena.
                    // Nessun velo scurente esterno: era un layer del vecchio
                    // design (pill opaca) e in conflitto con l'obiettivo
                    // "si vede la card sotto" — rimosso.
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(capsuleH / 2),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                          child: SvgPicture.asset(
                            ImageConstant.imgFooterCapsule,
                            fit: BoxFit.fill,
                          ),
                        ),
                      ),
                    ),
                    // Icone equispaziate (3 slot uguali), stessa dimensione
                    // per tutte e tre (come Figma — Home non è più grande).
                    Row(
                      children: [
                        Expanded(
                            child: _buildNavItem(iconSize,
                                ImageConstant.imgNavTicket, 0, AppRoutes.ordersScreen,
                                // Ticket_Voucher.svg ha molto vuoto interno nel suo
                                // viewBox 24×24 (il disegno occupa solo x:[3,21]
                                // y:[6,18]): a parità di box appare più piccolo
                                // degli altri due, che riempiono quasi tutto il
                                // loro canvas. Ritaglio il riquadro effettivo del
                                // disegno (stessa tecnica di custom_top_bar.dart
                                // per il logo, nessuna modifica al file .svg).
                                contentCrop: const Size(22, 16))),
                        Expanded(
                            child: _buildNavItem(iconSize,
                                ImageConstant.imgNavHome, 1, AppRoutes.homeScreen)),
                        Expanded(
                            child: _buildNavItem(iconSize,
                                ImageConstant.imgNavCart, 2, AppRoutes.cartScreen)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(double iconSize, String iconPath, int index,
      String routeName, {Size? contentCrop}) {
    final isSelected = currentIndex == index;
    // Icona nativa 24×24 (dimensione di tutti gli asset ufficiali footer,
    // tranne Home che è 33×33 ma riempie già tutto il suo canvas).
    const nativeSize = 24.0;
    final Widget svg = contentCrop == null
        ? SvgPicture.asset(iconPath, fit: BoxFit.contain)
        : FittedBox(
            fit: BoxFit.contain,
            child: SizedBox(
              width: contentCrop.width,
              height: contentCrop.height,
              child: OverflowBox(
                maxWidth: nativeSize,
                maxHeight: nativeSize,
                child: SvgPicture.asset(iconPath,
                    width: nativeSize, height: nativeSize),
              ),
            ),
          );
    return GestureDetector(
      onTap: () {
        if (!isSelected && routeName.isNotEmpty) {
          NavigatorService.pushNamedAndRemoveUntil(routeName);
        }
      },
      behavior: HitTestBehavior.opaque,
      child: Center(
        // Nessuna forma decorativa dietro l'icona attiva (niente cerchio/anello):
        // come nel Figma, la selezione si vede solo dall'icona a piena opacità
        // contro le altre attenuate.
        child: SizedBox(
          width: iconSize,
          height: iconSize,
          child: Opacity(
            opacity: isSelected ? 1.0 : 0.5,
            child: svg,
          ),
        ),
      ),
    );
  }
}
