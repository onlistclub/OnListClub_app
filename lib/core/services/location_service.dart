import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/citta_model.dart';

/// Servizio di risoluzione della posizione utente.
///
/// Combina tre fonti: GPS (geolocator), selezione manuale (con geocoding inverso)
/// e cache su `shared_preferences`. Espone anche flag persistenti come
/// `isGpsForced` letto sincronicamente all'avvio in `main.dart`. Dipende da
/// `CittaModel` per la lista città di Supabase.
class LocationService {
  static const String _remindLaterKey    = 'location_remind_later_at';
  static const String _idCittaKey        = 'id_utente_citta';
  static const String _nomeCittaKey      = 'user_citta';
  static const String _latKey            = 'user_city_lat';
  static const String _lngKey            = 'user_city_lng';
  static const String _gpsForcedKey      = 'gps_forced';

  /// Cache in memoria del flag GPS forzato. Letto sincronicamente dai chiamanti
  /// (UI, BLoC). Le scritture vengono persistite in SharedPreferences in modo
  /// fire-and-forget; per ripristinare il valore al boot dell'app chiamare
  /// [loadGpsForcedFromPrefs] da `main()`.
  static bool _isGpsForcedCached = false;
  static bool get isGpsForced => _isGpsForcedCached;
  static set isGpsForced(bool value) {
    _isGpsForcedCached = value;
    SharedPreferences.getInstance().then(
      (p) => p.setBool(_gpsForcedKey, value),
    );
  }

