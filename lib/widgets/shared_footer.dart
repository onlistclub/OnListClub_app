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

  @override
  Widget build(BuildContext context) {
    // Figma (off/footer-bar.PNG): barra a CAPSULA con bordo chiaro sottile e
    // fondo blu scuro tenue; 4 icone equispaziate; badge "tab attiva" 73x43
    // rgba(255,255,255,~0.25) arrotondato sotto l'icona.
    // Material trasparente: fornisce un DefaultTextStyle valido al sotto-albero.
    // Senza, su Android vecchi (es. S7) il badge notifiche eredita lo stile di
    // fallback di WidgetsApp (sottolineato giallo doppio). type: transparency
    // non aggiunge colore/elevation, quindi la grafica resta invariata.
    return Material(
      type: MaterialType.transparency,
      child: Container(
        color: Colors.black,
        child: SafeArea(
          top: false,
        child: SizedBox(
          height: 65,
          child: Center(
            child: Container(
              width: 312,
              height: 49,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.12),
                  width: 1,
                ),
              ),
              // spaceEvenly: i 4 item (pill 73px l'uno) si distribuiscono nei
              // 312px della capsula senza overflow. I vecchi gap fissi da 60px
              // davano 4×73 + 3×60 = 472px > 312px → RenderFlex overflow ~160px.
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildNavItem(ImageConstant.imgHome, 0, AppRoutes.homeScreen),
                  _buildNavItem(null, 1, AppRoutes.ordersScreen,
                      iconData: Icons.shopping_bag_outlined),
                  _buildNavItem(ImageConstant.imgShoppingCart, 2, AppRoutes.cartScreen),
                  _buildNavItem(ImageConstant.imgBell, 3, AppRoutes.notificationsScreen),
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
              color: Colors.white.withValues(alpha: isSelected ? 0.25 : 0),
              borderRadius: BorderRadius.circular(10),
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
                    color: isSelected ? Colors.white : const Color(0xFF888888),
                  )
                : Icon(
                    iconData,
                    size: 30,
                    color: isSelected ? Colors.white : const Color(0xFF888888),
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
