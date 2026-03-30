part of 'club_detail_bloc.dart';

class ClubDetailState extends Equatable {
  final LocaleModel locale;
  final SerataModel? eventoOggi;
  final bool isPreferito;
  final bool isLoadingFavorite;
  final bool showFavoriteBadge;
  final int selectedBottomNavIndex;
  final bool isLoading;

  const ClubDetailState({
    required this.locale,
    this.eventoOggi,
    this.isPreferito = false,
    this.isLoadingFavorite = false,
    this.showFavoriteBadge = false,
    this.selectedBottomNavIndex = 0,
    this.isLoading = false,
  });

  @override
  List<Object?> get props => [
        locale,
        eventoOggi,
        isPreferito,
        isLoadingFavorite,
        showFavoriteBadge,
        selectedBottomNavIndex,
        isLoading,
      ];

  ClubDetailState copyWith({
    LocaleModel? locale,
    SerataModel? eventoOggi,
    bool? isPreferito,
    bool? isLoadingFavorite,
    bool? showFavoriteBadge,
    int? selectedBottomNavIndex,
    bool? isLoading,
  }) {
    return ClubDetailState(
      locale: locale ?? this.locale,
      eventoOggi: eventoOggi ?? this.eventoOggi,
      isPreferito: isPreferito ?? this.isPreferito,
      isLoadingFavorite: isLoadingFavorite ?? this.isLoadingFavorite,
      showFavoriteBadge: showFavoriteBadge ?? this.showFavoriteBadge,
      selectedBottomNavIndex:
          selectedBottomNavIndex ?? this.selectedBottomNavIndex,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}
