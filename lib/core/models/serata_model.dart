import 'package:equatable/equatable.dart';

/// Modello per la tabella `eventi`.
/// Il nome del file rimane serata_model per compatibilità con gli import esistenti.
class SerataModel extends Equatable {
  final String id;
  final String clubId;
  final String nome;
  final DateTime data;
  final String? oraApertura;   // "22:00"
  final String? oraChiusura;   // "04:00"
  final int ingressiPrevisti;  // 0 = illimitato
  final int postiPrenotati;
  final String? locandinaUrl;
  final List<String> generiMusicali;
  final String stato;
  final double? prezzoIngresso;

  const SerataModel({
    required this.id,
    required this.clubId,
    required this.nome,
    required this.data,
    this.oraApertura,
    this.oraChiusura,
    this.ingressiPrevisti = 0,
    this.postiPrenotati = 0,
    this.locandinaUrl,
    this.generiMusicali = const [],
    this.stato = 'attivo',
    this.prezzoIngresso,
  });

  int? get postiDisponibili =>
      ingressiPrevisti > 0 ? ingressiPrevisti - postiPrenotati : null;

  /// Stringa di stato posti mostrata nella card/lista.
  String? get statusPosti {
    if (ingressiPrevisti == 0) return null; // illimitato
    final disp = ingressiPrevisti - postiPrenotati;
    if (disp <= 0) return 'Sold Out';
    if (disp <= (ingressiPrevisti * 0.2).ceil()) return 'Ultimi posti: $disp';
    return null;
  }

  String get orarioString {
    if (oraApertura != null && oraChiusura != null) {
      return '$oraApertura - $oraChiusura';
    }
    return '';
  }

  factory SerataModel.fromMap(Map<String, dynamic> m) {
    // ora_apertura può arrivare come "22:00:00" — tronchiamo a "22:00"
    String? _trim(String? s) => s != null && s.length >= 5 ? s.substring(0, 5) : s;

    return SerataModel(
      id: m['id'] as String,
      clubId: m['club_id'] as String,
      nome: m['nome'] as String,
      data: DateTime.parse(m['data'] as String),
      oraApertura: _trim(m['ora_apertura'] as String?),
      oraChiusura: _trim(m['ora_chiusura'] as String?),
      ingressiPrevisti: (m['ingressi_previsti'] as int?) ?? 0,
      postiPrenotati: (m['posti_prenotati'] as int?) ?? 0,
      locandinaUrl: m['locandina_url'] as String?,
      generiMusicali: (m['generi_musicali'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      stato: (m['stato'] as String?) ?? 'attivo',
      prezzoIngresso: (m['prezzo_ingresso'] as num?)?.toDouble(),
    );
  }

  @override
  List<Object?> get props => [
        id, clubId, nome, data,
        oraApertura, oraChiusura,
        ingressiPrevisti, postiPrenotati,
        locandinaUrl, generiMusicali, stato, prezzoIngresso,
      ];
}
