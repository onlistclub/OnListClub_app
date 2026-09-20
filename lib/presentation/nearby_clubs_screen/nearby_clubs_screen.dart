import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../core/constants/image_constant.dart';
import '../../core/models/citta_model.dart';
import '../../core/models/locale_model.dart';
import '../../core/services/analytics_service.dart';
import '../../core/services/club_service.dart';
import '../../core/services/location_service.dart';
import '../../core/services/navigator_service.dart';
import '../../core/services/user_profile_manager.dart';
import '../../core/utils/analytics_mixin.dart';
import '../../core/utils/responsive.dart';
import '../../routes/app_routes.dart';
import '../../theme/onlist_text_styles.dart';
import '../../widgets/image_fallback.dart';
import '../../widgets/shared_footer.dart';
import '../../widgets/shimmer_loading.dart';
import '../../widgets/staggered_item.dart';
import '../../widgets/top_bar_slot.dart';

// ── Design "Ricerca Club" (Figma off/NUOVO, CSS del 16/09/2026) ─────────────
// Tutte le misure sono px design (frame 393×852) scalate con R.sp, oppure px
// design puri dentro i blocchi a scala fissa (_ScalaFissa).

/// Sfondo schermata: `linear-gradient(180deg, #000000 0%, #0000FF 100%)`.
const LinearGradient _sfondo = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [Color(0xFF000000), Color(0xFF0000FF)],
);

/// Riempimento "vetro" di barra, chip e riquadro suggerimenti:
/// blu 12% sopra bianco 4% (`linear-gradient(…0,0,255,.12…), rgba(255,255,255,.04)`)
/// già composti in un unico colore.
const Color _vetro = Color(0x283A3AFF);

/// Bordo 1px `rgba(0, 21, 255, 0.29)`.
const Color _vetroBordo = Color(0x4A0015FF);

/// Margine laterale dei contenuti: barra e card larghe 367 su 393.
const double _margine = 13;

/// Stile musicale del pannello filtri: macro-categorie del Figma, ognuna
/// raggruppa i generi presenti nel DB. "Italiana" del Figma non ha generi
/// corrispondenti nel DB, quindi non compare.
const Map<String, Set<String>> _categorieGeneri = {
  'Mainstream / Commerciale': {'Commercial', 'Pop', 'Dance', 'Revival'},
  'Elettronica': {'House', 'Techno', 'Electro', 'EDM'},
  'Urban': {'Hip Hop', 'Reggaeton'},
  'Rock / Indie': {'Rock', 'Indie'},
};

/// Livelli del filtro prezzo ($ … $$$$$), uguali a `locali.prezzo_indicativo`.
const int _livelliPrezzo = 5;

/// Larghezze dei cinque scomparti della barra prezzo, ricavate dai centri dei
/// simboli nel CSS (21.5, 82, 141, 206, 286 su 323 di barra).
const List<int> _pesiPrezzo = [52, 60, 62, 72, 77];

class NearbyClubsScreen extends StatefulWidget {
  const NearbyClubsScreen({Key? key}) : super(key: key);

  static Widget builder(BuildContext context) => const NearbyClubsScreen();

  @override
  State<NearbyClubsScreen> createState() => _NearbyClubsScreenState();
}

