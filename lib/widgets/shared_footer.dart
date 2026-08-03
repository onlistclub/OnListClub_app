import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../core/app_export.dart';

/// Bottom navigation bar condivisa dalle schermate principali.
///
/// Design ufficiale `footer-bar-ufficiale.css` (frame Figma 393×852):
/// - capsula 243×54, bordo 2px `rgba(255,255,255,0.13)`, fill trasparente,
///   raggio pill (34 nel CSS, clampato a h/2). Il "vetro smerigliato" del
///   Figma è reso con `BackdropFilter` (sfoca il contenuto che scorre sotto).
/// - icone (asset ufficiali `assets/svg/ufficiali/`): `Vector.svg` (ticket
///   44×30) / `home.svg` (33×33) / `Shopping_Cart_01.svg` (carrello 33×34),
///   bianche, attiva opacità 1.0 / inattive 0.5.
/// - distanza dal bordo fisico inferiore: 21px design (top 777 + h 54 su 852),
///   fedele al CSS anche sotto l'home indicator iOS.
///
/// Ordine icone: 0 = Ticket (riepilogo ordini), 1 = Home, 2 = Carrello.
/// Le notifiche non sono più una tab della footer — si raggiungono dalla
/// pagina Profilo. Il Profilo stesso NON è qui — si raggiunge dall'icona
/// persona del `CustomTopBar`.
/// Tutte le misure passano da [R.sp] (sistema responsive dell'app), mai px
/// fissi. Passare `-1` per nessuna tab attiva.
class SharedFooter extends StatelessWidget {
  final int currentIndex;

  /// Se valorizzato, il tap su una tab NON naviga: invoca questo callback con
  /// l'indice (0 = Ticket/Ordini, 1 = Home, 2 = Carrello). È la modalità usata
  /// dallo shell persistente ([RootShell]), dove le tab sono un IndexedStack e
  /// cambiare tab deve preservare lo stato (nessun push/rebuild).
  /// Se null, resta il comportamento legacy: `pushNamedAndRemoveUntil` verso la
  /// rotta della tab (usato dalle schermate non ancora migrate allo shell).
  final void Function(int index)? onTabSelected;

  /// Pallino blu di notifica sull'icona CARRELLO: acceso quando c'è un ordine
  /// lasciato in sospeso e non ancora visto (vedi `PendingOrderService`).
  final bool badgeCarrello;

  const SharedFooter({
    Key? key,
    required this.currentIndex,
    this.onTabSelected,
    this.badgeCarrello = false,
  }) : super(key: key);

  // Dimensioni design (px Figma, frame 393×852) dal CSS ufficiale
  // `footer-bar-ufficiale.css`, scalate con R.sp. Capsula centrata (nel CSS i
  // margini laterali 71/79 differiscono di 8px: imprecisione Figma).
  static const double _designCapsuleW = 243;
  static const double _designCapsuleH = 54;
  static const double _designBorderW = 2;

  // Distanza della capsula dal bordo FISICO inferiore dello schermo
  // (CSS: top 777 + h 54 su frame 852 → 21px). Fedele al design: niente
  // SafeArea, la pill entra nella zona home-indicator su iOS.
  static const double _designBottomMargin = 21;

  // Dimensioni icone dal CSS ufficiale (box esterni, stroke incluso).
  static const double _ticketWidth = 44;
  static const double _ticketHeight = 30; // Aspect ratio nativo 41×29

  static const double _homeWidth = 33;
  static const double _homeHeight = 33;

  static const double _cartWidth = 33;
  static const double _cartHeight = 34; // Aspect ratio nativo 31×32

  // Pallino di notifica (CSS "Carrello in sospeso", Ellipse 22: 10×10 a
  // 294,784). L'icona carrello sta a 258,786 ed è 33×34, quindi il pallino
  // sborda di 3px a destra e sale di 2 sopra il suo bordo alto.
  static const double _dotSize = 10;
  static const double _dotRight = -3;
  static const double _dotTop = -2;

