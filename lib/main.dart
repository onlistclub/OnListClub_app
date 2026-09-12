/// Entry point dell'app OnListClub.
///
/// Inizializza Flutter, blocca l'orientamento verticale, legge le chiavi
/// (Supabase + Google) dai `--dart-define`, inizializza Supabase e fa partire
/// `MaterialApp` con le rotte definite in `AppRoutes`.
///
/// Le chiavi arrivano SOLO da `--dart-define`: `env.json` non è più un asset
/// dell'app (vedi pubspec.yaml). Passalo al comando di build, che è la stessa
/// cosa senza spedire il file dentro l'APK:
///     flutter run   --dart-define-from-file=env.json
///     flutter build appbundle --dart-define-from-file=env.json
library;

import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

// Assicurati che 'core/app_export.dart' non contenga logica bloccante sincrona.
import 'core/app_export.dart';
import 'core/services/analytics_service.dart';
import 'core/services/auth_service.dart';
import 'core/services/location_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';

var globalMessengerKey = GlobalKey<ScaffoldMessengerState>();

/// Status bar chiara: icone/orario/batteria/segnale BIANCHI su sfondo scuro
/// (tutta l'app è dark). statusBarColor trasparente così traspare il gradiente.
const SystemUiOverlayStyle _kLightStatusBar = SystemUiOverlayStyle(
  statusBarColor: Colors.transparent,
  statusBarIconBrightness: Brightness.light, // Android: icone bianche
  statusBarBrightness: Brightness.dark, // iOS: sfondo scuro → contenuti chiari
);

// Chiavi lette a build-time da --dart-define (vedi run_dev.bat / run_prod.bat).
//
// Niente fallback su un file dentro il bundle: un asset è leggibile da chiunque
// scompatti l'APK o l'IPA. env.json conteneva anche la BREVO_API_KEY, cioè la
// facoltà di mandare email e SMS a nome di OnListClub.
const _kSupabaseUrlDefine = String.fromEnvironment('SUPABASE_URL');
const _kSupabaseAnonKeyDefine = String.fromEnvironment('SUPABASE_ANON_KEY');
const _kGoogleWebClientIdDefine =
    String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');
const _kGoogleIosClientIdDefine =
    String.fromEnvironment('GOOGLE_IOS_CLIENT_ID');

/// Google Web Client ID — necessario come serverClientId per autenticare i
/// token Google tramite Supabase Auth.
String? googleWebClientId;

/// Google iOS Client ID — obbligatorio su iOS per inizializzare l'SDK nativo
/// GoogleSignIn. Senza, `signIn()` solleva un'eccezione nativa fatale (crash).
/// Va ricavato da un OAuth Client ID di tipo iOS (bundle com.onlistclub.app).
String? googleIosClientId;

