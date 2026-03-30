part of 'location_permission_bloc.dart';

class LocationPermissionState extends Equatable {
  final bool isLoading;
  final bool isPermissionGranted;
  final bool goToManualEntry;
  final String? errorMessage;

  const LocationPermissionState({
    this.isLoading = false,
    this.isPermissionGranted = false,
    this.goToManualEntry = false,
    this.errorMessage,
  });

  LocationPermissionState copyWith({
    bool? isLoading,
    bool? isPermissionGranted,
    bool? goToManualEntry,
    String? errorMessage,
  }) {
    return LocationPermissionState(
      isLoading: isLoading ?? this.isLoading,
      isPermissionGranted: isPermissionGranted ?? this.isPermissionGranted,
      goToManualEntry: goToManualEntry ?? this.goToManualEntry,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props =>
      [isLoading, isPermissionGranted, goToManualEntry, errorMessage];
}
