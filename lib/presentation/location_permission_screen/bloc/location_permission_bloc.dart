import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/services/analytics_service.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/user_profile_manager.dart';

part 'location_permission_event.dart';
part 'location_permission_state.dart';

class LocationPermissionBloc
    extends Bloc<LocationPermissionEvent, LocationPermissionState> {
  LocationPermissionBloc() : super(const LocationPermissionState()) {
    on<LocationPermissionInitialEvent>(_onInitialize);
    on<OpenSettingsEvent>(_onOpenSettings);
    on<RemindLaterEvent>(_onRemindLater);
    on<RicontrollaPermessoEvent>(_onRicontrolla);
  }

  Future<void> _onInitialize(
    LocationPermissionInitialEvent event,
    Emitter<LocationPermissionState> emit,
  ) async {
    final permission = await LocationService.checkPermission();
    if (permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse) {
      emit(state.copyWith(isPermissionGranted: true));
    }
  }

  /// Ritorno in primo piano: se nel frattempo il permesso è stato concesso
  /// dalle impostazioni di sistema, lo si registra e si prosegue.
  ///
  /// Si esce subito se il permesso risulta già concesso (niente da registrare
  /// due volte) o se una richiesta è ancora in corso: il dialogo nativo non
  /// manda l'app in background, ma se una piattaforma lo facesse questo
  /// controllo e la risposta del dialogo scriverebbero lo stesso evento.
  Future<void> _onRicontrolla(
    RicontrollaPermessoEvent event,
    Emitter<LocationPermissionState> emit,
  ) async {
    if (state.isPermissionGranted || state.isLoading) return;

    final permesso = await LocationService.checkPermission();
    if (permesso != LocationPermission.always &&
        permesso != LocationPermission.whileInUse) {
      return;
    }

    await _registraEsito(permesso);
    emit(state.copyWith(isPermissionGranted: true));
  }

  Future<void> _onOpenSettings(
    OpenSettingsEvent event,
    Emitter<LocationPermissionState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, errorMessage: null));

    try {
      final permission = await LocationService.checkPermission();

      if (permission == LocationPermission.deniedForever) {
        // User permanently denied: open phone settings
        await LocationService.openSettings();
        await _registraEsito(LocationPermission.deniedForever);
        emit(state.copyWith(isLoading: false));
      } else {
        // Request permission → triggers native OS dialog
        final result = await LocationService.requestPermission();
        await _registraEsito(result);
        if (result == LocationPermission.always ||
            result == LocationPermission.whileInUse) {
          emit(state.copyWith(isLoading: false, isPermissionGranted: true));
        } else {
          emit(state.copyWith(isLoading: false));
        }
      }
    } catch (e) {
      emit(state.copyWith(isLoading: false, errorMessage: e.toString()));
    }
  }

  /// Registra l'esito della richiesta: che permesso ha dato il sistema e con
  /// che precisione. Se è andata bene segna anche che questo utente, da adesso,
  /// si fa localizzare via GPS.
  Future<void> _registraEsito(LocationPermission risultato) async {
    final etichetta = LocationService.etichettaPermesso(risultato);
    final concesso = LocationService.permessoConcesso(etichetta);
    final precisione = await LocationService.precisionePermesso();

    AnalyticsService.logGpsPermission(
      granted: concesso,
      permesso: etichetta,
      precisione: precisione,
    );

    if (concesso) {
      AnalyticsService.logLocationConfirmed(
        modalita: 'gps',
        permesso: etichetta,
        precisione: precisione,
      );
      await UserProfileManager().salvaModalitaPosizione(modalita: 'gps');
    }
  }

  Future<void> _onRemindLater(
    RemindLaterEvent event,
    Emitter<LocationPermissionState> emit,
  ) async {
    // Chi rimanda non lasciava traccia: nei numeri era identico a chi non era
    // mai arrivato su questa schermata. È invece la scelta che conta di più,
    // perché è quella che manda tutto il flusso sulla ricerca città.
    AnalyticsService.logLocationPromptSkipped();
    await LocationService.saveRemindLaterTimestamp();
    emit(state.copyWith(goToManualEntry: true));
  }
}
