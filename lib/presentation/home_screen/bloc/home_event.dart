part of 'home_bloc.dart';

abstract class HomeEvent extends Equatable {
  const HomeEvent();

  @override
  List<Object?> get props => [];
}

class HomeInitialEvent extends HomeEvent {}

class HomeRefreshEvent extends HomeEvent {}

class HomeBottomNavSelectedEvent extends HomeEvent {
  final int index;
  const HomeBottomNavSelectedEvent(this.index);

  @override
  List<Object?> get props => [index];
}

class HomeForceGpsEvent extends HomeEvent {
  final bool enable;
  const HomeForceGpsEvent(this.enable);

  @override
  List<Object?> get props => [enable];
}
