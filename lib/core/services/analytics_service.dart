import 'package:device_info_plus/device_info_plus.dart';
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

  // ── Info dispositivo (popolate una volta all'avvio da initDeviceInfo) ──────
  // Allegate al metadata di OGNI evento così il foglio di monitoraggio (TAB
  // Dispositivi) può aggregare modello e versione OS. La colonna `platform`
  // viene valorizzata "iOS" / "Android" (maiuscole come nel foglio).
  static String? _deviceModel;
  static String? _osVersion;
  static String? _platformOverride;

  /// Nome della schermata attualmente visibile, aggiornato dal mixin
  /// ScreenAnalytics a ogni apertura pagina. Usato per popolare il campo
  /// `screen` degli errori catturati dagli handler globali (che non hanno
  /// contesto sulla schermata).
  static String? currentScreen;

  /// Legge modello dispositivo, versione OS e piattaforma una sola volta.
  /// Va chiamata in `main()` dopo l'init di Supabase e prima di `runApp`.
  /// Fire-and-forget: qualsiasi errore viene ignorato (mai bloccare l'avvio).
  static Future<void> initDeviceInfo() async {
    try {
      if (kIsWeb) {
        _platformOverride = 'web';
        return;
      }
      final info = DeviceInfoPlugin();
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        final ios = await info.iosInfo;
        // machine = identificativo modello (es. "iPhone14,3"); systemVersion
        // = versione iOS (es. "17.2").
        _deviceModel = ios.utsname.machine;
        _osVersion = ios.systemVersion;
        _platformOverride = 'iOS';
      } else if (defaultTargetPlatform == TargetPlatform.android) {
        final android = await info.androidInfo;
        _deviceModel = android.model; // es. "SM-G991B"
        _osVersion = android.version.release; // es. "14"
        _platformOverride = 'Android';
      } else {
        _platformOverride = defaultTargetPlatform.name;
      }
    } catch (e) {
      debugPrint('[Analytics] ⚠️ initDeviceInfo fallita: $e');
    }
  }

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

      // Piattaforma: usa il valore risolto da initDeviceInfo ("iOS"/"Android",
      // come atteso dal foglio). Fallback runtime se init non è ancora passata.
      String platform = _platformOverride ?? 'unknown';
      if (_platformOverride == null && !kIsWeb) {
        try {
          platform = defaultTargetPlatform.name; // 'android' | 'ios' | ...
        } catch (_) {}
      } else if (_platformOverride == null && kIsWeb) {
        platform = 'web';
      }

      // Allega modello e versione OS a ogni evento (TAB Dispositivi del foglio).
      final meta = <String, dynamic>{...?metadata};
      if (_deviceModel != null) meta['device_model'] = _deviceModel;
      if (_osVersion != null) meta['os_version'] = _osVersion;

      await _client.from('analytics_events').insert({
        'user_id':     user?.id,
        'event_name':  event,
        'metadata':    meta,
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

  // ── Funnel di conversione (nomi evento richiesti dal foglio MVP) ───────────
  // Questi event_name sono quelli che la dashboard interroga per il funnel
  // "apertura → prenotazione" e per la distribuzione oraria. Sono volutamente
  // separati dagli helper "storici" (logClubViewed/logClubSearch/…), che
  // restano per non perdere continuità con i dati già raccolti.

  /// Funnel: l'utente sta cercando un locale.
  /// [source] distingue l'origine: 'open' (apertura schermata ricerca),
  /// 'city' (selezione città), 'submit' (invio testo di ricerca).
  static Future<void> logSearch({String? query, String? source}) => log(
        event: 'search',
        metadata: {
          if (query != null && query.isNotEmpty) 'query': query,
          if (source != null) 'source': source,
        },
      );

  /// Funnel: l'utente apre il dettaglio di un locale o di un evento.
  static Future<void> logViewDetail({
    required String type, // 'locale' | 'evento'
    String? id,
    String? name,
  }) =>
      log(
        event: 'view_detail',
        metadata: {'type': type, 'id': id, 'name': name},
      );

  /// Funnel: l'utente aggiunge una prevendita/ticket o un tavolo al carrello.
  static Future<void> logAddToCart({
    required String type, // 'ticket' | 'table'
    String? eventId,
    dynamic price,
  }) =>
      log(
        event: 'add_to_cart',
        metadata: {'type': type, 'event_id': eventId, 'price': price},
      );

  /// Funnel: prenotazione completata con successo (evento richiesto dal foglio
  /// come `booking_complete`, distinto dallo storico `booking_completed`).
  static Future<void> logBookingComplete({
    required String type, // 'ticket' | 'table'
    String? eventId,
    dynamic amount,
  }) =>
      log(
        event: 'booking_complete',
        metadata: {'type': type, 'event_id': eventId, 'amount': amount},
      );

  // ── Errori (TAB Errori del foglio) ─────────────────────────────────────────

  /// Errore generico dell'app: alimenta "Errori più frequenti".
  static Future<void> logError({
    required String errorType,
    required String screen,
    String? message,
  }) =>
      log(
        event: 'error',
        metadata: {
          'error_type': errorType,
          'screen': screen,
          if (message != null) 'message': message,
        },
      );

  /// Errore di rete/API Supabase con codice HTTP: alimenta "Errori Supabase".
  static Future<void> logHttpError({
    required int status,
    String? screen,
    String? code,
  }) =>
      log(
        event: 'http_error',
        metadata: {
          'status': status,
          if (screen != null) 'screen': screen,
          if (code != null) 'code': code,
        },
      );

  /// Analizza un'eccezione e registra l'evento più adatto:
  /// - eccezioni Supabase con codice HTTP → `http_error` (401/403/404/409/500);
  /// - tutto il resto → `error` generico.
  /// [screen] è opzionale: se assente si usa [currentScreen] (schermata attiva).
  static Future<void> reportError(Object error, {String? screen}) async {
    final where = screen ?? currentScreen ?? 'unknown';
    final int? status = _httpStatusOf(error);
    if (status != null) {
      await logHttpError(
        status: status,
        screen: where,
        code: _codeOf(error),
      );
      return;
    }
    await logError(
      errorType: error.runtimeType.toString(),
      screen: where,
      message: error.toString(),
    );
  }

  /// Estrae un codice HTTP numerico dalle eccezioni Supabase note.
  /// - AuthException espone `statusCode` (stringa, es. "401").
  /// - PostgrestException espone `code` (codice Postgres/PostgREST): mappiamo i
  ///   più comuni sui codici HTTP mostrati dal foglio.
  static int? _httpStatusOf(Object error) {
    if (error is AuthException) {
      return int.tryParse(error.statusCode ?? '');
    }
    if (error is StorageException) {
      return int.tryParse(error.statusCode ?? '');
    }
    if (error is PostgrestException) {
      // A volte `code` è già lo status HTTP; altrimenti mappiamo i codici
      // Postgres ricorrenti (RLS, unique, JWT).
      final direct = int.tryParse(error.code ?? '');
      if (direct != null && direct >= 400 && direct <= 599) return direct;
      switch (error.code) {
        case '42501': // insufficient_privilege → violazione RLS
          return 403;
        case '23505': // unique_violation → duplicato
          return 409;
        case 'PGRST301': // JWT scaduto/assente
          return 401;
        case 'PGRST116': // nessuna riga / risorsa non trovata
          return 404;
      }
    }
    return null;
  }

  static String? _codeOf(Object error) {
    if (error is PostgrestException) return error.code;
    if (error is AuthException) return error.code;
    return null;
  }
}
