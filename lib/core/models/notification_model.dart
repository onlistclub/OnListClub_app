import 'package:equatable/equatable.dart';

class NotificationModel extends Equatable {
  final String id;
  final String utenteId;
  final String titolo;
  final String messaggio;
  final String tipo;
  final String? relatedId;
  final bool letto;
  final DateTime createdAt;

  const NotificationModel({
    required this.id,
    required this.utenteId,
    required this.titolo,
    required this.messaggio,
    required this.tipo,
    this.relatedId,
    this.letto = false,
    required this.createdAt,
  });

  factory NotificationModel.fromMap(Map<String, dynamic> map) {
    return NotificationModel(
      id: map['id'] as String,
      utenteId: map['utente_id'] as String,
      titolo: map['titolo'] as String,
      messaggio: map['messaggio'] as String,
      tipo: map['tipo'] as String,
      relatedId: map['related_id'] as String?,
      letto: map['letto'] as bool? ?? false,
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
      'related_id': relatedId,
      'letto': letto,
    };
  }

  @override
  List<Object?> get props => [id, utenteId, titolo, messaggio, tipo, relatedId, letto, createdAt];
}
