import 'package:flutter/material.dart';
import '../core/app_export.dart';

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
    return Container(
      color: Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: isHome ? null : () => NavigatorService.pushNamedAndRemoveUntil(AppRoutes.homeScreen),
            child: Hero(
              tag: 'app_logo',
              child: Image.asset(
                ImageConstant.imgLogoOnlist,
                height: 65,
                fit: BoxFit.contain,
              ),
            ),
          ),
          Row(
            children: [
              if (showSearch)
                GestureDetector(
                  onTap: onSearchTap ?? () => NavigatorService.pushNamed(AppRoutes.nearbyClubsScreen),
                  child: const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Icon(Icons.search, color: Colors.white, size: 28),
                  ),
                ),
              if (showProfile) ...[
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: onProfileTap ?? () => NavigatorService.pushNamed(AppRoutes.profileScreen),
                  child: const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Icon(Icons.person_outline, color: Colors.white, size: 28),
                  ),
                ),
              ],
              const SizedBox(width: 4),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(76);
}
