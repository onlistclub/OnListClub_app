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

/// L'app è tornata in primo piano: ricontrolla il permesso.
///
/// Serve per chi tocca "Apri Impostazioni", concede il permesso nelle
/// impostazioni di sistema e torna indietro: il dialogo nativo non c'è stato,
/// quindi nessuna risposta è mai arrivata all'app e senza questo controllo la
/// schermata resterebbe a chiedere un permesso che ormai è concesso.
class RicontrollaPermessoEvent extends LocationPermissionEvent {
  const RicontrollaPermessoEvent();
}
