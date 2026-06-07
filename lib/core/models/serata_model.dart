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
  // Campi info serata (Figma 19) — opzionali, null se non popolati nel DB.
  final String? dressCode;
  final String? etaMinima;
  final String? soundSystem;
  final String? parcheggio;
  final List<LineupDj> lineup;

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
    this.dressCode,
    this.etaMinima,
    this.soundSystem,
    this.parcheggio,
    this.lineup = const [],
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
    // Gestione vecchi e nuovi campi
    String? _trim(String? s) => s != null && s.length >= 5 ? s.substring(0, 5) : s;

    final inizioTs = m['inizio_evento'] as String?;
    final fineTs = m['fine_evento'] as String?;

    DateTime? parsedInizio =
        inizioTs != null ? DateTime.tryParse(inizioTs)?.toLocal() : null;
    DateTime? parsedData = m['data'] != null
        ? DateTime.tryParse(m['data'] as String)
        : null;
    final startDate = parsedInizio ?? parsedData ?? DateTime.now();

    final oraAp = parsedInizio != null
        ? "${startDate.hour.toString().padLeft(2, '0')}:${startDate.minute.toString().padLeft(2, '0')}"
        : _trim(m['ora_apertura'] as String?);

    String? oraCh = _trim(m['ora_chiusura'] as String?);
    final parsedFine =
        fineTs != null ? DateTime.tryParse(fineTs)?.toLocal() : null;
    if (parsedFine != null) {
      oraCh = "${parsedFine.hour.toString().padLeft(2, '0')}:${parsedFine.minute.toString().padLeft(2, '0')}";
    }

    return SerataModel(
      id: m['id'] as String,
      clubId: m['club_id'] as String,
      nome: m['nome'] as String,
      data: startDate,
      oraApertura: oraAp,
      oraChiusura: oraCh,
      ingressiPrevisti: (m['ingressi_previsti'] as int?) ?? 0,
      postiPrenotati: (m['posti_prenotati'] as int?) ?? 0,
      locandinaUrl: m['locandina_url'] as String?,
      generiMusicali: (m['generi_musicali'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      stato: (m['stato'] as String?) ?? 'attivo',
      prezzoIngresso: (m['prezzo_ingresso'] as num?)?.toDouble(),
      dressCode: m['dress_code'] as String?,
      etaMinima: m['eta_minima'] as String?,
      soundSystem: m['sound_system'] as String?,
      parcheggio: m['parcheggio'] as String?,
      lineup: (m['lineup'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .map(LineupDj.fromMap)
              .toList() ??
          const [],
    );
  }

  @override
  List<Object?> get props => [
        id, clubId, nome, data,
        oraApertura, oraChiusura,
        ingressiPrevisti, postiPrenotati,
        locandinaUrl, generiMusicali, stato, prezzoIngresso,
        dressCode, etaMinima, soundSystem, parcheggio, lineup,
      ];
}

/// Singolo DJ del line-up di una serata (Figma 19).
class LineupDj extends Equatable {
  final String nome;
  final String? iniziali;
  final String? stage;
  final String? oraInizio;
  final String? oraFine;
  final bool headliner;

  const LineupDj({
    required this.nome,
    this.iniziali,
    this.stage,
    this.oraInizio,
    this.oraFine,
    this.headliner = false,
  });

  String get orarioString {
    if (oraInizio != null && oraFine != null) return '$oraInizio - $oraFine';
    if (oraInizio != null) return oraInizio!;
    return '';
  }

  factory LineupDj.fromMap(Map<String, dynamic> m) {
    return LineupDj(
      nome: (m['nome'] ?? '') as String,
      iniziali: m['iniziali'] as String?,
      stage: m['stage'] as String?,
      oraInizio: m['ora_inizio'] as String?,
      oraFine: m['ora_fine'] as String?,
      headliner: (m['headliner'] as bool?) ?? false,
    );
  }

  @override
  List<Object?> get props => [nome, iniziali, stage, oraInizio, oraFine, headliner];
}
