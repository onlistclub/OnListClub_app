import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'register_service.dart';

/// Servizio singleton per il profilo utente in `public.utenti`.
///
/// Espone le operazioni che il resto dell'app fa sul profilo: verifica
/// completezza dei dati obbligatori, lettura/scrittura del raggio di ricerca,
/// upsert post-OAuth a partire dai metadata di `auth.users`. Dipende da
/// Supabase e da `AgeCalculator` per il flag `maggiorenne`.
class UserProfileManager {
  static final UserProfileManager _instance = UserProfileManager._internal();
  factory UserProfileManager() => _instance;
  UserProfileManager._internal();

  /// Returns true if the user has a complete profile in `public.utenti`.
  /// A profile is considered complete when the required fields
  /// (nome, cognome, data_nascita) are all non-null AND the user has at least
  /// one phone number in `utenti_numeri_telefono`.
  /// This is used to decide whether to redirect to CompleteProfileScreen
  /// (anche dopo il login OAuth Google/Apple, dove il telefono non arriva dal
  /// provider e va raccolto nel form di completamento).
  Future<bool> isProfileComplete() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) return false;
    final data = await client
        .from('utenti')
        .select('nome, cognome, data_nascita')
        .eq('id', user.id)
        .maybeSingle();
    if (data == null) return false;
    // Prima i campi base sulla riga utente: se mancano, è inutile interrogare
    // anche la tabella dei telefoni.
    final hasBaseFields = data['nome'] != null &&
        data['cognome'] != null &&
        data['data_nascita'] != null;
    if (!hasBaseFields) return false;
    // Il telefono è obbligatorio ma vive in una tabella separata (1:N), senza
    // FK dichiarata: lo verifichiamo con una query mirata. La colonna
    // `is_verified` esiste già qui: in futuro il gate potrà richiedere il
    // numero verificato via OTP, oggi basta che esista.
    final phone = await client
        .from('utenti_numeri_telefono')
        .select('id')
        .eq('id_utente', user.id)
        .limit(1)
        .maybeSingle();
    return phone != null;
  }

  /// Legge il raggio di ricerca in km salvato nel profilo utente.
  /// Restituisce 20 come default se non impostato o se la colonna non esiste ancora.
  Future<int> getRaggioKm() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) return 20;
    try {
      final data = await client
          .from('utenti')
          .select('raggio_km')
          .eq('id', user.id)
          .maybeSingle();
      return (data?['raggio_km'] as int?) ?? 20;
    } catch (_) {
      return 20;
    }
  }

  /// Salva il raggio di ricerca in km nel profilo utente.
  Future<void> saveRaggioKm(int km) async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) return;
    await client.from('utenti').update({'raggio_km': km}).eq('id', user.id);
  }

  /// Ensures that the user profile exists in the `public.utenti` table.
  /// Should be called after a successful login / email confirmation.
  ///
  /// Questo è il punto della "scrittura post-conferma": al momento del signUp
  /// (con "Confirm email" attivo) non c'è sessione e `auth.uid()` è null, quindi
  /// il profilo NON viene scritto lì. Qui invece la sessione è attiva, perciò la
  /// RPC atomica `register_user_transaction` passa la guardia di sicurezza e
  /// crea in un'unica transazione la riga `utenti` + il telefono in
  /// `utenti_numeri_telefono`, a partire dai metadata salvati su `auth.users`
  /// durante la registrazione.
  Future<void> ensureProfileExists() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;

    if (user == null) {
      debugPrint('[UserProfileManager] No authenticated user.');
      return;
    }

    try {
      debugPrint('[UserProfileManager] Checking if profile exists for ${user.id}...');

      // Se la riga esiste già, niente da fare: evitiamo riscritture a ogni login.
      final existing = await client
          .from('utenti')
          .select('id')
          .eq('id', user.id)
          .maybeSingle();
      if (existing != null) {
        debugPrint('[UserProfileManager] Profile already exists. Nothing to do.');
        return;
      }

      debugPrint('[UserProfileManager] Profile not found. Creating from metadata...');

      final metadata = user.userMetadata;
      if (metadata == null) {
        debugPrint('[UserProfileManager] No metadata found. Cannot create profile.');
        return;
      }

      final nome = metadata['nome'] as String?;
      final cognome = metadata['cognome'] as String?;
      final dobString = metadata['data_nascita'] as String?;
      final telefono = metadata['telefono'] as String?;
      final countryIso = metadata['phone_country_iso'] as String?;

      final dob = dobString != null ? DateTime.tryParse(dobString) : null;

      if (nome == null || cognome == null || dob == null || telefono == null) {
        debugPrint(
            '[UserProfileManager] Metadata incompleti (nome/cognome/dob/telefono). Skip creazione profilo.');
        return;
      }

      // Scrittura atomica utente + telefono (E.164) via RPC SECURITY DEFINER.
      // Ora `auth.uid()` == user.id, quindi la guardia passa e non c'è più
      // l'errore "Forbidden: caller is not the target user".
      await RegisterService().registerAtomic(
        userId: user.id,
        email: user.email ?? '',
        nome: nome,
        cognome: cognome,
        dataNascita: dob,
        telefono: telefono,
        countryIso: countryIso,
      );

      debugPrint('[UserProfileManager] Profile created successfully (via RPC).');
    } catch (e) {
      debugPrint('[UserProfileManager] Error ensuring profile: $e');
      // Non rilanciamo: non vogliamo bloccare il flusso di login/verifica.
    }
  }
}
