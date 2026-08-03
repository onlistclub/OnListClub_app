import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../../core/models/citta_model.dart';
import '../../core/models/locale_model.dart';
import '../../core/services/club_service.dart';
import '../../core/services/location_service.dart';
import '../../core/services/navigator_service.dart';
import '../../core/services/user_profile_manager.dart';
import '../../routes/app_routes.dart';
import '../../core/services/analytics_service.dart';
import '../../core/utils/analytics_mixin.dart';
import '../../widgets/custom_top_bar.dart';
import '../../widgets/shared_footer.dart';
import '../../widgets/shimmer_loading.dart';
import '../../widgets/staggered_item.dart';
import '../../widgets/image_fallback.dart';
import '../../theme/onlist_colors.dart';

enum _SortMode { distanza, popolarita }

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
  // subito gli ultimi dati (niente spinner/ricaricamento a schermo intero),
  // mentre un refresh silenzioso in background li aggiorna.
  static _NearbyData? _cachedData;

  /// Ultimi dati mostrati. La UI legge SEMPRE da qui, non da un `FutureBuilder`:
  /// assegnare un future nuovo riportava lo snapshot a `waiting` per un frame,
  /// quindi alla riapertura lo scheletro lampeggiava e la lista si ricostruiva
  /// da zero (le entrate `StaggeredItem` ripartivano) — il "saltino".
  /// Null = non abbiamo ancora nulla da mostrare → scheletro.
  _NearbyData? _data;

  /// Il caricamento corrente è fallito e non abbiamo dati da mostrare.
  bool _loadError = false;

  /// Marker monotonico dei caricamenti: scarta le risposte ormai obsolete
  /// (es. cambio città mentre il load precedente è ancora in volo).
  int _loadSeq = 0;
  String _searchQuery = '';
  _SortMode _sortMode = _SortMode.distanza;
  final Set<String> _selectedGeneri = {};
  final Set<String> _selectedCitta = {};
  int? _selectedPrezzo; // null = tutti, 1/2/3 = €/€€/€€€
  CittaModel?
      _customCity; // città cercata manualmente: ha priorità su GPS/saved

  // ── Barra di ricerca unificata ─────────────────────────────────────────────
  // Un solo campo cerca sia locali (filtro client-side sulla lista già
  // caricata) sia città (query su Supabase, ricentra la ricerca).
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  Timer? _cityDebounce;
  List<CittaModel> _cityResults = [];
  bool _cityLoading = false;
  // Marker monotonico per scartare risposte di chiamate ormai obsolete
  // (es. utente digita "mil" mentre "mi" è ancora in volo).
  int _citySeq = 0;

  // ── Fallback ricerca locali (BUG A) ─────────────────────────────────────────
  // Quando la ricerca nella zona corrente è VUOTA, si allarga per nome a TUTTE
  // le città in due sezioni. Compaiono solo in quel caso (vedi _buildEmptyOrFallback).
  List<LocaleModel> _fbStrong = []; // "Forse stai cercando" (match per nome)
  List<LocaleModel> _fbRelated = []; // "Altri in linea" (stessa zona dei match)
  bool _fbLoading = false;
  int _fbSeq = 0;
  String? _fbQuery; // query per cui il fallback corrente è calcolato/in corso
  Timer? _fbDebounce;

  @override
  void initState() {
    super.initState();
    // Funnel: apertura della schermata di ricerca (source 'open').
    AnalyticsService.logSearch(source: 'open');
    if (_cachedData != null) {
      // Riapertura: dati subito dalla cache (nessun ricaricamento visibile),
      // poi refresh silenzioso in background — che sostituisce i dati sul posto,
      // senza passare per lo scheletro.
      _data = _cachedData;
      _reload(showSkeleton: false);
    } else {
      // Tempo di caricamento della ricerca: quando i dati (posizione + locali)
      // sono pronti la prima volta. reportLoadTime è guardato → una sola volta,
      // per questo lo chiediamo solo qui e non sui refresh/cambi raggio.
      _reload(reportLoad: true);
    }
  }

  /// Ricarica i dati. Con `showSkeleton: false` la lista attuale resta a video
  /// finché i nuovi dati non sono pronti (riaperture e refresh silenziosi);
  /// con `true` si torna allo scheletro, giusto quando il contenuto cambia
  /// davvero (nuova città, nuovo raggio, "Riprova").
  Future<void> _reload({
    bool showSkeleton = true,
    bool reportLoad = false,
  }) async {
    _loadSeq++;
    final mySeq = _loadSeq;
    // Il setState serve solo se c'è davvero qualcosa da azzerare: al primo load
    // (da initState) siamo già in questo stato e setState lì non è ammesso.
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
      });
      if (reportLoad) reportLoadTime('load_time_ricerca');
    } catch (e) {
      debugPrint('[NearbyClubs] caricamento fallito: $e');
      if (!mounted || mySeq != _loadSeq) return;
      setState(() => _loadError = true);
    }
  }

  @override
  void dispose() {
    _cityDebounce?.cancel();
    _fbDebounce?.cancel();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  /// Aggiorna il filtro locali e, in parallelo, cerca città corrispondenti.
  void _onSearchChanged(String value) {
    setState(() => _searchQuery = value);

    _cityDebounce?.cancel();
    final query = value.trim();
    if (query.length < 2) {
      setState(() {
        _cityResults = [];
        _cityLoading = false;
      });
      return;
    }

    _citySeq++;
    final mySeq = _citySeq;
    setState(() => _cityLoading = true);
    _cityDebounce = Timer(const Duration(milliseconds: 300), () async {
      try {
        final r = await LocationService.searchCitta(query);
        if (!mounted || mySeq != _citySeq) return;
        setState(() {
          _cityResults = r;
          _cityLoading = false;
        });
      } catch (e) {
        debugPrint('[NearbyClubs] searchCitta fallita: $e');
        if (!mounted || mySeq != _citySeq) return;
        setState(() {
          _cityResults = [];
          _cityLoading = false;
        });
      }
    });
  }

  /// Ricentra la ricerca sulla città scelta e svuota il campo: la città
  /// diventa il contesto (chip in alto), non un filtro testuale sui nomi.
  void _selectCity(CittaModel citta) {
    // Funnel: ricerca attiva di un locale per città.
    AnalyticsService.logSearch(query: citta.nomeCitta, source: 'city');
    _cityDebounce?.cancel();
    _citySeq++;
    _searchCtrl.clear();
    _searchFocus.unfocus();
    setState(() {
      _customCity = citta;
      _searchQuery = '';
      _cityResults = [];
      _cityLoading = false;
    });
    _reload();
  }

  void _clearCity() {
    setState(() => _customCity = null);
    _reload();
  }

  /// Accende/spegne il GPS come sorgente della ricerca. Acceso, la città
  /// cercata a mano viene scartata: altrimenti avrebbe comunque la priorità
  /// in `_load()` e il GPS non avrebbe alcun effetto visibile.
  void _toggleGps(bool enable) {
    LocationService.isGpsForced = enable;
    if (enable) setState(() => _customCity = null);
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
    String? locationLabel;
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
          locationLabel = 'GPS';
        } else {
          debugPrint('[NearbyClubs] GPS permesso negato: $permission');
        }
      } catch (e) {
        debugPrint('[NearbyClubs] tryGps fallito: $e');
      }
    }

    if (_customCity != null && _customCity!.lat != null) {
      // Priorità 1: città cercata manualmente nell'app
      lat = _customCity!.lat;
      lng = _customCity!.lng;
      locationLabel = _customCity!.nomeCitta;
    } else if (isGpsForced) {
      // Priorità 2: GPS forzato. Se il GPS fallisce, fallback su saved.
      await tryGps();
      if (lat == null) {
        final savedCity = await LocationService.getSavedLocation();
        if (savedCity?.lat != null) {
          lat = savedCity!.lat;
          lng = savedCity.lng;
          locationLabel = savedCity.nomeCitta;
        }
      }
    } else {
      // GPS disattivato: la ricerca si basa su una città.
      // Priorità 3: città salvata manualmente nelle impostazioni
      final savedCity = await LocationService.getSavedLocation();
      if (savedCity?.lat != null) {
        lat = savedCity!.lat;
        lng = savedCity.lng;
        locationLabel = savedCity.nomeCitta;
      }

      // Priorità 4: nessuna città scelta → deduciamo la più vicina dall'ultima
      // posizione GPS in cache. Non chiediamo una nuova posizione: col toggle
      // spento il GPS non va interrogato.
      if (lat == null) {
        final cached = await LocationService.getCachedGpsPosition();
        if (cached != null) {
          final nearest =
              await LocationService.getNearestCitta(cached.lat, cached.lng);
          if (nearest?.lat != null) {
            lat = nearest!.lat;
            lng = nearest.lng;
            locationLabel = nearest.nomeCitta;
          }
        }
      }
    }

    // Se nessuna sorgente di posizione è disponibile, mostriamo comunque
    // i locali più popolari come fallback con etichetta esplicita.
    final locationAvailable = lat != null && lng != null;
    if (!locationAvailable) {
      locationLabel = 'Locali più popolari';
    }

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
      locationLabel: locationLabel,
      locationAvailable: locationAvailable,
      gpsAttempted: gpsAttempted,
    );
    _cachedData = data; // alimenta la cache per le riaperture
    return data;
  }

  // ── Fallback ricerca (BUG A) ────────────────────────────────────────────────

  /// Se la ricerca nella zona corrente è vuota, allarga la ricerca per nome a
  /// TUTTE le città (una sola volta per query). Chiamata da `build`: la fetch è
  /// dietro un debounce (Timer), quindi il `setState` avviene fuori dal build.
  void _maybeLoadFallback(String query, _NearbyData data) {
    if (_fbQuery == query) return; // già calcolato o in corso per questa query
    _fbQuery = query;
    _fbSeq++;
    final mySeq = _fbSeq;
    _fbLoading = true;
    _fbStrong = [];
    _fbRelated = [];
    // Debounce come per la ricerca città: niente query DB a ogni tasto.
    _fbDebounce?.cancel();
    _fbDebounce = Timer(
      const Duration(milliseconds: 300),
      () => _loadFallback(query, data, mySeq),
    );
  }

  Future<void> _loadFallback(String query, _NearbyData data, int mySeq) async {
    try {
      // Sezione 1: match per nome su tutte le città (ilike '%query%').
      final strong = await ClubService.searchClubsByName(query);
      final strongIds = strong.map((c) => c.id).toSet();
      // Sezione 2: altri locali nella stessa zona dei match (stesse città),
      // esclusi quelli già mostrati sopra.
      final cityIds =
          strong.map((c) => c.idCitta).whereType<String>().toSet().toList();
      final sameZone = await ClubService.getClubsInCities(cityIds);
      final related = <LocaleModel>[
        for (final c in sameZone)
          if (!strongIds.contains(c.id)) c,
      ];
      if (!mounted || mySeq != _fbSeq) return;
      setState(() {
        _fbStrong = _sortByProximity(strong, data.lat, data.lng);
        _fbRelated = _sortByProximity(related, data.lat, data.lng);
        _fbLoading = false;
      });
    } catch (e) {
      debugPrint('[NearbyClubs] fallback ricerca fallito: $e');
      if (!mounted || mySeq != _fbSeq) return;
      setState(() => _fbLoading = false);
    }
  }

  /// Ordina per vicinanza all'utente. Locale senza coordinate → in fondo;
  /// senza posizione utente → ripiega su famosità.
  List<LocaleModel> _sortByProximity(
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

  // ── Filtering ──────────────────────────────────────────────────────────────

  /// Predicato di filtro condiviso: lo usa sia la lista sia il popup filtri
  /// per contare i locali risultanti ("Mostra N locali") senza duplicare le
  /// regole. Non ordina: l'ordinamento resta responsabilità del chiamante.
  static List<LocaleModel> _applyFilters(
    List<LocaleModel> clubs, {
    required String searchQuery,
    required Set<String> generi,
    required Set<String> citta,
    required int? prezzo,
  }) {
    return clubs.where((c) {
      // Testo
      if (searchQuery.isNotEmpty) {
        final q = searchQuery.toLowerCase();
        if (!c.nome.toLowerCase().contains(q) &&
            !(c.nomeCitta?.toLowerCase().contains(q) ?? false)) {
          return false;
        }
      }
      // Genere
      if (generi.isNotEmpty && !c.generiMusicali.any(generi.contains)) {
        return false;
      }
      // Città
      if (citta.isNotEmpty && !citta.contains(c.nomeCitta)) return false;
      // Prezzo
      if (prezzo != null && c.prezzoIndicativo != prezzo) return false;
      return true;
    }).toList();
  }

  List<LocaleModel>? _filteredCache;
  String? _filteredCacheKey;

  List<LocaleModel> _filtered(List<LocaleModel> clubs) {
    final key =
        '${identityHashCode(clubs)}|$_searchQuery|${_selectedGeneri.join(',')}'
        '|${_selectedCitta.join(',')}|$_selectedPrezzo|${_sortMode.index}';
    if (key == _filteredCacheKey && _filteredCache != null) {
      return _filteredCache!;
    }

    var list = _applyFilters(
      clubs,
      searchQuery: _searchQuery,
      generi: _selectedGeneri,
      citta: _selectedCitta,
      prezzo: _selectedPrezzo,
    );

    if (_sortMode == _SortMode.popolarita) {
      list.sort((a, b) => b.famosita.compareTo(a.famosita));
    }

    _filteredCache = list;
    _filteredCacheKey = key;
    return list;
  }

  bool get _hasActiveFilters => _activeFilterCount > 0;

  /// Numero di filtri attivi, mostrato come badge sul bottone "Filtri":
  /// ogni genere e ogni città contano uno, il prezzo conta uno in tutto.
  int get _activeFilterCount =>
      _selectedGeneri.length +
      _selectedCitta.length +
      (_selectedPrezzo != null ? 1 : 0);

  /// Apre il popup dei filtri (genere, città, prezzo). I filtri si applicano
  /// live a ogni tocco: chiudere il popup con lo swipe non perde le scelte.
  Future<void> _showFiltersSheet(_NearbyData data) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: OnlistColors.black,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (_) => _FiltersSheet(
        clubs: data.clubs,
        allGeneri: data.allGeneri,
        allCitta: data.allCitta,
        searchQuery: _searchQuery,
        initialGeneri: _selectedGeneri,
        initialCitta: _selectedCitta,
        initialPrezzo: _selectedPrezzo,
        onChanged: (generi, citta, prezzo) {
          setState(() {
            _selectedGeneri
              ..clear()
              ..addAll(generi);
            _selectedCitta
              ..clear()
              ..addAll(citta);
            _selectedPrezzo = prezzo;
          });
        },
      ),
    );
  }

  // ── Radius dialog ──────────────────────────────────────────────────────────

  double _zoomForRadius(int km) {
    if (km <= 3) return 13;
    if (km <= 8) return 11;
    if (km <= 15) return 10;
    return 9;
  }

  Future<void> _showRadiusDialog(
    int currentRaggio, {
    double? lat,
    double? lng,
  }) async {
    int tempRaggio = currentRaggio;
    final mapCtrl = (lat != null && lng != null) ? MapController() : null;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Dialog(
          backgroundColor: OnlistColors.black,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          // Dialog + ConstrainedBox avoids AlertDialog's IntrinsicWidth,
          // which crashes when FlutterMap is inside (no intrinsic width impl).
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cambia raggio',
                    style: TextStyle(
                        fontFamily: 'Helvetica',
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 18),
                  ),
                  const SizedBox(height: 16),
                  // Mappa con cerchio raggio
                  if (lat != null && lng != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox(
                        height: 160,
                        width: double.infinity,
                        child: FlutterMap(
                          mapController: mapCtrl,
                          options: MapOptions(
                            initialCenter: LatLng(lat, lng),
                            initialZoom: _zoomForRadius(tempRaggio),
                            interactionOptions: const InteractionOptions(
                              flags: InteractiveFlag.none,
                            ),
                          ),
                          children: [
                            // Basemap CARTO "dark_matter": look pulito e
                            // minimale, coerente col tema scuro dell'app.
                            // Niente API key; l'attribuzione sotto è richiesta
                            // dalla licenza CARTO/OpenStreetMap.
                            TileLayer(
                              urlTemplate:
                                  'https://basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
                              subdomains: const ['a', 'b', 'c', 'd'],
                              retinaMode:
                                  RetinaMode.isHighDensity(context),
                              userAgentPackageName: 'com.onlist.app',
                            ),
                            CircleLayer(
                              circles: [
                                CircleMarker(
                                  point: LatLng(lat, lng),
                                  radius: tempRaggio * 1000.0,
                                  useRadiusInMeter: true,
                                  color: OnlistColors.blueElectric
                                      .withValues(alpha: 0.18),
                                  borderColor: OnlistColors.blueElectric
                                      .withValues(alpha: 0.7),
                                  borderStrokeWidth: 2,
                                ),
                              ],
                            ),
                            MarkerLayer(
                              markers: [
                                Marker(
                                  point: LatLng(lat, lng),
                                  width: 24,
                                  height: 24,
                                  child: const Icon(
                                    Icons.location_on,
                                    color: OnlistColors.blueElectric,
                                    size: 24,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '© OpenStreetMap, © CARTO',
                      style: TextStyle(
                        fontFamily: 'Helvetica',
                        fontSize: 9,
                        color: Colors.white24,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Center(
                    child: Text(
                      '$tempRaggio km',
                      style: TextStyle(
                        fontFamily: 'Helvetica',
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  SliderTheme(
                    data: SliderTheme.of(ctx).copyWith(
                      activeTrackColor: OnlistColors.blueElectric,
                      inactiveTrackColor: Colors.white24,
                      thumbColor: OnlistColors.blueElectric,
                      overlayColor:
                          OnlistColors.blueElectric.withValues(alpha: 0.1),
                      trackHeight: 3,
                    ),
                    child: Slider(
                      min: 2,
                      max: 50,
                      divisions: 48,
                      value: tempRaggio.toDouble(),
                      onChanged: (v) {
                        setS(() => tempRaggio = v.round());
                        if (lat != null && lng != null) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            try {
                              mapCtrl!.move(
                                LatLng(lat, lng),
                                _zoomForRadius(tempRaggio),
                              );
                            } catch (_) {}
                          });
                        }
                      },
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('2 km',
                          style: TextStyle(
                              fontFamily: 'Helvetica',
                              fontSize: 11,
                              color: Colors.white38)),
                      Text('50 km',
                          style: TextStyle(
                              fontFamily: 'Helvetica',
                              fontSize: 11,
                              color: Colors.white38)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: Text('Annulla',
                            style: TextStyle(
                                fontFamily: 'Helvetica',
                                color: Colors.white54)),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: OnlistColors.blueElectric,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(7)),
                        ),
                        child: Text('Applica',
                            style: TextStyle(
                                fontFamily: 'Helvetica',
                                color: Colors.white,
                                fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (confirmed == true) {
      await UserProfileManager().saveRaggioKm(tempRaggio);
      _reload();
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isGpsForced = LocationService.isGpsForced;

    return Scaffold(
      backgroundColor: OnlistColors.black,
      // Footer flottante: il gradiente si estende dietro la capsula così sotto
      // non resta la fascia nera dello Scaffold.
      extendBody: true,
      // Footer: unica e globale, montata da RootShell (non qui).
      body: DecoratedBox(
        decoration:
            const BoxDecoration(gradient: OnlistColors.screenBackground),
        child: SafeArea(
          bottom: false,
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── CustomTopBar ──
            // Icona ricerca mostrata anche qui per uniformità con le altre
            // schermate: no-op perché si è già nella schermata di ricerca.
            CustomTopBar(onSearchTap: () {}),
            // Subheader with back button and chips
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: NavigatorService.goBack,
                    child: const Icon(Icons.arrow_back_ios_new,
                        color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Builder(
                        builder: (_) {
                          final data = _data;
                          final raggio = data?.raggio ?? 20;
                          final locLabel = data?.locationLabel;
                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Chip raggio
                              GestureDetector(
                                onTap: () => _showRadiusDialog(
                                  raggio,
                                  lat: data?.lat,
                                  lng: data?.lng,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: OnlistColors.blueElectric
                                        .withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(7),
                                    border: Border.all(
                                      color: OnlistColors.blueElectric
                                          .withValues(alpha: 0.5),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        '$raggio km',
                                        style: TextStyle(
                                          fontFamily: 'Helvetica',
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: OnlistColors.blueElectric,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      const Icon(Icons.tune,
                                          color: OnlistColors.blueElectric, size: 12),
                                    ],
                                  ),
                                ),
                              ),
                              // Chip sorgente posizione
                              if (locLabel != null) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: OnlistColors.blueDeep,
                                    borderRadius: BorderRadius.circular(7),
                                    border: Border.all(
                                        color: OnlistColors.blueElectric.withValues(alpha: 0.35)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        locLabel,
                                        style: TextStyle(
                                          fontFamily: 'Helvetica',
                                          fontSize: 11,
                                          color: Colors.white54,
                                        ),
                                      ),
                                      // La città scelta a mano si toglie da qui
                                      // e si torna alla sorgente automatica.
                                      if (_customCity != null) ...[
                                        const SizedBox(width: 4),
                                        GestureDetector(
                                          behavior: HitTestBehavior.opaque,
                                          onTap: _clearCity,
                                          child: const Icon(Icons.close,
                                              color: Colors.white54, size: 12),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                              // Toggle GPS: acceso ricentra sulla posizione
                              // reale, spento riporta la ricerca sulla città.
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () => _toggleGps(!isGpsForced),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isGpsForced
                                        ? OnlistColors.blueElectric
                                            .withValues(alpha: 0.18)
                                        : OnlistColors.blueDeep,
                                    borderRadius: BorderRadius.circular(7),
                                    border: Border.all(
                                      color: isGpsForced
                                          ? OnlistColors.blueElectric
                                          : OnlistColors.blueElectric
                                              .withValues(alpha: 0.35),
                                      width: isGpsForced ? 1.5 : 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        isGpsForced
                                            ? Icons.close
                                            : Icons.my_location,
                                        color: Colors.white,
                                        size: 12,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        isGpsForced ? 'Rimuovi GPS' : 'Usa GPS',
                                        style: TextStyle(
                                          fontFamily: 'Helvetica',
                                          fontSize: 10,
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Search bar unificata (locali + città) ─────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: OnlistColors.blueDeep,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: OnlistColors.blueElectric.withValues(alpha: 0.35)),
                ),
                child: TextField(
                  controller: _searchCtrl,
                  focusNode: _searchFocus,
                  textInputAction: TextInputAction.search,
                  style: TextStyle(
                      fontFamily: 'Helvetica',
                      fontSize: 14,
                      color: Colors.white,
                      fontWeight: FontWeight.w500),
                  decoration: InputDecoration(
                    hintText: 'Cerca locale o città…',
                    hintStyle: TextStyle(
                        fontFamily: 'Helvetica',
                        fontSize: 14,
                        color: Colors.white38),
                    prefixIcon: const Icon(Icons.search,
                        color: Colors.white38, size: 20),
                    suffixIcon: _searchQuery.isEmpty
                        ? null
                        : GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              _searchCtrl.clear();
                              _onSearchChanged('');
                            },
                            child: const Icon(Icons.close,
                                color: Colors.white38, size: 18),
                          ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onChanged: _onSearchChanged,
                  // Funnel: ricerca attiva quando l'utente conferma il testo
                  // (azione "cerca" della tastiera), non a ogni tasto.
                  onSubmitted: (value) {
                    final q = value.trim();
                    if (q.isNotEmpty) {
                      AnalyticsService.logSearch(query: q, source: 'submit');
                    }
                  },
                ),
              ),
            ),

            // ── Suggerimenti città ────────────────────────────────────────
            // Compaiono sotto la barra mentre si scrive: "Jesolo" propone di
            // ricentrare la ricerca su Jesolo, mentre la lista sotto continua
            // a filtrare i locali per nome.
            _buildCitySuggestions(),

            // ── Sort chips ─────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: [
                  _SortChip(
                    label: 'Più vicino',
                    icon: Icons.near_me,
                    selected: _sortMode == _SortMode.distanza,
                    onTap: () => setState(() => _sortMode = _SortMode.distanza),
                  ),
                  const SizedBox(width: 8),
                  _SortChip(
                    label: 'Più popolare',
                    icon: Icons.local_fire_department,
                    selected: _sortMode == _SortMode.popolarita,
                    onTap: () =>
                        setState(() => _sortMode = _SortMode.popolarita),
                  ),
                  const Spacer(),
                  // Bottone filtri: raccoglie genere/città/prezzo in un popup
                  // così non occupano tre righe fisse sopra la lista.
                  // Attivo solo a dati pronti: senza `data` non sappiamo quali
                  // generi e città proporre.
                  Builder(
                    builder: (_) {
                      final data = _data;
                      return _FiltersButton(
                        count: _activeFilterCount,
                        onTap:
                            data == null ? null : () => _showFiltersSheet(data),
                      );
                    },
                  ),
                ],
              ),
            ),

            // ── Filtri + lista ───────────────────────────────────────────
            // Legge da `_data`: finché ci sono dati la lista resta a video anche
            // durante un refresh, così non lampeggia lo scheletro (vedi _reload).
            Expanded(
              child: Builder(
                builder: (context) {
                  final data = _data;
                  if (data == null) {
                    if (!_loadError) return const _NearbySkeleton();
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Errore nel caricamento',
                            style: TextStyle(
                                fontFamily: 'Helvetica',
                                color: Colors.white54),
                          ),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: () => _reload(),
                            child: const Text(
                              'Riprova',
                              style: TextStyle(
                                  fontFamily: 'Helvetica',
                                  color: OnlistColors.blueElectric),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  final filtered = _filtered(data.clubs);

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Banner non bloccante quando la posizione non è
                      // disponibile: l'utente vede comunque i locali più
                      // popolari ma capisce perché.
                      if (!data.locationAvailable)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: OnlistColors.blueDeep,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: OnlistColors.blueElectric.withValues(alpha: 0.35), width: 0.5),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.location_off,
                                  color: Colors.white54, size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  data.gpsAttempted
                                      ? 'Posizione non disponibile. Mostro i locali più popolari.'
                                      : 'Imposta la tua città per vedere i locali vicini.',
                                  style: const TextStyle(
                                    fontFamily: 'Helvetica',
                                    fontSize: 12,
                                    color: Colors.white70,
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: () => _reload(),
                                child: const Text(
                                  'Riprova',
                                  style: TextStyle(
                                    fontFamily: 'Helvetica',
                                    fontSize: 12,
                                    color: OnlistColors.blueElectric,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      // ── Lista locali ───────────────────────────────────
                      if (filtered.isEmpty)
                        Expanded(child: _buildEmptyOrFallback(data))
                      else
                        Expanded(
                          child: ListView.separated(
                            padding: EdgeInsets.fromLTRB(
                                12, 8, 12, 8 + SharedFooter.height),
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) => Container(
                              height: 0.5,
                              color: Colors.white.withValues(alpha: 0.08),
                              margin: const EdgeInsets.symmetric(vertical: 2),
                            ),
                            itemBuilder: (context, i) {
                              return StaggeredItem(
                                index: i,
                                child: _ClubListTile(
                                  club: filtered[i],
                                  userLat: data.lat,
                                  userLng: data.lng,
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }

  // ── Empty / fallback ricerca (BUG A) ────────────────────────────────────────

  /// Cosa mostrare quando la lista filtrata è vuota:
  /// - senza ricerca testuale → messaggio standard (filtri / raggio);
  /// - con ricerca testuale vuota nella zona → si allarga la ricerca a TUTTE le
  ///   città e si mostrano le due sezioni "Forse stai cercando" / "Altri in
  ///   linea con la tua ricerca".
  Widget _buildEmptyOrFallback(_NearbyData data) {
    final q = _searchQuery.trim();
    // Il fallback a due sezioni scatta SOLO quando l'unico vincolo è il testo
    // cercato. Con filtri genere/città/prezzo attivi resta il messaggio standard
    // (allargare a tutte le città ignorando quei filtri sarebbe incoerente).
    if (q.isEmpty || _hasActiveFilters) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            (_hasActiveFilters || q.isNotEmpty)
                ? 'Nessun locale corrisponde ai filtri.'
                : 'Nessun locale trovato nel raggio di ${data.raggio} km.',
            style: TextStyle(
                fontFamily: 'Helvetica', fontSize: 15, color: Colors.white54),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    // Zona corrente vuota → allarga la ricerca alle altre città (una volta).
    _maybeLoadFallback(q, data);

    if (_fbLoading) return const _NearbySkeleton();

    if (_fbStrong.isEmpty && _fbRelated.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Nessun locale trovato per “$q”.',
            style: TextStyle(
                fontFamily: 'Helvetica', fontSize: 15, color: Colors.white54),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView(
      padding: EdgeInsets.fromLTRB(12, 4, 12, 8 + SharedFooter.height),
      children: [
        if (_fbStrong.isNotEmpty) ...[
          _fallbackHeader('Forse stai cercando:'),
          for (var i = 0; i < _fbStrong.length; i++)
            StaggeredItem(
              index: i,
              child: _ClubListTile(
                club: _fbStrong[i],
                userLat: data.lat,
                userLng: data.lng,
              ),
            ),
        ],
        if (_fbRelated.isNotEmpty) ...[
          _fallbackHeader('Altri in linea con la tua ricerca:'),
          for (final c in _fbRelated)
            _ClubListTile(
              club: c,
              userLat: data.lat,
              userLng: data.lng,
            ),
        ],
      ],
    );
  }

  Widget _fallbackHeader(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 14, 2, 6),
        child: Text(
          text,
          style: TextStyle(
            fontFamily: 'Helvetica',
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      );

  // ── Suggerimenti città ─────────────────────────────────────────────────────

  /// Pannello dei suggerimenti città sotto la barra di ricerca.
  /// Vuoto (zero altezza) finché non c'è qualcosa da proporre, così non
  /// sottrae spazio alla lista dei locali nel caso normale.
  Widget _buildCitySuggestions() {
    if (_searchQuery.trim().length < 2) return const SizedBox.shrink();
    if (_cityLoading && _cityResults.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: SizedBox(
          height: 2,
          child: LinearProgressIndicator(
            backgroundColor: Colors.transparent,
            color: OnlistColors.blueElectric,
            minHeight: 2,
          ),
        ),
      );
    }
    if (_cityResults.isEmpty) {
      // Nessuna città/luogo reale corrisponde: lo diciamo esplicitamente invece
      // di proporre il testo digitato come città (era il bug: "Il muretto" —
      // un locale — veniva accettato come città).
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: OnlistColors.blueDeep,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: OnlistColors.blueElectric.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            const Icon(Icons.location_off, color: Colors.white38, size: 16),
            const SizedBox(width: 10),
            Text(
              'Nessuna città trovata',
              style: TextStyle(
                fontFamily: 'Helvetica',
                fontSize: 13,
                color: Colors.white54,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      constraints: const BoxConstraints(maxHeight: 180),
      decoration: BoxDecoration(
        color: OnlistColors.blueDeep,
        borderRadius: BorderRadius.circular(10),
        border:
            Border.all(color: OnlistColors.blueElectric.withValues(alpha: 0.35)),
      ),
      child: ListView.builder(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: _cityResults.length,
        itemBuilder: (_, i) {
          final c = _cityResults[i];
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _selectCity(c),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  const Icon(Icons.location_city,
                      color: OnlistColors.blueElectric, size: 16),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      c.nomeCitta,
                      style: TextStyle(
                        fontFamily: 'Helvetica',
                        fontSize: 14,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    'Cerca qui',
                    style: TextStyle(
                      fontFamily: 'Helvetica',
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: OnlistColors.blueElectric,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Bottone filtri ───────────────────────────────────────────────────────────

/// Apre il popup dei filtri. Il badge mostra quanti filtri sono attivi, così
/// l'utente sa che la lista è filtrata anche se i controlli non sono a video.
class _FiltersButton extends StatelessWidget {
  final int count;
  final VoidCallback? onTap;

  const _FiltersButton({required this.count, this.onTap});

  @override
  Widget build(BuildContext context) {
    final active = count > 0;
    return Opacity(
      opacity: onTap == null ? 0.4 : 1,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: active
                ? OnlistColors.blueElectric.withValues(alpha: 0.18)
                : OnlistColors.blueDeep,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(
              color: active
                  ? OnlistColors.blueElectric
                  : OnlistColors.blueElectric.withValues(alpha: 0.35),
              width: active ? 1.5 : 0.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.tune,
                  size: 14,
                  color: active ? OnlistColors.blueElectric : Colors.white38),
              const SizedBox(width: 5),
              Text(
                'Filtri',
                style: TextStyle(
                  fontFamily: 'Helvetica',
                  fontSize: 13,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                  color: active ? Colors.white : Colors.white54,
                ),
              ),
              if (active) ...[
                const SizedBox(width: 6),
                Container(
                  width: 16,
                  height: 16,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: OnlistColors.blueElectric,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontFamily: 'Helvetica',
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Popup filtri ─────────────────────────────────────────────────────────────

/// Bottom sheet con genere musicale, città e prezzo. Le scelte si applicano
/// live via [onChanged]: chiudere con lo swipe non le perde. Il bottone in
/// fondo mostra quanti locali restano, per dare un'idea dell'effetto prima di
/// tornare alla lista.
class _FiltersSheet extends StatefulWidget {
  final List<LocaleModel> clubs;
  final List<String> allGeneri;
  final List<String> allCitta;
  final String searchQuery;
  final Set<String> initialGeneri;
  final Set<String> initialCitta;
  final int? initialPrezzo;
  final void Function(Set<String> generi, Set<String> citta, int? prezzo)
      onChanged;

  const _FiltersSheet({
    required this.clubs,
    required this.allGeneri,
    required this.allCitta,
    required this.searchQuery,
    required this.initialGeneri,
    required this.initialCitta,
    required this.initialPrezzo,
    required this.onChanged,
  });

  @override
  State<_FiltersSheet> createState() => _FiltersSheetState();
}

class _FiltersSheetState extends State<_FiltersSheet> {
  late final Set<String> _generi = {...widget.initialGeneri};
  late final Set<String> _citta = {...widget.initialCitta};
  late int? _prezzo = widget.initialPrezzo;

  void _emit() {
    setState(() {});
    widget.onChanged(_generi, _citta, _prezzo);
  }

  int get _count => _NearbyClubsScreenState._applyFilters(
        widget.clubs,
        searchQuery: widget.searchQuery,
        generi: _generi,
        citta: _citta,
        prezzo: _prezzo,
      ).length;

  bool get _hasAny => _generi.isNotEmpty || _citta.isNotEmpty || _prezzo != null;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Maniglia di trascinamento
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(1000),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 10),
              child: Row(
                children: [
                  Text(
                    'Filtri',
                    style: TextStyle(
                      fontFamily: 'Helvetica',
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  if (_hasAny)
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        _generi.clear();
                        _citta.clear();
                        _prezzo = null;
                        _emit();
                      },
                      child: Text(
                        'Azzera',
                        style: TextStyle(
                          fontFamily: 'Helvetica',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: OnlistColors.blueElectric,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _section(
                      'Prezzo',
                      [1, 2, 3]
                          .map((p) => _chip(
                                label: '€' * p,
                                selected: _prezzo == p,
                                // Ritocco sullo stesso prezzo = nessun filtro:
                                // è un gruppo a scelta singola, non cumulativo.
                                onTap: () {
                                  _prezzo = _prezzo == p ? null : p;
                                  _emit();
                                },
                              ))
                          .toList(),
                    ),
                    if (widget.allGeneri.isNotEmpty)
                      _section(
                        'Genere musicale',
                        widget.allGeneri
                            .map((g) => _chip(
                                  label: g,
                                  icon: Icons.music_note,
                                  selected: _generi.contains(g),
                                  onTap: () {
                                    if (!_generi.remove(g)) _generi.add(g);
                                    _emit();
                                  },
                                ))
                            .toList(),
                      ),
                    if (widget.allCitta.length > 1)
                      _section(
                        'Città',
                        widget.allCitta
                            .map((c) => _chip(
                                  label: c,
                                  icon: Icons.location_city,
                                  selected: _citta.contains(c),
                                  onTap: () {
                                    if (!_citta.remove(c)) _citta.add(c);
                                    _emit();
                                  },
                                ))
                            .toList(),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: OnlistColors.blueElectric,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    _count == 1 ? 'Mostra 1 locale' : 'Mostra $_count locali',
                    style: TextStyle(
                      fontFamily: 'Helvetica',
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(String title, List<Widget> chips) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        Text(
          title,
          style: TextStyle(
            fontFamily: 'Helvetica',
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.white54,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: chips),
      ],
    );
  }

  Widget _chip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    IconData? icon,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? OnlistColors.blueElectric.withValues(alpha: 0.18)
              : OnlistColors.blueDeep,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
            color: selected
                ? OnlistColors.blueElectric
                : OnlistColors.blueElectric.withValues(alpha: 0.35),
            width: selected ? 1.5 : 0.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon,
                  size: 13,
                  color: selected ? OnlistColors.blueElectric : Colors.white),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Helvetica',
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Sort chip ────────────────────────────────────────────────────────────────

class _SortChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _SortChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? OnlistColors.blueElectric.withValues(alpha: 0.18)
              : OnlistColors.blueDeep,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
            color: selected ? OnlistColors.blueElectric : OnlistColors.blueElectric.withValues(alpha: 0.35),
            width: selected ? 1.5 : 0.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 14,
                color: selected ? OnlistColors.blueElectric : Colors.white),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Helvetica',
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Skeleton di caricamento ──────────────────────────────────────────────────
// Scheletro della lista locali (thumbnail + due/tre righe) mentre i dati e la
// posizione vengono risolti. Un solo controller via `Shimmer`.
class _NearbySkeleton extends StatelessWidget {
  const _NearbySkeleton();

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: 7,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, __) => Row(
          children: const [
            ShimmerBox(width: 64, height: 64, radius: 10),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShimmerBox(width: 150, height: 16, radius: 6),
                  SizedBox(height: 8),
                  ShimmerBox(width: 200, height: 12, radius: 6),
                  SizedBox(height: 6),
                  ShimmerBox(width: 110, height: 11, radius: 6),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Club list tile ───────────────────────────────────────────────────────────

/// Avvolge [child] in un `Hero` solo se [enabled] (es. esiste una foto reale),
/// così le card senza foto non "volano" uno stock placeholder verso un'icona.
Widget _heroWrap({
  required String tag,
  required bool enabled,
  required Widget child,
}) =>
    enabled ? Hero(tag: tag, child: child) : child;

class _ClubListTile extends StatelessWidget {
  final LocaleModel club;
  final double? userLat;
  final double? userLng;

  const _ClubListTile({
    required this.club,
    required this.userLat,
    required this.userLng,
  });

  String? _distanceLabel() {
    if (userLat == null ||
        userLng == null ||
        club.lat == null ||
        club.lng == null) return null;
    final dist =
        ClubService.distanceKm(userLat!, userLng!, club.lat!, club.lng!);
    return dist < 1
        ? '${(dist * 1000).round()} m'
        : '${dist.toStringAsFixed(1)} km';
  }

  @override
  Widget build(BuildContext context) {
    final distLabel = _distanceLabel();
    return GestureDetector(
      onTap: () => NavigatorService.pushNamed(
        AppRoutes.clubDetailScreen,
        arguments: club,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            // Club image: morph Hero verso il dettaglio (solo se c'è una foto reale)
            _heroWrap(
              tag: 'club-img-${club.id}',
              enabled: club.fotoUrl != null,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 64,
                  height: 64,
                  child: club.fotoUrl != null
                      ? CachedNetworkImage(
                          imageUrl: club.fotoUrl!,
                          fit: BoxFit.cover,
                          memCacheWidth: 192,
                          memCacheHeight: 192,
                          // Niente dissolvenza da 500ms (default): la schermata
                          // si ricrea a ogni apertura e le foto già in cache
                          // ri-sfumavano ogni volta, sembrando un ricaricamento.
                          fadeInDuration: Duration.zero,
                          errorWidget: (_, __, ___) =>
                              ImageFallback(seed: club.id),
                        )
                      : ImageFallback(seed: club.id),
                ),
              ),
            ),
            const SizedBox(width: 14),
            // Club info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    club.nome,
                    style: TextStyle(
                      fontFamily: 'Helvetica',
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  if (club.indirizzoCompleto.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      club.indirizzoCompleto,
                      style: TextStyle(
                          fontFamily: 'Helvetica',
                          fontSize: 12,
                          color: Colors.white54),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (club.generiString.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      club.generiString,
                      style: TextStyle(
                          fontFamily: 'Helvetica',
                          fontSize: 11,
                          color: OnlistColors.blueElectric),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            // Right: distance + popularity
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (distLabel != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: OnlistColors.blueDeep,
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(
                          color: OnlistColors.blueElectric.withValues(alpha: 0.35),
                          width: 0.5),
                    ),
                    child: Text(
                      distLabel,
                      style: TextStyle(
                        fontFamily: 'Helvetica',
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                if (club.famosita > 0) ...[
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.local_fire_department,
                          size: 11, color: Color(0xFFFF6B35)),
                      const SizedBox(width: 2),
                      Text(
                        '${club.famosita}',
                        style: TextStyle(
                          fontFamily: 'Helvetica',
                          fontSize: 10,
                          color: Colors.white38,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ],
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
  final String? locationLabel;
  final bool locationAvailable;
  final bool gpsAttempted;

  _NearbyData({
    required this.clubs,
    required this.raggio,
    required this.lat,
    required this.lng,
    this.locationLabel,
    this.locationAvailable = true,
    this.gpsAttempted = false,
  });

  List<String> get allGeneri {
    final s = <String>{};
    for (final c in clubs) {
      s.addAll(c.generiMusicali);
    }
    return s.toList()..sort();
  }

  List<String> get allCitta {
    return clubs.map((c) => c.nomeCitta).whereType<String>().toSet().toList()
      ..sort();
  }
}
