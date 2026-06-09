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
              child: Image.asset(
                ImageConstant.imgLogoOnlist,
                height: 120, // più grande, vicino alla proporzione del Figma nav-bar
                fit: BoxFit.contain,
              ),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showSearch)
                GestureDetector(
                  onTap: onSearchTap ?? () => NavigatorService.pushNamed(AppRoutes.nearbyClubsScreen),
                  child: const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Icon(Icons.search, color: Colors.white, size: 30),
                  ),
                ),
              if (showProfile) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: onProfileTap ?? () => NavigatorService.pushNamed(AppRoutes.profileScreen),
                  child: const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Icon(Icons.person_outline, color: Colors.white, size: 30),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // Logo 120 + padding verticale 10+10 = 140.
  @override
  Size get preferredSize => const Size.fromHeight(140);
}
