import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/services/analytics_service.dart';
import '../../../core/services/location_service.dart';

part 'location_permission_event.dart';
part 'location_permission_state.dart';

class LocationPermissionBloc
    extends Bloc<LocationPermissionEvent, LocationPermissionState> {
  LocationPermissionBloc() : super(const LocationPermissionState()) {
    on<LocationPermissionInitialEvent>(_onInitialize);
    on<OpenSettingsEvent>(_onOpenSettings);
    on<RemindLaterEvent>(_onRemindLater);
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
        AnalyticsService.logGpsPermission(granted: false);
        emit(state.copyWith(isLoading: false));
      } else {
        // Request permission → triggers native OS dialog
        final result = await LocationService.requestPermission();
        if (result == LocationPermission.always ||
            result == LocationPermission.whileInUse) {
          AnalyticsService.logGpsPermission(granted: true);
          emit(state.copyWith(isLoading: false, isPermissionGranted: true));
        } else {
          AnalyticsService.logGpsPermission(granted: false);
          emit(state.copyWith(isLoading: false));
        }
      }
    } catch (e) {
      emit(state.copyWith(isLoading: false, errorMessage: e.toString()));
    }
  }

  Future<void> _onRemindLater(
    RemindLaterEvent event,
    Emitter<LocationPermissionState> emit,
  ) async {
    await LocationService.saveRemindLaterTimestamp();
    emit(state.copyWith(goToManualEntry: true));
  }
}
