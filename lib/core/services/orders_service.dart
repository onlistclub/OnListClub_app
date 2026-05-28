import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Storico ordini dell'utente: prevendite + prenotazioni tavolo.
///
/// Espone i fetch usati da `OrdersScreen` e dai dettagli prevendita/tavolo.
/// Restituisce mappe grezze dal DB (non model dedicati) perché lo schema è
/// ancora in evoluzione.
class OrdersService {
  static SupabaseClient get _client => Supabase.instance.client;

  // ─────────────────────────────────────────────────────────────────────────────
  // PREVENDITE
  // ─────────────────────────────────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> getPrevenditeOrdini() async {
    final user = _client.auth.currentUser;
    if (user == null) return [];

    try {
      final items = await _client
          .from('prenotazioni_prevendite')
          .select('id, nome, cognome, data_nascita, id_prenotazione, id_prevendita')
          .eq('id_utente', user.id)
          .order('id', ascending: false);

      if (items.isEmpty) return [];

      final prenIds = items.map((e) => e['id_prenotazione']).whereType<String>().toSet().toList();
      final prenotazioni = prenIds.isNotEmpty
          ? await _client.from('prenotazioni').select('id, stato, created_at, id_evento').inFilter('id', prenIds)
          : <Map<String, dynamic>>[];

      final eventoIds = prenotazioni.map((e) => e['id_evento']).whereType<String>().toSet().toList();
      final eventi = eventoIds.isNotEmpty
          ? await _client.from('eventi').select('id, nome, inizio_evento, club_id').inFilter('id', eventoIds)
          : <Map<String, dynamic>>[];

      final localeIds = eventi.map((e) => e['club_id']).whereType<String>().toSet().toList();
      final locali = localeIds.isNotEmpty
          ? await _client.from('locali').select('id, nome, foto_url').inFilter('id', localeIds)
          : <Map<String, dynamic>>[];

      final prevIds = items.map((e) => e['id_prevendita']).whereType<String>().toSet().toList();
      final prevendite = prevIds.isNotEmpty
          ? await _client.from('prevendite').select('id_prevendita, tipo, prezzo, descrizione').inFilter('id_prevendita', prevIds)
          : <Map<String, dynamic>>[];

      final localiMap = {for (final l in locali) l['id'] as String: l};
      final eventiMap = {
        for (final e in eventi)
          e['id'] as String: {
            ...e, 
            'data': e['inizio_evento'], // Mappiamo manualmente per il UI
            'locali': localiMap[e['club_id']]
          }
      };
      final prenotazioniMap = {
        for (final p in prenotazioni)
          p['id'] as String: {...p, 'eventi': eventiMap[p['id_evento']]}
      };
      final prevenditeMap = {for (final p in prevendite) p['id_prevendita'] as String: p};

      return items
          .map((item) {
            final pren = prenotazioniMap[item['id_prenotazione']];
            final prev = prevenditeMap[item['id_prevendita']];
            if (pren == null) {
              debugPrint(
                  '[OrdersService] getPrevenditeOrdini: FK prenotazione mancante per item ${item['id']}');
              return null;
            }
            return {
              ...item,
              'prenotazioni': pren,
              'prevendite': prev,
            };
          })
          .whereType<Map<String, dynamic>>()
          .toList();
    } catch (e) {
      debugPrint('[OrdersService] getPrevenditeOrdini errore: $e');
      return [];
    }
  }

  /// Annulla una prevendita impostando lo stato della prenotazione a
  /// 'annullata' (soft delete: in MVP conserviamo i dati per analisi).
  static Future<void> annullaPrevendita(String idPrenotazione) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Utente non autenticato');
    await _client
        .from('prenotazioni')
        .update({'stato': 'annullata'})
        .eq('id', idPrenotazione)
        .eq('id_utente', user.id);
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // TAVOLI
  // ─────────────────────────────────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> getTavoliOrdini() async {
    final user = _client.auth.currentUser;
    if (user == null) return [];

    try {
      // Usiamo 'quantita' invece di 'quantita_drink' come visto in BookingService
      final items = await _client
          .from('prenotazioni_tavolo')
          .select('id, nome_cliente, n_persone, stato, id_drink, quantita, id_tavolo, id_evento')
          .eq('id_utente', user.id)
          .order('id', ascending: false);

      if (items.isEmpty) return [];

      final eventoIds = items.map((e) => e['id_evento']).whereType<String>().toSet().toList();
      final eventi = eventoIds.isNotEmpty
          ? await _client.from('eventi').select('id, nome, inizio_evento, club_id').inFilter('id', eventoIds)
          : <Map<String, dynamic>>[];

      final localeIds = eventi.map((e) => e['club_id']).whereType<String>().toSet().toList();
      final locali = localeIds.isNotEmpty
          ? await _client.from('locali').select('id, nome, foto_url').inFilter('id', localeIds)
          : <Map<String, dynamic>>[];

      final tavoloIds = items.map((e) => e['id_tavolo']).whereType<String>().toSet().toList();
      final tavoli = tavoloIds.isNotEmpty
          ? await _client.from('tavoli').select('id_tavolo, nome_tavolo').inFilter('id_tavolo', tavoloIds)
          : <Map<String, dynamic>>[];

      final drinkIds = items.map((e) => e['id_drink']).whereType<String>().toSet().toList();
      final drinks = drinkIds.isNotEmpty
          ? await _client.from('drink').select('id_drink, nome, prezzo').inFilter('id_drink', drinkIds)
          : <Map<String, dynamic>>[];

      final localiMap = {for (final l in locali) l['id'] as String: l};
      final eventiMap = {
        for (final e in eventi)
          e['id'] as String: {
            ...e, 
            'data': e['inizio_evento'], // Mappiamo manualmente per il UI
            'locali': localiMap[e['club_id']]
          }
      };
      final tavoliMap = {for (final t in tavoli) t['id_tavolo'] as String: t};
      final drinkMap = {for (final d in drinks) d['id_drink'] as String: d};

      return items
          .map((item) {
            final evento = eventiMap[item['id_evento']];
            final tavolo = tavoliMap[item['id_tavolo']];
            if (evento == null || tavolo == null) {
              debugPrint(
                  '[OrdersService] getTavoliOrdini: FK mancante (evento=${evento != null}, tavolo=${tavolo != null}) per item ${item['id']}');
              return null;
            }
            return {
              ...item,
              'quantita_drink': item['quantita'],
              'eventi': evento,
              'tavoli': tavolo,
              'drink': drinkMap[item['id_drink']],
            };
          })
          .whereType<Map<String, dynamic>>()
          .toList();
    } catch (e) {
      debugPrint('[OrdersService] getTavoliOrdini errore: $e');
      return [];
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // PROFILO
  // ─────────────────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>?> getUserProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;
    return _client
        .from('utenti')
        .select('id, nome, cognome, data_nascita, email')
        .eq('id', user.id)
        .maybeSingle();
  }

  static Future<void> updateProfile({String? nome, String? cognome, String? dataNascita}) async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    final Map<String, dynamic> updates = {};
    if (nome != null) updates['nome'] = nome;
    if (cognome != null) updates['cognome'] = cognome;
    if (dataNascita != null) updates['data_nascita'] = dataNascita;
    if (updates.isEmpty) return;
    await _client.from('utenti').update(updates).eq('id', user.id);
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // HISTORY / BOOKING STATS
  // ─────────────────────────────────────────────────────────────────────────────

  static Future<List<String>> _getUtenteClubIds() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      debugPrint('[OrdersService] ❌ _getUtenteClubIds: utente non loggato');
      return [];
    }

    try {
      final prenRes = await _client.from('prenotazioni').select('id_evento').eq('id_utente', user.id);
      final tavRes = await _client.from('prenotazioni_tavolo').select('id_evento').eq('id_utente', user.id);
      debugPrint('[OrdersService] 📊 prenotazioni rows=${prenRes.length}, tavoli rows=${tavRes.length}');

      final eventoIds = <String>{};
      for (var p in prenRes) eventoIds.add(p['id_evento'] as String);
      for (var t in tavRes) eventoIds.add(t['id_evento'] as String);

      if (eventoIds.isEmpty) {
        debugPrint('[OrdersService] ⚠️ Nessun evento trovato per utente ${user.id}');
        return [];
      }

      final eventi = await _client.from('eventi').select('club_id').inFilter('id', eventoIds.toList());
      final clubIds = eventi.map((e) => e['club_id'] as String).toList();
      debugPrint('[OrdersService] 🏛️ Club IDs da storico: $clubIds');
      return clubIds;
    } catch (e) {
      debugPrint('[OrdersService] ❌ _getUtenteClubIds errore: $e');
      return [];
    }
  }

  static Future<int> getTotalBookingsCount() async {
    final ids = await _getUtenteClubIds();
    debugPrint('[OrdersService] 📊 getTotalBookingsCount: ${ids.length}');
    return ids.length;
  }

  static Future<Map<String, double>?> getMostFrequentClubCoordinates() async {
    final clubIds = await _getUtenteClubIds();
    debugPrint('[OrdersService] 🗺️ getMostFrequentClubCoordinates clubIds=$clubIds');
    if (clubIds.isEmpty) return null;

    var frequencies = <String, int>{};
    for(var id in clubIds) {
      frequencies[id] = (frequencies[id] ?? 0) + 1;
    }
    debugPrint('[OrdersService] 📈 Frequenze club: $frequencies');

    String mostFreqId = frequencies.entries.reduce((a, b) => a.value > b.value ? a : b).key;
    debugPrint('[OrdersService] 🏆 Club più frequentato: $mostFreqId');

    try {
      // Usiamo una select che preleva anche info citta tramite JOIN per fallback
      final response = await _client.from('locali').select('lat, lng, citta!id_citta(lat, lng)').eq('id', mostFreqId).maybeSingle();
      debugPrint('[OrdersService] 🗺️ Response locale $mostFreqId: $response');
      if (response == null) return null;

      double? lat = response['lat'] != null ? (response['lat'] as num).toDouble() : null;
      double? lng = response['lng'] != null ? (response['lng'] as num).toDouble() : null;

      if (lat == null || lng == null) {
        final cittaObj = response['citta'];
        debugPrint('[OrdersService] 🏙️ Fallback citta per coordinate: $cittaObj');
        if (cittaObj != null) {
          lat = cittaObj['lat'] != null ? (cittaObj['lat'] as num).toDouble() : null;
          lng = cittaObj['lng'] != null ? (cittaObj['lng'] as num).toDouble() : null;
        }
      }

      if (lat != null && lng != null) {
        debugPrint('[OrdersService] ✅ Coordinate club frequentato: lat=$lat, lng=$lng');
        return {'lat': lat, 'lng': lng};
      }
      debugPrint('[OrdersService] ❌ Nessuna coordinata trovata per club $mostFreqId');
    } catch (e) {
      debugPrint('[OrdersService] ❌ getMostFrequentClubCoordinates errore: $e');
    }
    return null;
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // PREFERITI
  // ─────────────────────────────────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> getPreferiti() async {
    final user = _client.auth.currentUser;
    if (user == null) return [];

    final rows = await _client
        .from('preferiti')
        .select('id, locale_id')
        .eq('id_utente', user.id);

    if (rows.isEmpty) return [];

    final localeIds = rows.map((e) => e['locale_id']).whereType<String>().toSet().toList();
    final locali = await _client
        .from('locali')
        .select('id, nome, foto_url, indirizzo')
        .inFilter('id', localeIds);

    final localiMap = {for (final l in locali) l['id'] as String: l};

    return rows.map((r) => {...r, 'locali': localiMap[r['locale_id']]}).toList();
  }
}
