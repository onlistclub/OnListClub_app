part of 'event_detail_club_bloc.dart';

abstract class EventDetailClubEvent extends Equatable {
  const EventDetailClubEvent();

  @override
  List<Object?> get props => [];
}

class EventDetailClubInitialEvent extends EventDetailClubEvent {}

class EventDetailClubToggleFavoriteEvent extends EventDetailClubEvent {}

class EventDetailClubHideBadgeEvent extends EventDetailClubEvent {}

class EventDetailClubBottomNavSelectedEvent extends EventDetailClubEvent {
  final int index;
  const EventDetailClubBottomNavSelectedEvent(this.index);

  @override
  List<Object?> get props => [index];
}