  /// Altezza di "clearance" usata dalle schermate con `extendBody: true` come
  /// padding di fondo, così l'ultimo contenuto scrollabile supera la capsula.
  /// Coincide con l'ingombro reale del widget: capsula + margine inferiore.
  static double get height =>
      R.sp(_designCapsuleH) + R.sp(_designBottomMargin);

  @override
  Widget build(BuildContext context) {
    // Misure esatte dal CSS ufficiale (243×54 design px), scalate con R.sp —
    // nessun calcolo derivato da R.width/margini: R.sp ha già il proprio
    // tetto per i tablet (scale clampato a 1.30).
    final capsuleW = R.sp(_designCapsuleW);
    final capsuleH = R.sp(_designCapsuleH);

    return Material(
      type: MaterialType.transparency,
      child: SizedBox(
        height: height,
        child: Padding(
          padding: EdgeInsets.only(bottom: R.sp(_designBottomMargin)),
          child: Center(
            child: SizedBox(
              width: capsuleW,
              height: capsuleH,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Capsula "vetro smerigliato" come da CSS ufficiale:
                  // fill trasparente (rgba(0,0,0,0.004) ≈ nullo), bordo
                  // 2px bianco al 13%, raggio pill (34 clampato a h/2).
                  // Il BackdropFilter sfoca il contenuto che scorre sotto,
                  // rendendo l'effetto vetro del Figma.
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(capsuleH / 2),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: const Color(0x21FFFFFF), // bianco 13%
                              width: R.sp(_designBorderW),
                            ),
                            borderRadius:
                                BorderRadius.circular(capsuleH / 2),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Icone equispaziate (3 slot uguali), stessa larghezza/spazio
                  // per tutte e tre (come Figma — Home non è spostata).
                  Row(
                    children: [
                      Expanded(
                          child: _buildNavItem(
                              R.sp(_ticketWidth),
                              R.sp(_ticketHeight),
                              ImageConstant.imgNavTicket,
                              0,
                              AppRoutes.ordersScreen)),
                      Expanded(
                          child: _buildNavItem(
                              R.sp(_homeWidth),
                              R.sp(_homeHeight),
                              ImageConstant.imgNavHome,
                              1,
                              AppRoutes.homeScreen)),
                      Expanded(
                          child: _buildNavItem(
                              R.sp(_cartWidth),
                              R.sp(_cartHeight),
                              ImageConstant.imgNavCart,
                              2,
                              AppRoutes.cartScreen,
                              badge: badgeCarrello)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(double width, double height, String iconPath, int index,
      String routeName,
      {bool badge = false}) {
    final isSelected = currentIndex == index;
    return GestureDetector(
      onTap: () {
        // Modalità shell: cambia tab senza navigare (stato preservato).
        if (onTabSelected != null) {
          onTabSelected!(index);
          return;
        }
        // Modalità legacy: naviga alla rotta della tab.
        if (!isSelected && routeName.isNotEmpty) {
          NavigatorService.pushNamedAndRemoveUntil(routeName);
        }
      },
      behavior: HitTestBehavior.opaque,
      child: Center(
        // Nessuna forma decorativa dietro l'icona attiva (niente cerchio/anello):
        // come nel Figma, la selezione si vede solo dall'icona a piena opacità
        // contro le altre attenuate. Altezza e larghezza calibrate.
        child: SizedBox(
          width: width,
          height: height,
          // Il pallino sborda dal riquadro dell'icona: senza Clip.none lo
          // Stack lo taglierebbe.
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: Opacity(
                  opacity: isSelected ? 1.0 : 0.5,
                  child: SvgPicture.asset(iconPath, fit: BoxFit.contain),
                ),
              ),
              if (badge)
                Positioned(
                  right: R.sp(_dotRight),
                  top: R.sp(_dotTop),
                  // A piena opacità anche a tab spenta: è un avviso, non deve
                  // attenuarsi insieme all'icona.
                  child: SvgPicture.asset(
                    ImageConstant.imgNotificaPallino,
                    width: R.sp(_dotSize),
                    height: R.sp(_dotSize),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
