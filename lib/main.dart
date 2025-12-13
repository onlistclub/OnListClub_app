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

class MyApp extends StatelessWidget {
  
  // Questa funzione gestisce TUTTE le operazioni asincrone e lunghe all'avvio.
  Future<void> _initializeApp() async {
    // 🚨 CRITICAL: Device orientation lock (Ora è asincrono e atteso qui)
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);

    final env = await _loadEnvSafe();
    await Supabase.initialize(
      url: env['SUPABASE_URL'] ?? '',
      anonKey: env['SUPABASE_ANON_KEY'] ?? '',
    );
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
        // Usa FutureBuilder per gestire il caricamento asincrono.
        return FutureBuilder(
          future: _initializeApp(), // Lancia la funzione di inizializzazione asincrona
          builder: (context, snapshot) {
            // Se lo stato è in attesa, mostriamo una schermata di caricamento.
            if (snapshot.connectionState == ConnectionState.waiting) {
              return MaterialApp(
                debugShowCheckedModeBanner: false,
                home: Scaffold(
                  // Puoi sostituire il CircularProgressIndicator con il tuo Splash Screen
                  body: Center(child: CircularProgressIndicator()), 
                ),
              );
            }

            // Una volta completato il Future, carica l'interfaccia principale dell'app.
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
      },
    );
  }
}
