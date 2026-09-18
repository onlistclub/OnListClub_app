import 'dart:math';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
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
///
/// ── Campi aggiunti a OGNI evento (dentro `metadata`) ──────────────────────
///   - `session_id` → stesso valore per tutti gli eventi di una sessione,
///     anche a cavallo del login: è quello che permette di seguire una persona
///     da `app_open` alla prenotazione, anche prima che abbia un account.
///   - `seq`        → contatore progressivo dentro l'avvio dell'app. Gli insert
///     partono in parallelo e `created_at` lo decide il DB all'arrivo: due
///     eventi vicini possono finire in ordine inverso. Il percorso si ordina
///     per (`session_id`, `seq`), non per `created_at`.
///   - `client_ts`  → ora del telefono (UTC) nel momento dell'evento.
///
/// ── Schermate ─────────────────────────────────────────────────────────────
/// Le aperture (`screen_<nome>`) e le uscite (`page_exit`) non le registrano
/// più le singole schermate: lo fa [AnalyticsRouteObserver] guardando il
/// Navigator, più `RootShell` per i cambi tab. C'è sempre UNA sola schermata
/// visibile alla volta: ogni `page_exit` chiude esattamente il `screen_*` che
/// l'ha preceduto (vedi [mostraSchermata]).
class AnalyticsService {
  static final _client = Supabase.instance.client;

  // Versione app: letta dal pubspec all'avvio (initDeviceInfo), non ricopiata
  // a mano. Una costante qui dentro sopravvive a ogni release che qualcuno si
  // dimentica di aggiornare, e da quel momento tutti gli eventi mentono sulla
  // versione — con il risultato che un crash della 1.0.3 sembra della 1.0.0.
  // Il fallback vale solo finché initDeviceInfo non è passata.
  static String _appVersion = '0.0.0';

  // ── Info dispositivo (popolate una volta all'avvio da initDeviceInfo) ──────
  // Allegate al metadata di OGNI evento così il foglio di monitoraggio (TAB
  // Dispositivi) può aggregare modello e versione OS. La colonna `platform`
  // viene valorizzata "iOS" / "Android" (maiuscole come nel foglio).
  static String? _deviceModel;
  static String? _osVersion;
  static String? _platformOverride;

  /// Nome della schermata attualmente visibile, aggiornato da [mostraSchermata]
  /// a ogni cambio. Usato per popolare il campo `screen` degli errori
  /// catturati dagli handler globali (che non hanno contesto sulla schermata).
  static String? currentScreen;

  /// Orologio sostituibile nei test (sessioni scadute, durate).
  @visibleForTesting
  static DateTime Function() orologio = DateTime.now;

  /// Nei test riceve ogni evento al posto di Supabase.
  @visibleForTesting
  static void Function(String event, Map<String, dynamic> metadata)?
      registroPerTest;