class _NearbyClubsScreenState extends State<NearbyClubsScreen>
    with ScreenAnalytics {
  @override
  String get screenName => 'search_nearby';

  // Cache in memoria condivisa tra le aperture: riaprendo la Ricerca si mostrano
  // subito gli ultimi dati, mentre un refresh silenzioso li aggiorna.
  static _NearbyData? _cachedData;

  /// Ultimi dati mostrati. La UI legge SEMPRE da qui, non da un `FutureBuilder`:
  /// assegnare un future nuovo riportava lo snapshot a `waiting` per un frame
  /// (lo scheletro lampeggiava alla riapertura). Null = scheletro.
  _NearbyData? _data;

  /// Il caricamento corrente è fallito e non abbiamo dati da mostrare.
  bool _loadError = false;

  /// Marker monotonico dei caricamenti: scarta le risposte obsolete.
  int _loadSeq = 0;

  // ── Filtri ────────────────────────────────────────────────────────────────
  final Set<String> _selectedCategorie = {};
  int? _selectedPrezzo; // null = tutti, 1…5

  /// Città scelta con "Cerca qui": ha priorità su GPS e città salvata.
  CittaModel? _customCity;

  // ── Barra di ricerca ──────────────────────────────────────────────────────
  // Un solo campo cerca sia locali sia città. Dopo "Cerca qui" la barra mostra
  // il nome della città scelta ([_barraMostraCitta]): la X la toglie e la
  // ricerca torna alla posizione automatica.
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  String _searchQuery = '';
  bool _barraMostraCitta = false;

  // ── Risultati della ricerca testuale ──────────────────────────────────────
  // Con almeno 2 caratteri: città da proporre ("Cerca qui"), locali per nome
  // su tutte le città ("Forse stai cercando") e altri locali delle stesse zone
  // ("Altri locali in linea con la tua ricerca").
  Timer? _searchDebounce;
  int _searchSeq = 0;
  bool _searchLoading = false;
  List<CittaModel> _cityResults = [];
  List<LocaleModel> _forse = [];
  List<LocaleModel> _altri = [];

  static const int _maxCitta = 3;

  bool get _ricercaAttiva => _searchQuery.trim().length >= 2;

  @override
  void initState() {
    super.initState();
    // NIENTE logSearch qui: aprire la schermata non è una ricerca (l'apertura
    // la registra già ScreenAnalytics).
    if (_cachedData != null) {
      _data = _cachedData;
      _reload(showSkeleton: false);
    } else {
      _reload(reportLoad: true);
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  /// Ricarica i dati. Con `showSkeleton: false` la lista attuale resta a video
  /// finché i nuovi dati non sono pronti.
  Future<void> _reload({
    bool showSkeleton = true,
    bool reportLoad = false,
  }) async {
    _loadSeq++;
    final mySeq = _loadSeq;
    if (showSkeleton && (_data != null || _loadError)) {
      setState(() {
        _data = null;
        _loadError = false;
      });
    }
    try {
      final d = await _load();
      if (!mounted || mySeq != _loadSeq) return;
      setState(() {
        _data = d;
        _loadError = false;
        // Le distanze dei risultati dipendono dalla posizione appena cambiata.
        _forse = _sortByProximity(_forse, d.lat, d.lng);
        _altri = _sortByProximity(_altri, d.lat, d.lng);
      });
      if (reportLoad) reportLoadTime('load_time_ricerca');
    } catch (e) {
      debugPrint('[NearbyClubs] caricamento fallito: $e');
      if (!mounted || mySeq != _loadSeq) return;
      setState(() => _loadError = true);
    }
  }

  // ── Barra: testo, città, GPS ─────────────────────────────────────────────

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchSeq++;
    final String q = value.trim();
    setState(() {
      // Modificare il nome della città scelta lo trasforma in una ricerca;
      // il centro resta sulla città finché non la si toglie con la X.
      _barraMostraCitta = false;
      _searchQuery = value;
      if (q.length < 2) {
        _searchLoading = false;
        _cityResults = [];
        _forse = [];
        _altri = [];
      } else {
        _searchLoading = true;
      }
    });
    if (q.length < 2) return;
    final mySeq = _searchSeq;
    _searchDebounce = Timer(
      const Duration(milliseconds: 300),
      () => _cerca(q, mySeq),
    );
  }

  Future<void> _cerca(String q, int mySeq) async {
    try {
      final risultati = await Future.wait([
        LocationService.searchCitta(q),
        ClubService.searchClubsByName(q),
      ]);
      final citta = (risultati[0] as List<CittaModel>)
          .take(_maxCitta)
          .toList(growable: false);
      final forse = risultati[1] as List<LocaleModel>;
      final forseIds = forse.map((c) => c.id).toSet();
      // Stesse zone dei locali trovati per nome, più le città che
      // corrispondono al testo ("Milano" → i locali di Milano).
      final cityIds = <String>{
        ...forse.map((c) => c.idCitta).whereType<String>(),
        ...citta.map((c) => c.idCitta),
      }.toList();
      final stesseZone = await ClubService.getClubsInCities(cityIds);
      final altri = [
        for (final c in stesseZone)
          if (!forseIds.contains(c.id)) c,
      ];
      if (!mounted || mySeq != _searchSeq) return;
      setState(() {
        _cityResults = citta;
        _forse = _sortByProximity(forse, _data?.lat, _data?.lng);
        _altri = _sortByProximity(altri, _data?.lat, _data?.lng);
        _searchLoading = false;
      });
    } catch (e) {
      debugPrint('[NearbyClubs] ricerca fallita: $e');
      if (!mounted || mySeq != _searchSeq) return;
      setState(() {
        _cityResults = [];
        _forse = [];
        _altri = [];
        _searchLoading = false;
      });
    }
  }

  /// "Cerca qui": la città diventa il centro della ricerca e il suo nome
  /// resta nella barra.
  void _selectCity(CittaModel citta) {
    AnalyticsService.logSearch(query: citta.nomeCitta, source: 'city');
    _searchDebounce?.cancel();
    _searchSeq++;
    _searchFocus.unfocus();
    _searchCtrl.text = citta.nomeCitta;
    setState(() {
      _customCity = citta;
      _barraMostraCitta = true;
      _searchQuery = '';
      _searchLoading = false;
      _cityResults = [];
      _forse = [];
      _altri = [];
    });
    _reload();
  }

  void _onClearTap() {
    final bool eraCitta = _barraMostraCitta;
    _searchCtrl.clear();
    _onSearchChanged('');
    if (eraCitta) {
      setState(() => _customCity = null);
      _reload();
    }
  }

  /// Accende/spegne il GPS come sorgente della ricerca. Acceso, la città
  /// scelta a mano viene scartata: altrimenti avrebbe la priorità in `_load()`.
  void _toggleGps(bool enable) {
    LocationService.isGpsForced = enable;
    AnalyticsService.logGpsForced(enabled: enable);
    if (enable) {
      if (_barraMostraCitta) {
        _searchCtrl.clear();
        _onSearchChanged('');
      }
      setState(() => _customCity = null);
    }
    _reload();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(enable
            ? 'Ricerca tramite GPS attivata'
            : 'GPS disattivato: ricerca per città'),
      ),
    );
  }

  // ── Load ───────────────────────────────────────────────────────────────────

  Future<_NearbyData> _load() async {
    final raggio = await UserProfileManager().getRaggioKm();
    final isGpsForced = LocationService.isGpsForced;

    double? lat;
    double? lng;
    bool gpsAttempted = false;

    Future<void> tryGps() async {
      gpsAttempted = true;
      try {
        var permission = await Geolocator.checkPermission();
        if (!kIsWeb && permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission == LocationPermission.whileInUse ||
            permission == LocationPermission.always) {
          final pos = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.low,
              timeLimit: Duration(seconds: 3),
            ),
          );
          lat = pos.latitude;
          lng = pos.longitude;
        } else {
          debugPrint('[NearbyClubs] GPS permesso negato: $permission');
        }
      } catch (e) {
        debugPrint('[NearbyClubs] tryGps fallito: $e');
      }
    }

    if (_customCity != null && _customCity!.lat != null) {
      // Priorità 1: città scelta con "Cerca qui".
      lat = _customCity!.lat;
      lng = _customCity!.lng;
    } else if (isGpsForced) {
      // Priorità 2: GPS forzato; se fallisce, città salvata.
      await tryGps();
      if (lat == null) {
        final savedCity = await LocationService.getSavedLocation();
        if (savedCity?.lat != null) {
          lat = savedCity!.lat;
          lng = savedCity.lng;
        }
      }
    } else {
      // Priorità 3: città salvata nelle impostazioni.
      final savedCity = await LocationService.getSavedLocation();
      if (savedCity?.lat != null) {
        lat = savedCity!.lat;
        lng = savedCity.lng;
      }
      // Priorità 4: città più vicina all'ultima posizione GPS in cache (col
      // toggle spento il GPS non va interrogato).
      if (lat == null) {
        final cached = await LocationService.getCachedGpsPosition();
        if (cached != null) {
          final nearest =
              await LocationService.getNearestCitta(cached.lat, cached.lng);
          if (nearest?.lat != null) {
            lat = nearest!.lat;
            lng = nearest.lng;
          }
        }
      }
    }

    // Senza posizione si mostrano comunque i locali più popolari.
    final locationAvailable = lat != null && lng != null;

    List<LocaleModel> clubs = [];
    try {
      clubs = await ClubService.getLocaliVicini(lat, lng,
          raggioKm: raggio.toDouble());
    } catch (e) {
      debugPrint('[NearbyClubs] getLocaliVicini fallito: $e');
    }
    final data = _NearbyData(
      clubs: clubs,
      raggio: raggio,
      lat: lat,
      lng: lng,
      locationAvailable: locationAvailable,
      gpsAttempted: gpsAttempted,
    );
    _cachedData = data;
    return data;
  }

  /// Ordina per vicinanza all'utente. Locale senza coordinate → in fondo;
  /// senza posizione utente → ripiega su famosità.
  static List<LocaleModel> _sortByProximity(
      List<LocaleModel> list, double? uLat, double? uLng) {
    final l = [...list];
    if (uLat == null || uLng == null) {
      l.sort((a, b) => b.famosita.compareTo(a.famosita));
      return l;
    }
    double dist(LocaleModel c) => (c.lat == null || c.lng == null)
        ? double.infinity
        : ClubService.distanceKm(uLat, uLng, c.lat!, c.lng!);
    l.sort((a, b) {
      final da = dist(a), db = dist(b);
      if (da == db) return b.famosita.compareTo(a.famosita);
      return da.compareTo(db);
    });
    return l;
  }

  // ── Filtri ─────────────────────────────────────────────────────────────────

  /// Predicato condiviso da lista e pannello filtri ("Mostra N risultati").
  static List<LocaleModel> _applyFilters(
    List<LocaleModel> clubs, {
    required Set<String> categorie,
    required int? prezzo,
  }) {
    final Set<String> generi = {
      for (final c in categorie) ...?_categorieGeneri[c],
    };
    return clubs.where((c) {
      if (generi.isNotEmpty && !c.generiMusicali.any(generi.contains)) {
        return false;
      }
      if (prezzo != null && c.prezzoIndicativo != prezzo) return false;
      return true;
    }).toList();
  }

  List<LocaleModel> _filtra(List<LocaleModel> clubs) => _applyFilters(
        clubs,
        categorie: _selectedCategorie,
        prezzo: _selectedPrezzo,
      );

  int get _activeFilterCount =>
      _selectedCategorie.length + (_selectedPrezzo != null ? 1 : 0);

  /// Locali su cui agiscono i filtri in questo momento: i risultati della
  /// ricerca se si sta cercando, altrimenti i locali vicini.
  List<LocaleModel> _baseCorrente() {
    if (_ricercaAttiva) return [..._forse, ..._altri];
    return _data?.clubs ?? const [];
  }

  Future<void> _showFiltersSheet() async {
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (_, __, ___) => _FiltersSheet(
        base: _baseCorrente(),
        initialCategorie: _selectedCategorie,
        initialPrezzo: _selectedPrezzo,
        onChanged: (categorie, prezzo) {
          setState(() {
            _selectedCategorie
              ..clear()
              ..addAll(categorie);
            _selectedPrezzo = prezzo;
          });
        },
      ),
      transitionBuilder: (_, anim, __, child) {
        final curved =
            CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.25),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  Future<void> _showRadiusDialog(_NearbyData? data) async {
    final int? scelto = await showDialog<int>(
      context: context,
      // CSS Rectangle 347: nero 86% × opacità 0.8 ≈ 69%.
      barrierColor: const Color(0xB0000000),
      builder: (_) => _RadiusDialog(
        raggioIniziale: data?.raggio ?? 20,
        lat: data?.lat,
        lng: data?.lng,
      ),
    );
    if (scelto != null) {
      await UserProfileManager().saveRaggioKm(scelto);
      _reload();
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      // Il gradiente continua dietro la footer flottante.
      extendBody: true,
      // Footer: unica e globale, montata da RootShell (non qui).
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: _sfondo),
        child: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // L'icona ricerca resta muta: si è già in Ricerca.
              TopBarSlot(onSearchTap: () {}),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: R.sp(_margine)),
                child: _buildSearchBar(),
              ),
              // CSS: barra 111+43 = 154, chip a 163.
              SizedBox(height: R.sp(9)),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: R.sp(_margine)),
                child: _buildChips(),
              ),
              // Chip 163+21 = 184, contenuto a 198.
              SizedBox(height: R.sp(14)),
              Expanded(child: _buildContenuto()),
            ],
          ),
        ),
      ),
    );
  }

  // ── Barra di ricerca (Rectangle 303: 367×43 r17) ──────────────────────────
  Widget _buildSearchBar() {
    final TextStyle testo = OnlistTextStyles.hn(
      fontSize: R.sp(20),
      fontWeight: FontWeight.w300,
      color: Colors.white,
      height: 1.0,
    );
    return Container(
      height: R.sp(43),
      decoration: BoxDecoration(
        color: _vetro,
        border: Border.all(color: _vetroBordo),
        borderRadius: BorderRadius.circular(R.sp(17)),
      ),
      child: Row(
        children: [
          // Lente 24 a x 11, testo a x 42.
          SizedBox(width: R.sp(11)),
          Icon(Icons.search, color: Colors.white, size: R.sp(24)),
          SizedBox(width: R.sp(7)),
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              focusNode: _searchFocus,
              textInputAction: TextInputAction.search,
              cursorColor: Colors.white,
              style: testo,
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: 'Cerca locale o città...',
                hintStyle: testo,
              ),
              onChanged: _onSearchChanged,
              // Funnel: ricerca attiva quando l'utente conferma il testo.
              onSubmitted: (value) {
                final q = value.trim();
                if (q.isNotEmpty) {
                  AnalyticsService.logSearch(query: q, source: 'submit');
                }
              },
            ),
          ),
          // X 24 a 11 dal bordo destro, solo se c'è qualcosa da togliere.
          if (_searchCtrl.text.isNotEmpty)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _onClearTap,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: R.sp(11)),
                child: Icon(Icons.close, color: Colors.white, size: R.sp(24)),
              ),
            )
          else
            SizedBox(width: R.sp(11)),
        ],
      ),
    );
  }

  // ── Chip: raggio, GPS, filtri (h 21, r10.5) ───────────────────────────────
  Widget _buildChips() {
    final data = _data;
    final bool gps = LocationService.isGpsForced;
    final int filtri = _activeFilterCount;
    return Row(
      children: [
        _Chip(
          icona: Icons.directions_walk,
          iconaSize: 10,
          label: '${data?.raggio ?? 20} km',
          onTap: () => _showRadiusDialog(data),
        ),
        SizedBox(width: R.sp(5)),
        // Spento il chip è al 50%, come nel Figma.
        _Chip(
          icona: Icons.location_on,
          iconaSize: 12,
          label: 'Usa GPS',
          attenuato: !gps,
          onTap: () => _toggleGps(!gps),
        ),
        const Spacer(),
        _Chip(
          icona: Icons.list,
          iconaSize: 20,
          label: filtri > 0 ? 'Filtri ($filtri)' : 'Filtri',
          onTap: _showFiltersSheet,
        ),
      ],
    );
  }

  // ── Contenuto sotto i chip ────────────────────────────────────────────────
  Widget _buildContenuto() {
    if (_ricercaAttiva) return _buildRisultatiRicerca();

    final data = _data;
    if (data == null) {
      if (!_loadError) return const _NearbySkeleton();
      return _Messaggio(
        testo: 'Errore nel caricamento',
        azione: 'Riprova',
        onAzione: _reload,
      );
    }

    final lista = _filtra(data.clubs);
    return ListView(
      padding: EdgeInsets.fromLTRB(
          R.sp(_margine), 0, R.sp(_margine), SharedFooter.height + R.sp(16)),
      children: [
        if (!data.locationAvailable) ...[
          _BannerPosizione(
            testo: data.gpsAttempted
                ? 'Posizione non disponibile. Mostro i locali più popolari.'
                : 'Imposta la tua città per vedere i locali vicini.',
            onRiprova: _reload,
          ),
          SizedBox(height: R.sp(14)),
        ],
        if (lista.isEmpty)
          _Messaggio(
            testo: _activeFilterCount > 0
                ? 'Nessun locale corrisponde ai filtri.'
                : 'Nessun locale trovato nel raggio di ${data.raggio} km.',
          )
        else
          ..._righe(lista, data, stagger: true),
      ],
    );
  }

  Widget _buildRisultatiRicerca() {
    final data = _data;
    final String q = _searchQuery.trim();
    final forse = _filtra(_forse);
    final altri = _filtra(_altri);
    return ListView(
      padding: EdgeInsets.fromLTRB(
          R.sp(_margine), 0, R.sp(_margine), SharedFooter.height + R.sp(16)),
      children: [
        _SuggerimentiCitta(
          citta: _cityResults,
          loading: _searchLoading,
          onCercaQui: _selectCity,
        ),
        // Riquadro 198+107 = 305, titolo a 324.
        SizedBox(height: R.sp(19)),
        if (_searchLoading)
          const _NearbySkeleton(inLista: true)
        else if (forse.isEmpty && altri.isEmpty)
          _Messaggio(
            testo: _activeFilterCount > 0
                ? 'Nessun locale per “$q” con questi filtri.'
                : 'Nessun locale trovato per “$q”.',
          )
        else ...[
          if (forse.isNotEmpty) ...[
            const _TitoloSezione('Forse stai cercando :'),
            // Titolo 324+20 = 344, prima riga a 358.
            SizedBox(height: R.sp(14)),
            ..._righe(forse, data, stagger: true),
            // Riga 358+77 = 435, titolo successivo a 451.
            SizedBox(height: R.sp(16)),
          ],
          if (altri.isNotEmpty) ...[
            const _TitoloSezione('Altri locali in linea con la tua ricerca :'),
            SizedBox(height: R.sp(15)),
            ..._righe(altri, data),
          ],
        ],
      ],
    );
  }

  /// Righe locale separate dal filo bianco (CSS Line 19–21: una riga ogni 96,
  /// filo a +87 dall'alto della riga).
  List<Widget> _righe(List<LocaleModel> clubs, _NearbyData? data,
      {bool stagger = false}) {
    return [
      for (var i = 0; i < clubs.length; i++) ...[
        if (i > 0) const _Separatore(),
        stagger
            ? StaggeredItem(
                index: i,
                child: _ClubRow(
                    club: clubs[i], userLat: data?.lat, userLng: data?.lng),
              )
            : _ClubRow(club: clubs[i], userLat: data?.lat, userLng: data?.lng),
      ],
    ];
  }
}

