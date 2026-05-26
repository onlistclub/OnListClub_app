import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Servizio di analytics leggero per la fase di MVP di OnList.
///
/// Ogni chiamata è fire-and-forget: non blocca mai l'app e non
/// solleva mai eccezioni. I log vengono scritti sulla tabella
/// `analytics_events` in Supabase.
///
/// ── Convenzioni sui nomi degli eventi ─────────────────────────────────────
/// Usa snake_case, con un prefisso che identifica l'area funzionale:
///   - location_*   → flusso di risoluzione posizione
///   - club_*       → visualizzazione/selezione club
///   - booking_*    → flusso di prenotazione
///   - auth_*       → login/registrazione
///   - search_*     → ricerca locali
class AnalyticsService {
  static final _client = Supabase.instance.client;

  // Versione app (aggiornala ogni release)
  static const String _appVersion = '1.0.0';

  // ── API pubblica ──────────────────────────────────────────────────────────

  /// Logga un evento con metadati opzionali.
  ///
  /// Esempio:
  /// ```dart
  /// AnalyticsService.log(
  ///   event: 'location_resolved',
  ///   metadata: {'source': 'gps', 'lat': 45.4, 'lng': 9.1},
  /// );
  /// ```
  static Future<void> log({
    required String event,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final user = _client.auth.currentUser;

      String platform = 'unknown';
      if (kIsWeb) {
        platform = 'web';
      } else {
        try {
          // Rileva la piattaforma a runtime senza package_info_plus
          platform = defaultTargetPlatform.name.toLowerCase(); // 'android' | 'ios' | 'linux' | ...
        } catch (_) {}
      }

      await _client.from('analytics_events').insert({
        'user_id':     user?.id,
        'event_name':  event,
        'metadata':    metadata ?? <String, dynamic>{},
        'platform':    platform,
        'app_version': _appVersion,
        'is_debug':    kDebugMode,
      });

      debugPrint('[Analytics] 📊 "$event" — ${metadata ?? {}}');
    } catch (e) {
      // Mai bloccare l'app per un log fallito
      debugPrint('[Analytics] ⚠️ Log fallito ("$event"): $e');
    }
  }

  // ── Helper specifici per il flusso posizione ──────────────────────────────

  /// Registra come è stata risolta la posizione nella Home.
  /// Chiamato alla fine di HomeBloc._load().
  static Future<void> logLocationResolved({
    required String source,   // 'gps' | 'storico' | 'citta_manuale' | 'nessuna'
    double? lat,
    double? lng,
    int bookingsCount = 0,
    String? clubId,
    String? clubName,
  }) =>
      log(
        event: 'location_resolved',
        metadata: {
          'source':          source,
          'lat':             lat,
          'lng':             lng,
          'bookings_count':  bookingsCount,
          'club_id':         clubId,
          'club_name':       clubName,
        },
      );

  /// Registra che l'utente ha concesso / negato il GPS.
  static Future<void> logGpsPermission({required bool granted}) =>
      log(
        event: 'gps_permission',
        metadata: {'granted': granted},
      );

  /// Registra che l'utente ha selezionato una città manualmente.
  static Future<void> logCitySelected({
    required String cityName,
    required String cityId,
    double? lat,
    double? lng,
  }) =>
      log(
        event: 'city_selected',
        metadata: {
          'city_name': cityName,
          'city_id':   cityId,
          'lat':       lat,
          'lng':       lng,
        },
      );

  /// Registra l'attivazione/disattivazione del GPS forzato dalla Home.
  static Future<void> logGpsForced({required bool enabled}) =>
      log(
        event: 'gps_forced_toggle',
        metadata: {'enabled': enabled},
      );

  /// Registra l'esito della ricerca club nella NearbyClubs screen.
  static Future<void> logClubSearch({
    required int resultsCount,
    String? cityFilter,
    int? radius,
    String? sortMode,
  }) =>
      log(
        event: 'club_search',
        metadata: {
          'results_count': resultsCount,
          'city_filter':   cityFilter,
          'radius_km':     radius,
          'sort_mode':     sortMode,
        },
      );

  /// Registra l'apertura della scheda di un club.
  static Future<void> logClubViewed({
    required String clubId,
    required String clubName,
  }) =>
      log(
        event: 'club_viewed',
        metadata: {
          'club_id':   clubId,
          'club_name': clubName,
        },
      );

  /// Registra il completamento di una prenotazione (tavolo o prevendita).
  static Future<void> logBookingCompleted({
    required String type, // 'tavolo' | 'prevendita'
    required String clubId,
    required String eventId,
    double? totalPrice,
  }) =>
      log(
        event: 'booking_completed',
        metadata: {
          'type':        type,
          'club_id':     clubId,
          'event_id':    eventId,
          'total_price': totalPrice,
        },
      );
}
