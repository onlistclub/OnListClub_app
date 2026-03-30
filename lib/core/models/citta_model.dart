class CittaModel {
  final String idCitta;
  final String nomeCitta;

  const CittaModel({required this.idCitta, required this.nomeCitta});

  factory CittaModel.fromJson(Map<String, dynamic> json) {
    return CittaModel(
      idCitta: json['id_citta'] as String,
      nomeCitta: json['nome_citta'] as String,
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