Future<void> main() async {
  // Assicura che il binding Flutter sia pronto: serve per chiamate native
  // (orientamento, rootBundle, secure storage) prima di runApp.
  WidgetsFlutterBinding.ensureInitialized();

  debugPrint('[Startup] Initializing orientation...');
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  // Status bar chiara su tutta l'app (sfondi scuri). Coperte anche le schermate
  // con AppBar tramite theme.appBarTheme.systemOverlayStyle in MyApp.
  SystemChrome.setSystemUIOverlayStyle(_kLightStatusBar);

  debugPrint('[Startup] Loading env...');
  final String supabaseUrl = _kSupabaseUrlDefine;
  final String supabaseAnonKey = _kSupabaseAnonKeyDefine;
  String? googleClientId =
      _kGoogleWebClientIdDefine.isEmpty ? null : _kGoogleWebClientIdDefine;
  String? googleIosId =
      _kGoogleIosClientIdDefine.isEmpty ? null : _kGoogleIosClientIdDefine;

  // Senza queste due l'app non parla con nessuno: meglio fermarsi qui, con un
  // messaggio che dice cosa manca, che pubblicare una build muta che sembra
  // solo "lenta a caricare".
  if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
    throw StateError(
      'SUPABASE_URL / SUPABASE_ANON_KEY mancanti: la build è stata lanciata '
      'senza --dart-define. Usa "flutter run --dart-define-from-file=env.json" '
      '(o run_dev.bat / run_prod.bat).',
    );
  }

  googleWebClientId = googleClientId;
  if (googleWebClientId == null ||
      googleWebClientId!.contains('SOSTITUIRE')) {
    debugPrint(
        '[Startup] ⚠️ GOOGLE_WEB_CLIENT_ID non configurato — Google Sign-In non funzionerà.');
    googleWebClientId = null;
  }

  googleIosClientId = googleIosId;
  if (googleIosClientId == null ||
      googleIosClientId!.isEmpty ||
      googleIosClientId!.contains('SOSTITUIRE')) {
    debugPrint(
        '[Startup] ⚠️ GOOGLE_IOS_CLIENT_ID non configurato — Google Sign-In su iOS sarà disabilitato (no crash).');
    googleIosClientId = null;
  }

  debugPrint('[Startup] Initializing Supabase...');
  // Atteso esplicitamente prima di runApp: garantisce che la sessione
  // persistente venga ripristinata dallo storage sicuro (Keychain/EncryptedSP)
  // prima che lo SplashScreen legga currentSession. Senza questo await,
  // SplashScreen può leggere null per race condition e mandare al login
  // anche utenti già autenticati.
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
    // Implicit invece del default PKCE: i link di reset password/verifica
    // email arrivano via email e vengono aperti in un browser esterno
    // all'app (non nel suo storage sicuro). Con PKCE il code_verifier resta
    // solo nell'app che ha fatto la richiesta, quindi il browser non riesce
    // mai a completare lo scambio — il link sembra "non valido" al primo
    // click. Con implicit i token arrivano nell'URL e qualunque browser può
    // completare il flusso.
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.implicit,
    ),
  );

  // Inizializza l'SDK Google una sola volta: la 7.x richiede initialize()
  // prima di qualsiasi authenticate(). clientId solo su iOS (su Android la
  // config arriva da serverClientId + SHA-1 registrato).
  if (googleWebClientId != null) {
    try {
      await GoogleSignIn.instance.initialize(
        clientId:
            defaultTargetPlatform == TargetPlatform.iOS ? googleIosClientId : null,
        serverClientId: googleWebClientId,
      );
    } catch (e) {
      debugPrint('[Startup] GoogleSignIn.initialize fallita: $e');
    }
  }

  // Listener globale auth: reagisce a logout/scadenza in tempo reale ovunque.
  await AuthService.instance.init();

  // Ripristina i flag persistenti che vengono letti sincronicamente
  // a runtime (es. LocationService.isGpsForced).
  await LocationService.loadGpsForcedFromPrefs();

  // Forza sempre l'highlight da touch: su emulatori/desktop con tastiera,
  // Flutter userebbe la modalità "traditional" e lascerebbe un cerchio grigio
  // di focus sull'ultima cella toccata (es. nel CalendarDatePicker Material).
  FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTouch;

  // Info dispositivo (modello + versione OS) per il monitoraggio: letta una
  // sola volta e allegata a ogni evento analytics.
  await AnalyticsService.initDeviceInfo();

  // Handler d'errore globali → TAB "Errori" del foglio di monitoraggio.
  // Catturano gli errori non gestiti (framework + async) senza cambiarne il
  // comportamento: presentano l'errore come prima e in più lo registrano.
  final previousOnError = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) {
    previousOnError?.call(details);
    AnalyticsService.reportError(details.exception);
  };
  WidgetsBinding.instance.platformDispatcher.onError = (error, stack) {
    AnalyticsService.reportError(error);
    // false: non consideriamo l'errore "gestito", lasciando che si propaghi
    // come farebbe di default (comportamento invariato).
    return false;
  };

  debugPrint('[Startup] Initialization complete.');

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Sizer(
      builder: (context, orientation, deviceType) {
        return MaterialApp(
          title: 'OnList',
          // Status bar chiara anche sulle schermate con AppBar (che altrimenti
          // sovrascriverebbero lo stile globale impostato in main()).
          theme: ThemeData(
            appBarTheme: const AppBarTheme(systemOverlayStyle: _kLightStatusBar),
          ),
          // 🚨 CRITICAL: NEVER REMOVE OR MODIFY
          builder: (context, child) {
            final isDesktop = kIsWeb ||
                defaultTargetPlatform == TargetPlatform.windows ||
                defaultTargetPlatform == TargetPlatform.macOS ||
                defaultTargetPlatform == TargetPlatform.linux;
            Widget content = MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(1.0),
                // Ignora l'impostazione iOS "Testo in grassetto" (Accessibilità):
                // mantiene i pesi Helvetica Neue del design system invece di
                // forzare FontWeight.bold su tutti i Text.
                boldText: false,
              ),
              child: child!,
            );
            if (isDesktop) {
              content = Container(
                color: Colors.black,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 430),
                    child: content,
                  ),
                ),
              );
            }
            // Default GLOBALE: icone status bar chiare (bianche) su tutte le
            // schermate, ri-asserito ad ogni frame. Vale sia Android sia iOS
            // (con UIViewControllerBasedStatusBarAppearance=YES). Una singola
            // schermata su sfondo chiaro puo' sovrascrivere avvolgendosi in un
            // altro AnnotatedRegion<SystemUiOverlayStyle>.
            return AnnotatedRegion<SystemUiOverlayStyle>(
              value: _kLightStatusBar,
              child: content,
            );
          },
          // 🚨 END CRITICAL SECTION
          navigatorKey: NavigatorService.navigatorKey,
          debugShowCheckedModeBanner: false,
          localizationsDelegates: [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate
          ],
          supportedLocales: [Locale('en', 'US')],
          initialRoute: AppRoutes.initialRoute,
          // Transizioni unificate per tutte le rotte (vedi page_transitions.dart).
          onGenerateRoute: AppRoutes.onGenerateRoute,
        );
      },
    );
  }
}