  /// Ripristina il flag GPS forzato dal disco. Chiamare al boot.
  static Future<void> loadGpsForcedFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _isGpsForcedCached = prefs.getBool(_gpsForcedKey) ?? false;
  }

  static const int    _remindIntervalDays = 7;

  // Cache GPS device position
  static const String _gpsLatKey        = 'gps_cached_lat';
  static const String _gpsLngKey        = 'gps_cached_lng';
  static const String _gpsTimestampKey  = 'gps_cached_at';
  static const int    _gpsCacheMinutes  = 60;

  // ---------------------------------------------------------------------------
  // GPS permission helpers
  // ---------------------------------------------------------------------------

  static Future<LocationPermission> checkPermission() =>
      Geolocator.checkPermission();

  static Future<LocationPermission> requestPermission() =>
      Geolocator.requestPermission();

  static Future<bool> openSettings() => Geolocator.openAppSettings();

  /// Torna true se bisogna mostrare la schermata di richiesta posizione.
  static Future<bool> shouldShowLocationPrompt() async {
    final permission = await Geolocator.checkPermission();
    debugPrint('[LocationService] 🔑 shouldShowLocationPrompt — permission=$permission');
    if (permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse) {
      debugPrint('[LocationService] ✅ Permesso già concesso, non mostrare prompt');
      return false;
    }

    final prefs = await SharedPreferences.getInstance();
    final ts = prefs.getInt(_remindLaterKey);
    if (ts != null) {
      final daysSince = DateTime.now()
          .difference(DateTime.fromMillisecondsSinceEpoch(ts))
          .inDays;
      debugPrint('[LocationService] ⏰ Remind later: $daysSince giorni fa (intervallo=$_remindIntervalDays)');
      if (daysSince < _remindIntervalDays) return false;
    }
    debugPrint('[LocationService] 📱 Mostra prompt posizione');
    return true;
  }

  // ---------------------------------------------------------------------------
  // GPS position cache
  // ---------------------------------------------------------------------------

  /// Salva la posizione GPS ottenuta dal dispositivo con timestamp corrente.
  static Future<void> saveGpsPosition(double lat, double lng) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_gpsLatKey, lat);
    await prefs.setDouble(_gpsLngKey, lng);
    await prefs.setInt(
        _gpsTimestampKey, DateTime.now().millisecondsSinceEpoch);
  }

  /// Restituisce la posizione GPS in cache se è più recente di [_gpsCacheMinutes].
  /// Restituisce null se la cache è scaduta o assente.
  static Future<({double lat, double lng})?> getCachedGpsPosition() async {
    final prefs = await SharedPreferences.getInstance();
    final ts = prefs.getInt(_gpsTimestampKey);
    if (ts == null) {
      debugPrint('[LocationService] 📡 GPS cache: nessuna cache presente');
      return null;
    }
    final age = DateTime.now()
        .difference(DateTime.fromMillisecondsSinceEpoch(ts))
        .inMinutes;
    if (age >= _gpsCacheMinutes) {
      debugPrint('[LocationService] 📡 GPS cache: scaduta ($age min, max=$_gpsCacheMinutes)');
      return null;
    }
    final lat = prefs.getDouble(_gpsLatKey);
    final lng = prefs.getDouble(_gpsLngKey);
    if (lat == null || lng == null) return null;
    debugPrint('[LocationService] 📡 GPS cache: valida ($age min) lat=$lat, lng=$lng');
    return (lat: lat, lng: lng);
  }

  static Future<void> saveRemindLaterTimestamp() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_remindLaterKey, DateTime.now().millisecondsSinceEpoch);
  }

  // ---------------------------------------------------------------------------
  // City search (Supabase)
  // ---------------------------------------------------------------------------

  /// Cerca città per prefisso (ILIKE 'query%'), max 8 risultati.
  static Future<List<CittaModel>> searchCitta(String query) async {
    final q = query.trim();
    if (q.length < 2) return [];

    List<CittaModel> results = [];

    // 1. Supabase (Tabella citta)
    try {
      final responseCitta = await Supabase.instance.client
          .from('citta')
          .select('id_citta, nome_citta, lat, lng')
          .ilike('nome_citta', '$q%')
          .order('nome_citta')
          .limit(5);

      results.addAll((responseCitta as List).map((e) => CittaModel.fromJson(e as Map<String, dynamic>)));
    } catch (e) {
      debugPrint('[LocationService] searchCitta - query citta fallita: $e');
    }

    // 2. Supabase (Tabella posti_famosi)
    if (results.length < 8) {
      try {
        final responsePosti = await Supabase.instance.client
            .from('posti_famosi')
            .select('id, nome, lat, lng')
            .ilike('nome', '%$q%')
            .limit(8 - results.length);

        results.addAll((responsePosti as List).map((e) => CittaModel(
          idCitta: e['id'] as String,
          nomeCitta: '${e['nome']}',
          lat: (e['lat'] as num?)?.toDouble(),
          lng: (e['lng'] as num?)?.toDouble(),
        )));
      } catch (e) {
        debugPrint('[LocationService] searchCitta - query posti_famosi fallita: $e');
      }
    }

    // 2. Fallback su Geocoding (se non trova nulla o per POI specifici)
    if (results.isEmpty) {
      try {
        final locs = await locationFromAddress(q).timeout(const Duration(seconds: 4));
        if (locs.isNotEmpty) {
          final loc = locs.first;
          results.add(CittaModel(
            idCitta: 'custom_poi',
            nomeCitta: q, // il testo inserito dall'utente fungerà da nome
            lat: loc.latitude,
            lng: loc.longitude,
          ));
        }
      } catch (e) {
        debugPrint('[LocationService] searchCitta - geocoding fallback fallito: $e');
      }
    }

    return results;
  }

  // ---------------------------------------------------------------------------
  // Manual location persistence
  // ---------------------------------------------------------------------------

  static Future<void> saveManualLocation(CittaModel citta) async {
    debugPrint('[LocationService] 💾 saveManualLocation: ${citta.nomeCitta} (lat=${citta.lat}, lng=${citta.lng})');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_idCittaKey,   citta.idCitta);
    await prefs.setString(_nomeCittaKey, citta.nomeCitta);
    if (citta.lat != null) {
      await prefs.setDouble(_latKey, citta.lat!);
    } else {
      await prefs.remove(_latKey);
    }
    if (citta.lng != null) {
      await prefs.setDouble(_lngKey, citta.lng!);
    } else {
      await prefs.remove(_lngKey);
    }

    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(data: {
          'id_citta':   citta.idCitta,
          'nome_citta': citta.nomeCitta,
        }),
      );
    } catch (e) {
      debugPrint('[LocationService] saveManualLocation - updateUser fallito: $e');
    }
  }

  static Future<CittaModel?> getSavedLocation() async {
    final prefs = await SharedPreferences.getInstance();
    final id   = prefs.getString(_idCittaKey);
    String? nome = prefs.getString(_nomeCittaKey);
    if (nome != null) nome = nome.replaceAll('📍', '').trim();
    if (id == null || nome == null) {
      debugPrint('[LocationService] 🏙️ getSavedLocation: nessuna città salvata');
      return null;
    }
    final lat = prefs.getDouble(_latKey);
    final lng = prefs.getDouble(_lngKey);
    debugPrint('[LocationService] 🏙️ getSavedLocation: $nome (lat=$lat, lng=$lng)');
    return CittaModel(idCitta: id, nomeCitta: nome, lat: lat, lng: lng);
  }
}
