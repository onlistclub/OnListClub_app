import '../models/event_detail_model.dart';
import '../../../core/app_export.dart';
import '../../../core/models/locale_model.dart';
import '../../../core/models/serata_model.dart';
import '../../../core/services/club_service.dart';

part 'event_detail_event.dart';
part 'event_detail_state.dart';

class EventDetailBloc extends Bloc<EventDetailEvent, EventDetailState> {
  EventDetailBloc(EventDetailState initialState) : super(initialState) {
    on<EventDetailInitialEvent>(_onInitialize);
    on<BottomNavItemSelectedEvent>(_onBottomNavItemSelected);
  }

  Future<void> _onInitialize(
    EventDetailInitialEvent event,
    Emitter<EventDetailState> emit,
  ) async {
    emit(state.copyWith(isLoading: true));
    try {
      final clubs = await ClubService.getLocaliByFamosita(limit: 1);
      if (clubs.isEmpty) {
        emit(state.copyWith(isLoading: false));
        return;
      }
      final hottest = clubs.first;
      final evento = await ClubService.getEventoOggi(hottest.id);
      emit(state.copyWith(
        isLoading: false,
        hottestClub: hottest,
        eventoOggi: evento,
      ));
    } catch (_) {
      emit(state.copyWith(isLoading: false));
    }
  }

  void _onBottomNavItemSelected(
    BottomNavItemSelectedEvent event,
    Emitter<EventDetailState> emit,
  ) {
    emit(state.copyWith(selectedBottomNavIndex: event.index));
  }
}
