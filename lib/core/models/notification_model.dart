import 'package:equatable/equatable.dart';

/// Modello del dominio per la tabella `notifiche`.
///
/// Espone i campi mostrati da `NotificationsScreen` (titolo, messaggio, tipo,
/// flag letto, createdAt) più `relatedId` per il deep-link verso la risorsa
/// collegata (ordine, prevendita, evento).
class NotificationModel extends Equatable {
  final String id;
  final String utenteId;
  final String titolo;
  final String messaggio;
  final String tipo;
  final String? relatedId;
  /// Tipo di risorsa puntata dal deep-link (es. 'club', 'ordine').
  final String? linkTipo;
  final bool letto;
  /// Se valorizzato, la notifica è "dovuta" solo a partire da questo istante
  /// (scheduling lato server). Le notifiche future non vengono mostrate in-app.
  final DateTime? programmataPer;
  /// True quando la push è già stata inviata dal cron server-side.
  final bool inviata;
  final DateTime createdAt;

  const NotificationModel({
    required this.id,
    required this.utenteId,
    required this.titolo,
    required this.messaggio,
    required this.tipo,
    this.relatedId,
    this.linkTipo,
    this.letto = false,
    this.programmataPer,
    this.inviata = false,
    required this.createdAt,
  });

  factory NotificationModel.fromMap(Map<String, dynamic> map) {
    return NotificationModel(
      id: map['id'] as String,
      utenteId: map['utente_id'] as String,
      titolo: map['titolo'] as String,
      messaggio: map['messaggio'] as String,
      tipo: map['tipo'] as String,
      relatedId: map['link_id'] as String?,
      linkTipo: map['link_tipo'] as String?,
      letto: map['letta'] as bool? ?? false,
      programmataPer: DateTime.tryParse(map['programmata_per'] as String? ?? ''),
      inviata: map['inviata'] as bool? ?? false,
      createdAt: DateTime.tryParse(map['created_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'utente_id': utenteId,
      'titolo': titolo,
      'messaggio': messaggio,
      'tipo': tipo,
      'link_id': relatedId,
      'link_tipo': linkTipo,
      'letta': letto,
      'programmata_per': programmataPer?.toIso8601String(),
      'inviata': inviata,
    };
  }

  @override
  List<Object?> get props =>
      [id, utenteId, titolo, messaggio, tipo, relatedId, linkTipo, letto,
       programmataPer, inviata, createdAt];
}
