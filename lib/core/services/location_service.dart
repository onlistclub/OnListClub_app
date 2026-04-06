import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/citta_model.dart';

class LocationService {
  static const String _remindLaterKey    = 'location_remind_later_at';
  static const String _idCittaKey        = 'user_id_citta';
  static const String _nomeCittaKey      = 'user_citta';
  static const String _latKey            = 'user_city_lat';
  static const String _lngKey            = 'user_city_lng';
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
    if (permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse) {
      return false;
    }

    final prefs = await SharedPreferences.getInstance();
    final ts = prefs.getInt(_remindLaterKey);
    if (ts != null) {
      final daysSince = DateTime.now()
          .difference(DateTime.fromMillisecondsSinceEpoch(ts))
          .inDays;
      if (daysSince < _remindIntervalDays) return false;
    }
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
    if (ts == null) return null;
    final age = DateTime.now()
        .difference(DateTime.fromMillisecondsSinceEpoch(ts))
        .inMinutes;
    if (age >= _gpsCacheMinutes) return null;
    final lat = prefs.getDouble(_gpsLatKey);
    final lng = prefs.getDouble(_gpsLngKey);
    if (lat == null || lng == null) return null;
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

    final response = await Supabase.instance.client
        .from('citta')
        .select('id_citta, nome_citta, lat, lng')
        .ilike('nome_citta', '$q%')
        .order('nome_citta')
        .limit(8);

    return (response as List)
        .map((e) => CittaModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ---------------------------------------------------------------------------
  // Manual location persistence
  // ---------------------------------------------------------------------------

  static Future<void> saveManualLocation(CittaModel citta) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_idCittaKey,   citta.idCitta);
    await prefs.setString(_nomeCittaKey, citta.nomeCitta);
    if (citta.lat != null) await prefs.setDouble(_latKey, citta.lat!);
    if (citta.lng != null) await prefs.setDouble(_lngKey, citta.lng!);

    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(data: {
          'id_citta':   citta.idCitta,
          'nome_citta': citta.nomeCitta,
        }),
      );
    } catch (_) {}
  }

  static Future<CittaModel?> getSavedLocation() async {
    final prefs = await SharedPreferences.getInstance();
    final id   = prefs.getString(_idCittaKey);
    final nome = prefs.getString(_nomeCittaKey);
    if (id == null || nome == null) return null;
    final lat = prefs.getDouble(_latKey);
    final lng = prefs.getDouble(_lngKey);
    return CittaModel(idCitta: id, nomeCitta: nome, lat: lat, lng: lng);
  }
}
