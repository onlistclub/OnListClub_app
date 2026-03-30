part of 'event_detail_club_bloc.dart';

class EventDetailClubState extends Equatable {
  final EventDetailClubModel? model;
  final LocaleModel club;
  final SerataModel serata;
  final bool isLoading;
  final bool isLoadingFavorite;
  final bool isPreferito;
  final bool showFavoriteBadge;
  final int selectedBottomNavIndex;

  const EventDetailClubState({
    this.model,
    required this.club,
    required this.serata,
    this.isLoading = false,
    this.isLoadingFavorite = false,
    this.isPreferito = false,
    this.showFavoriteBadge = false,
    this.selectedBottomNavIndex = 0,
  });

  @override
  List<Object?> get props => [
        model,
        club,
        serata,
        isLoading,
        isLoadingFavorite,
        isPreferito,
        showFavoriteBadge,
        selectedBottomNavIndex,
      ];

  EventDetailClubState copyWith({
    EventDetailClubModel? model,
    LocaleModel? club,
    SerataModel? serata,
    bool? isLoading,
    bool? isLoadingFavorite,
    bool? isPreferito,
    bool? showFavoriteBadge,
    int? selectedBottomNavIndex,
  }) {
    return EventDetailClubState(
      model: model ?? this.model,
      club: club ?? this.club,
      serata: serata ?? this.serata,
      isLoading: isLoading ?? this.isLoading,
      isLoadingFavorite: isLoadingFavorite ?? this.isLoadingFavorite,
      isPreferito: isPreferito ?? this.isPreferito,
      showFavoriteBadge: showFavoriteBadge ?? this.showFavoriteBadge,
      selectedBottomNavIndex:
          selectedBottomNavIndex ?? this.selectedBottomNavIndex,
    );
  }
}
