import 'package:flutter/material.dart';
import '../../core/utils/image_constant.dart';
import '../../core/utils/navigator_service.dart';
import '../../routes/app_routes.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  static Widget builder(BuildContext context) => const SplashScreen();

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (mounted) {
        NavigatorService.pushNamedAndRemoveUntil(
          AppRoutes.authenticationScreen,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0000FF),
      body: GestureDetector(
        onTap: () => NavigatorService.pushNamedAndRemoveUntil(
          AppRoutes.authenticationScreen,
        ),
        behavior: HitTestBehavior.opaque,
        child: SizedBox.expand(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo OnList
              Image.asset(
                ImageConstant.imgLogoOnlist,
                width: 140,
                height: 140,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 48),
              // Freccia cerchio
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: const Icon(
                  Icons.arrow_upward,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
