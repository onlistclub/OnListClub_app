import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../core/app_export.dart';

/// Bottom navigation bar condivisa dalle schermate principali.
///
/// Usa gli asset UFFICIALI del design (`assets/svg/ufficiali/`):
/// - capsula: `Rectangle 261.svg` (213×48), resa "vetro smerigliato" con
///   `BackdropFilter` (sfoca il contenuto sotto) invece di un fill piatto
/// - icone: `Ticket_Voucher.svg` / `Vector.svg` (home) / `Shopping_Cart_01.svg`,
///   tutte renderizzate a 24×24 (stessa dimensione, bianche)
///
/// Ordine icone: 0 = Ticket (riepilogo ordini), 1 = Home, 2 = Carrello.
/// Le notifiche non sono più una tab della footer — si raggiungono dalla
/// pagina Profilo. Il Profilo stesso NON è qui — si raggiunge dall'icona
/// persona del `CustomTopBar`.
/// Tutte le misure sono scalate in proporzione alla larghezza (base 213),
/// quindi responsive senza pixel fissi. Passare `-1` per nessuna tab attiva.
class SharedFooter extends StatelessWidget {
  final int currentIndex;

  const SharedFooter({
    Key? key,
    required this.currentIndex,
  }) : super(key: key);

  /// Altezza di "clearance" usata dalle schermate con `extendBody: true` come
  /// padding di fondo, così l'ultimo contenuto scrollabile supera la capsula.
  static const double height = 70;

  // Dimensioni native del design (in px Figma, capsula `Rectangle 261.svg`).
  static const double _designW = 213;
  static const double _designH = 48;
  static const double _margin = 20; // CSS: left 20 → margine laterale

  @override
  Widget build(BuildContext context) {
    // Capsula larga (schermo − margini), con tetto per non gonfiarsi sui tablet.
    final capsuleW = (R.width - _margin * 2).clamp(0.0, _designW * 1.15);
    final scale = capsuleW / _designW;
    final capsuleH = _designH * scale;

    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Velo sfocato dietro la capsula + sopra l'home indicator iOS.
          // Attivo su tutte le schermate con footer (coerenza col Figma).
          Positioned.fill(
            child: IgnorePointer(
              child: ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.0),
                          Colors.black.withOpacity(0.35),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: SizedBox(
              height: height,
              child: Padding(
                // Spinge leggermente la capsula in basso (Figma 07-aggiornato:
                // capsula a top 781 / altezza schermo 852, margine sotto ridotto).
                padding: EdgeInsets.only(bottom: bottomInset == 0 ? 6 : 0),
                child: Center(
                  child: SizedBox(
                    width: capsuleW,
                    height: capsuleH,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                  // Capsula "vetro smerigliato": sfoca il contenuto che scorre
                  // sotto (BackdropFilter) e ci stende sopra il fill ufficiale
                  // (Rectangle 261.svg, 4% bianco) — così la capsula resta
                  // realmente trasparente/traslucida come nel Figma, non un
                  // riquadro opaco. Raggio = metà altezza, pillola piena come
                  // l'asset (rx 24 su h 48).
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
                                child: _buildNavItem(scale, ImageConstant.imgNavTicket,
                                    24, 24, 0, AppRoutes.ordersScreen)),
                            Expanded(
                                child: _buildNavItem(scale, ImageConstant.imgNavHome,
                                    24, 24, 1, AppRoutes.homeScreen)),
                            Expanded(
                                child: _buildNavItem(scale, ImageConstant.imgNavCart,
                                    24, 24, 2, AppRoutes.cartScreen)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Diametro nativo del cerchio "riempimento leggero" dietro la tab attiva:
  // abbraccia le icone (tutte 24×24 ora) con un margine confortevole.
  static const double _selectedCircleSize = 40;

  Widget _buildNavItem(double scale, String iconPath, double iconW,
      double iconH, int index, String routeName) {
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
          // Cerchio a riempimento leggero dietro l'icona attiva (nessun
          // asset dedicato nel design: stesso stile dello sfondo capsula,
          // bianco a bassa opacità, nessun bordo visibile).
          if (isSelected)
            Container(
              width: _selectedCircleSize * scale,
              height: _selectedCircleSize * scale,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
            ),
          // Icona bianca (nativa dal design). Attiva: piena. Inattiva:
          // attenuata (come Figma), nessun effetto extra oltre l'opacità.
          SizedBox(
            width: iconW * scale,
            height: iconH * scale,
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
