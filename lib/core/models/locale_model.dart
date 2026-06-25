import 'package:equatable/equatable.dart';

/// Modello del dominio per la tabella `locali` (club/discoteca).
///
/// Espone i campi mostrati dalle schermate di scoperta (Home, NearbyClubs,
/// ClubDetail): nome, indirizzo, foto, generi musicali, prezzo indicativo,
/// coordinate. `nomeCitta` arriva dal JOIN con `citta` in `ClubService`.
class LocaleModel extends Equatable {
  final String id;
  final String nome;
  final String? indirizzo;
  /// Nome della città (da JOIN con citta.nome_citta)
  final String? nomeCitta;
  /// FK verso citta.id_citta
  final String? idCitta;
  final String? logoUrl;
  final String? fotoUrl;
  final int famosita;
  final List<String> generiMusicali;
  final int prezzoIndicativo;
  final String? linkTripadvisor;
  final String? descrizione;
  final double? lat;
  final double? lng;
  /// Orario standard di apertura del locale (es. 22:00), proveniente da
  /// `locali.orario_apertura` (TIME). Nullable: i locali senza orario fisso
  /// non mostrano la riga nella UI.
  final String? orarioApertura;
  /// Orario standard di chiusura del locale (es. 04:00). Coppia con
  /// [orarioApertura].
  final String? orarioChiusura;

  const LocaleModel({
    required this.id,
    required this.nome,
    this.indirizzo,
    this.nomeCitta,
    this.idCitta,
    this.logoUrl,
    this.fotoUrl,
    this.famosita = 0,
    this.generiMusicali = const [],
    this.prezzoIndicativo = 1,
    this.linkTripadvisor,
    this.descrizione,
    this.lat,
    this.lng,
    this.orarioApertura,
    this.orarioChiusura,
  });

  String get prezzoString => '€' * prezzoIndicativo;

  String get generiString => generiMusicali.join(' - ');

  /// Indirizzo completo: "Via X, Città"
  String get indirizzoCompleto {
    final parts = <String>[
      if (indirizzo != null && indirizzo!.isNotEmpty) indirizzo!,
      if (nomeCitta != null && nomeCitta!.isNotEmpty) nomeCitta!,
    ];
    return parts.join(', ');
  }

  /// Orario formato display "HH:mm - HH:mm" (es. "22:00 - 04:00").
  /// Stringa vuota se manca anche uno solo dei due valori.
  String get orarioString {
    if (orarioApertura == null || orarioChiusura == null) return '';
    return '${_formatTime(orarioApertura!)} - ${_formatTime(orarioChiusura!)}';
  }

  /// Postgres TIME arriva come "HH:mm:ss" → tagliamo i secondi.
  static String _formatTime(String t) =>
      t.length >= 5 ? t.substring(0, 5) : t;

  factory LocaleModel.fromMap(Map<String, dynamic> m) {
    // Supabase JOIN restituisce citta come oggetto annidato:
    // {"nome_citta": "Milano", "lat": 45.46, "lng": 9.19}
    final cittaObj = m['citta'] as Map<String, dynamic>?;

    // Usa le coordinate del locale se presenti, altrimenti fallback alle
    // coordinate della città (JOIN). Questo permette di trovare i locali
    // nel raggio anche se non hanno lat/lng propri nella tabella.
    final lat = (m['lat'] as num?)?.toDouble() ??
        (cittaObj?['lat'] as num?)?.toDouble();
    final lng = (m['lng'] as num?)?.toDouble() ??
        (cittaObj?['lng'] as num?)?.toDouble();

    return LocaleModel(
      id: m['id'] as String,
      nome: m['nome'] as String,
      indirizzo: m['indirizzo'] as String?,
      nomeCitta: cittaObj?['nome_citta'] as String?,
      idCitta: m['id_citta'] as String?,
      logoUrl: m['logo_url'] as String?,
      fotoUrl: m['foto_url'] as String?,
      famosita: (m['famosita'] as int?) ?? 0,
      generiMusicali: (m['generi_musicali'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      prezzoIndicativo: (m['prezzo_indicativo'] as int?) ?? 1,
      linkTripadvisor: m['link_tripadvisor'] as String?,
      descrizione: m['descrizione'] as String?,
      lat: lat,
      lng: lng,
      orarioApertura: m['orario_apertura']?.toString(),
      orarioChiusura: m['orario_chiusura']?.toString(),
    );
  }

  @override
  List<Object?> get props => [
        id, nome, indirizzo, nomeCitta, idCitta, logoUrl, fotoUrl,
        famosita, generiMusicali, prezzoIndicativo,
        linkTripadvisor, descrizione, lat, lng,
        orarioApertura, orarioChiusura,
      ];
}
