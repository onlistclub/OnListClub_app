import 'package:flutter/material.dart';
import '../../core/constants/image_constant.dart';
import '../../core/services/navigator_service.dart';
import '../../core/services/analytics_service.dart';
import '../../core/utils/analytics_mixin.dart';
import '../../routes/app_routes.dart';
import '../../theme/onlist_colors.dart';
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

  // Canvas Figma di riferimento per la 01 Prima pagina.
  static const double _figmaW = 393;
  static const double _figmaH = 852;
  static const double _logoSize = 311;
  static const double _logoLeft = 41;
  static const double _logoTop = 270;
  static const double _logoRadius = 77;
  static const double _arrowSize = 48;
  static const double _arrowLeft = 173;
  static const double _arrowTop = 557;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        onTap: () => NavigatorService.pushNamedAndRemoveUntil(
          AppRoutes.authenticationScreen,
        ),
        behavior: HitTestBehavior.opaque,
        child: DecoratedBox(
          decoration: const BoxDecoration(gradient: OnlistColors.onboardingBackground),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final scaleX = constraints.maxWidth / _figmaW;
              final scaleY = constraints.maxHeight / _figmaH;
              return Stack(
                children: [
                  Positioned(
                    left: _logoLeft * scaleX,
                    top: _logoTop * scaleY,
                    width: _logoSize * scaleX,
                    height: _logoSize * scaleX, // square — uso scaleX per mantenere proporzioni
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(_logoRadius * scaleX),
                      child: Image.asset(
                        ImageConstant.imgLogoOnlist,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  Positioned(
                    left: _arrowLeft * scaleX,
                    top: _arrowTop * scaleY,
                    width: _arrowSize * scaleX,
                    height: _arrowSize * scaleX,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: OnlistColors.white,
                          width: 4 * scaleX,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.arrow_upward,
                        color: OnlistColors.white,
                        size: 28 * scaleX,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
