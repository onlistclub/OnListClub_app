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
      // Una sola query con embedding PostgREST al posto di 5 round-trip:
      // prenotazioni_prevendite → prenotazioni → eventi → locali, più prevendite.
      // Le FK sono univoche, quindi le relazioni risolvono a oggetti singoli.
      final items = await _client
          .from('prenotazioni_prevendite')
          .select(
            'id, nome, cognome, data_nascita, id_prenotazione, id_prevendita, '
            'prenotazioni(id, stato, created_at, id_evento, '
            'eventi(id, nome, inizio_evento, club_id, '
            'locali(id, nome, foto_url))), '
            'prevendite(id_prevendita, tipo, prezzo, descrizione)',
          )
          .eq('id_utente', user.id)
          .order('id', ascending: false);

      return items
          .map((item) {
            final pren = item['prenotazioni'] as Map<String, dynamic>?;
            if (pren == null) {
              debugPrint(
                  '[OrdersService] getPrevenditeOrdini: FK prenotazione mancante per item ${item['id']}');
              return null;
            }
            // La UI si aspetta eventi['data'] (= inizio_evento).
            final evento = pren['eventi'] as Map<String, dynamic>?;
            if (evento != null) evento['data'] = evento['inizio_evento'];
            return item;
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
      // Una sola query con embedding PostgREST al posto di 5 round-trip:
      // prenotazioni_tavolo → eventi → locali, più tavoli e drink.
      final items = await _client
          .from('prenotazioni_tavolo')
          .select(
            'id, nome_cliente, n_persone, stato, id_drink, quantita, id_tavolo, id_evento, '
            'eventi(id, nome, inizio_evento, club_id, locali(id, nome, foto_url)), '
            'tavoli(id_tavolo, nome_tavolo), '
            'drink(id_drink, nome, prezzo)',
          )
          .eq('id_utente', user.id)
          .order('id', ascending: false);

      return items
          .map((item) {
            final evento = item['eventi'] as Map<String, dynamic>?;
            final tavolo = item['tavoli'] as Map<String, dynamic>?;
            if (evento == null || tavolo == null) {
              debugPrint(
                  '[OrdersService] getTavoliOrdini: FK mancante (evento=${evento != null}, tavolo=${tavolo != null}) per item ${item['id']}');
              return null;
            }
            // La UI si aspetta eventi['data'] (= inizio_evento) e quantita_drink.
            evento['data'] = evento['inizio_evento'];
            item['quantita_drink'] = item['quantita'];
            return item;
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

  /// Restituisce gli ID dei locali in cui l'utente ha prenotazioni
  /// (prevendite + tavoli). Pubblico così la Home può calcolarli una volta
  /// sola e riusarli per conteggio e coordinate, evitando query duplicate.
  static Future<List<String>> getUtenteClubIds() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      debugPrint('[OrdersService] ❌ getUtenteClubIds: utente non loggato');
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
      debugPrint('[OrdersService] ❌ getUtenteClubIds errore: $e');
      return [];
    }
  }

  /// Numero di locali distinti prenotati. Se [precomputedIds] è passato non
  /// rilegge dal DB (riuso del risultato di [getUtenteClubIds]).
  static Future<int> getTotalBookingsCount({List<String>? precomputedIds}) async {
    final ids = precomputedIds ?? await getUtenteClubIds();
    debugPrint('[OrdersService] 📊 getTotalBookingsCount: ${ids.length}');
    return ids.length;
  }

  /// Coordinate del locale più frequentato dall'utente. Se [precomputedIds] è
  /// passato non rilegge gli ID dal DB (riuso del risultato di [getUtenteClubIds]).
  static Future<Map<String, double>?> getMostFrequentClubCoordinates({List<String>? precomputedIds}) async {
    final clubIds = precomputedIds ?? await getUtenteClubIds();
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
