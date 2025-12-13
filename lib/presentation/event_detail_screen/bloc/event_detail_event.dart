part of 'event_detail_bloc.dart';

abstract class EventDetailEvent extends Equatable {
  const EventDetailEvent();

  @override
  List<Object?> get props => [];
}

class EventDetailInitialEvent extends EventDetailEvent {}

class ReserveButtonPressedEvent extends EventDetailEvent {}

class BottomNavItemSelectedEvent extends EventDetailEvent {
  final int index;

  const BottomNavItemSelectedEvent(this.index);

  @override
  List<Object?> get props => [index];
}
