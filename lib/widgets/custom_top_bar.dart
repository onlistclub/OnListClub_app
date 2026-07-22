import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../core/app_export.dart';
import '../core/services/badge_service.dart';

/// App bar custom condivisa dalle schermate principali.
///
/// Espone le opzioni `showProfile`, `showSearch`, `isHome` e i callback
/// associati. Implementa `PreferredSizeWidget` per poter essere usata come
/// `appBar:` di uno `Scaffold`. Le icone arrivano da `ImageConstant`.
class CustomTopBar extends StatelessWidget implements PreferredSizeWidget {
  final bool showProfile;
  final bool showSearch;
  final VoidCallback? onSearchTap;
  final VoidCallback? onProfileTap;
  final bool isHome;

  const CustomTopBar({
    Key? key,
    this.showProfile = true,
    this.showSearch = true,
    this.onSearchTap,
    this.onProfileTap,
    this.isHome = false,
  }) : super(key: key);

  // ── Crop virtuale del wordmark ──────────────────────────────────────────
  // `logo_onlist_wordmark.png` NON è ritagliato: è un canvas quadrato con la
  // scritta "OnList" che occupa solo una fascia centrale, circondata da ampio
  // spazio trasparente. Renderizzarlo con BoxFit.contain e un aspect ratio
  // "largo" (assumendo un ritaglio che non esiste) lo rimpiccioliva e lo
  // spostava in alto a sinistra nella navbar. Lo ritagliamo qui via
  // OverflowBox+Transform (nessuna modifica al file su disco).
  // Percentuali basate sul bounding box dei pixel PIENI delle lettere
  // (left/width/bottom), con un po' di headroom in alto (_cropTop alzato,
  // _cropHeight aumentato di pari misura → bordo inferiore delle lettere
  // invariato) per NON clippare il glow viola del puntino della "i", che
  // sfora sopra la cap-height. Sorgente: nuovo logo off_logo.
  static const double _cropLeft = 0.1237;
  static const double _cropTop = 0.3950;
  static const double _cropWidth = 0.7520;
  static const double _cropHeight = 0.2535;
  static double get _cropAspect => _cropWidth / _cropHeight;

  /// Altezza della scritta "OnList": dimensione fissa (non scalata su R.w),
  /// coerente con le icone search/profile (32px) — misurato su
  /// `docs/figma_screen/off/nav-bar.png`: logo 37px vs icone 34px, quindi
  /// stessa taglia, non 30% dello schermo (che lo rendeva enorme/sfocato).
  static const double _logoHeight = 34;

  static double get _logoWidth => _logoHeight * _cropAspect;

  /// Padding verticale della barra (sopra+sotto).
  static const double _vPad = 10;

  @override
  Widget build(BuildContext context) {
    // Spec Figma `docs/figma_screen/off/07 - Home-aggiornato.png` / `nav-bar.png`:
    // wordmark OnList grande sul bordo sinistro, search + profile sul bordo
    // destro. Il crop virtuale (_buildLogo) compensa il padding trasparente
    // dell'asset quadrato — vedi commento sopra `_cropLeft` ecc.
    return Container(
      color: Colors.transparent,
      padding: const EdgeInsets.fromLTRB(16, _vPad, 12, _vPad),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          GestureDetector(
            // `pushNamed` (non `...AndRemoveUntil`): dentro lo shell viene
            // intercettato come CAMBIO TAB verso la Home (niente nuovo shell,
            // stato preservato). Vedi NavigatorService.pushNamed.
            onTap: isHome ? null : () => NavigatorService.pushNamed(AppRoutes.homeScreen),
            // Niente più Hero(tag:'app_logo'): i 3 tab dello shell restano
            // montati insieme nell'IndexedStack e tre Hero con lo stesso tag nel
            // medesimo sottoalbero farebbero crashare il primo volo Hero. Il
            // logo è comunque nella stessa posizione su ogni schermata, quindi
            // il morph era impercettibile.
            child: _buildLogo(),
          ),
          const Spacer(),
          if (showSearch)
            GestureDetector(
              onTap: onSearchTap ?? () => NavigatorService.pushNamed(AppRoutes.nearbyClubsScreen),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                child: SvgPicture.asset(ImageConstant.imgNavSearch,
                    width: 34, height: 34),
              ),
            ),
          if (showProfile)
            GestureDetector(
              onTap: onProfileTap ?? () => NavigatorService.pushNamed(AppRoutes.profileScreen),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    SvgPicture.asset(ImageConstant.imgNavProfile,
                        width: 34, height: 34),
                    // Pallino "hai notifiche non lette" — sostituisce il
                    // badge che prima stava sulla campanella della footer.
                    Positioned(
                      top: -2,
                      right: -2,
                      child: ValueListenableBuilder<int>(
                        valueListenable: BadgeService().notificationBadgeCount,
                        builder: (context, count, child) {
                          if (count == 0) return const SizedBox.shrink();
                          return SvgPicture.asset(
                              ImageConstant.imgProfileBadgeDot,
                              width: 12,
                              height: 12);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Crop virtuale del wordmark: renderizza l'asset (quadrato) ingrandito
  /// e lo trasla/clippa così che nel box finale (_logoWidth × _logoHeight)
  /// sia visibile solo la fascia con la scritta "OnList".
  Widget _buildLogo() {
    final double boxW = _logoWidth;
    final double boxH = _logoHeight;
    // Lato del render quadrato: la frazione _cropHeight del lato deve
    // corrispondere a boxH.
    final double side = boxH / _cropHeight;
    return ClipRect(
      child: SizedBox(
        width: boxW,
        height: boxH,
        child: OverflowBox(
          alignment: Alignment.topLeft,
          minWidth: side,
          maxWidth: side,
          minHeight: side,
          maxHeight: side,
          child: Transform.translate(
            offset: Offset(-_cropLeft * side, -_cropTop * side),
            child: Image.asset(
              ImageConstant.imgLogoOnlistWordmark,
              width: side,
              height: side,
              fit: BoxFit.fill,
            ),
          ),
        ),
      ),
    );
  }

  // Altezza barra = altezza logo + padding verticale (10+10).
  @override
  Size get preferredSize => Size.fromHeight(_logoHeight + _vPad * 2);
}
