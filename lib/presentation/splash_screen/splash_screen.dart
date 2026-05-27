import 'package:flutter/material.dart';
import '../../core/constants/image_constant.dart';
import '../../core/services/navigator_service.dart';
import '../../core/services/analytics_service.dart';
import '../../core/utils/analytics_mixin.dart';
import '../../routes/app_routes.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  static Widget builder(BuildContext context) => const SplashScreen();

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with ScreenAnalytics {
  @override
  String get screenName => 'splash';

  @override
  void initState() {
    super.initState();
    AnalyticsService.log(event: 'app_open');
    _checkSession();
  }

  Future<void> _checkSession() async {
    await Future.delayed(const Duration(milliseconds: 1800));
    if (!mounted) return;
    
    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session != null) {
        NavigatorService.pushNamedAndRemoveUntil(AppRoutes.homeScreen);
      } else {
        NavigatorService.pushNamedAndRemoveUntil(AppRoutes.authenticationScreen);
      }
    } catch (e) {
      debugPrint('[Splash] Session check error: $e');
      NavigatorService.pushNamedAndRemoveUntil(AppRoutes.authenticationScreen);
    }
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
