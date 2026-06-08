import 'package:flutter/material.dart';
import '../../core/constants/image_constant.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/navigator_service.dart';
import '../../core/services/analytics_service.dart';
import '../../core/utils/analytics_mixin.dart';
import '../../routes/app_routes.dart';
import '../../theme/onlist_colors.dart';

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
    // Delay puramente estetico: Supabase è già inizializzato (vedi main.dart)
    // quindi non c'è race condition; teniamo lo splash visibile abbastanza
    // da far riconoscere il brand.
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;

    try {
      final session = AuthService.instance.currentSession;
      if (session == null) {
        // Nessuna sessione persistita: utente non loggato → login.
        NavigatorService.pushNamedAndRemoveUntil(
            AppRoutes.authenticationScreen);
        return;
      }
      if (AuthService.instance.isLoggedIn) {
        // Sessione valida (token non scaduto): entra diretto.
        NavigatorService.pushNamedAndRemoveUntil(AppRoutes.homeScreen);
        return;
      }
      // Sessione presente ma access token scaduto (gli access token Supabase
      // durano ~1h): NON fare logout — si tenta il refresh col refresh token.
      // Se riesce, l'utente resta loggato e non deve rifare il login; se
      // fallisce (refresh token revocato/utente eliminato) si ripiega sul login.
      await AuthService.instance.refreshSession();
      NavigatorService.pushNamedAndRemoveUntil(AppRoutes.homeScreen);
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
      // Niente GestureDetector qui: il tap NON deve bypassare il check
      // sessione, altrimenti un utente loggato che tocca lo splash finisce
      // comunque al login.
      body: DecoratedBox(
        decoration:
            const BoxDecoration(gradient: OnlistColors.onboardingBackground),
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
    );
  }
}