  /// Legge modello dispositivo, versione OS e piattaforma una sola volta.
  /// Va chiamata in `main()` dopo l'init di Supabase e prima di `runApp`.
  /// Fire-and-forget: qualsiasi errore viene ignorato (mai bloccare l'avvio).
  static Future<void> initDeviceInfo() async {
    // In un try suo: se la lettura del pacchetto fallisce, il modello del
    // dispositivo si legge lo stesso (e viceversa).
    try {
      final info = await PackageInfo.fromPlatform();
      // "1.0.0+3": teniamo anche il build number, è quello che distingue due
      // caricamenti sullo store con lo stesso version name.
      _appVersion = info.buildNumber.isEmpty
          ? info.version
          : '${info.version}+${info.buildNumber}';
    } catch (e) {
      debugPrint('[Analytics] ⚠️ lettura versione app fallita: $e');
    }

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

  // ── Sessione ──────────────────────────────────────────────────────────────
  //
  // Una sessione = un uso continuo dell'app. Parte all'avvio e, se l'app torna
  // in primo piano dopo più di [pausaNuovaSessione] in background, ne parte
  // una nuova (stessa regola di Umami/GA). L'id vive solo in memoria: non è
  // salvato sul telefono e non identifica il dispositivo nel tempo.

  /// Background oltre il quale il ritorno nell'app conta come nuova sessione.
  static const Duration pausaNuovaSessione = Duration(minutes: 30);

  static String _sessionId = _nuovoId();
  static int _seq = 0;
  static int _schermateSessione = 0;

  /// Tempo in primo piano accumulato nella sessione (le pause brevi in
  /// background non contano).
  static Duration _attivaAccumulata = Duration.zero;
  static DateTime? _inPrimoPianoDa = orologio();
  static DateTime? _inBackgroundDa;
  static AppLifecycleListener? _lifecycle;

  static String get sessionId => _sessionId;

  /// Registra `session_start` e si mette in ascolto di background/primo piano.
  /// Va chiamata una volta in `main()`, dopo [initDeviceInfo].
  static void avviaSessione() {
    if (_lifecycle != null) return;
    _lifecycle = AppLifecycleListener(
      onHide: suAppNascosta,
      onShow: suAppVisibile,
    );
    log(event: 'session_start', metadata: {'motivo': 'avvio'});
  }

  /// App in background (o scheda nascosta sul web): chiude la schermata
  /// visibile e registra `session_end`.
  ///
  /// `session_end` parte a OGNI passaggio in background, perché un'app chiusa
  /// dal sistema mentre è in background non ha un'altra occasione per farlo.
  /// Se l'utente torna entro [pausaNuovaSessione] la sessione continua e il
  /// `session_end` successivo avrà una durata maggiore: per ogni sessione vale
  /// l'ULTIMO `session_end`.
  @visibleForTesting
  static void suAppNascosta() {
    final adesso = orologio();
    if (_inBackgroundDa != null) return;
    _inBackgroundDa = adesso;
    final ultima = _schermataVisibile;
    _chiudiSchermata(motivo: 'app_in_background');
    final da = _inPrimoPianoDa;
    if (da != null) _attivaAccumulata += adesso.difference(da);
    _inPrimoPianoDa = null;
    log(event: 'session_end', metadata: {
      'duration_seconds': _attivaAccumulata.inSeconds,
      'schermate': _schermateSessione,
      if (ultima != null) 'page_name': ultima,
    });
    // Dopo la chiusura la schermata va ricordata per il ritorno.
    _daRiaprire = ultima;
  }

  /// App di nuovo in primo piano: riapre la schermata lasciata, dentro la
  /// stessa sessione o in una nuova se la pausa è stata lunga.
  @visibleForTesting
  static void suAppVisibile() {
    final adesso = orologio();
    final da = _inBackgroundDa;
    if (da == null) return;
    _inBackgroundDa = null;
    _inPrimoPianoDa = adesso;
    final nome = _daRiaprire;
    _daRiaprire = null;
    if (adesso.difference(da) >= pausaNuovaSessione) {
      _sessionId = _nuovoId();
      _schermateSessione = 0;
      _attivaAccumulata = Duration.zero;
      log(event: 'session_start', metadata: {'motivo': 'ritorno_dopo_pausa'});
      if (nome != null) mostraSchermata(nome);
    } else if (nome != null) {
      mostraSchermata(nome, ritorno: true);
    }
  }

  static String _nuovoId() {
    // UUID v4 senza dipendenze extra.
    final r = Random.secure();
    final b = List<int>.generate(16, (_) => r.nextInt(256));
    b[6] = (b[6] & 0x0f) | 0x40;
    b[8] = (b[8] & 0x3f) | 0x80;
    final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-'
        '${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
  }

  // ── Schermate ─────────────────────────────────────────────────────────────

  static String? _schermataVisibile;
  static DateTime? _schermataDa;
  static String? _daRiaprire;
  static int _sospensioni = 0;

  /// Registrati da `RootShell` mentre è montato: dicono quale tab è attiva e
  /// quale rotta sta in cima al suo Navigator annidato. Servono a
  /// [AnalyticsRouteObserver] per dare un nome alla rotta dello shell, che da
  /// sola non dice cosa si sta guardando.
  static String Function()? nomeTabAttiva;
  static String? Function()? rottaInCimaShell;

  /// Segna [nome] come schermata visibile: chiude quella precedente con
  /// `page_exit` e registra `screen_<nome>`.
  ///
  /// [ritorno] = si torna su una schermata già aperta (dettaglio chiuso, app
  /// riaperta, tab già attiva): l'evento porta `ritorno: true`, così chi conta
  /// le "aperture" può escluderli, mentre il percorso resta completo.
  static void mostraSchermata(String nome, {bool ritorno = false}) {
    if (_sospensioni > 0) return;
    // Navigazione avvenuta con l'app in background: nessuno la sta guardando.
    // Diventa la schermata da riaprire quando l'app torna visibile.
    if (_inBackgroundDa != null) {
      _daRiaprire = nome;
      return;
    }
    if (nome == _schermataVisibile) return;
    final precedente = _schermataVisibile;
    _chiudiSchermata();
    _schermataVisibile = nome;
    _schermataDa = orologio();
    currentScreen = nome;
    _schermateSessione++;
    log(
      event: 'screen_$nome',
      metadata: {
        'screen': nome,
        'page_name': nome,
        if (precedente != null) 'referrer_page': precedente,
        if (ritorno) 'ritorno': true,
      },
    );
  }

  static void _chiudiSchermata({String? motivo}) {
    final nome = _schermataVisibile;
    final da = _schermataDa;
    _schermataVisibile = null;
    _schermataDa = null;
    if (nome == null || da == null) return;
    // "Tempo medio (s)" per schermata del foglio.
    log(
      event: 'page_exit',
      metadata: {
        'screen': nome,
        'page_name': nome,
        'duration_seconds': orologio().difference(da).inSeconds,
        if (motivo != null) 'motivo': motivo,
      },
    );
  }

  /// Esegue [azione] senza registrare navigazioni: serve quando lo shell
  /// chiude in un colpo solo tutti i dettagli aperti prima di un cambio tab,
  /// che altrimenti risulterebbero come "ritorni" mai visti dall'utente.
  static T senzaTracciareNavigazione<T>(T Function() azione) {
    _sospensioni++;
    try {
      return azione();
    } finally {
      _sospensioni--;
    }
  }

  @visibleForTesting
  static void resetPerTest() {
    _sessionId = _nuovoId();
    _seq = 0;
    _schermateSessione = 0;
    _attivaAccumulata = Duration.zero;
    _inPrimoPianoDa = orologio();
    _inBackgroundDa = null;
    _schermataVisibile = null;
    _schermataDa = null;
    _daRiaprire = null;
    _sospensioni = 0;
    currentScreen = null;
    nomeTabAttiva = null;
    rottaInCimaShell = null;
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
    // Fuori dal try: vanno assegnati nell'ordine in cui gli eventi nascono,
    // prima di qualsiasi await.
    final meta = <String, dynamic>{
      ...?metadata,
      'session_id': _sessionId,
      'seq': _seq++,
      'client_ts': orologio().toUtc().toIso8601String(),
    };

    final registro = registroPerTest;
    if (registro != null) {
      registro(event, meta);
      return;
    }

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

  // ── Utilità per i valori ──────────────────────────────────────────────────

  /// Coordinate arrotondate a 2 decimali (~1 km): bastano per le analisi per
  /// zona e non registrano dove si trova esattamente una persona (vedi "Cose
  /// da NON fare" in test/mvp_analytics_plan.md).
  @visibleForTesting
  static double? arrotondaCoordinata(double? valore) =>
      valore == null ? null : (valore * 100).roundToDouble() / 100;

  /// Importo in euro come numero, da qualunque forma arrivi dall'app
  /// ("25€", "12,50 €", "1.200€", 25). `null` se non è un importo.
  ///
  /// I prezzi nell'app sono stringhe da mostrare: senza questo campo numerico
  /// la dashboard non può sommare gli incassi.
  static double? importoEuro(dynamic valore) {
    if (valore == null) return null;
    if (valore is num) return valore.toDouble();
    var testo = valore.toString().replaceAll(RegExp(r'[^0-9,.\-]'), '');
    if (testo.isEmpty) return null;
    if (testo.contains(',')) {
      // Formato italiano: il punto separa le migliaia, la virgola i decimali.
      testo = testo.replaceAll('.', '').replaceAll(',', '.');
    } else if (RegExp(r'^\d{1,3}(\.\d{3})+$').hasMatch(testo)) {
      // "1.200" senza decimali: punto delle migliaia.
      testo = testo.replaceAll('.', '');
    }
    return double.tryParse(testo);
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
          'lat':             arrotondaCoordinata(lat),
          'lng':             arrotondaCoordinata(lng),
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
          'lat':       arrotondaCoordinata(lat),
          'lng':       arrotondaCoordinata(lng),
        },
      );

  /// Registra l'attivazione/disattivazione del GPS forzato dalla Home.
  static Future<void> logGpsForced({required bool enabled}) =>
      log(
        event: 'gps_forced_toggle',
        metadata: {'enabled': enabled},
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

  /// Tap in Home che porta al dettaglio di un club. La schermata successiva
  /// la registra già l'observer: questo evento dice QUALE elemento della Home
  /// l'ha aperta ('hero', 'riserva_posto', 'consigliati_card',
  /// 'consigliati_prenota').
  static Future<void> logHomeTap({
    required String elemento,
    String? clubId,
    String? clubName,
  }) =>
      log(
        event: 'home_tap',
        metadata: {
          'elemento': elemento,
          'club_id': clubId,
          'club_name': clubName,
        },
      );

  /// Club aggiunto o tolto dai preferiti (dettaglio club).
  static Future<void> logFavorite({
    required bool aggiunto,
    required String clubId,
    String? clubName,
  }) =>
      log(
        event: aggiunto ? 'favorite_added' : 'favorite_removed',
        metadata: {'club_id': clubId, 'club_name': clubName},
      );

  // ── Funnel di conversione (nomi evento richiesti dal foglio MVP) ───────────
  // Questi event_name sono quelli che la dashboard interroga per il funnel
  // "apertura → prenotazione" e per la distribuzione oraria.
  //
  // Qui vivevano anche `logClubSearch` (event 'club_search') e
  // `logBookingCompleted` (event 'booking_completed'), tenuti "per continuità
  // con i dati già raccolti". Non li chiamava nessuno: nessuna continuità da
  // preservare, solo due nomi evento in più che somigliavano a 'search' e
  // 'booking_complete' e rendevano ambiguo quale dei due leggere.
  // `logClubViewed` invece è vivo (club_detail_screen) e resta.

  /// Funnel: l'utente sta cercando un locale.
  /// [source] distingue l'origine: 'city' (selezione città) o 'submit'
  /// (invio del testo di ricerca). Entrambe sono ricerche vere: la semplice
  /// apertura della schermata NON entra qui, la registra già l'observer
  /// delle rotte come `screen_*`.
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
        metadata: {
          'type': type,
          'event_id': eventId,
          'price': price,
          'price_eur': importoEuro(price),
        },
      );

  /// Funnel: prenotazione completata con successo (evento richiesto dal foglio
  /// come `booking_complete`, distinto dallo storico `booking_completed`).
  ///
  /// [bookingId] è l'id in `prenotazioni`: l'importo vero sta lì
  /// (`prezzo_totale`, calcolato da BookingService). Per i tavoli l'app non
  /// conosce il prezzo, quindi `amount` resta vuoto e si legge dal DB.
  static Future<void> logBookingComplete({
    required String type, // 'ticket' | 'table'
    String? eventId,
    dynamic amount,
    String? bookingId,
  }) =>
      log(
        event: 'booking_complete',
        metadata: {
          'type': type,
          'event_id': eventId,
          'amount': amount,
          'amount_eur': importoEuro(amount),
          'prenotazione_id': bookingId,
        },
      );

  /// Pagamento riuscito: stesso momento di [logBookingComplete], con il nome
  /// evento storico che il foglio usa per gli incassi.
  static Future<void> logPaymentSuccess({
    required String type, // 'ticket' | 'table'
    dynamic amount,
    String? bookingId,
  }) =>
      log(
        event: 'booking_payment_success',
        metadata: {
          'type': type,
          'amount': amount,
          'amount_eur': importoEuro(amount),
          'prenotazione_id': bookingId,
        },
      );

  // ── Errori (TAB Errori del foglio) ─────────────────────────────────────────

  /// Oltre questa lunghezza il messaggio d'errore viene tagliato: alcune
  /// eccezioni si portano dietro interi payload di risposta.
  static const int _maxMessaggioErrore = 500;

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
          if (message != null)
            'message': message.length > _maxMessaggioErrore
                ? message.substring(0, _maxMessaggioErrore)
                : message,
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
