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

  /// Nome identificativo della schermata (es. 'home', 'club_detail', 'cart')
  String get screenName;

  @override
  void initState() {
    super.initState();
    _pageOpenedAt = DateTime.now();
    
    // Log apertura pagina
    AnalyticsService.log(
      event: 'page_view',
      metadata: {'page_name': screenName},
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
