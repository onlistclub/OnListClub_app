import '../models/event_detail_model.dart';
import '../../../core/app_export.dart';

part 'event_detail_event.dart';
part 'event_detail_state.dart';

class EventDetailBloc extends Bloc<EventDetailEvent, EventDetailState> {
  EventDetailBloc(EventDetailState initialState) : super(initialState) {
    on<EventDetailInitialEvent>(_onInitialize);
    on<ReserveButtonPressedEvent>(_onReserveButtonPressed);
    on<BottomNavItemSelectedEvent>(_onBottomNavItemSelected);
  }

  void _onInitialize(
    EventDetailInitialEvent event,
    Emitter<EventDetailState> emit,
  ) async {
    emit(state.copyWith(
      selectedBottomNavIndex: 0,
      isLoading: false,
    ));
  }

  void _onReserveButtonPressed(
    ReserveButtonPressedEvent event,
    Emitter<EventDetailState> emit,
  ) async {
    emit(state.copyWith(isLoading: true));

    // Simulate reservation process
    await Future.delayed(Duration(seconds: 1));

    emit(state.copyWith(
      isLoading: false,
      reservationSuccess: true,
    ));
  }

  void _onBottomNavItemSelected(
    BottomNavItemSelectedEvent event,
    Emitter<EventDetailState> emit,
  ) async {
    emit(state.copyWith(
      selectedBottomNavIndex: event.index,
    ));
  }
}
