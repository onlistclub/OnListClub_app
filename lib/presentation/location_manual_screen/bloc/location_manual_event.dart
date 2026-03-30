part of 'location_manual_bloc.dart';

abstract class LocationManualEvent extends Equatable {
  const LocationManualEvent();
  @override
  List<Object?> get props => [];
}

class SearchCittaEvent extends LocationManualEvent {
  final String query;
  const SearchCittaEvent(this.query);
  @override
  List<Object?> get props => [query];
}

class SelectCittaEvent extends LocationManualEvent {
  final CittaModel citta;
  const SelectCittaEvent(this.citta);
  @override
  List<Object?> get props => [citta];
}

class SubmitLocationEvent extends LocationManualEvent {
  const SubmitLocationEvent();
}