// ── Pezzi comuni ─────────────────────────────────────────────────────────────

/// Blocco disegnato a dimensione design fissa e scalato sulla larghezza
/// disponibile (proporzioni esatte del Figma, tetto 1.15× sui tablet).
class _ScalaFissa extends StatelessWidget {
  final double w;
  final double h;
  final Widget child;

  const _ScalaFissa({required this.w, required this.h, required this.child});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final ratio = constraints.maxWidth / w;
      final scale = ratio < 1.15 ? ratio : 1.15;
      // Align con heightFactor 1, non Center: con altezza libera (il pannello
      // filtri) il Center si prendeva tutto lo schermo e il pannello copriva
      // la pagina intera.
      return Align(
        alignment: Alignment.topCenter,
        heightFactor: 1,
        child: SizedBox(
          width: w * scale,
          height: h * scale,
          child: FittedBox(
            fit: BoxFit.fill,
            child: SizedBox(width: w, height: h, child: child),
          ),
        ),
      );
    });
  }
}

class _Chip extends StatelessWidget {
  final IconData icona;
  final double iconaSize;
  final String label;
  final bool attenuato;
  final VoidCallback? onTap;

  const _Chip({
    required this.icona,
    required this.iconaSize,
    required this.label,
    this.attenuato = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: attenuato ? 0.5 : 1,
        child: Container(
          height: R.sp(21),
          padding: EdgeInsets.fromLTRB(R.sp(6), 0, R.sp(8), 0),
          decoration: BoxDecoration(
            color: _vetro,
            border: Border.all(color: _vetroBordo),
            borderRadius: BorderRadius.circular(R.sp(10.5)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // L'icona va centrata sulle MAIUSCOLE, non sul riquadro del
              // testo: con height 1 la linea di base cade al 78.3% e le
              // maiuscole sono alte il 73%, quindi il loro centro sta 8.2
              // centesimi di corpo più in alto del centro del riquadro.
              Transform.translate(
                offset: Offset(0, -R.sp(11) * 0.082),
                child: Icon(icona, color: Colors.white, size: R.sp(iconaSize)),
              ),
              SizedBox(width: R.sp(3)),
              Text(
                label,
                style: OnlistTextStyles.hn(
                  fontSize: R.sp(11),
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                  height: 1.0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TitoloSezione extends StatelessWidget {
  final String testo;
  const _TitoloSezione(this.testo);

  @override
  Widget build(BuildContext context) {
    return Text(
      testo,
      style: OnlistTextStyles.hn(
        fontSize: R.sp(20),
        fontWeight: FontWeight.w700,
        color: Colors.white,
        height: 1.0,
        letterSpacing: -0.05 * R.sp(20),
      ),
    );
  }
}

class _Separatore extends StatelessWidget {
  const _Separatore();

  @override
  Widget build(BuildContext context) {
    // Riga 77 + 10 = filo, poi 8 fino alla riga dopo (passo 96).
    return Padding(
      padding: EdgeInsets.only(top: R.sp(10), bottom: R.sp(8)),
      child: Container(height: 1, color: const Color(0x80FFFFFF)),
    );
  }
}

class _Messaggio extends StatelessWidget {
  final String testo;
  final String? azione;
  final VoidCallback? onAzione;

  const _Messaggio({required this.testo, this.azione, this.onAzione});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: R.sp(24)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            testo,
            textAlign: TextAlign.center,
            style: OnlistTextStyles.hn(
              fontSize: R.sp(15),
              color: Colors.white70,
            ),
          ),
          if (azione != null) ...[
            SizedBox(height: R.sp(12)),
            GestureDetector(
              onTap: onAzione,
              child: Text(
                azione!,
                style: OnlistTextStyles.hn(
                  fontSize: R.sp(15),
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Avviso non bloccante quando la posizione non è disponibile, nello stesso
/// "vetro" della barra.
class _BannerPosizione extends StatelessWidget {
  final String testo;
  final VoidCallback onRiprova;

  const _BannerPosizione({required this.testo, required this.onRiprova});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(R.sp(14), R.sp(10), R.sp(10), R.sp(10)),
      decoration: BoxDecoration(
        color: _vetro,
        border: Border.all(color: _vetroBordo),
        borderRadius: BorderRadius.circular(R.sp(17)),
      ),
      child: Row(
        children: [
          Icon(Icons.location_off, color: Colors.white70, size: R.sp(16)),
          SizedBox(width: R.sp(8)),
          Expanded(
            child: Text(
              testo,
              style: OnlistTextStyles.hn(
                fontSize: R.sp(13),
                color: Colors.white,
              ),
            ),
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onRiprova,
            child: Padding(
              padding: EdgeInsets.all(R.sp(4)),
              child: Text(
                'Riprova',
                style: OnlistTextStyles.hn(
                  fontSize: R.sp(13),
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Suggerimenti città (Rectangle 308: 367 × righe da 32, r17) ──────────────
class _SuggerimentiCitta extends StatelessWidget {
  final List<CittaModel> citta;
  final bool loading;
  final ValueChanged<CittaModel> onCercaQui;

  const _SuggerimentiCitta({
    required this.citta,
    required this.loading,
    required this.onCercaQui,
  });

  @override
  Widget build(BuildContext context) {
    final TextStyle stile = OnlistTextStyles.hn(
      fontSize: R.sp(15),
      fontWeight: FontWeight.w400,
      color: Colors.white,
      height: 1.0,
    );
    final List<Widget> righe;
    if (citta.isEmpty) {
      righe = [
        SizedBox(
          height: R.sp(32),
          child: Row(
            children: [
              if (loading)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: R.sp(6)),
                    child: const LinearProgressIndicator(
                      minHeight: 2,
                      backgroundColor: Colors.transparent,
                      color: Colors.white,
                    ),
                  ),
                )
              else ...[
                _pin(),
                SizedBox(width: R.sp(5)),
                Text('Nessuna città trovata', style: stile),
              ],
            ],
          ),
        ),
      ];
    } else {
      righe = [
        for (final c in citta)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onCercaQui(c),
            child: SizedBox(
              height: R.sp(32),
              child: Row(
                children: [
                  _pin(),
                  SizedBox(width: R.sp(5)),
                  Expanded(
                    child: Text(
                      c.nomeCitta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: stile,
                    ),
                  ),
                  Text('Cerca qui', style: stile),
                ],
              ),
            ),
          ),
      ];
    }
    return Container(
      // CSS: prima riga di testo a +16, pin a x 6, "Cerca qui" a 21 dal bordo.
      padding: EdgeInsets.fromLTRB(R.sp(6), R.sp(6), R.sp(21), R.sp(5)),
      decoration: BoxDecoration(
        color: _vetro,
        border: Border.all(color: _vetroBordo),
        borderRadius: BorderRadius.circular(R.sp(17)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: righe),
    );
  }

  /// Pin 16 col gradiente `#00FFE1 → #2F00FF` dall'alto al basso.
  Widget _pin() {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF00FFE1), Color(0xFF2F00FF)],
      ).createShader(bounds),
      child: Icon(Icons.location_on, color: Colors.white, size: R.sp(16)),
    );
  }
}

// ── Skeleton ─────────────────────────────────────────────────────────────────
class _NearbySkeleton extends StatelessWidget {
  /// Dentro una lista già scrollabile: niente scroll proprio, poche righe.
  final bool inLista;

  const _NearbySkeleton({this.inLista = false});

  @override
  Widget build(BuildContext context) {
    Widget riga() => _ScalaFissa(
          w: _ClubRow._w,
          h: _ClubRow._h,
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ShimmerBox(width: 90, height: 77, radius: 6),
              SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 6),
                  ShimmerBox(width: 180, height: 26, radius: 6),
                  SizedBox(height: 12),
                  ShimmerBox(width: 150, height: 15, radius: 6),
                  SizedBox(height: 8),
                  ShimmerBox(width: 100, height: 9, radius: 4),
                ],
              ),
            ],
          ),
        );
    final int n = inLista ? 3 : 6;
    final righe = [
      for (var i = 0; i < n; i++) ...[
        if (i > 0) SizedBox(height: R.sp(19)),
        riga(),
      ],
    ];
    if (inLista) return Shimmer(child: Column(children: righe));
    return Shimmer(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.symmetric(horizontal: R.sp(_margine)),
        children: righe,
      ),
    );
  }
}

// ── Riga locale ──────────────────────────────────────────────────────────────

/// Avvolge [child] in un `Hero` solo se c'è una foto reale, così i locali
/// senza foto non fanno volare un placeholder.
Widget _heroWrap({
  required String tag,
  required bool enabled,
  required Widget child,
}) =>
    enabled ? Hero(tag: tag, child: child) : child;

/// Riga locale del Figma "Ricerca Club e Città", 367×77 a partire dalla foto:
/// foto 90×77 r6; nome 32/37 bold a x 96; generi 19/500 a (98,41);
/// indirizzo 11/500 a (100,66); pill distanza 18 alta r8 a y 56, a filo destro.
class _ClubRow extends StatelessWidget {
  final LocaleModel club;
  final double? userLat;
  final double? userLng;

  const _ClubRow({
    required this.club,
    required this.userLat,
    required this.userLng,
  });

  static const double _w = 367;
  static const double _h = 77;

  /// "900 m", "64 km", "1.000 km" (km interi, punto delle migliaia).
  String? _distanza() {
    if (userLat == null ||
        userLng == null ||
        club.lat == null ||
        club.lng == null) {
      return null;
    }
    final km = ClubService.distanceKm(userLat!, userLng!, club.lat!, club.lng!);
    if (km < 1) return '${(km * 1000).round()} m';
    final cifre = km.round().toString();
    final buf = StringBuffer();
    for (var i = 0; i < cifre.length; i++) {
      if (i > 0 && (cifre.length - i) % 3 == 0) buf.write('.');
      buf.write(cifre[i]);
    }
    return '$buf km';
  }

  @override
  Widget build(BuildContext context) {
    final String? distanza = _distanza();
    final TextStyle medio = OnlistTextStyles.hn(
      fontWeight: FontWeight.w500,
      color: Colors.white,
      height: 1.0,
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => NavigatorService.pushNamed(
        AppRoutes.clubDetailScreen,
        arguments: club,
      ),
      child: _ScalaFissa(
        w: _w,
        h: _h,
        child: Stack(
          children: [
            _heroWrap(
              tag: 'club-img-${club.id}',
              enabled: club.fotoUrl != null,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  width: 90,
                  height: 77,
                  child: club.fotoUrl != null
                      ? CachedNetworkImage(
                          imageUrl: club.fotoUrl!,
                          fit: BoxFit.cover,
                          memCacheWidth: 270,
                          memCacheHeight: 231,
                          // Niente dissolvenza: la schermata si ricrea a ogni
                          // apertura e le foto in cache sembravano ricaricarsi.
                          fadeInDuration: Duration.zero,
                          errorWidget: (_, __, ___) =>
                              ImageFallback(seed: club.id),
                        )
                      : ImageFallback(seed: club.id),
                ),
              ),
            ),
            Positioned(
              left: 96,
              top: 0,
              right: 0,
              child: Text(
                club.nome,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: OnlistTextStyles.hn(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  height: 37 / 32,
                  letterSpacing: -0.08 * 32,
                ),
              ),
            ),
            if (club.generiString.isNotEmpty)
              Positioned(
                left: 98,
                top: 41,
                right: 64,
                child: Text(
                  club.generiString,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: medio.copyWith(fontSize: 19),
                ),
              ),
            if (club.indirizzoCompleto.isNotEmpty)
              Positioned(
                left: 100,
                top: 66,
                right: 64,
                child: Text(
                  club.indirizzoCompleto,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: medio.copyWith(fontSize: 11),
                ),
              ),
            if (distanza != null)
              Positioned(
                right: 0,
                top: 56,
                child: Container(
                  height: 18,
                  padding: const EdgeInsets.fromLTRB(5, 0, 6, 0),
                  decoration: BoxDecoration(
                    color: const Color(0x33D9D9D9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Centrata sulle maiuscole come nei chip.
                      Transform.translate(
                        offset: const Offset(0, -10 * 0.082),
                        child: const Icon(Icons.location_on,
                            color: Colors.white, size: 10),
                      ),
                      const SizedBox(width: 3),
                      Text(distanza, style: medio.copyWith(fontSize: 10)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Popup raggio (CSS "Ricerca Club_GPS") ────────────────────────────────────
// Card 314×367 r30 (Rectangle 348), contenuti in px design dentro _ScalaFissa.

class _RadiusDialog extends StatefulWidget {
  final int raggioIniziale;
  final double? lat;
  final double? lng;

  const _RadiusDialog({
    required this.raggioIniziale,
    required this.lat,
    required this.lng,
  });

  @override
  State<_RadiusDialog> createState() => _RadiusDialogState();
}

class _RadiusDialogState extends State<_RadiusDialog> {
  static const double _w = 314;
  static const double _h = 367;
  static const int _min = 2;
  static const int _max = 50;

  late int _raggio = widget.raggioIniziale.clamp(_min, _max);
  final MapController _mapCtrl = MapController();

  bool get _haMappa => widget.lat != null && widget.lng != null;

  /// Lato corto del riquadro mappa in px design (262×139).
  static const double _latoMappa = 139;

  /// Zoom che fa entrare TUTTO il cerchio del raggio nel riquadro: alzando il
  /// raggio la mappa si allontana, abbassandolo si avvicina (doc correzioni
  /// 18/09). Prima erano quattro scalini fissi e il cerchio usciva.
  ///
  /// Alla latitudine L un pixel vale 156543.034·cos(L)/2^zoom metri.
  double _zoomPerRaggio(int km) {
    final double lat = widget.lat ?? 0;
    // 90% del lato: un margine perché il bordo del cerchio non tocchi i lati.
    final double metriPerPixel = (km * 2000) / (_latoMappa * 0.9);
    final double z = math.log(156543.03392 *
            math.cos(lat * math.pi / 180) /
            metriPerPixel) /
        math.ln2;
    return z.clamp(1.0, 18.0);
  }

  @override
  void dispose() {
    _mapCtrl.dispose();
    super.dispose();
  }

  TextStyle _stile(double size, {double opacita = 1}) => OnlistTextStyles.hn(
        fontSize: size,
        fontWeight: FontWeight.w500,
        color: Colors.white.withValues(alpha: opacita),
        height: 1.0,
        letterSpacing: 0.005 * size,
      );

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: EdgeInsets.symmetric(horizontal: R.sp(42)),
      child: _ScalaFissa(
        w: _w,
        h: _h,
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x590077FF), Color(0x590000FF)],
            ),
            borderRadius: BorderRadius.circular(30),
          ),
          child: Stack(
            children: [
              Positioned(
                left: 26,
                top: 22,
                child: Text('Cambia raggio', style: _stile(20)),
              ),
              // Mappa 262×139 r20 a (26,61).
              Positioned(
                left: 26,
                top: 61,
                width: 262,
                height: 139,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: _haMappa
                      ? _mappa()
                      : const ColoredBox(color: Color(0x33FFFFFF)),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: 217,
                child: Center(child: Text('$_raggio km', style: _stile(20))),
              ),
              // Slider: binario 226 da x 44 a y 255 (3px), pallino 16 bianco.
              Positioned(
                left: 36,
                top: 243,
                width: 242,
                height: 24,
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    activeTrackColor: const Color(0xFF0077FF),
                    inactiveTrackColor: Colors.white,
                    thumbColor: Colors.white,
                    overlayShape: SliderComponentShape.noOverlay,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 8),
                    trackShape: const RectangularSliderTrackShape(),
                  ),
                  child: Slider(
                    min: _min.toDouble(),
                    max: _max.toDouble(),
                    divisions: _max - _min,
                    value: _raggio.toDouble(),
                    onChanged: (v) {
                      setState(() => _raggio = v.round());
                      if (_haMappa) {
                        _mapCtrl.move(LatLng(widget.lat!, widget.lng!),
                            _zoomPerRaggio(_raggio));
                      }
                    },
                  ),
                ),
              ),
              Positioned(
                left: 26,
                top: 266,
                child: Text('$_min km', style: _stile(10, opacita: 0.7)),
              ),
              Positioned(
                right: 26,
                top: 266,
                child: Text('$_max km', style: _stile(10, opacita: 0.7)),
              ),
              // Annulla (testo a x 134) e Applica (79×28 r9 a (209,319)).
              Positioned(
                left: 120,
                top: 319,
                height: 28,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.pop(context),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Center(child: Text('Annulla', style: _stile(13))),
                  ),
                ),
              ),
              Positioned(
                left: 209,
                top: 319,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context, _raggio),
                  child: Container(
                    width: 79,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x330000FF), Color(0x330077FF)],
                      ),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text('Applica', style: _stile(13)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Tile OpenStreetMap rese NERE: prima si passano in scala di grigi e poi
  /// si invertono, così le mappe chiare diventano quasi nere come nel Figma.
  ///
  /// Il `darkModeTileBuilder` di flutter_map inverte lasciando le tinte, e la
  /// mappa restava verde e rosa (doc correzioni 18/09). Qui la riga è la
  /// stessa per R, G e B — nessun colore sopravvive — e il fattore 0.85 la
  /// scurisce ancora un po'.
  static Widget _tileNere(BuildContext context, Widget tile, TileImage image) {
    return ColorFiltered(
      colorFilter: const ColorFilter.matrix(<double>[
        -0.1807, -0.6079, -0.0614, 0, 216.75, //R
        -0.1807, -0.6079, -0.0614, 0, 216.75, //G
        -0.1807, -0.6079, -0.0614, 0, 216.75, //B
        0, 0, 0, 1, 0, //A
      ]),
      child: tile,
    );
  }

  /// Mappa OpenStreetMap scurita (le basemap scure di CARTO ora chiedono
  /// una API key e mostravano la scritta "API KEY" sulle tile).
  Widget _mappa() {
    final centro = LatLng(widget.lat!, widget.lng!);
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapCtrl,
          options: MapOptions(
            initialCenter: centro,
            initialZoom: _zoomPerRaggio(_raggio),
            interactionOptions:
                const InteractionOptions(flags: InteractiveFlag.none),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.onlist.app',
              tileBuilder: _tileNere,
            ),
            CircleLayer(
              circles: [
                CircleMarker(
                  point: centro,
                  radius: _raggio * 1000.0,
                  useRadiusInMeter: true,
                  color: const Color(0x331E00FF),
                  borderColor: const Color(0xFF1E00FF),
                  borderStrokeWidth: 2,
                ),
              ],
            ),
            MarkerLayer(
              markers: [
                Marker(
                  point: centro,
                  width: 20,
                  height: 20,
                  child: const Icon(Icons.location_on,
                      color: Color(0xFF1E00FF), size: 20),
                ),
              ],
            ),
          ],
        ),
        // Attribuzione richiesta dalla licenza OpenStreetMap.
        Positioned(
          right: 10,
          bottom: 4,
          child: Text(
            '© OpenStreetMap',
            style: OnlistTextStyles.hn(
              fontSize: 6,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Pannello filtri (CSS "Ricerca Club_ Sezione Filtri") ─────────────────────
// Pannello 393×407 dal fondo, sopra il contenuto sfocato e scurito al 68%.
// Le scelte si applicano subito tramite [onChanged].

class _FiltersSheet extends StatefulWidget {
  final List<LocaleModel> base;
  final Set<String> initialCategorie;
  final int? initialPrezzo;
  final void Function(Set<String> categorie, int? prezzo) onChanged;

  const _FiltersSheet({
    required this.base,
    required this.initialCategorie,
    required this.initialPrezzo,
    required this.onChanged,
  });

  @override
  State<_FiltersSheet> createState() => _FiltersSheetState();
}

class _FiltersSheetState extends State<_FiltersSheet> {
  static const double _w = 393;
  static const double _h = 407;

  /// Macro-categorie nell'ordine del Figma.
  static final List<String> _nomiCategorie =
      _categorieGeneri.keys.toList(growable: false);

  late final Set<String> _scelte = {...widget.initialCategorie};
  late int? _prezzo = widget.initialPrezzo;

  final ScrollController _caroselloCtrl = ScrollController();
  int _paginaCarosello = 0;

  /// Trascinamento verso il basso in corso (px reali).
  double _trascinamento = 0;

  @override
  void initState() {
    super.initState();
    _caroselloCtrl.addListener(_aggiornaPagina);
  }

  @override
  void dispose() {
    _caroselloCtrl.dispose();
    super.dispose();
  }

  void _aggiornaPagina() {
    // Un pallino per categoria: quello acceso segue lo scorrimento.
    final pos = _caroselloCtrl.position;
    final int n = _nomiCategorie.length;
    if (n < 2 || pos.maxScrollExtent <= 0) return;
    final int p = (pos.pixels / pos.maxScrollExtent * (n - 1))
        .round()
        .clamp(0, n - 1);
    if (p != _paginaCarosello) setState(() => _paginaCarosello = p);
  }

  void _emit() {
    setState(() {});
    widget.onChanged(_scelte, _prezzo);
  }

  int get _count => _NearbyClubsScreenState._applyFilters(
        widget.base,
        categorie: _scelte,
        prezzo: _prezzo,
      ).length;

  bool get _haFiltri => _scelte.isNotEmpty || _prezzo != null;

  TextStyle _stile(double size,
          {FontWeight peso = FontWeight.w500,
          double ls = -0.06,
          Color colore = Colors.white}) =>
      OnlistTextStyles.hn(
        fontSize: size,
        fontWeight: peso,
        color: colore,
        height: 1.0,
        letterSpacing: ls * size,
      );

  @override
  Widget build(BuildContext context) {
    final double safeBottom = MediaQuery.paddingOf(context).bottom;
    return Stack(
      children: [
        // Contenuto dietro: sfocato e scurito (Rectangle 315, nero 68%).
        Positioned.fill(
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: const ColoredBox(color: Color(0xAD000000)),
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: Transform.translate(
            offset: Offset(0, _trascinamento),
            child: GestureDetector(
              onVerticalDragUpdate: (d) => setState(() {
                _trascinamento =
                    (_trascinamento + d.delta.dy).clamp(0.0, double.infinity);
              }),
              onVerticalDragEnd: (d) {
                final bool chiudi = _trascinamento > R.sp(100) ||
                    (d.primaryVelocity ?? 0) > 700;
                if (chiudi) {
                  Navigator.pop(context);
                } else {
                  setState(() => _trascinamento = 0);
                }
              },
              child: Material(
                type: MaterialType.transparency,
                child: DecoratedBox(
                  // Rectangle 314: `linear-gradient(180deg, #0033FF, #000B41)`.
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFF0033FF), Color(0xFF000B41)],
                    ),
                  ),
                  child: Padding(
                    padding: EdgeInsets.only(bottom: safeBottom),
                    child: _ScalaFissa(w: _w, h: _h, child: _contenuto()),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _contenuto() {
    final List<String> categorie = _nomiCategorie;
    return Stack(
      children: [
        // Maniglia 68×7 r5 bianca al 70%.
        Positioned(
          left: 165,
          top: 9,
          child: Container(
            width: 68,
            height: 7,
            decoration: BoxDecoration(
              color: const Color(0xB3FFFFFF),
              borderRadius: BorderRadius.circular(5),
            ),
          ),
        ),
        // "Filtri" a contorno: SVG ufficiale 381×86 (già bianco al 50%), al
        // posto della parola scritta col font dell'app, che non ha le
        // lettere larghe del Figma.
        Positioned(
          left: 5,
          top: 37,
          width: 381,
          height: 86,
          child: SvgPicture.asset(
            ImageConstant.imgScrittaFiltri,
            width: 381,
            height: 86,
            fit: BoxFit.fill,
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: 142,
          child: Center(child: Text('Stile musicale', style: _stile(29))),
        ),
        // Carosello categorie (chip 24 r14.5, testo 17 light) da x 11.
        Positioned(
          left: 0,
          right: 0,
          top: 183,
          height: 24,
          child: ListView.separated(
            controller: _caroselloCtrl,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 11),
            itemCount: categorie.length,
            separatorBuilder: (_, __) => const SizedBox(width: 7),
            itemBuilder: (_, i) => _chipCategoria(categorie[i]),
          ),
        ),
        // "swipe" + indicatore di pagina a y 213–220.
        Positioned(
          left: 0,
          right: 0,
          top: 213,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('swipe',
                  style: _stile(10, peso: FontWeight.w300, ls: 0)),
              const SizedBox(width: 3),
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Row(
                  children: [
                    for (var i = 0; i < categorie.length; i++) ...[
                      if (i > 0) const SizedBox(width: 3),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: i == _paginaCarosello ? 27 : 4,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: 233,
          child: Center(child: Text('Prezzo', style: _stile(29))),
        ),
        // Barra prezzo 323×24 r17.5 a (35,272), bianco 20%.
        Positioned(
          left: 35,
          top: 272,
          width: 323,
          height: 24,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0x33D9D9D9),
              border: Border.all(color: const Color(0x2EFFFFFF)),
              borderRadius: BorderRadius.circular(17.5),
            ),
            child: Row(
              children: [
                // Scomparti NON uguali: nel CSS i centri dei simboli stanno a
                // 21.5, 82, 141, 206 e 286 dal bordo della barra, cioè i
                // gruppi più lunghi occupano più spazio. Con cinque parti
                // uguali "$$$$" e "$$$$$" finivano fuori asse (doc correzioni
                // 19/09).
                for (var p = 1; p <= _livelliPrezzo; p++)
                  Expanded(
                    flex: _pesiPrezzo[p - 1],
                    child: _segmentoPrezzo(p),
                  ),
              ],
            ),
          ),
        ),
        // "Elimina filtri" (38% se non c'è niente da eliminare).
        Positioned(
          left: 45,
          top: 328,
          width: 141,
          height: 35,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _haFiltri
                ? () {
                    _scelte.clear();
                    _prezzo = null;
                    _emit();
                  }
                : null,
            child: Center(
              child: Text(
                'Elimina filtri',
                style: _stile(20,
                    colore: _haFiltri ? Colors.white : const Color(0x61FFFFFF)),
              ),
            ),
          ),
        ),
        // "Mostra N risultati" 167×35 r17.5 a (188,328).
        Positioned(
          left: 188,
          top: 328,
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 167,
              height: 35,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0x00FFFFFF), Color(0x5E0066FF)],
                ),
                border: Border.all(color: const Color(0x59FFFFFF)),
                borderRadius: BorderRadius.circular(17.5),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  _count == 1 ? 'Mostra 1 risultato' : 'Mostra $_count risultati',
                  style: _stile(20),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _chipCategoria(String nome) {
    final bool scelta = _scelte.contains(nome);
    return GestureDetector(
      onTap: () {
        if (!_scelte.remove(nome)) _scelte.add(nome);
        _emit();
      },
      child: Stack(
        children: [
          // Scelta: `#FFFFFF → #004DFF` (84%) al 50%; le altre: bianco 30%
          // → blu 30% (73%), col testo al 50%.
          Positioned.fill(
            child: Opacity(
              opacity: scelta ? 0.5 : 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: scelta
                      ? const LinearGradient(
                          colors: [Color(0xFFFFFFFF), Color(0xFF004DFF)],
                          stops: [0, 0.8413],
                        )
                      : const LinearGradient(
                          colors: [Color(0x4DFFFFFF), Color(0x4D0900FF)],
                          stops: [0, 0.7308],
                        ),
                  // Filo chiaro attorno alle chip, come nel Figma (doc
                  // correzioni 19/09: "i bordi presenti nel Figma").
                  border: Border.all(color: const Color(0x59FFFFFF)),
                  borderRadius: BorderRadius.circular(14.5),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 9),
            child: Center(
              widthFactor: 1,
              child: Opacity(
                opacity: scelta ? 1 : 0.5,
                child: Text(nome,
                    style: _stile(17, peso: FontWeight.w300, ls: 0)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _segmentoPrezzo(int livello) {
    final bool scelto = _prezzo == livello;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      // Ritoccare lo stesso livello toglie il filtro.
      onTap: () {
        _prezzo = scelto ? null : livello;
        _emit();
      },
      child: Center(
        child: Container(
          height: 24,
          padding: const EdgeInsets.symmetric(horizontal: 18.5),
          alignment: Alignment.center,
          decoration: scelto
              ? BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0x4DFFFFFF), Color(0x4D0900FF)],
                    stops: [0, 0.7308],
                  ),
                  border: Border.all(color: const Color(0x59FFFFFF)),
                  borderRadius: BorderRadius.circular(14.5),
                )
              : null,
          child: Opacity(
            opacity: scelto ? 1 : 0.5,
            // Icona ufficiale del dollaro (doc correzioni 18/09), ripetuta
            // quanto il livello: il testo "$$$$$" non ci stava nel segmento.
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < livello; i++) ...[
                  if (i > 0) const SizedBox(width: 2),
                  SvgPicture.asset(
                    ImageConstant.imgDollaroFiltro,
                    width: 8,
                    height: 14,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Data model ───────────────────────────────────────────────────────────────

class _NearbyData {
  final List<LocaleModel> clubs;
  final int raggio;
  final double? lat;
  final double? lng;
  final bool locationAvailable;
  final bool gpsAttempted;

  _NearbyData({
    required this.clubs,
    required this.raggio,
    required this.lat,
    required this.lng,
    this.locationAvailable = true,
    this.gpsAttempted = false,
  });
}
