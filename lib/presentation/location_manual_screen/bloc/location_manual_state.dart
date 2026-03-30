part of 'location_manual_bloc.dart';

class LocationManualState extends Equatable {
  final String           query;
  final List<CittaModel> cities;
  final CittaModel?      selectedCitta;
  final bool             isLoadingCities;
  final bool             isLoading;
  final bool             isSuccess;
  final String?          errorMessage;

  const LocationManualState({
    this.query           = '',
    this.cities          = const [],
    this.selectedCitta,
    this.isLoadingCities = false,
    this.isLoading       = false,
    this.isSuccess       = false,
    this.errorMessage,
  });

  LocationManualState copyWith({
    String?           query,
    List<CittaModel>? cities,
    CittaModel?       selectedCitta,
    bool?             isLoadingCities,
    bool?             isLoading,
    bool?             isSuccess,
    String?           errorMessage,
    bool              clearSelected = false,
  }) {
    return LocationManualState(
      query:           query           ?? this.query,
      cities:          cities          ?? this.cities,
      selectedCitta:   clearSelected   ? null : (selectedCitta ?? this.selectedCitta),
      isLoadingCities: isLoadingCities ?? this.isLoadingCities,
      isLoading:       isLoading       ?? this.isLoading,
      isSuccess:       isSuccess       ?? this.isSuccess,
      errorMessage:    errorMessage,
    );
  }

  @override
  List<Object?> get props =>
      [query, cities, selectedCitta, isLoadingCities, isLoading, isSuccess, errorMessage];
}
