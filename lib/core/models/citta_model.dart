/// Modello del dominio per la tabella `citta`.
///
/// Espone id, nome e coordinate della città. Usata dalla schermata di selezione
/// manuale (`LocationManualScreen`) e come fallback geografico in `ClubService`
/// quando un locale non ha lat/lng propri.
class CittaModel {
  final String idCitta;
  final String nomeCitta;
  final double? lat;
  final double? lng;

  const CittaModel({
    required this.idCitta,
    required this.nomeCitta,
    this.lat,
    this.lng,
  });

  factory CittaModel.fromJson(Map<String, dynamic> json) {
    return CittaModel(
      idCitta: json['id_citta'] as String,
      nomeCitta: json['nome_citta'] as String,
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is CittaModel && other.idCitta == idCitta;

  @override
  int get hashCode => idCitta.hashCode;

  @override
  String toString() => nomeCitta;
}
