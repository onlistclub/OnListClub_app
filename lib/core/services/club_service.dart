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

  /// Recupera il locale più vicino alle coordinate utente.
  /// Usa la RPC PostGIS `nearby_clubs` (server-side, indice spaziale).
  /// Se lat/lng sono null o la RPC fallisce, fallback su famosità.
  static Future<LocaleModel?> getLocaleVicino(
    double? lat,
    double? lng,
  ) async {
    if (lat == null || lng == null) {
      final clubs = await getLocaliByFamosita(limit: 1);
      return clubs.isEmpty ? null : clubs.first;
    }
    // Raggio largo per "il più vicino in assoluto", senza limitarsi.
    final list = await _rpcNearbyClubs(lat: lat, lng: lng, raggioKm: 500);
    if (list != null && list.isNotEmpty) return list.first;
    final clubs = await getLocaliByFamosita(limit: 1);
    return clubs.isEmpty ? null : clubs.first;
  }

  /// Recupera tutti i locali ordinati per distanza dall'utente.
  /// Usa la RPC PostGIS `nearby_clubs` (filtra per raggio + ordina lato server).
  /// Se lat/lng sono null o la RPC fallisce, fallback su famosità.
  static Future<List<LocaleModel>> getLocaliVicini(
    double? lat,
    double? lng, {
    double? raggioKm,
  }) async {
    if (lat == null || lng == null) {
      return getLocaliByFamosita(limit: 50);
    }
    final list = await _rpcNearbyClubs(
      lat: lat,
      lng: lng,
      raggioKm: raggioKm ?? 50,
    );
    if (list != null) return list;
    // Fallback robusto: se la RPC non è disponibile, mostriamo almeno i popolari.
    return getLocaliByFamosita(limit: 50);
  }

  /// Chiama la RPC `nearby_clubs(user_lat, user_lng, raggio_km)` e mappa il
  /// risultato in `LocaleModel`. Ritorna null se la chiamata fallisce
  /// (es. RPC non deployata): i chiamanti devono gestire il fallback.
  static Future<List<LocaleModel>?> _rpcNearbyClubs({
    required double lat,
    required double lng,
    required double raggioKm,
  }) async {
    try {
      final response = await _client.rpc(
        'nearby_clubs',
        params: {
          'user_lat': lat,
          'user_lng': lng,
          'raggio_km': raggioKm,
        },
      );
      final rows = (response as List<dynamic>?) ?? const [];
      return rows
          .whereType<Map<String, dynamic>>()
          .map(_localeFromRpcRow)
          .toList(growable: false);
    } catch (e) {
      debugPrint('[ClubService] RPC nearby_clubs fallita: $e');
      return null;
    }
  }

  /// La RPC ritorna `citta` come stringa (nome città) e `lat`/`lng` già
  /// COALESCE-ati con la città. Riformiamo lo shape atteso da
  /// `LocaleModel.fromMap` (che vuole `citta` come oggetto nidificato).
  static LocaleModel _localeFromRpcRow(Map<String, dynamic> m) {
    return LocaleModel.fromMap({
      'id': m['id'],
      'nome': m['nome'],
      'indirizzo': m['indirizzo'],
      'id_citta': m['id_citta'],
      'logo_url': m['logo_url'],
      'foto_url': m['foto_url'],
      'famosita': m['famosita'],
      'generi_musicali': m['generi_musicali'],
      'prezzo_indicativo': m['prezzo_indicativo'],
      'link_tripadvisor': m['link_tripadvisor'],
      'descrizione': m['descrizione'],
      'lat': m['lat'],
      'lng': m['lng'],
      'citta': {'nome_citta': m['citta']},
    });
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
