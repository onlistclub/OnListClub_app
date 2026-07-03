import 'age_calculator.dart';

/// Gate d'età per gli eventi classificati 16+/18+ (`eventi.eta_minima`).
///
/// L'evento resta VISIBILE ovunque; il blocco scatta solo sulla schermata di
/// prenotazione, che viene "blurrata" con un messaggio. Qui vive solo la logica
/// pura (parsing dell'età minima + confronto con l'età utente).
class AgeGate {
  AgeGate._();

  /// Estrae l'età minima richiesta dalla stringa `eta_minima` del DB.
  /// Gestisce i formati reali: "16+", "18", "18+", "16+ con accompagnatore",
  /// "18+ Documento obbligatorio". Ritorna 0 se non c'è restrizione (null/testo
  /// senza numero come "Nessuna").
  static int requiredAge(String? etaMinima) {
    if (etaMinima == null) return 0;
    final m = RegExp(r'\d+').firstMatch(etaMinima);
    if (m == null) return 0;
    return int.tryParse(m.group(0)!) ?? 0;
  }

  /// Se l'utente ([dob]) è troppo giovane per l'evento ([etaMinima]), ritorna
  /// l'età minima richiesta (>0); altrimenti null (nessun blocco).
  ///
  /// In assenza di restrizione o di data di nascita non blocchiamo: non vogliamo
  /// impedire la prenotazione a un utente valido per un dato mancante.
  static int? blockedMinAge({
    required String? etaMinima,
    required DateTime? dob,
  }) {
    final required = requiredAge(etaMinima);
    if (required <= 0 || dob == null) return null;
    return AgeCalculator.age(dob) < required ? required : null;
  }
}
