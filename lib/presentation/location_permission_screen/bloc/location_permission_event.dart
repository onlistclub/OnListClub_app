part of 'location_permission_bloc.dart';

abstract class LocationPermissionEvent extends Equatable {
  const LocationPermissionEvent();
  @override
  List<Object?> get props => [];
}

class LocationPermissionInitialEvent extends LocationPermissionEvent {
  const LocationPermissionInitialEvent();
}

class OpenSettingsEvent extends LocationPermissionEvent {
  const OpenSettingsEvent();
}

class RemindLaterEvent extends LocationPermissionEvent {
  const RemindLaterEvent();
}
