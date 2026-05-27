import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/age_calculator.dart';

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
  /// (nome, cognome, data_nascita) are all non-null.
  /// This is used to decide whether to redirect to CompleteProfileScreen.
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
    // Il profilo è completo solo se tutti i campi obbligatori sono presenti
    return data['nome'] != null &&
        data['cognome'] != null &&
        data['data_nascita'] != null;
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
  /// Should be called after a successful login.
  ///
  /// If the profile does not exist, it is created using the metadata
  /// stored in [auth.users] (which was populated during registration).
  Future<void> ensureProfileExists() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;

    if (user == null) {
      debugPrint('[UserProfileManager] No authenticated user.');
      return;
    }

    try {
      debugPrint('[UserProfileManager] Checking if profile exists for ${user.id}...');
      
      // Check if row exists
      final data = await client
          .from('utenti')
          .select('id')
          .eq('id', user.id)
          .maybeSingle();

      if (data != null) {
        debugPrint('[UserProfileManager] Profile exists. Proceeding to upsert via RPC.');
      }

      debugPrint('[UserProfileManager] Profile not found. Creating from metadata...');
      
      final metadata = user.userMetadata;
      if (metadata == null) {
        debugPrint('[UserProfileManager] No metadata found. Cannot create profile.');
        return;
      }

      // Extract data
      final nome = metadata['nome'] as String?;
      final cognome = metadata['cognome'] as String?;
      final dobString = metadata['data_nascita'] as String?;
      
      DateTime? dob;
      if (dobString != null) {
        dob = DateTime.tryParse(dobString);
      }

      bool isAdult = false;
      if (dob != null) {
        isAdult = AgeCalculator.isAdult(dob);
      }

      // Upsert solo su public.utenti; non inseriamo telefono qui
      await Supabase.instance.client.from('utenti').upsert({
        'id': user.id,
        'nome': nome,
        'cognome': cognome,
        'email': user.email,
        'data_nascita': dob?.toIso8601String(),
        'maggiorenne': isAdult,
      });

      debugPrint('[UserProfileManager] Profile created successfully.');

    } catch (e) {
      debugPrint('[UserProfileManager] Error ensuring profile: $e');
      // We don't rethrow because we don't want to block login flow,
      // but in a real app you might want to show an error or retry.
    }
  }
}
