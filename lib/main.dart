/// Entry point dell'app OnListClub.
///
/// Inizializza Flutter, blocca l'orientamento verticale, carica le chiavi
/// (Supabase + Google) da `--dart-define` con fallback a `env.json`, inizializza
/// Supabase e fa partire `MaterialApp` con le rotte definite in `AppRoutes`.
library;

import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

// Assicurati che 'core/app_export.dart' non contenga logica bloccante sincrona.
import 'core/app_export.dart';
import 'core/services/location_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';

var globalMessengerKey = GlobalKey<ScaffoldMessengerState>();

// Chiavi lette a build-time da --dart-define. Esempio:
//   flutter run --dart-define=SUPABASE_URL=... \
//               --dart-define=SUPABASE_ANON_KEY=... \
//               --dart-define=GOOGLE_WEB_CLIENT_ID=...
// In assenza di --dart-define, si fa fallback su env.json (solo per dev locale).
const _kSupabaseUrlDefine = String.fromEnvironment('SUPABASE_URL');
const _kSupabaseAnonKeyDefine = String.fromEnvironment('SUPABASE_ANON_KEY');
const _kGoogleWebClientIdDefine =
    String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');

/// Google Web Client ID — necessario come serverClientId per autenticare i
/// token Google tramite Supabase Auth.
String? googleWebClientId;

void main() {
  // 1. Assicura che l'ambiente Flutter sia inizializzato prima di qualsiasi altra cosa.
  WidgetsFlutterBinding.ensureInitialized();
  
  // Avvia l'app immediatamente. Tutta la logica di inizializzazione va nel FutureBuilder.
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {

  @override
  void initState() {
    super.initState();
    debugPrint('[Startup] Starting app initialization...');
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      debugPrint('[Startup] Initializing orientation...');
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);

      debugPrint('[Startup] Loading env...');
      // Priorità: --dart-define (sicuro, non finisce negli asset).
      // Fallback: env.json (dev locale, da rimuovere prima della release).
      String supabaseUrl = _kSupabaseUrlDefine;
      String supabaseAnonKey = _kSupabaseAnonKeyDefine;
      String? googleClientId =
          _kGoogleWebClientIdDefine.isEmpty ? null : _kGoogleWebClientIdDefine;

      if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
        debugPrint(
            '[Startup] ⚠️ --dart-define non impostate, fallback a env.json');
        final env = await _loadEnvSafe();
        if (supabaseUrl.isEmpty) {
          supabaseUrl = (env['SUPABASE_URL'] as String?) ?? '';
        }
        if (supabaseAnonKey.isEmpty) {
          supabaseAnonKey = (env['SUPABASE_ANON_KEY'] as String?) ?? '';
        }
        googleClientId ??= env['GOOGLE_WEB_CLIENT_ID'] as String?;
      }

      googleWebClientId = googleClientId;
      if (googleWebClientId == null ||
          googleWebClientId!.contains('SOSTITUIRE')) {
        debugPrint(
            '[Startup] ⚠️ GOOGLE_WEB_CLIENT_ID non configurato — Google Sign-In non funzionerà.');
        googleWebClientId = null;
      }

      debugPrint('[Startup] Initializing Supabase...');
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseAnonKey,
      );

      // Ripristina i flag persistenti che vengono letti sincronicamente
      // a runtime (es. LocationService.isGpsForced).
      await LocationService.loadGpsForcedFromPrefs();
      debugPrint('[Startup] Initialization complete.');
    } catch (e) {
      debugPrint('[Startup] Initialization error: $e');
    }
  }

  Future<Map<String, dynamic>> _loadEnvSafe() async {
    try {
      final raw = await rootBundle.loadString('env.json');
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      try {
        final raw = await rootBundle.loadString('assets/env.json');
        return jsonDecode(raw) as Map<String, dynamic>;
      } catch (_) {
        return {};
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Sizer(
      builder: (context, orientation, deviceType) {
        
        return MaterialApp(
          title: 'OnList',
          // 🚨 CRITICAL: NEVER REMOVE OR MODIFY
          builder: (context, child) {
            final isDesktop = kIsWeb ||
                defaultTargetPlatform == TargetPlatform.windows ||
                defaultTargetPlatform == TargetPlatform.macOS ||
                defaultTargetPlatform == TargetPlatform.linux;
            Widget content = MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(1.0),
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
            return content;
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
          routes: AppRoutes.routes,
        );
      },
    );
  }
}
