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
    // Spec Figma `docs/figma_screen/off/07 - Home-aggiornato.png`: wordmark
    // OnList incollato al bordo sinistro, search + profile in coppia compatta
    // sul bordo destro.
    return Container(
      color: Colors.transparent,
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: isHome ? null : () => NavigatorService.pushNamedAndRemoveUntil(AppRoutes.homeScreen),
            child: Hero(
              tag: 'app_logo',
              // Wordmark più contenuto (Figma nav-bar mostra il logo a ~25% schermo)
              // così non occupa spazio. L'asset è quadrato con ampio padding
              // trasparente: usiamo fitWidth e altezza proporzionale.
              child: SizedBox(
                width: R.w(28),
                height: R.w(11),
                child: Image.asset(
                  ImageConstant.imgLogoOnlist,
                  fit: BoxFit.fitWidth,
                  alignment: Alignment.centerLeft,
                ),
              ),
            ),
          ),
          const Spacer(),
          if (showSearch)
            GestureDetector(
              onTap: onSearchTap ?? () => NavigatorService.pushNamed(AppRoutes.nearbyClubsScreen),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                child: Image.asset(ImageConstant.imgNavSearch,
                    width: 30, height: 30),
              ),
            ),
          if (showProfile)
            GestureDetector(
              onTap: onProfileTap ?? () => NavigatorService.pushNamed(AppRoutes.profileScreen),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                child: Image.asset(ImageConstant.imgNavProfile,
                    width: 22, height: 28),
              ),
            ),
        ],
      ),
    );
  }

  // Altezza barra = slot logo (R.w(11)) + padding verticale (10+10).
  @override
  Size get preferredSize => Size.fromHeight(R.w(11) + 20);
}
