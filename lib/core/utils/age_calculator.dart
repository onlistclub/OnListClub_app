/// Helper puro per il calcolo della maggiore età.
///
/// Espone `AgeCalculator.isAdult(dob)` (true se ≥ 18 anni). Usato in
/// registrazione e in `UserProfileManager.ensureProfileExists` per impostare
/// il flag `maggiorenne` su `utenti`. Nessuna dipendenza esterna.
class AgeCalculator {
  /// Età in anni compiuti alla data [currentDate] (default: oggi).
  static int age(DateTime dob, {DateTime? currentDate}) {
    final now = currentDate ?? DateTime.now();

    // Età preliminare basata solo sull'anno.
    int years = now.year - dob.year;

    // Decrementa se il compleanno di quest'anno non è ancora avvenuto
    // (mese corrente precedente, o stesso mese ma giorno precedente).
    if (now.month < dob.month ||
        (now.month == dob.month && now.day < dob.day)) {
      years--;
    }
    return years;
  }

  /// Calcola se una persona è maggiorenne (>= 18 anni)
  /// basandosi sulla data di nascita [dob] e una data di riferimento [currentDate] (opzionale, default: oggi).
  static bool isAdult(DateTime dob, {DateTime? currentDate}) =>
      age(dob, currentDate: currentDate) >= 18;
}
