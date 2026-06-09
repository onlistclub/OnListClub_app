import 'package:flutter/material.dart';
import '../../core/app_export.dart';
import '../core/services/badge_service.dart';

/// Bottom navigation bar condivisa dalle schermate principali.
///
/// Ordine icone (allineato al Figma `docs/figma_screen/off/`):
/// 0 = Home, 1 = Borsa (ordini acquistati), 2 = Carrello (cart attivo),
/// 3 = Campanella (notifiche). Il Profilo NON è in questa nav bar — si
/// raggiunge dall'icona persona del `CustomTopBar` (in alto a destra).
///
/// Riceve `currentIndex` per evidenziare la tab attiva. Passare `-1` per
/// nessuna tab evidenziata (es. schermate raggiunte da Profilo).
class SharedFooter extends StatelessWidget {
  final int currentIndex;

  const SharedFooter({Key? key, required this.currentIndex}) : super(key: key);

  /// Altezza visiva del footer (capsula 49 + margini verticali).
  /// Usata come padding di "clearance" nelle schermate con `extendBody: true`
  /// così l'ultimo contenuto scrollabile può superare la capsula flottante.
  static const double height = 65;

  @override
  Widget build(BuildContext context) {
    // Figma (off/footer-bar.PNG + CSS "Home"): barra 354×49 (≈ schermo−40),
    // raggio 10, fondo bianco ~2% con bordo chiaro 1px; 4 icone ~30×31
    // equispaziate; pill "tab attiva" 73×43 raggio 7 bianco ~31%.
    // Sfondo TRASPARENTE: la capsula FLOTTA sul contenuto e non lo oscura —
    // con `extendBody: true` le schermate scrollano dietro di essa.
    // Material trasparente: fornisce un DefaultTextStyle valido al sotto-albero
    // (evita lo stile di fallback sottolineato del badge su Android datati).
    return Material(
      type: MaterialType.transparency,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: height,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Center(
              child: Container(
                width: double.infinity,
                height: 49,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.02),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                    width: 1,
                  ),
                ),
                // Expanded: 4 slot equispaziati che non vanno in overflow
                // nemmeno su telefoni molto stretti (la pill 73px resta centrata).
                child: Row(
                  children: [
                    Expanded(
                        child: _buildNavItem(
                            ImageConstant.imgHome, 0, AppRoutes.homeScreen)),
                    Expanded(
                        child: _buildNavItem(null, 1, AppRoutes.ordersScreen,
                            iconData: Icons.shopping_bag_outlined)),
                    Expanded(
                        child: _buildNavItem(ImageConstant.imgShoppingCart, 2,
                            AppRoutes.cartScreen)),
                    Expanded(
                        child: _buildNavItem(ImageConstant.imgBell, 3,
                            AppRoutes.notificationsScreen)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(String? imagePath, int index, String routeName, {IconData? iconData}) {
    final isSelected = currentIndex == index;
    return GestureDetector(
      onTap: () {
        if (index == 3) {
          BadgeService().clearNotificationBadge();
        }
        if (!isSelected && routeName.isNotEmpty) {
          NavigatorService.pushNamedAndRemoveUntil(routeName);
        }
      },
      behavior: HitTestBehavior.opaque,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // Pill "tab attiva" — 73×43 rgba(255,255,255,0.25) radius 10 (Figma).
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            width: 73,
            height: 43,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: isSelected ? 0.31 : 0),
              borderRadius: BorderRadius.circular(7),
            ),
          ),
          AnimatedOpacity(
            opacity: isSelected ? 1.0 : 0.5,
            duration: const Duration(milliseconds: 200),
            child: imagePath != null
                ? CustomImageView(
                    imagePath: imagePath,
                    height: 30.93,
                    width: 30.29,
                    color: Colors.white, // Figma: icone bianche, dimming via opacity
                  )
                : Icon(
                    iconData,
                    size: 30.93,
                    color: Colors.white,
                  ),
          ),
          if (index == 3) // Badge per le notifiche
            ValueListenableBuilder<int>(
              valueListenable: BadgeService().notificationBadgeCount,
              builder: (context, count, child) {
                if (count == 0) return const SizedBox.shrink();
                return Positioned(
                  top: 0,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      count > 9 ? '9+' : '$count',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.none,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
