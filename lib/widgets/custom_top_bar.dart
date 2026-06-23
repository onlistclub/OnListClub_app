import 'package:flutter/material.dart';
import '../core/app_export.dart';

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

  @override
  Widget build(BuildContext context) {
    // Spec Figma `docs/figma_screen/off/nav-bar.png`: contenitore nero con
    // wordmark OnList prominente a sinistra e search/persona a destra.
    return Container(
      color: Colors.transparent,
      padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: isHome ? null : () => NavigatorService.pushNamedAndRemoveUntil(AppRoutes.homeScreen),
            child: Hero(
              tag: 'app_logo',
              // L'asset logo è quadrato (1563×1563) col wordmark centrato e ampio
              // padding trasparente. Riempiamo la LARGHEZZA (≈ proporzione Figma
              // nav-bar: wordmark ~31% schermo) e ritagliamo il padding verticale,
              // così il logo è grande ma la barra resta bassa. Misure responsive
              // (proporzionali alla larghezza schermo), non pixel fissi.
              child: SizedBox(
                width: R.w(54),
                height: R.w(12),
                child: Image.asset(
                  ImageConstant.imgLogoOnlist,
                  fit: BoxFit.fitWidth,
                ),
              ),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showSearch)
                GestureDetector(
                  onTap: onSearchTap ?? () => NavigatorService.pushNamed(AppRoutes.nearbyClubsScreen),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    // Asset ufficiale navbar (assets/svg/search.png, 34×34).
                    child: Image.asset(ImageConstant.imgNavSearch,
                        width: 34, height: 34),
                  ),
                ),
              if (showProfile) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: onProfileTap ?? () => NavigatorService.pushNamed(AppRoutes.profileScreen),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    // Asset ufficiale navbar (assets/svg/profile.png, 23×29).
                    child: Image.asset(ImageConstant.imgNavProfile,
                        width: 23, height: 29),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // Altezza barra = slot logo responsive (R.w(12)) + padding verticale (10+10).
  @override
  Size get preferredSize => Size.fromHeight(R.w(12) + 20);
}
