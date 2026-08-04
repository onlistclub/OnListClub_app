import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../core/app_export.dart';
import 'onlist_wordmark.dart';
// NOTIFICHE DISATTIVATE (MVP): import non piu usato dopo aver nascosto il badge
// notifiche. Riattivare insieme al pallino nella build.
// import '../core/services/badge_service.dart';

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

  /// Icona "accesa" perché sei già su quella schermata.
  ///
  /// Stessa logica della [SharedFooter]: l'attiva resta a piena opacità e
  /// l'altra si attenua. Se non sei né in Ricerca né in Account restano
  /// entrambe piene — lì non c'è niente da segnalare.
  final bool searchAttiva;
  final bool profiloAttivo;

  /// Opacità dell'icona non attiva, identica a quella della footer.
  static const double _opacitaSpenta = 0.5;

  const CustomTopBar({
    Key? key,
    this.showProfile = true,
    this.showSearch = true,
    this.onSearchTap,
    this.onProfileTap,
    this.isHome = false,
    this.searchAttiva = false,
    this.profiloAttivo = false,
  }) : super(key: key);

  /// Opacità di un'icona: piena se è la sua schermata o se nessuna delle due
  /// lo è, attenuata se "accesa" è l'altra.
  double _opacita(bool attiva) {
    final bool qualcunaAttiva = searchAttiva || profiloAttivo;
    if (!qualcunaAttiva) return 1.0;
    return attiva ? 1.0 : _opacitaSpenta;
  }

  /// Altezza della scritta "OnList": dimensione fissa (non scalata su R.w),
  /// coerente con le icone search/profile (32px) — misurato su
  /// `docs/figma_screen/off/nav-bar.png`: logo 37px vs icone 34px, quindi
  /// stessa taglia, non 30% dello schermo (che lo rendeva enorme/sfocato).
  ///
  /// Il ritaglio del wordmark sta ora in [OnlistWordmark], condiviso con la
  /// card "Tu e OnList" dell'Account.
  static const double _logoHeight = 34;

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
            onTap: isHome
                ? null
                : () => NavigatorService.pushNamed(AppRoutes.homeScreen),
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
              onTap: onSearchTap ??
                  () => NavigatorService.pushNamed(AppRoutes.nearbyClubsScreen),
              child: Padding(
                // Padding destro ridotto (6 → 2.5): avvicina la lente al
                // profilo di ~3.5px, come chiesto nel doc correzioni. Il
                // profilo resta ancorato al bordo, quindi si muove la lente.
                padding:
                    EdgeInsets.fromLTRB(R.sp(6), R.sp(6), R.sp(2.5), R.sp(6)),
                child: Opacity(
                  opacity: _opacita(searchAttiva),
                  child: SvgPicture.asset(ImageConstant.imgNavSearch,
                      width: R.sp(34), height: R.sp(34)),
                ),
              ),
            ),
          if (showProfile)
            GestureDetector(
              onTap: onProfileTap ??
                  () => NavigatorService.pushNamed(AppRoutes.profileScreen),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Opacity(
                      opacity: _opacita(profiloAttivo),
                      child: SvgPicture.asset(ImageConstant.imgNavProfile,
                          width: 34, height: 34),
                    ),
                    // NOTIFICHE DISATTIVATE (MVP): pallino "hai notifiche non
                    // lette" nascosto insieme alla pagina notifiche. Riattivare
                    // ripristinando anche l'import di BadgeService sopra.
                    /*
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
                    */
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLogo() => const OnlistWordmark(height: _logoHeight);

  // Altezza barra = altezza logo + padding verticale (10+10).
  @override
  Size get preferredSize => Size.fromHeight(_logoHeight + _vPad * 2);
}
