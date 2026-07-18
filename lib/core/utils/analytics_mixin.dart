import 'package:flutter/material.dart';
import '../services/analytics_service.dart';

/// Mixin da aggiungere agli State degli Screen per tracciare automaticamente
/// l'apertura della pagina e il tempo di permanenza.
///
/// Uso:
/// ```dart
/// class _MyScreenState extends State<MyScreen> with ScreenAnalytics {
///   @override
///   String get screenName => 'my_screen_name';
/// }
/// ```
mixin ScreenAnalytics<T extends StatefulWidget> on State<T> {
  late final DateTime _pageOpenedAt;

  // Evita di registrare il tempo di caricamento più di una volta (un refresh o
  // un rebuild non deve falsare la metrica del primo caricamento).
  bool _loadTimeReported = false;

  /// Nome identificativo della schermata (es. 'home', 'club_detail', 'cart')
  String get screenName;

  @override
  void initState() {
    super.initState();
    _pageOpenedAt = DateTime.now();

    // Tiene traccia della schermata attiva: serve agli handler d'errore globali
    // (main.dart) per popolare il campo `screen` degli errori non catturati.
    AnalyticsService.currentScreen = screenName;

    // Log apertura pagina
    AnalyticsService.log(
      event: 'page_view',
      metadata: {'page_name': screenName},
    );
  }

  /// Registra il tempo di caricamento della schermata (da apertura a dati
  /// pronti) come `metadata.duration_ms`. Da chiamare UNA volta, quando i dati
  /// da Supabase sono arrivati. Le chiamate successive vengono ignorate.
  ///
  /// [loadEvent] è il nome evento atteso dal foglio, es. 'load_time_home'.
  void reportLoadTime(String loadEvent) {
    if (_loadTimeReported || !mounted) return;
    _loadTimeReported = true;
    final ms = DateTime.now().difference(_pageOpenedAt).inMilliseconds;
    AnalyticsService.log(
      event: loadEvent,
      metadata: {'duration_ms': ms},
    );
  }

  @override
  void dispose() {
    final duration = DateTime.now().difference(_pageOpenedAt).inSeconds;
    
    // Log uscita pagina con durata
    AnalyticsService.log(
      event: 'page_exit',
      metadata: {
        'page_name': screenName,
        'duration_seconds': duration,
      },
    );
    super.dispose();
  }
}
