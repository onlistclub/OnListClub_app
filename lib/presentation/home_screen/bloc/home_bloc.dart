import 'package:geolocator/geolocator.dart';
import '../models/home_model.dart';
import '../../../core/app_export.dart';
import '../../../core/models/locale_model.dart';
import '../../../core/models/serata_model.dart';
import '../../../core/services/club_service.dart';
import '../../../core/utils/user_profile_manager.dart';

part 'home_event.dart';
part 'home_state.dart';

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  HomeBloc(HomeState initialState) : super(initialState) {
    on<HomeInitialEvent>(_onInitialize);
    on<HomeBottomNavSelectedEvent>(_onBottomNavSelected);
    on<HomeRefreshEvent>(_onRefresh);
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
    await _load(emit);
  }

  Future<void> _load(Emitter<HomeState> emit) async {
    emit(state.copyWith(isLoading: true));
    try {
      // 1. Raggio utente
      final raggio = await UserProfileManager().getRaggioKm();

      // 2. Posizione GPS (best-effort, non bloccante)
      double? lat;
      double? lng;
      try {
        final permission = await Geolocator.checkPermission();
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
        }
      } catch (_) {}

      // 3. Locale più vicino
      final locale = await ClubService.getLocaleVicino(lat, lng);
      if (locale == null) {
        emit(state.copyWith(isLoading: false, raggioKm: raggio));
        return;
      }

      // 4. Serate future del locale
      final eventi = await ClubService.getUpcomingEventi(locale.id);

      emit(state.copyWith(
        isLoading: false,
        localeVicino: locale,
        upcomingEventi: eventi,
        raggioKm: raggio,
      ));
    } catch (_) {
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
