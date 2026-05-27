/// Helper puro per il calcolo della maggiore età.
///
/// Espone `AgeCalculator.isAdult(dob)` (true se ≥ 18 anni). Usato in
/// registrazione e in `UserProfileManager.ensureProfileExists` per impostare
/// il flag `maggiorenne` su `utenti`. Nessuna dipendenza esterna.
class AgeCalculator {
  /// Calcola se una persona è maggiorenne (>= 18 anni)
  /// basandosi sulla data di nascita [dob] e una data di riferimento [currentDate] (opzionale, default: oggi).
  static bool isAdult(DateTime dob, {DateTime? currentDate}) {
    final now = currentDate ?? DateTime.now();
    
    // Calcola l'età preliminare basata solo sull'anno
    int age = now.year - dob.year;
    
    // Verifica se il compleanno è già avvenuto quest'anno
    // Se il mese corrente è precedente al mese di nascita
    // O se siamo nello stesso mese ma il giorno corrente è precedente al giorno di nascita
    // Allora l'età deve essere decrementata di 1
    if (now.month < dob.month || 
        (now.month == dob.month && now.day < dob.day)) {
      age--;
    }
    
    return age >= 18;
  }
}
