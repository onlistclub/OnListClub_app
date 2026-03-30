import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/event_detail_club_model.dart';
import '../../../core/app_export.dart';
import '../../../core/models/locale_model.dart';
import '../../../core/models/serata_model.dart';
import '../../../core/services/club_service.dart';

part 'event_detail_club_event.dart';
part 'event_detail_club_state.dart';

class EventDetailClubBloc
    extends Bloc<EventDetailClubEvent, EventDetailClubState> {
  EventDetailClubBloc(EventDetailClubState initialState) : super(initialState) {
    on<EventDetailClubInitialEvent>(_onInitialize);
    on<EventDetailClubToggleFavoriteEvent>(_onToggleFavorite);
    on<EventDetailClubHideBadgeEvent>(_onHideBadge);
    on<EventDetailClubBottomNavSelectedEvent>(_onBottomNavSelected);
  }

  Future<void> _onInitialize(
    EventDetailClubInitialEvent event,
    Emitter<EventDetailClubState> emit,
  ) async {
    emit(state.copyWith(isLoading: true));
    final userId = Supabase.instance.client.auth.currentUser?.id;
    final isPreferito = userId != null
        ? await ClubService.isPreferito(userId, state.club.id)
        : false;
    emit(state.copyWith(isLoading: false, isPreferito: isPreferito));
  }

  Future<void> _onToggleFavorite(
    EventDetailClubToggleFavoriteEvent event,
    Emitter<EventDetailClubState> emit,
  ) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    emit(state.copyWith(isLoadingFavorite: true));
    final wasPreferito = state.isPreferito;
    try {
      if (wasPreferito) {
        await ClubService.removePreferito(userId, state.club.id);
        emit(state.copyWith(
          isPreferito: false,
          showFavoriteBadge: false,
          isLoadingFavorite: false,
        ));
      } else {
        await ClubService.addPreferito(userId, state.club.id);
        emit(state.copyWith(
          isPreferito: true,
          showFavoriteBadge: true,
          isLoadingFavorite: false,
        ));
        await Future.delayed(const Duration(milliseconds: 2500));
        add(EventDetailClubHideBadgeEvent());
      }
    } catch (_) {
      emit(state.copyWith(isLoadingFavorite: false));
    }
  }

  void _onHideBadge(
    EventDetailClubHideBadgeEvent event,
    Emitter<EventDetailClubState> emit,
  ) {
    emit(state.copyWith(showFavoriteBadge: false));
  }

  void _onBottomNavSelected(
    EventDetailClubBottomNavSelectedEvent event,
    Emitter<EventDetailClubState> emit,
  ) {
    emit(state.copyWith(selectedBottomNavIndex: event.index));
  }
}
