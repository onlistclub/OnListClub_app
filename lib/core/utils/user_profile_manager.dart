import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'age_calculator.dart';

class UserProfileManager {
  static final UserProfileManager _instance = UserProfileManager._internal();
  factory UserProfileManager() => _instance;
  UserProfileManager._internal();

  /// Ensures that the user profile exists in the `public.users` table.
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
          .from('users')
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
      final _telefono = metadata['telefono'] as String?;
      final _phoneIso = metadata['phone_country_iso'] as String?;
      
      DateTime? dob;
      if (dobString != null) {
        dob = DateTime.tryParse(dobString);
      }

      bool isAdult = false;
      if (dob != null) {
        isAdult = AgeCalculator.isAdult(dob);
      }

      // Upsert solo su public.users; non inseriamo telefono qui
      await Supabase.instance.client.from('users').upsert({
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
