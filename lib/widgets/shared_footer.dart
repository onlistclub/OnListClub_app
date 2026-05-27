import 'package:flutter/material.dart';
import '../../core/app_export.dart';
import '../core/services/badge_service.dart';

/// Bottom navigation bar condivisa dalle schermate principali.
///
/// Riceve `currentIndex` per evidenziare la tab attiva, gestisce internamente
/// la navigazione fra Home / Ordini / Notifiche / Profilo. Si aggancia a
/// `BadgeService` per mostrare il pallino sulle notifiche non lette.
class SharedFooter extends StatelessWidget {
  final int currentIndex;

  const SharedFooter({Key? key, required this.currentIndex}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Figma specs: iconSOTTO at left:34, top:787 in 852px screen
    // Rectangle 191: 312x49px, rgba(255,255,255,0.02), border-radius:10
    // Frame 355: gap:60px, centered, 298.42x30.93px
    return Container(
      color: Colors.black,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 65, // 852 - 787 = 65px from bottom
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
                    _buildNavItem(ImageConstant.imgShoppingCart, 1, AppRoutes.cartScreen),
                    const SizedBox(width: 60),
                    _buildNavItem(ImageConstant.imgBell, 2, AppRoutes.notificationsScreen),
                    const SizedBox(width: 60),
                    _buildNavItem(ImageConstant.imgUser, 3, AppRoutes.profileScreen),
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
        if (index == 2) {
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
          if (index == 2) // Badge per le notifiche
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
