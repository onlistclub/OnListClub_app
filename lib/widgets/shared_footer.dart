import 'package:flutter/material.dart';
import '../../core/app_export.dart';
import '../core/services/badge_service.dart';

/// Bottom navigation bar condivisa dalle schermate principali.
///
/// Usa gli asset UFFICIALI del design (`assets/svg/`), così la barra è
/// pixel-perfect col Figma `off/footer-bar.PNG`:
/// - capsula/bordo: `bordo_footer.png` (354×49)
/// - pill tab attiva: `selezionato.png` (73×43)
/// - icone: `home/bag/carrello/notification.png` (~34, bianche)
///
/// Ordine icone: 0 = Home, 1 = Borsa (ordini), 2 = Carrello, 3 = Campanella.
/// Il Profilo NON è qui — si raggiunge dall'icona persona del `CustomTopBar`.
/// Tutte le misure sono scalate in proporzione alla larghezza (base 354),
/// quindi responsive senza pixel fissi. Passare `-1` per nessuna tab attiva.
class SharedFooter extends StatelessWidget {
  final int currentIndex;

  const SharedFooter({Key? key, required this.currentIndex}) : super(key: key);

  /// Altezza di "clearance" usata dalle schermate con `extendBody: true` come
  /// padding di fondo, così l'ultimo contenuto scrollabile supera la capsula.
  static const double height = 65;

  // Dimensioni native del design (in px Figma).
  static const double _designW = 354;
  static const double _designH = 49;
  static const double _margin = 20; // CSS: left 20 → margine laterale

  @override
  Widget build(BuildContext context) {
    // Capsula larga (schermo − margini), con tetto per non gonfiarsi sui tablet.
    final capsuleW = (R.width - _margin * 2).clamp(0.0, _designW * 1.15);
    final scale = capsuleW / _designW;
    final capsuleH = _designH * scale;

    return Material(
      type: MaterialType.transparency,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: height,
          child: Center(
            child: SizedBox(
              width: capsuleW,
              height: capsuleH,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Bordo/capsula ufficiale (asset esatto).
                  Positioned.fill(
                    child: Image.asset(
                      ImageConstant.imgFooterBorder,
                      fit: BoxFit.fill,
                    ),
                  ),
                  // Icone equispaziate (4 slot uguali).
                  Row(
                    children: [
                      Expanded(
                          child: _buildNavItem(scale, ImageConstant.imgNavHome,
                              34, 34, 0, AppRoutes.homeScreen)),
                      Expanded(
                          child: _buildNavItem(scale, ImageConstant.imgNavBag,
                              34, 32, 1, AppRoutes.ordersScreen)),
                      Expanded(
                          child: _buildNavItem(scale, ImageConstant.imgNavCart,
                              34, 34, 2, AppRoutes.cartScreen)),
                      Expanded(
                          child: _buildNavItem(scale, ImageConstant.imgNavBell,
                              31, 34, 3, AppRoutes.notificationsScreen)),
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

  Widget _buildNavItem(double scale, String iconPath, double iconW,
      double iconH, int index, String routeName) {
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
          // Pill "selezionato" ufficiale (73×43) dietro l'icona attiva.
          if (isSelected)
            Image.asset(
              ImageConstant.imgFooterPill,
              width: 73 * scale,
              height: 43 * scale,
              fit: BoxFit.fill,
            ),
          // Icona bianca (nativa ~34). Inattiva: attenuata (come Figma).
          SizedBox(
            width: iconW * scale,
            height: iconH * scale,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: Opacity(
                    opacity: isSelected ? 1.0 : 0.5,
                    child: Image.asset(iconPath, fit: BoxFit.contain),
                  ),
                ),
                // Badge notifiche (solo campanella) — fuori dall'opacity.
                if (index == 3)
                  Positioned(
                    top: -6 * scale,
                    right: -8 * scale,
                    child: ValueListenableBuilder<int>(
                      valueListenable:
                          BadgeService().notificationBadgeCount,
                      builder: (context, count, child) {
                        if (count == 0) return const SizedBox.shrink();
                        return Container(
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
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
