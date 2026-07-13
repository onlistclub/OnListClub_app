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

  // Dimensioni design (px Figma), scalate con R.sp ovunque siano usate.
  static const double _designMargin = 38; // (393-317)/2: margine laterale capsula
  static const double _designMaxW = 317; // tetto larghezza (non gonfiarsi su tablet)
  static const double _designCapsuleH = 52; // altezza pillola compatta
  static const double _designIconSize = 30; // icone quadrate, stessa taglia
  static const double _designSelectedCircle = 44; // icona 30 + margine confortevole
  static const double _designClearanceExtra = 28; // spazio sopra/sotto la pillola

  /// Altezza di "clearance" usata dalle schermate con `extendBody: true` come
  /// padding di fondo, così l'ultimo contenuto scrollabile supera la capsula.
  /// Non è più una costante fissa: scala con R.sp come tutto il resto.
  static double get height => R.sp(_designCapsuleH) + R.sp(_designClearanceExtra);

  @override
  Widget build(BuildContext context) {
    // Capsula larga (schermo − margini scalati), con tetto per non gonfiarsi
    // sui tablet. Tutto passa da R.sp: niente px fissi né mix con R.width grezzo.
    final margin = R.sp(_designMargin);
    final capsuleW =
        (R.width - margin * 2).clamp(0.0, R.sp(_designMaxW * 1.15));
    final capsuleH = R.sp(_designCapsuleH);
    final iconSize = R.sp(_designIconSize);
    final selectedCircleSize = R.sp(_designSelectedCircle);

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
                            child: _buildNavItem(iconSize, selectedCircleSize,
                                ImageConstant.imgNavTicket, 0, AppRoutes.ordersScreen)),
                        Expanded(
                            child: _buildNavItem(iconSize, selectedCircleSize,
                                ImageConstant.imgNavHome, 1, AppRoutes.homeScreen)),
                        Expanded(
                            child: _buildNavItem(iconSize, selectedCircleSize,
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

  Widget _buildNavItem(double iconSize, double selectedCircleSize,
      String iconPath, int index, String routeName) {
    final isSelected = currentIndex == index;
    return GestureDetector(
      onTap: () {
        if (!isSelected && routeName.isNotEmpty) {
          NavigatorService.pushNamedAndRemoveUntil(routeName);
        }
      },
      behavior: HitTestBehavior.opaque,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // Anello sottile dietro l'icona attiva (nessun asset dedicato nel
          // design): solo bordo, centro trasparente — si vede il vetro della
          // capsula anche dentro il cerchio, non un disco bianco pieno.
          if (isSelected)
            Container(
              width: selectedCircleSize,
              height: selectedCircleSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withOpacity(0.55),
                  width: 1.4,
                ),
              ),
            ),
          // Icona bianca (nativa dal design). Attiva: piena. Inattiva:
          // attenuata (come Figma), nessun effetto extra oltre l'opacità.
          SizedBox(
            width: iconSize,
            height: iconSize,
            child: Opacity(
              opacity: isSelected ? 1.0 : 0.5,
              child: SvgPicture.asset(iconPath, fit: BoxFit.contain),
            ),
          ),
        ],
      ),
    );
  }
}
