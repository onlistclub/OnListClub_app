import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/locale_model.dart';
import '../models/serata_model.dart';

/// SELECT con JOIN verso citta per ottenere nome_citta e coordinate città.
/// Le coordinate città servono come fallback per locali senza lat/lng propri.
/// Colonne esplicite (solo quelle lette da LocaleModel.fromMap) invece di `*`:
/// evita di scaricare campi inutili (telefono, email, created_at) sulle liste.
const _localiSelect =
    'id, nome, indirizzo, id_citta, logo_url, foto_url, famosita, '
    'generi_musicali, prezzo_indicativo, link_tripadvisor, descrizione, '
    'lat, lng, citta(nome_citta, lat, lng)';

/// Accesso a `locali` ed `eventi` su Supabase.
///
/// Espone i fetch usati da Home, NearbyClubs e ClubDetail: lista locali per città,
/// dettaglio singolo locale, serate del locale, filtri per raggio km. Restituisce
/// sempre `LocaleModel` / `SerataModel` già mappati.
class ClubService {
  static SupabaseClient get _client => Supabase.instance.client;

  /// Recupera un locale per ID (include nome città via JOIN).
  static Future<LocaleModel?> getLocaleById(String id) async {
    final response = await _client
        .from('locali')
        .select(_localiSelect)
        .eq('id', id)
        .maybeSingle();
    if (response == null) return null;
    return LocaleModel.fromMap(response);
  }

  /// Recupera l'evento attivo di oggi per un locale.
  static Future<SerataModel?> getEventoOggi(String clubId) async {
    final oggi = DateTime.now().toIso8601String().substring(0, 10);
    final oggiInizio = '${oggi}T00:00:00Z';
    final domaniInizio = DateTime.now().add(const Duration(days: 1)).toIso8601String().substring(0, 10) + 'T00:00:00Z';
    
    final response = await _client
        .from('eventi')
        .select()
        .eq('club_id', clubId)
        .gte('inizio_evento', oggiInizio)
        .lt('inizio_evento', domaniInizio)
        .eq('stato', 'attivo')
        .order('inizio_evento')
        .limit(1)
        .maybeSingle();
    if (response == null) return null;
    return SerataModel.fromMap(response);
  }

  /// Recupera tutti gli eventi dal giorno odierno in poi per un locale.
  static Future<List<SerataModel>> getUpcomingEventi(
    String clubId, {
    int limit = 10,
  }) async {
    final oggi = DateTime.now().toIso8601String().substring(0, 10);
    final oggiInizio = '${oggi}T00:00:00Z';
    
    final response = await _client
        .from('eventi')
        .select()
        .eq('club_id', clubId)
        .eq('stato', 'attivo')
        .gte('inizio_evento', oggiInizio)
        .order('inizio_evento')
        .limit(limit);
    return (response as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .map((m) => SerataModel.fromMap(m))
        .toList();
  }

  /// Recupera il locale più vicino alle coordinate utente (Haversine).
  /// Se lat/lng sono null o nessun locale ha coordinate, fallback su famosità.
  static Future<LocaleModel?> getLocaleVicino(
    double? lat,
    double? lng,
  ) async {
    if (lat == null || lng == null) {
      final clubs = await getLocaliByFamosita(limit: 1);
      return clubs.isEmpty ? null : clubs.first;
    }

    final response = await _client
        .from('locali')
        .select(_localiSelect);

    final locali = (response as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .map((m) => LocaleModel.fromMap(m))
        .where((l) => l.lat != null && l.lng != null)
        .toList();

    if (locali.isEmpty) {
      final clubs = await getLocaliByFamosita(limit: 1);
      return clubs.isEmpty ? null : clubs.first;
    }

    locali.sort((a, b) {
      final da = _haversineKm(lat, lng, a.lat!, a.lng!);
      final db = _haversineKm(lat, lng, b.lat!, b.lng!);
      return da.compareTo(db);
    });
    return locali.first;
  }

  /// Recupera tutti i locali ordinati per distanza (Haversine) dall'utente.
  /// Se lat/lng sono null, fallback su famosità.
  /// I locali senza coordinate proprie usano le coordinate della città (via JOIN).
  static Future<List<LocaleModel>> getLocaliVicini(
    double? lat,
    double? lng, {
    double? raggioKm,
  }) async {
    if (lat == null || lng == null) {
      return getLocaliByFamosita(limit: 50);
    }

    try {
      final response = await _client
          .from('locali')
          .select(_localiSelect);

      var locali = (response as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map((m) => LocaleModel.fromMap(m))
          .where((l) => l.lat != null && l.lng != null)
          .toList();

      if (raggioKm != null) {
        locali = locali
            .where((l) => _haversineKm(lat, lng, l.lat!, l.lng!) <= raggioKm)
            .toList();
      }

      locali.sort((a, b) {
        final da = _haversineKm(lat, lng, a.lat!, a.lng!);
        final db = _haversineKm(lat, lng, b.lat!, b.lng!);
        return da.compareTo(db);
      });
      return locali;
    } catch (e, stacktrace) {
      debugPrint("[DEBUG] ERRORE MENTRE CARICO I LOCALI: $e\n$stacktrace");
      return [];
    }

  }

  /// Controlla se un locale è nei preferiti dell'utente.
  static Future<bool> isPreferito(String userId, String localeId) async {
    final response = await _client
        .from('preferiti')
        .select('id')
        .eq('id_utente', userId)
        .eq('locale_id', localeId)
        .maybeSingle();
    return response != null;
  }

  /// Aggiunge un locale ai preferiti.
  static Future<void> addPreferito(String userId, String localeId) async {
    await _client.from('preferiti').insert({
      'id_utente': userId,
      'locale_id': localeId,
    });
  }

  /// Rimuove un locale dai preferiti.
  static Future<void> removePreferito(String userId, String localeId) async {
    await _client
        .from('preferiti')
        .delete()
        .eq('id_utente', userId)
        .eq('locale_id', localeId);
  }

  /// Lista locali ordinati per famosità (per la home).
  static Future<List<LocaleModel>> getLocaliByFamosita({int limit = 20}) async {
    final response = await _client
        .from('locali')
        .select(_localiSelect)
        .order('famosita', ascending: false)
        .limit(limit);
    return (response as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .map((m) => LocaleModel.fromMap(m))
        .toList();
  }

  // ── Haversine ──────────────────────────────────────────────────────────────

  /// Distanza in km tra due coordinate (Haversine). Usabile dall'esterno.
  static double distanceKm(
          double lat1, double lng1, double lat2, double lng2) =>
      _haversineKm(lat1, lng1, lat2, lng2);

  static double _haversineKm(
      double lat1, double lng1, double lat2, double lng2) {
    const r = 6371.0;
    final dLat = _toRad(lat2 - lat1);
    final dLng = _toRad(lng2 - lng1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRad(lat1)) * cos(_toRad(lat2)) * sin(dLng / 2) * sin(dLng / 2);
    return r * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  static double _toRad(double deg) => deg * pi / 180;
}
