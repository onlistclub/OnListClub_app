import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/app_export.dart';
import '../../../core/models/locale_model.dart';
import '../../../core/models/serata_model.dart';
import '../../../core/services/club_service.dart';

part 'club_detail_event.dart';
part 'club_detail_state.dart';

class ClubDetailBloc extends Bloc<ClubDetailEvent, ClubDetailState> {
  ClubDetailBloc(ClubDetailState initialState) : super(initialState) {
    on<ClubDetailInitialEvent>(_onInitialize);
    on<ToggleFavoriteEvent>(_onToggleFavorite);
    on<HideFavoriteBadgeEvent>(_onHideFavoriteBadge);
    on<BottomNavItemSelectedEvent>(_onBottomNavItemSelected);
  }

  Future<void> _onInitialize(
    ClubDetailInitialEvent event,
    Emitter<ClubDetailState> emit,
  ) async {
    emit(state.copyWith(isLoading: true));

    final clubId = state.locale.id;
    final userId = Supabase.instance.client.auth.currentUser?.id;

    final results = await Future.wait([
      ClubService.getEventoOggi(clubId),
      ClubService.getUpcomingEventi(clubId),
      if (userId != null) ClubService.isPreferito(userId, clubId),
    ]);

    final evento = results[0] as SerataModel?;
    final serate = results[1] as List<SerataModel>;
    final isPreferito = (userId != null && results.length > 2)
        ? results[2] as bool
        : false;

    emit(state.copyWith(
      eventoOggi: evento,
      serate: serate,
      isPreferito: isPreferito,
      isLoading: false,
    ));
  }

  Future<void> _onToggleFavorite(
    ToggleFavoriteEvent event,
    Emitter<ClubDetailState> emit,
  ) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    emit(state.copyWith(isLoadingFavorite: true));

    final wasPreferito = state.isPreferito;
    try {
      if (wasPreferito) {
        await ClubService.removePreferito(userId, state.locale.id);
        emit(state.copyWith(
          isPreferito: false,
          showFavoriteBadge: false,
          isLoadingFavorite: false,
        ));
      } else {
        await ClubService.addPreferito(userId, state.locale.id);
        emit(state.copyWith(
          isPreferito: true,
          showFavoriteBadge: true,
          isLoadingFavorite: false,
        ));
        await Future.delayed(const Duration(milliseconds: 2500));
        add(HideFavoriteBadgeEvent());
      }
    } catch (_) {
      emit(state.copyWith(isLoadingFavorite: false));
    }
  }

  void _onHideFavoriteBadge(
    HideFavoriteBadgeEvent event,
    Emitter<ClubDetailState> emit,
  ) {
    emit(state.copyWith(showFavoriteBadge: false));
  }

  void _onBottomNavItemSelected(
    BottomNavItemSelectedEvent event,
    Emitter<ClubDetailState> emit,
  ) {
    emit(state.copyWith(selectedBottomNavIndex: event.index));
  }
}
