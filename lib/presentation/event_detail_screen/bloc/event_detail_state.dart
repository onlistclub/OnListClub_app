part of 'event_detail_bloc.dart';

class EventDetailState extends Equatable {
  final EventDetailModel? eventDetailModel;
  final bool isLoading;
  final int selectedBottomNavIndex;
  final LocaleModel? hottestClub;
  final SerataModel? eventoOggi;

  const EventDetailState({
    this.eventDetailModel,
    this.isLoading = false,
    this.selectedBottomNavIndex = 0,
    this.hottestClub,
    this.eventoOggi,
  });

  @override
  List<Object?> get props => [
        eventDetailModel,
        isLoading,
        selectedBottomNavIndex,
        hottestClub,
        eventoOggi,
      ];

  EventDetailState copyWith({
    EventDetailModel? eventDetailModel,
    bool? isLoading,
    int? selectedBottomNavIndex,
    LocaleModel? hottestClub,
    SerataModel? eventoOggi,
  }) {
    return EventDetailState(
      eventDetailModel: eventDetailModel ?? this.eventDetailModel,
      isLoading: isLoading ?? this.isLoading,
      selectedBottomNavIndex:
          selectedBottomNavIndex ?? this.selectedBottomNavIndex,
      hottestClub: hottestClub ?? this.hottestClub,
      eventoOggi: eventoOggi ?? this.eventoOggi,
    );
  }
}
