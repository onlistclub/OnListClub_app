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
import '../../core/utils/analytics_mixin.dart';
import '../../widgets/custom_top_bar.dart';
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

  late Future<_NearbyData> _future;
  String _searchQuery = '';
  _SortMode _sortMode = _SortMode.distanza;
  final Set<String> _selectedGeneri = {};
  final Set<String> _selectedCitta = {};
  int? _selectedPrezzo; // null = tutti, 1/2/3 = €/€€/€€€
  CittaModel?
      _customCity; // città cercata manualmente: ha priorità su GPS/saved

  @override
  void initState() {
    super.initState();
    _future = _load();
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
      // Priorità 3: città salvata manualmente nelle impostazioni
      final savedCity = await LocationService.getSavedLocation();
      if (savedCity?.lat != null) {
        lat = savedCity!.lat;
        lng = savedCity.lng;
        locationLabel = savedCity.nomeCitta;
      }

      // Priorità 4: fallback a GPS
      if (lat == null) {
        await tryGps();
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
    return _NearbyData(
      clubs: clubs,
      raggio: raggio,
      lat: lat,
      lng: lng,
      locationLabel: locationLabel,
      locationAvailable: locationAvailable,
      gpsAttempted: gpsAttempted,
    );
  }

  // ── Filtering ──────────────────────────────────────────────────────────────

  List<LocaleModel>? _filteredCache;
  String? _filteredCacheKey;

  List<LocaleModel> _filtered(List<LocaleModel> clubs) {
    final key =
        '${identityHashCode(clubs)}|$_searchQuery|${_selectedGeneri.join(',')}'
        '|${_selectedCitta.join(',')}|$_selectedPrezzo|${_sortMode.index}';
    if (key == _filteredCacheKey && _filteredCache != null) {
      return _filteredCache!;
    }

    var list = clubs.where((c) {
      // Testo
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        if (!c.nome.toLowerCase().contains(q) &&
            !(c.nomeCitta?.toLowerCase().contains(q) ?? false)) {
          return false;
        }
      }
      // Genere
      if (_selectedGeneri.isNotEmpty &&
          !c.generiMusicali.any(_selectedGeneri.contains)) {
        return false;
      }
      // Città
      if (_selectedCitta.isNotEmpty && !_selectedCitta.contains(c.nomeCitta)) {
        return false;
      }
      // Prezzo
      if (_selectedPrezzo != null && c.prezzoIndicativo != _selectedPrezzo) {
        return false;
      }
      return true;
    }).toList();

    if (_sortMode == _SortMode.popolarita) {
      list.sort((a, b) => b.famosita.compareTo(a.famosita));
    }

    _filteredCache = list;
    _filteredCacheKey = key;
    return list;
  }

  bool get _hasActiveFilters =>
      _selectedGeneri.isNotEmpty ||
      _selectedCitta.isNotEmpty ||
      _selectedPrezzo != null;

  void _clearFilters() => setState(() {
        _selectedGeneri.clear();
        _selectedCitta.clear();
        _selectedPrezzo = null;
      });

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
                            TileLayer(
                              urlTemplate:
                                  'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
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
                    const SizedBox(height: 12),
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
      final newFuture = _load();
      setState(() {
        _future = newFuture;
      });
    }
  }

  // ── City picker ────────────────────────────────────────────────────────────

  Future<void> _showCityPicker() async {
    final TextEditingController ctrl = TextEditingController();
    List<CittaModel> results = [];
    Timer? searchDebounce;
    // Marker monotonico per scartare risposte di chiamate ormai obsolete
    // (es. utente digita "mil" mentre "mi" è ancora in volo).
    int searchSeq = 0;

    final picked = await showDialog<CittaModel>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Dialog(
          backgroundColor: OnlistColors.black,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360, maxHeight: 440),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cerca per città',
                    style: TextStyle(
                        fontFamily: 'Helvetica',
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 17),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: ctrl,
                    autofocus: true,
                    style: TextStyle(
                        fontFamily: 'Helvetica',
                        color: Colors.white,
                        fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Nome città…',
                      hintStyle: TextStyle(
                          fontFamily: 'Helvetica',
                          color: Colors.white38,
                          fontSize: 14),
                      prefixIcon: const Icon(Icons.search,
                          color: Colors.white38, size: 20),
                      filled: true,
                      fillColor: OnlistColors.blueDeep,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onChanged: (v) {
                      searchDebounce?.cancel();
                      final query = v.trim();
                      if (query.length < 2) {
                        setS(() => results = []);
                        return;
                      }
                      searchSeq++;
                      final mySeq = searchSeq;
                      searchDebounce = Timer(
                        const Duration(milliseconds: 300),
                        () async {
                          try {
                            final r =
                                await LocationService.searchCitta(query);
                            // Scarta se nel frattempo l'utente ha digitato altro.
                            if (mySeq != searchSeq) return;
                            setS(() => results = r);
                          } catch (e) {
                            debugPrint(
                                '[NearbyClubs] searchCitta fallita: $e');
                            if (mySeq != searchSeq) return;
                            setS(() => results = []);
                          }
                        },
                      );
                    },
                  ),
                  if (results.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: results.length,
                        itemBuilder: (_, i) {
                          final c = results[i];
                          return InkWell(
                            onTap: () => Navigator.pop(ctx, c),
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 4, vertical: 10),
                              child: Row(
                                children: [
                                  const Icon(Icons.location_city,
                                      color: OnlistColors.blueElectric, size: 18),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      c.nomeCitta,
                                      style: TextStyle(
                                          fontFamily: 'Helvetica',
                                          color: Colors.white,
                                          fontSize: 14),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ] else if (ctrl.text.trim().length >= 2) ...[
                    const SizedBox(height: 20),
                    Center(
                      child: Text(
                        'Nessuna città trovata',
                        style: TextStyle(
                            fontFamily: 'Helvetica',
                            color: Colors.white38,
                            fontSize: 13),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text('Annulla',
                          style: TextStyle(
                              fontFamily: 'Helvetica', color: Colors.white54)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (picked != null) {
      setState(() => _customCity = picked);
      final newFuture = _load();
      setState(() {
        _future = newFuture;
      });
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isGpsForced = LocationService.isGpsForced;

    return Scaffold(
      backgroundColor: OnlistColors.black,
      body: DecoratedBox(
        decoration:
            const BoxDecoration(gradient: OnlistColors.screenBackground),
        child: SafeArea(
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── CustomTopBar ──
            const CustomTopBar(showSearch: false),
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
                      child: FutureBuilder<_NearbyData>(
                        future: _future,
                        builder: (_, snap) {
                          final raggio = snap.data?.raggio ?? 20;
                          final locLabel = snap.data?.locationLabel;
                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Chip raggio
                              GestureDetector(
                                onTap: () => _showRadiusDialog(
                                  raggio,
                                  lat: snap.data?.lat,
                                  lng: snap.data?.lng,
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
                                    ],
                                  ),
                                ),
                              ],
                              // Usa GPS button (solo se non forzato e non su GPS)
                              if (!isGpsForced && locLabel != 'GPS') ...[
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: () {
                                    LocationService.isGpsForced = true;
                                    setState(() {
                                      _customCity = null;
                                      _future = _load();
                                    });
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text(
                                              'Ricerca tramite GPS attivata')),
                                    );
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: OnlistColors.blueDeep,
                                      borderRadius: BorderRadius.circular(7),
                                      border: Border.all(
                                          color: OnlistColors.blueElectric
                                              .withValues(alpha: 0.35)),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.my_location,
                                            color: Colors.white, size: 12),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Usa GPS',
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
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Search bar ────────────────────────────────────────────────
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
                  style: TextStyle(
                      fontFamily: 'Helvetica',
                      fontSize: 14,
                      color: Colors.white,
                      fontWeight: FontWeight.w500),
                  decoration: InputDecoration(
                    hintText: 'Cerca locale…',
                    hintStyle: TextStyle(
                        fontFamily: 'Helvetica',
                        fontSize: 14,
                        color: Colors.white38),
                    prefixIcon: const Icon(Icons.search,
                        color: Colors.white38, size: 20),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onChanged: (v) => setState(() => _searchQuery = v),
                ),
              ),
            ),

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
                  if (_hasActiveFilters) ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _clearFilters,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2A1A1A),
                          borderRadius: BorderRadius.circular(7),
                          border: Border.all(
                              color: Colors.redAccent.withValues(alpha: 0.5),
                              width: 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.close,
                                size: 12, color: Colors.redAccent),
                            const SizedBox(width: 4),
                            Text('Azzera',
                                style: TextStyle(
                                    fontFamily: 'Helvetica',
                                    fontSize: 12,
                                    color: Colors.redAccent)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // ── Ricerca per città ──────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: GestureDetector(
                onTap: _showCityPicker,
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: _customCity != null
                        ? OnlistColors.blueElectric.withValues(alpha: 0.12)
                        : OnlistColors.blueDeep,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _customCity != null
                          ? OnlistColors.blueElectric.withValues(alpha: 0.5)
                          : OnlistColors.blueElectric.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 10),
                      Icon(
                        Icons.location_city,
                        color: _customCity != null
                            ? OnlistColors.blueElectric
                            : Colors.white38,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _customCity?.nomeCitta ?? 'Cerca per città…',
                          style: TextStyle(
                            fontFamily: 'Helvetica',
                            fontSize: 13,
                            color: _customCity != null
                                ? Colors.white
                                : Colors.white38,
                          ),
                        ),
                      ),
                      if (_customCity != null)
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            setState(() => _customCity = null);
                            final newFuture = _load();
                            setState(() {
                              _future = newFuture;
                            });
                          },
                          child: const Padding(
                            padding: EdgeInsets.all(10),
                            child: Icon(Icons.close,
                                color: Colors.white54, size: 15),
                          ),
                        )
                      else
                        const Padding(
                          padding: EdgeInsets.only(right: 10),
                          child: Icon(Icons.search,
                              color: Colors.white38, size: 15),
                        ),
                    ],
                  ),
                ),
              ),
            ),

            // ── Filtri + lista (FutureBuilder) ────────────────────────────
            Expanded(
              child: FutureBuilder<_NearbyData>(
                future: _future,
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const _NearbySkeleton();
                  }
                  if (snap.hasError || snap.data == null) {
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
                            onPressed: () =>
                                setState(() => _future = _load()),
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

                  final data = snap.data!;
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
                                onPressed: () =>
                                    setState(() => _future = _load()),
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
                      // ── Filtro prezzo ──────────────────────────────────
                      _buildPriceRow(),

                      // ── Filtro genere ──────────────────────────────────
                      if (data.allGeneri.isNotEmpty)
                        _buildChipRow(
                          items: data.allGeneri,
                          selected: _selectedGeneri,
                          onToggle: (g) => setState(() {
                            if (_selectedGeneri.contains(g)) {
                              _selectedGeneri.remove(g);
                            } else {
                              _selectedGeneri.add(g);
                            }
                          }),
                          icon: Icons.music_note,
                        ),

                      // ── Filtro città ───────────────────────────────────
                      if (data.allCitta.length > 1)
                        _buildChipRow(
                          items: data.allCitta,
                          selected: _selectedCitta,
                          onToggle: (c) => setState(() {
                            if (_selectedCitta.contains(c)) {
                              _selectedCitta.remove(c);
                            } else {
                              _selectedCitta.add(c);
                            }
                          }),
                          icon: Icons.location_city,
                        ),

                      // ── Lista locali ───────────────────────────────────
                      if (filtered.isEmpty)
                        Expanded(
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                _hasActiveFilters || _searchQuery.isNotEmpty
                                    ? 'Nessun locale corrisponde ai filtri.'
                                    : 'Nessun locale trovato nel raggio di ${data.raggio} km.',
                                style: TextStyle(
                                  fontFamily: 'Helvetica',
                                  fontSize: 15,
                                  color: Colors.white54,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        )
                      else
                        Expanded(
                          child: ListView.separated(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
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

  // ── Filter widgets ─────────────────────────────────────────────────────────

  Widget _buildPriceRow() {
    return Padding(
      padding: const EdgeInsets.only(left: 12, right: 12, bottom: 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [1, 2, 3].map((p) {
            final label = '€' * p;
            final sel = _selectedPrezzo == p;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => setState(() => _selectedPrezzo = sel ? null : p),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: sel
                        ? OnlistColors.blueElectric.withValues(alpha: 0.18)
                        : OnlistColors.blueDeep,
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(
                      color: sel
                          ? OnlistColors.blueElectric
                          : OnlistColors.blueElectric.withValues(alpha: 0.35),
                      width: sel ? 1.5 : 0.5,
                    ),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontFamily: 'Helvetica',
                      fontSize: 13,
                      fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                      color: sel ? Colors.white : Colors.white54,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildChipRow({
    required List<String> items,
    required Set<String> selected,
    required void Function(String) onToggle,
    required IconData icon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, right: 12, bottom: 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: items.map((item) {
            final sel = selected.contains(item);
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => onToggle(item),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: sel
                        ? OnlistColors.blueElectric.withValues(alpha: 0.18)
                        : OnlistColors.blueDeep,
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(
                      color: sel
                          ? OnlistColors.blueElectric
                          : OnlistColors.blueElectric.withValues(alpha: 0.35),
                      width: sel ? 1.5 : 0.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon,
                          size: 13,
                          color:
                              sel ? OnlistColors.blueElectric : Colors.white38),
                      const SizedBox(width: 5),
                      Text(
                        item,
                        style: TextStyle(
                          fontFamily: 'Helvetica',
                          fontSize: 13,
                          fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                          color: sel ? Colors.white : Colors.white54,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
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
                color: selected ? OnlistColors.blueElectric : Colors.white38),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Helvetica',
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: selected ? Colors.white : Colors.white54,
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
                          errorWidget: (_, __, ___) => const ImageFallback(),
                        )
                      : const ImageFallback(),
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
