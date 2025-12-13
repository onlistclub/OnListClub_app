part of 'event_detail_bloc.dart';

class EventDetailState extends Equatable {
  final EventDetailModel? eventDetailModel;
  final bool isLoading;
  final bool reservationSuccess;
  final int selectedBottomNavIndex;

  const EventDetailState({
    this.eventDetailModel,
    this.isLoading = false,
    this.reservationSuccess = false,
    this.selectedBottomNavIndex = 0,
  });

  @override
  List<Object?> get props => [
        eventDetailModel,
        isLoading,
        reservationSuccess,
        selectedBottomNavIndex,
      ];

  EventDetailState copyWith({
    EventDetailModel? eventDetailModel,
    bool? isLoading,
    bool? reservationSuccess,
    int? selectedBottomNavIndex,
  }) {
    return EventDetailState(
      eventDetailModel: eventDetailModel ?? this.eventDetailModel,
      isLoading: isLoading ?? this.isLoading,
      reservationSuccess: reservationSuccess ?? this.reservationSuccess,
      selectedBottomNavIndex:
          selectedBottomNavIndex ?? this.selectedBottomNavIndex,
    );
  }
}
