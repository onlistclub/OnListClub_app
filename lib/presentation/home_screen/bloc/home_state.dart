part of 'home_bloc.dart';

class HomeState extends Equatable {
  final HomeModel? homeModel;
  final bool isLoading;
  final int selectedBottomNavIndex;
  final LocaleModel? localeVicino;
  final List<SerataModel> upcomingEventi;
  final List<LocaleModel> recommendedClubs;
  /// Prima serata futura di ogni club consigliato (chiave: id club).
  final Map<String, SerataModel> nextSerataByClub;
  final int raggioKm;
  final bool isGpsForced;
  /// True quando il GPS è stato forzato ma non è disponibile (permesso negato,
  /// preview web, timeout): la UI mostra un messaggio e mantiene l'ultima
  /// posizione invece di ricadere in silenzio sul club più famoso.
  final bool gpsUnavailable;

  const HomeState({
    this.homeModel,
    this.isLoading = false,
    this.selectedBottomNavIndex = 0,
    this.localeVicino,
    this.upcomingEventi = const [],
    this.recommendedClubs = const [],
    this.nextSerataByClub = const {},
    this.raggioKm = 20,
    this.isGpsForced = false,
    this.gpsUnavailable = false,
  });

  @override
  List<Object?> get props => [
        homeModel,
        isLoading,
        selectedBottomNavIndex,
        localeVicino,
        upcomingEventi,
        recommendedClubs,
        nextSerataByClub,
        raggioKm,
        isGpsForced,
        gpsUnavailable,
      ];

  HomeState copyWith({
    HomeModel? homeModel,
    bool? isLoading,
    int? selectedBottomNavIndex,
    LocaleModel? localeVicino,
    List<SerataModel>? upcomingEventi,
    List<LocaleModel>? recommendedClubs,
    Map<String, SerataModel>? nextSerataByClub,
    int? raggioKm,
    bool? isGpsForced,
    bool? gpsUnavailable,
  }) {
    return HomeState(
      homeModel: homeModel ?? this.homeModel,
      isLoading: isLoading ?? this.isLoading,
      selectedBottomNavIndex:
          selectedBottomNavIndex ?? this.selectedBottomNavIndex,
      localeVicino: localeVicino ?? this.localeVicino,
      upcomingEventi: upcomingEventi ?? this.upcomingEventi,
      recommendedClubs: recommendedClubs ?? this.recommendedClubs,
      nextSerataByClub: nextSerataByClub ?? this.nextSerataByClub,
      raggioKm: raggioKm ?? this.raggioKm,
      isGpsForced: isGpsForced ?? this.isGpsForced,
      gpsUnavailable: gpsUnavailable ?? this.gpsUnavailable,
    );
  }
}
