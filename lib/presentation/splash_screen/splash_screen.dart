import 'package:flutter/material.dart';
import '../../core/constants/image_constant.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/legal_consent_service.dart';
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
      if (!AuthService.instance.isLoggedIn) {
        // Sessione presente ma access token scaduto (gli access token Supabase
        // durano ~1h): NON fare logout — si tenta il refresh col refresh token.
        // Se riesce, l'utente resta loggato e non deve rifare il login; se
        // fallisce (refresh token revocato/utente eliminato) si ripiega sul login.
        await AuthService.instance.refreshSession();
      }
      await _routeAfterLogin();
    } catch (e) {
      debugPrint('[Splash] Session check error: $e');
      NavigatorService.pushNamedAndRemoveUntil(AppRoutes.authenticationScreen);
    }
  }

  /// Decide dove portare l'utente autenticato: home oppure, se serve, la
  /// schermata di ri-accettazione delle policy. Il controllo su
  /// `user_consents` viene fatto QUI (non nella home) perché serve una sola
  /// volta a sessione, e vogliamo tenere la home libera da guardie.
  Future<void> _routeAfterLogin() async {
    final userId = AuthService.instance.currentSession?.user.id;
    if (userId == null) {
      NavigatorService.pushNamedAndRemoveUntil(AppRoutes.authenticationScreen);
      return;
    }
    final status = await LegalConsentService.checkReacceptance(userId);
    if (!mounted) return;
    if (status.needsReacceptance) {
      NavigatorService.pushNamedAndRemoveUntil(
        AppRoutes.legalReacceptScreen,
        arguments: {'status': status},
      );
      return;
    }
    NavigatorService.pushNamedAndRemoveUntil(AppRoutes.homeScreen);
  }

  /// Misura del logo in logical px, dal Figma nuovo del 27/09 (`intro.css`:
  /// "WHITE INTERO 2" 229×97, centrata — 378 + 97/2 = 426,5, cioè metà dei 852
  /// del frame).
  ///
  /// DEVONO combaciare con la dimensione a cui flutter_native_splash rende il
  /// logo, altrimenti al passaggio nativa→Flutter il logo "salta". Il tool
  /// tratta il sorgente come 4x: `assets/native_splash/logo_onlist_wordmark.png`
  /// è 916×388 → 229×97 logici, ed è generato dallo stesso asset brand di
  /// [ImageConstant.imgLogoOnlistIntero]. Se cambia una delle due, cambiare
  /// anche l'altra e rilanciare `dart run flutter_native_splash:create`.
  ///
  /// Niente `R.sp` qui: la native splash disegna a misura fissa su qualsiasi
  /// telefono, quindi scalare solo il lato Flutter rimetterebbe il salto.
  static const double _kLogoW = 229.0;
  static const double _kLogoH = 97.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Niente GestureDetector qui: il tap NON deve bypassare il check
      // sessione, altrimenti un utente loggato che tocca lo splash finisce
      // comunque al login.
      body: DecoratedBox(
        decoration:
            const BoxDecoration(gradient: OnlistColors.onboardingBackground),
        // Solo la scritta, centrata: il Figma nuovo non ha più la freccia
        // sotto al marchio. L'alone della pallina fa parte dell'immagine.
        child: Center(
          child: SizedBox(
            width: _kLogoW,
            height: _kLogoH,
            // `fill` e non `contain`: la misura è già quella esatta del
            // rapporto dell'asset, e così il riquadro coincide al pixel con
            // quello della native splash invece di lasciare un filo di bordo.
            child: Image.asset(
              ImageConstant.imgLogoOnlistIntero,
              fit: BoxFit.fill,
            ),
          ),
        ),
      ),
    );
  }
}
