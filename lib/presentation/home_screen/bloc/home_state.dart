part of 'home_bloc.dart';

class HomeState extends Equatable {
  final HomeModel? homeModel;
  final bool isLoading;
  final int selectedBottomNavIndex;
  final LocaleModel? localeVicino;
  final List<SerataModel> upcomingEventi;
  final int raggioKm;

  const HomeState({
    this.homeModel,
    this.isLoading = false,
    this.selectedBottomNavIndex = 0,
    this.localeVicino,
    this.upcomingEventi = const [],
    this.raggioKm = 20,
  });

  @override
  List<Object?> get props => [
        homeModel,
        isLoading,
        selectedBottomNavIndex,
        localeVicino,
        upcomingEventi,
        raggioKm,
      ];

  HomeState copyWith({
    HomeModel? homeModel,
    bool? isLoading,
    int? selectedBottomNavIndex,
    LocaleModel? localeVicino,
    List<SerataModel>? upcomingEventi,
    int? raggioKm,
  }) {
    return HomeState(
      homeModel: homeModel ?? this.homeModel,
      isLoading: isLoading ?? this.isLoading,
      selectedBottomNavIndex:
          selectedBottomNavIndex ?? this.selectedBottomNavIndex,
      localeVicino: localeVicino ?? this.localeVicino,
      upcomingEventi: upcomingEventi ?? this.upcomingEventi,
      raggioKm: raggioKm ?? this.raggioKm,
    );
  }
}
