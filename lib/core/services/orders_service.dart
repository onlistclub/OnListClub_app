import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Storico ordini dell'utente: prevendite + prenotazioni tavolo.
///
/// Espone i fetch usati da `OrdersScreen` e dai dettagli prevendita/tavolo.
/// Restituisce mappe grezze dal DB (non model dedicati) perché lo schema è
/// ancora in evoluzione.
class OrdersService {
  static SupabaseClient get _client => Supabase.instance.client;

  /// Cambia ogni volta che un nuovo ordine (prevendita) viene creato.
  ///
  /// `OrdersScreen` resta MONTATA in un IndexedStack (vedi RootShell): senza
  /// questo segnale il suo `initState` non torna più a chiamarsi, quindi un
  /// acquisto fatto senza passare dalla Home non comparirebbe nel riepilogo
  /// finché non si ricrea l'intera shell (stesso schema di
  /// `PendingOrderService.revisione` per il carrello).
  static final ValueNotifier<int> revisione = ValueNotifier<int>(0);

  static void segnalaNuovoOrdine() => revisione.value++;

  // ─────────────────────────────────────────────────────────────────────────────
  // PREVENDITE
  // ─────────────────────────────────────────────────────────────────────────────

  /// `created_at` della prenotazione madre di una riga prevendita.
  /// `prenotazioni_prevendite` non ha un timestamp proprio.
  static DateTime? _createdAt(Map<String, dynamic> item) {
    final raw = (item['prenotazioni'] as Map<String, dynamic>?)?['created_at'];
    return raw == null ? null : DateTime.tryParse(raw.toString());
  }

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
          .eq('id_utente', user.id);
      // NIENTE .order('id'): `prenotazioni_prevendite.id` è un uuid casuale
      // (`gen_random_uuid()`), quindi ordinarlo dava un ordine stabile ma
      // SCOLLEGATO dal tempo — la "prima riga" era sempre la stessa a caso, ed
      // è il motivo per cui la conferma ordine mostrava sempre lo stesso club.
      // La tabella non ha un `created_at` proprio: si ordina qui sotto su
      // quello della prenotazione madre.

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
          // Le prevendite annullate non compaiono più nel riepilogo ordini.
          .where((item) =>
              ((item['prenotazioni'] as Map<String, dynamic>?)?['stato']
                  ?.toString()
                  .toLowerCase()) !=
              'annullata')
          .toList()
        // Ordine cronologico VERO: dal più recente al più vecchio.
        ..sort((a, b) {
          final da = _createdAt(a);
          final db = _createdAt(b);
          if (da == null && db == null) return 0;
          if (da == null) return 1; // senza data in fondo
          if (db == null) return -1;
          return db.compareTo(da);
        });
    } catch (e) {
      debugPrint('[OrdersService] getPrevenditeOrdini errore: $e');
      return [];
    }
  }

  /// Annulla una prevendita.
  ///
  /// L'UPDATE diretto su `prenotazioni` è bloccato dalla RLS (non esiste una
  /// policy UPDATE), quindi usiamo la RPC `annulla_prevendita` (SECURITY
  /// DEFINER): imposta `stato='annullata'` per la prenotazione dell'utente, il
  /// che fa scattare il trigger `trg_restore_prevendita_stock` → il posto torna
  /// libero. La prenotazione annullata viene poi nascosta dalla lista ordini.
  static Future<void> annullaPrevendita(String idPrenotazione) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Utente non autenticato');
    await _client.rpc('annulla_prevendita', params: {
      'p_id_prenotazione': idPrenotazione,
    });
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
          .eq('id_utente', user.id);
      // Tolto anche qui `.order('id')`: `prenotazioni_tavolo.id` è un uuid
      // casuale, ordinarlo non dava un ordine cronologico. Questa tabella non
      // ha né `created_at` proprio né la prenotazione madre nell'embed, quindi
      // per ora resta senza ordinamento — la sezione Tavoli è nascosta
      // nell'MVP e nessuna schermata chiama questo metodo. Se un domani torna
      // visibile, aggiungere `prenotazioni(created_at)` all'embed e ordinare
      // come in getPrevenditeOrdini.

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
    // `foto_url` esiste solo dopo la migration 2026-08-01_foto_profilo_utenti:
    // se la colonna non c'è la select fallisce, quindi si ricade su quella
    // base — la schermata Account continua a funzionare senza foto.
    try {
      return await _client
          .from('utenti')
          .select('id, nome, cognome, data_nascita, email, foto_url')
          .eq('id', user.id)
          .maybeSingle();
    } catch (_) {
      return _client
          .from('utenti')
          .select('id, nome, cognome, data_nascita, email')
          .eq('id', user.id)
          .maybeSingle();
    }
  }

  /// Numero di telefono primario dell'utente (E.164), da
  /// `utenti_numeri_telefono` — NON è una colonna di `utenti`.
  static Future<String?> getUserTelefono() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;
    try {
      final row = await _client
          .from('utenti_numeri_telefono')
          .select('telefono, is_primary')
          .eq('id_utente', user.id)
          .order('is_primary', ascending: false)
          .limit(1)
          .maybeSingle();
      return row?['telefono'] as String?;
    } catch (e) {
      debugPrint('[OrdersService] getUserTelefono errore: $e');
      return null;
    }
  }

  /// Quante prevendite ha acquistato l'utente (annullate escluse): è il numero
  /// mostrato dalla card "Tu e OnList" nella schermata Account.
  static Future<int> getNumeroSerate() async {
    final user = _client.auth.currentUser;
    if (user == null) return 0;
    try {
      final rows = await _client
          .from('prenotazioni_prevendite')
          .select('id, prenotazioni(stato)')
          .eq('id_utente', user.id);
      return rows
          .where((r) =>
              ((r['prenotazioni'] as Map<String, dynamic>?)?['stato']
                  ?.toString()
                  .toLowerCase()) !=
              'annullata')
          .length;
    } catch (e) {
      debugPrint('[OrdersService] getNumeroSerate errore: $e');
      return 0;
    }
  }

  /// Carica la foto profilo sul bucket Storage `avatars` e salva l'URL
  /// pubblico su `utenti.foto_url`. Richiede la migration
  /// `2026-08-01_foto_profilo_utenti.sql` (colonna + bucket + policy).
  /// Restituisce l'URL salvato.
  static Future<String> uploadFotoProfilo(File file) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Utente non autenticato');
    final ext = file.path.split('.').last.toLowerCase();
    // Un solo file per utente (upsert): niente accumulo di vecchie foto.
    final path = '${user.id}/avatar.$ext';
    await _client.storage.from('avatars').upload(
          path,
          file,
          fileOptions: const FileOptions(upsert: true),
        );
    final url = _client.storage.from('avatars').getPublicUrl(path);
    // Cache-busting: l'URL è sempre lo stesso, senza query la vecchia foto
    // resterebbe in cache dopo il cambio.
    final versioned = '$url?v=${DateTime.now().millisecondsSinceEpoch}';
    await _client
        .from('utenti')
        .update({'foto_url': versioned}).eq('id', user.id);
    return versioned;
  }

  static Future<void> updateProfile(
      {String? nome, String? cognome, String? dataNascita}) async {
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
      final prenRes = await _client
          .from('prenotazioni')
          .select('id_evento')
          .eq('id_utente', user.id);
      final tavRes = await _client
          .from('prenotazioni_tavolo')
          .select('id_evento')
          .eq('id_utente', user.id);
      debugPrint(
          '[OrdersService] 📊 prenotazioni rows=${prenRes.length}, tavoli rows=${tavRes.length}');

      final eventoIds = <String>{};
      for (var p in prenRes) eventoIds.add(p['id_evento'] as String);
      for (var t in tavRes) eventoIds.add(t['id_evento'] as String);

      if (eventoIds.isEmpty) {
        debugPrint(
            '[OrdersService] ⚠️ Nessun evento trovato per utente ${user.id}');
        return [];
      }

      final eventi = await _client
          .from('eventi')
          .select('club_id')
          .inFilter('id', eventoIds.toList());
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
  static Future<int> getTotalBookingsCount(
      {List<String>? precomputedIds}) async {
    final ids = precomputedIds ?? await getUtenteClubIds();
    debugPrint('[OrdersService] 📊 getTotalBookingsCount: ${ids.length}');
    return ids.length;
  }

  /// Coordinate del locale più frequentato dall'utente. Se [precomputedIds] è
  /// passato non rilegge gli ID dal DB (riuso del risultato di [getUtenteClubIds]).
  static Future<Map<String, double>?> getMostFrequentClubCoordinates(
      {List<String>? precomputedIds}) async {
    final clubIds = precomputedIds ?? await getUtenteClubIds();
    debugPrint(
        '[OrdersService] 🗺️ getMostFrequentClubCoordinates clubIds=$clubIds');
    if (clubIds.isEmpty) return null;

    var frequencies = <String, int>{};
    for (var id in clubIds) {
      frequencies[id] = (frequencies[id] ?? 0) + 1;
    }
    debugPrint('[OrdersService] 📈 Frequenze club: $frequencies');

    String mostFreqId =
        frequencies.entries.reduce((a, b) => a.value > b.value ? a : b).key;
    debugPrint('[OrdersService] 🏆 Club più frequentato: $mostFreqId');

    try {
      // Usiamo una select che preleva anche info citta tramite JOIN per fallback
      final response = await _client
          .from('locali')
          .select('lat, lng, citta!id_citta(lat, lng)')
          .eq('id', mostFreqId)
          .maybeSingle();
      debugPrint('[OrdersService] 🗺️ Response locale $mostFreqId: $response');
      if (response == null) return null;

      double? lat =
          response['lat'] != null ? (response['lat'] as num).toDouble() : null;
      double? lng =
          response['lng'] != null ? (response['lng'] as num).toDouble() : null;

      if (lat == null || lng == null) {
        final cittaObj = response['citta'];
        debugPrint(
            '[OrdersService] 🏙️ Fallback citta per coordinate: $cittaObj');
        if (cittaObj != null) {
          lat = cittaObj['lat'] != null
              ? (cittaObj['lat'] as num).toDouble()
              : null;
          lng = cittaObj['lng'] != null
              ? (cittaObj['lng'] as num).toDouble()
              : null;
        }
      }

      if (lat != null && lng != null) {
        debugPrint(
            '[OrdersService] ✅ Coordinate club frequentato: lat=$lat, lng=$lng');
        return {'lat': lat, 'lng': lng};
      }
      debugPrint(
          '[OrdersService] ❌ Nessuna coordinata trovata per club $mostFreqId');
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

    final localeIds =
        rows.map((e) => e['locale_id']).whereType<String>().toSet().toList();
    final locali = await _client
        .from('locali')
        .select('id, nome, foto_url, indirizzo')
        .inFilter('id', localeIds);

    final localiMap = {for (final l in locali) l['id'] as String: l};

    return rows
        .map((r) => {...r, 'locali': localiMap[r['locale_id']]})
        .toList();
  }
}
