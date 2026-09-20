import 'package:flutter/material.dart';
import '../services/analytics_service.dart';

/// Mixin da aggiungere agli State degli Screen per misurare il tempo di
/// caricamento dei dati.
///
/// Apertura schermata (`screen_<nome>`) e tempo di permanenza (`page_exit`)
/// NON passano più da qui: li registra `AnalyticsRouteObserver` guardando il
/// Navigator (e `RootShell` per i cambi tab). Farlo in `initState`/`dispose`
/// dava numeri sbagliati: le tab dello shell sono montate tutte all'avvio e
/// una schermata coperta da un dettaglio resta montata.
///
/// Uso:
/// ```dart
/// class _MyScreenState extends State<MyScreen> with ScreenAnalytics {
///   @override
///   String get screenName => 'my_screen_name';
/// }
/// ```
mixin ScreenAnalytics<T extends StatefulWidget> on State<T> {
  /// Millisecondi del cronometro all'apertura (non l'ora del telefono: vedi
  /// [AnalyticsService.orologioMs]).
  late final int _apertaAMs;

  // Evita di registrare il tempo di caricamento più di una volta (un refresh o
  // un rebuild non deve falsare la metrica del primo caricamento).
  bool _loadTimeReported = false;

  /// Nome identificativo della schermata (es. 'home', 'club_detail', 'cart').
  /// Allegato agli eventi `load_time_*`.
  String get screenName;

  @override
  void initState() {
    super.initState();
    _apertaAMs = AnalyticsService.orologioMs();
  }

  /// Registra il tempo di caricamento della schermata (da apertura a dati
  /// pronti) come `metadata.duration_ms`. Da chiamare UNA volta, quando i dati
  /// da Supabase sono arrivati. Le chiamate successive vengono ignorate.
  ///
  /// [loadEvent] è il nome evento atteso dal foglio, es. 'load_time_home'.
  void reportLoadTime(String loadEvent) {
    if (_loadTimeReported || !mounted) return;
    _loadTimeReported = true;
    final ms = AnalyticsService.orologioMs() - _apertaAMs;
    AnalyticsService.log(
      event: loadEvent,
      metadata: {'duration_ms': ms, 'screen': screenName},
    );
  }
}
