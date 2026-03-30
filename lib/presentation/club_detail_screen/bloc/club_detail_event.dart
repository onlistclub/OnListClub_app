part of 'club_detail_bloc.dart';

abstract class ClubDetailEvent extends Equatable {
  const ClubDetailEvent();

  @override
  List<Object?> get props => [];
}

class ClubDetailInitialEvent extends ClubDetailEvent {}

class ToggleFavoriteEvent extends ClubDetailEvent {}

class HideFavoriteBadgeEvent extends ClubDetailEvent {}

class BottomNavItemSelectedEvent extends ClubDetailEvent {
  final int index;

  const BottomNavItemSelectedEvent(this.index);

  @override
  List<Object?> get props => [index];
}
