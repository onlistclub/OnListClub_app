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
    // Figma specs: Rectangle 191: 354x49px rgba(255,255,255,0.02) border-radius:10,
    // 4 icone equispaziate, badge "tab attiva" 73x43 rgba(255,255,255,~0.25) sotto l'icona.
    return Container(
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
                color: Colors.white.withValues(alpha: 0.02),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildNavItem(ImageConstant.imgHome, 0, AppRoutes.homeScreen),
                    const SizedBox(width: 60),
                    _buildNavItem(null, 1, AppRoutes.ordersScreen,
                        iconData: Icons.shopping_bag_outlined),
                    const SizedBox(width: 60),
                    _buildNavItem(ImageConstant.imgShoppingCart, 2, AppRoutes.cartScreen),
                    const SizedBox(width: 60),
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
        children: [
          AnimatedScale(
            scale: isSelected ? 1.2 : 1.0,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutBack,
            child: AnimatedOpacity(
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
          ),
          if (index == 3) // Badge per le notifiche
            ValueListenableBuilder<int>(
              valueListenable: BadgeService().notificationBadgeCount,
              builder: (context, count, child) {
                if (count == 0) return const SizedBox.shrink();
                return Positioned(
                  top: -4,
                  right: -4,
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
