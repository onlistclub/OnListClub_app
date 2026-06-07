part of 'home_bloc.dart';

class HomeState extends Equatable {
  final HomeModel? homeModel;
  final bool isLoading;
  final int selectedBottomNavIndex;
  final LocaleModel? localeVicino;
  final List<SerataModel> upcomingEventi;
  final List<LocaleModel> recommendedClubs;
  final int raggioKm;
  final bool isGpsForced;
  final String locationSourceLabel;

  const HomeState({
    this.homeModel,
    this.isLoading = false,
    this.selectedBottomNavIndex = 0,
    this.localeVicino,
    this.upcomingEventi = const [],
    this.recommendedClubs = const [],
    this.raggioKm = 20,
    this.isGpsForced = false,
    this.locationSourceLabel = '',
  });

  @override
  List<Object?> get props => [
        homeModel,
        isLoading,
        selectedBottomNavIndex,
        localeVicino,
        upcomingEventi,
        recommendedClubs,
        raggioKm,
        isGpsForced,
        locationSourceLabel,
      ];

  HomeState copyWith({
    HomeModel? homeModel,
    bool? isLoading,
    int? selectedBottomNavIndex,
    LocaleModel? localeVicino,
    List<SerataModel>? upcomingEventi,
    List<LocaleModel>? recommendedClubs,
    int? raggioKm,
    bool? isGpsForced,
    String? locationSourceLabel,
  }) {
    return HomeState(
      homeModel: homeModel ?? this.homeModel,
      isLoading: isLoading ?? this.isLoading,
      selectedBottomNavIndex:
          selectedBottomNavIndex ?? this.selectedBottomNavIndex,
      localeVicino: localeVicino ?? this.localeVicino,
      upcomingEventi: upcomingEventi ?? this.upcomingEventi,
      recommendedClubs: recommendedClubs ?? this.recommendedClubs,
      raggioKm: raggioKm ?? this.raggioKm,
      isGpsForced: isGpsForced ?? this.isGpsForced,
      locationSourceLabel: locationSourceLabel ?? this.locationSourceLabel,
    );
  }
}
