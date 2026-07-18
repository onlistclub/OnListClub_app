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

  /// La freccia "su" entra in dissolvenza subito DOPO l'handoff dalla native
  /// splash: la native mostra solo gradiente + logo (l'OS non può disegnare la
  /// freccia), quindi farla comparire dolcemente fa leggere l'insieme come un
  /// unico splash animato invece che come una seconda schermata che appare.
  bool _showArrow = false;

  @override
  void initState() {
    super.initState();
    AnalyticsService.log(event: 'app_open');
    _revealArrowSoon();
    _checkSession();
  }

  void _revealArrowSoon() {
    Future.delayed(const Duration(milliseconds: 220), () {
      if (mounted) setState(() => _showArrow = true);
    });
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

  /// Lato del logo in logical px. DEVE combaciare con la dimensione a cui
  /// flutter_native_splash rende il logo nella native splash, altrimenti al
  /// passaggio nativa→Flutter il logo "salta". Il tool tratta il sorgente
  /// (`logo_onlist.png`, 1024px) come 4x → 1024/4 = 256 logical px, centrato.
  /// (Su iOS il tool può scalarlo un filo diversamente: verificare su device;
  /// se il logo cambia dimensione all'avvio, aggiustare qui.)
  static const double _kLogoSize = 256.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Niente GestureDetector qui: il tap NON deve bypassare il check
      // sessione, altrimenti un utente loggato che tocca lo splash finisce
      // comunque al login.
      body: DecoratedBox(
        decoration:
            const BoxDecoration(gradient: OnlistColors.onboardingBackground),
        child: Stack(
          children: [
            // Logo centrato, stessa posizione e dimensione della native splash:
            // l'handoff OS→Flutter è invisibile (un solo passaggio).
            Center(
              child: SizedBox(
                width: _kLogoSize,
                height: _kLogoSize,
                child: Image.asset(
                  ImageConstant.imgLogoOnlist,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            // Freccia "su" poco sotto il centro, in dissolvenza (vedi _showArrow).
            Align(
              alignment: const Alignment(0, 0.34),
              child: AnimatedOpacity(
                opacity: _showArrow ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeOut,
                child: Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    // Tratto sottile come in Figma off/01.
                    border: Border.all(color: OnlistColors.white, width: 1.6),
                  ),
                  child: const Icon(
                    Icons.arrow_upward,
                    color: OnlistColors.white,
                    size: 24,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
