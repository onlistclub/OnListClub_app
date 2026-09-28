import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../core/models/citta_model.dart';
import '../../../core/services/analytics_service.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/user_profile_manager.dart';

part 'location_manual_event.dart';
part 'location_manual_state.dart';

class LocationManualBloc
    extends Bloc<LocationManualEvent, LocationManualState> {
  LocationManualBloc() : super(const LocationManualState()) {
    on<LoadInitialRadiusEvent>(_onLoadInitialRadius);
    on<SearchCittaEvent>(_onSearch);
    on<SelectCittaEvent>(_onSelect);
    on<ChangeRaggioEvent>(_onChangeRaggio);
    on<SubmitLocationEvent>(_onSubmit);

    add(const LoadInitialRadiusEvent());
  }

  Future<void> _onLoadInitialRadius(
    LoadInitialRadiusEvent event,
    Emitter<LocationManualState> emit,
  ) async {
    final km = await UserProfileManager().getRaggioKm();
    emit(state.copyWith(raggioKm: km));
  }

  Future<void> _onSearch(
    SearchCittaEvent event,
    Emitter<LocationManualState> emit,
  ) async {
    emit(state.copyWith(
      query: event.query,
      cities: [],
      isLoadingCities: event.query.trim().length >= 2,
      clearSelected: true,
    ));

    if (event.query.trim().length < 2) return;

    try {
      final results = await LocationService.searchCitta(event.query);
      emit(state.copyWith(cities: results, isLoadingCities: false));
    } catch (_) {
      emit(state.copyWith(cities: [], isLoadingCities: false));
    }
  }

  void _onSelect(
    SelectCittaEvent event,
    Emitter<LocationManualState> emit,
  ) {
    // Analytics: quale città viene toccata nella lista. NON è ancora la
    // scelta definitiva — quella è `location_confirmed`, che parte solo da
    // "Entra" (_onSubmit). Chi cerca, tocca e poi abbandona resta qui.
    AnalyticsService.logCitySelected(
      cityName: event.citta.nomeCitta,
      cityId:   event.citta.idCitta,
      lat:      event.citta.lat,
      lng:      event.citta.lng,
    );
    emit(state.copyWith(
      selectedCitta: event.citta,
      cities: [],
      query: event.citta.nomeCitta,
    ));
  }

  void _onChangeRaggio(
    ChangeRaggioEvent event,
    Emitter<LocationManualState> emit,
  ) {
    emit(state.copyWith(raggioKm: event.km));
  }

  Future<void> _onSubmit(
    SubmitLocationEvent event,
    Emitter<LocationManualState> emit,
  ) async {
    if (state.selectedCitta == null) {
      emit(state.copyWith(errorMessage: 'Seleziona una città dalla lista'));
      return;
    }

    emit(state.copyWith(isLoading: true, errorMessage: null));

    try {
      final citta = state.selectedCitta!;
      await LocationService.saveManualLocation(citta);
      await UserProfileManager().saveRaggioKm(state.raggioKm);
      // Qui la posizione è decisa davvero: l'utente ha premuto "Entra".
      AnalyticsService.logLocationConfirmed(
        modalita:  'citta',
        cityId:    citta.idCitta,
        cityName:  citta.nomeCitta,
        raggioKm:  state.raggioKm,
      );
      await UserProfileManager().salvaModalitaPosizione(
        modalita:      'citta',
        posizioneId:   citta.idCitta,
        posizioneNome: citta.nomeCitta,
      );
      emit(state.copyWith(isLoading: false, isSuccess: true));
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        errorMessage: 'Errore nel salvataggio: $e',
      ));
    }
  }
}
