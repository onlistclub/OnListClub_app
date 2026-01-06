import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

// Assicurati che 'core/app_export.dart' non contenga logica bloccante sincrona.
import 'core/app_export.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';

var globalMessengerKey = GlobalKey<ScaffoldMessengerState>();

void main() {
  // 1. Assicura che l'ambiente Flutter sia inizializzato prima di qualsiasi altra cosa.
  WidgetsFlutterBinding.ensureInitialized();
  
  // 2. Avvia l'app immediatamente. Tutta la logica di inizializzazione va nel FutureBuilder.
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
      final env = await _loadEnvSafe();
      
      debugPrint('[Startup] Initializing Supabase...');
      await Supabase.initialize(
        url: env['SUPABASE_URL'] ?? '',
        anonKey: env['SUPABASE_ANON_KEY'] ?? '',
      );
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
        // We do NOT wait for the future to complete before showing the app.
        // We launch the MaterialApp immediately.
        // The AuthenticationScreen will be shown immediately.
        // If the user interacts before Supabase is ready, we rely on Supabase
        // being fast or handling the error/waiting state in the Bloc.
        // Given Supabase.initialize is needed for client access, we assume it finishes
        // before the user can type credentials and hit login.
        
        return MaterialApp(
          title: 'OnList',
          // 🚨 CRITICAL: NEVER REMOVE OR MODIFY
          builder: (context, child) {
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(1.0),
              ),
              child: child!,
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
          routes: AppRoutes.routes,
        );
      },
    );
  }
}
