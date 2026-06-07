import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../models/home_model.dart';
import '../../../core/app_export.dart';
import '../../../core/models/locale_model.dart';
import '../../../core/models/serata_model.dart';
import '../../../core/services/analytics_service.dart';
import '../../../core/services/club_service.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/orders_service.dart';
import '../../../core/services/user_profile_manager.dart';

part 'home_event.dart';
part 'home_state.dart';

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  HomeBloc(HomeState initialState)
      : super(initialState.copyWith(isGpsForced: LocationService.isGpsForced)) {
    on<HomeInitialEvent>(_onInitialize);
    on<HomeBottomNavSelectedEvent>(_onBottomNavSelected);
    on<HomeRefreshEvent>(_onRefresh);
    on<HomeForceGpsEvent>(_onForceGps);
  }

  Future<void> _onInitialize(
    HomeInitialEvent event,
    Emitter<HomeState> emit,
  ) async {
    await _load(emit);
  }

  Future<void> _onRefresh(
    HomeRefreshEvent event,
    Emitter<HomeState> emit,
  ) async {
    emit(state.copyWith(isGpsForced: LocationService.isGpsForced));
    await _load(emit);
  }

  Future<void> _onForceGps(
    HomeForceGpsEvent event,
    Emitter<HomeState> emit,
  ) async {
    LocationService.isGpsForced = event.enable;
    emit(state.copyWith(isGpsForced: event.enable));
    // Analytics: traccia il toggle GPS forzato
    AnalyticsService.logGpsForced(enabled: event.enable);
    await _load(emit);
  }

  Future<void> _load(Emitter<HomeState> emit) async {
    emit(state.copyWith(isLoading: true));
    try {
      // 1. Raggio utente
      final raggio = await UserProfileManager().getRaggioKm();
      debugPrint('[HomeBloc] 🏠 _load() START — raggio=$raggio, isGpsForced=${state.isGpsForced}');

      double? lat;
      double? lng;
      String sourceLabel = '';

      Future<void> tryGps() async {
        debugPrint('[HomeBloc] 📡 tryGps() chiamato');
        try {
          final cached = await LocationService.getCachedGpsPosition();
          if (cached != null) {
            lat = cached.lat;
            lng = cached.lng;
            sourceLabel = 'Posizione Attuale';
            debugPrint('[HomeBloc] ✅ GPS da cache: lat=$lat, lng=$lng');
          } else {
            final permission = await Geolocator.checkPermission();
            debugPrint('[HomeBloc] 🔑 Permesso GPS: $permission');
            if (permission == LocationPermission.whileInUse ||
                permission == LocationPermission.always) {
              final pos = await Geolocator.getCurrentPosition(
                locationSettings: const LocationSettings(
                  accuracy: LocationAccuracy.low,
                  timeLimit: Duration(seconds: 5),
                ),
              );
              lat = pos.latitude;
              lng = pos.longitude;
              sourceLabel = 'Posizione Attuale';
              debugPrint('[HomeBloc] ✅ GPS fresco: lat=$lat, lng=$lng');
              await LocationService.saveGpsPosition(lat!, lng!);
            } else {
              debugPrint('[HomeBloc] ❌ GPS non concesso — permission=$permission');
            }
          }
        } catch (e) {
          debugPrint('[HomeBloc] ❌ tryGps errore: $e');
        }
      }

      int bookingsCount = 0;
      if (state.isGpsForced) {
        debugPrint('[HomeBloc] 🎯 GPS forzato dall\'utente');
        await tryGps();
      } else {
        // 2. Se > 5 prenotazioni, usa lo storico.
        // Calcoliamo gli ID club dell'utente UNA sola volta e li riusiamo per
        // conteggio e coordinate: evita di rieseguire le query su prenotazioni.
        final clubIds = await OrdersService.getUtenteClubIds();
        bookingsCount = clubIds.length;
        debugPrint('[HomeBloc] 📊 Prenotazioni totali: $bookingsCount');
        if (bookingsCount >= 5) {
          final freqLoc = await OrdersService.getMostFrequentClubCoordinates(
              precomputedIds: clubIds);
          debugPrint('[HomeBloc] ⭐ Coordinate club frequentato: $freqLoc');
          if (freqLoc != null) {
            lat = freqLoc['lat'];
            lng = freqLoc['lng'];
            sourceLabel = '⭐ Selezione per te';
          }
        }

        // 3. Posizione manuale (Città o punto di riferimento)
        if (lat == null) {
          final savedCity = await LocationService.getSavedLocation();
          debugPrint('[HomeBloc] 🏙️ Città salvata: ${savedCity?.nomeCitta} (lat=${savedCity?.lat}, lng=${savedCity?.lng})');
          if (savedCity != null) {
            lat = savedCity.lat;
            lng = savedCity.lng;
            sourceLabel = '${savedCity.nomeCitta}';
          }
        }

        // 4. Fallback a GPS
        if (lat == null) {
          debugPrint('[HomeBloc] 🔄 Nessuna fonte trovata, fallback a GPS');
          await tryGps();
        }
      }

      // Analytics: traccia la sorgente posizione e il club mostrato
      String analyticsSource;
      if (state.isGpsForced) {
        analyticsSource = 'gps_forced';
      } else if (sourceLabel.startsWith('⭐')) {
        analyticsSource = 'storico';
      } else if (lat != null && sourceLabel.startsWith('Posizione')) {
        analyticsSource = 'gps';
      } else if (lat != null) {
        analyticsSource = 'citta_manuale';
      } else {
        analyticsSource = 'nessuna';
      }

      final locale = await ClubService.getLocaleVicino(lat, lng);
      debugPrint('[HomeBloc] 🏛️ Locale vicino: ${locale?.nome ?? "NESSUNO"} (id=${locale?.id})');
      if (locale == null) {
        debugPrint('[HomeBloc] ⚠️ Nessun locale trovato — fine _load()');
        AnalyticsService.logLocationResolved(
          source: analyticsSource,
          lat: lat,
          lng: lng,
          bookingsCount: 0,
        );
        emit(state.copyWith(isLoading: false, raggioKm: raggio));
        return;
      }

      // 4. Serate future del locale + altri club vicini (per "Club consigliati")
      final results = await Future.wait([
        ClubService.getUpcomingEventi(locale.id),
        ClubService.getLocaliVicini(lat, lng, raggioKm: raggio.toDouble()),
      ]);
      final eventi = results[0] as List<SerataModel>;
      final allNearby = results[1] as List<LocaleModel>;
      final recommended = allNearby
          .where((c) => c.id != locale.id)
          .take(8)
          .toList(growable: false);
      debugPrint('[HomeBloc] 📅 Eventi trovati: ${eventi.length} per ${locale.nome}');
      debugPrint('[HomeBloc] 🏟️ Club consigliati: ${recommended.length}');

      // Analytics: log completo con club trovato
      AnalyticsService.logLocationResolved(
        source: analyticsSource,
        lat: lat,
        lng: lng,
        bookingsCount: bookingsCount,
        clubId: locale.id,
        clubName: locale.nome,
      );

      emit(state.copyWith(
        isLoading: false,
        localeVicino: locale,
        upcomingEventi: eventi,
        recommendedClubs: recommended,
        raggioKm: raggio,
        locationSourceLabel: sourceLabel,
      ));
      debugPrint('[HomeBloc] ✅ _load() COMPLETATO — club=${locale.nome}, source=$sourceLabel');
    } catch (e, stack) {
      debugPrint('[HomeBloc] ❌ ERRORE _load: $e\n$stack');
      emit(state.copyWith(isLoading: false));
    }
  }

  void _onBottomNavSelected(
    HomeBottomNavSelectedEvent event,
    Emitter<HomeState> emit,
  ) {
    emit(state.copyWith(selectedBottomNavIndex: event.index));
  }
}
