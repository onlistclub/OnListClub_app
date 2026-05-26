import 'package:flutter/material.dart';
import '../../core/app_export.dart';
import '../home_screen/home_screen.dart';
import '../cart_screen/cart_screen.dart';
import '../profile_screen/profile_screen.dart';

class MainLayoutScreen extends StatefulWidget {
  const MainLayoutScreen({Key? key}) : super(key: key);

  static Widget builder(BuildContext context) {
    return const MainLayoutScreen();
  }

  @override
  State<MainLayoutScreen> createState() => _MainLayoutScreenState();
}

class _MainLayoutScreenState extends State<MainLayoutScreen> {
  int _currentIndex = 0;

  late final List<Widget> _screens = [
    HomeScreen.builder(context),
    CartScreen.builder(context),
    const Center(child: Text("Notifiche", style: TextStyle(color: Colors.white))),
    ProfileScreen.builder(context),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xFF2A2A2A), width: 0.5)),
          color: Color(0xFF0D0D0D),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 10),
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              _buildNavItem(ImageConstant.imgHome, 0),
              _buildNavItem(ImageConstant.imgShoppingCart, 1),
              _buildNavItem(ImageConstant.imgBell, 2),
              _buildNavItem(ImageConstant.imgUser, 3),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(String imagePath, int index) {
    final isSelected = _currentIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _currentIndex = index),
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          height: 31,
          child: Center(
            child: AnimatedScale(
              scale: isSelected ? 1.2 : 1.0,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutBack,
              child: AnimatedOpacity(
                opacity: isSelected ? 1.0 : 0.5,
                duration: const Duration(milliseconds: 200),
                child: CustomImageView(
                  imagePath: imagePath,
                  height: 28,
                  width: 28,
                  color: isSelected ? Colors.white : const Color(0xFF888888),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
