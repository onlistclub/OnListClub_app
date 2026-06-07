import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'notification_service.dart';

/// Accesso alle tabelle `prevendite` e `prenotazioni_tavolo` su Supabase.
///
/// Espone i metodi usati dal flusso di acquisto: lettura disponibilita',
/// creazione prevendita/tavolo, annullamento. Dipende da `NotificationService`
/// per generare la notifica utente quando una prenotazione cambia stato.
class BookingService {
  static SupabaseClient get _client => Supabase.instance.client;

  /// Recupera le prevendite per un evento.
  static Future<List<Map<String, dynamic>>> getPrevendite(String eventoId) async {
    final response = await _client
        .from('prevendite')
        .select('*')
        .eq('id_evento', eventoId);
    return List<Map<String, dynamic>>.from(response);
  }

  /// Mappa id_tavolo -> occupato per un evento, calcolata server-side via RPC
  /// `get_tavoli_disponibilita`. Necessaria perche' la RLS di prenotazioni_tavolo
  /// nasconde le prenotazioni altrui: leggere l'occupazione dal client porterebbe
  /// a vedere libero cio' che libero non e' (overbooking tra utenti diversi).
  static Future<Map<String, bool>> _loadOccupazione(String eventoId) async {
    final res = await _client
        .rpc('get_tavoli_disponibilita', params: {'p_id_evento': eventoId});
    final rows = (res as List).cast<Map<String, dynamic>>();
    return {
      for (final r in rows) r['id_tavolo'] as String: r['occupato'] as bool,
    };
  }

  static Future<List<Map<String, dynamic>>> getTavoli(String eventoId) async {
    final evento = await _client.from('eventi').select('club_id').eq('id', eventoId).single();
    final clubId = evento['club_id'] as String;

    final occupazione = await _loadOccupazione(eventoId);

    final response = await _client
        .from('tavoli')
        .select('*')
        .eq('id_locale', clubId);

    final allTavoli = List<Map<String, dynamic>>.from(response);
    return allTavoli
        .where((t) => occupazione[t['id_tavolo']] != true)
        .toList();
  }

  /// Recupera TUTTI i tavoli per un evento (per la mappa).
  /// Lo stato occupato/libero arriva dalla RPC server-side `_loadOccupazione`.
  static Future<List<Map<String, dynamic>>> getAllTavoliByEvento(String eventoId) async {
    final evento = await _client.from('eventi').select('club_id').eq('id', eventoId).single();
    final clubId = evento['club_id'] as String;

    final occupazione = await _loadOccupazione(eventoId);

    final response = await _client
        .from('tavoli')
        .select('*')
        .eq('id_locale', clubId);

    final data = List<Map<String, dynamic>>.from(response);
    return data
        .map((t) => {
              ...t,
              'isOccupato': occupazione[t['id_tavolo']] ?? false,
            })
        .toList();
  }

  /// Crea una prenotazione completa nel DB.
  static Future<void> createReservation({
    required String bookingType,
    required String? ticketId,
    required String? tavoloId,
    required String? drinkId,
    required int bottleQuantity,
    required String eventoId,
    int? nPersone,
    List<Map<String, String>>? ticketHolders,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception("Utente non autenticato");

    // R3/R4: Recupera nome reale dal profilo utente (non piu' da email)
    final profilo = await _client
        .from('utenti')
        .select('nome, cognome')
        .eq('id', user.id)
        .maybeSingle();
    final nomeCompleto = [
      profilo?['nome'] as String? ?? '',
      profilo?['cognome'] as String? ?? '',
    ].where((s) => s.isNotEmpty).join(' ');
    final emailLocalPart = user.email?.split('@').first ?? '';
    final nomeCliente = nomeCompleto.isNotEmpty
        ? nomeCompleto
        : (emailLocalPart.isNotEmpty ? emailLocalPart : 'Cliente OnList');

    final validTavoloId = (tavoloId != null && tavoloId.isNotEmpty) ? tavoloId : null;
    final validDrinkId = (drinkId != null && drinkId.isNotEmpty) ? drinkId : null;

    String finalEventoId = eventoId;
    if (finalEventoId.isEmpty && validTavoloId != null) {
      try {
        final tavoloData = await _client.from('tavoli').select('id_locale').eq('id_tavolo', validTavoloId).single();
        throw Exception("id_evento non puo' essere vuoto per calcolare la prenotazione_tavolo del locale ${tavoloData['id_locale']}");
      } catch (e) {
        throw Exception("Errore nel recupero dati tavolo: $e");
      }
    }
    if (finalEventoId.isEmpty) throw Exception("Errore DEBUG: id_evento e' vuoto.");

    // --- CALCOLO PREZZO TOTALE + VALIDAZIONE DISPONIBILITA' ---
    // Difesa atomica reale: UNIQUE INDEX parziale lato DB
    // (uq_prenotazioni_tavolo_attiva) + catch SQLSTATE 23505 sull'insert.
    // Il pre-check qui sotto serve solo come early-fail UX (chiama la stessa
    // RPC server-side usata dalla mappa, quindi vede anche le prenotazioni
    // altrui che la RLS di prenotazioni_tavolo nasconderebbe al SELECT diretto).
    // Per le prevendite lo stock e' decrementato dal trigger
    // `trg_decrement_prevendita_stock` (atomico server-side).
    double prezzoTotale = 0.0;
    if (bookingType == 'ticket' && ticketId != null) {
      final prevendita = await _client
          .from('prevendite')
          .select('prezzo, quantita_disponibile')
          .eq('id_prevendita', ticketId)
          .single();
      final numBiglietti = ticketHolders?.length ?? nPersone ?? 1;
      final disponibili =
          (prevendita['quantita_disponibile'] as num?)?.toInt() ?? 0;
      if (disponibili < numBiglietti) {
        throw Exception(
            'Prevendita non piu\' disponibile: restano $disponibili biglietti, ne servono $numBiglietti.');
      }
      prezzoTotale = (prevendita['prezzo'] as num).toDouble() * numBiglietti;
    } else if (bookingType == 'table' && validTavoloId != null) {
      // Pre-check via RPC: vede le prenotazioni di tutti gli utenti.
      final occupazione = await _loadOccupazione(finalEventoId);
      if (occupazione[validTavoloId] == true) {
        throw Exception(
            'Tavolo non piu\' disponibile: e\' stato appena prenotato da un altro utente.');
      }

      final tavoloData = await _client.from('tavoli').select('prezzo_minimo').eq('id_tavolo', validTavoloId).single();
      double costoTavolo = (tavoloData['prezzo_minimo'] as num?)?.toDouble() ?? 0.0;

      double costoDrink = 0.0;
      if (validDrinkId != null) {
        final drinkData = await _client.from('drink').select('prezzo').eq('id_drink', validDrinkId).single();
        costoDrink = (drinkData['prezzo'] as num?)?.toDouble() ?? 0.0;
      }

      prezzoTotale = costoTavolo + (costoDrink * bottleQuantity);
    }

    // 1. Creazione record prenotazione MADRE
    final reservation = await _client.from('prenotazioni').insert({
      'id_evento': finalEventoId,
      'id_utente': user.id,
      'nome_cliente': nomeCliente,
      'n_persone': bookingType == 'ticket' ? (ticketHolders?.length ?? nPersone ?? 1) : (nPersone ?? 10),
      'stato': 'confermata',
      'prezzo_totale': prezzoTotale,
      if (bookingType == 'ticket' && ticketId != null) 'id_prevendita': ticketId,
    }).select().single();

    final String reservationId = reservation['id'];

    if (bookingType == 'table' && validTavoloId != null) {
      try {
        await _client.from('prenotazioni_tavolo').insert({
          'id_prenotazione': reservationId,
          'id_tavolo': validTavoloId,
          'id_evento': finalEventoId,
          'id_utente': user.id,
          'n_persone': nPersone ?? 10,
          'nome_cliente': nomeCliente,
          'stato': 'confermata',
          if (validDrinkId != null) 'id_drink': validDrinkId,
          if (validDrinkId != null) 'quantita': bottleQuantity,
        });
      } on PostgrestException catch (e) {
        // 23505 = unique_violation -> uq_prenotazioni_tavolo_attiva ha bloccato
        // un overbooking. Annulliamo la prenotazione madre appena creata e
        // segnaliamo all'utente.
        if (e.code == '23505') {
          await _client
              .from('prenotazioni')
              .update({'stato': 'annullata'})
              .eq('id', reservationId);
          throw Exception(
              'Tavolo non piu\' disponibile: e\' stato appena prenotato da un altro utente.');
        }
        rethrow;
      }
    } else if (bookingType == 'ticket' && ticketId != null) {
      // Per le prevendite inseriamo sempre almeno 1 riga in prenotazioni_prevendite
      final holders = (ticketHolders != null && ticketHolders.isNotEmpty)
          ? ticketHolders
          : [{'name': '', 'dob': ''}];

      for (var holder in holders) {
        final fullName = (holder['name'] ?? '').trim();
        final parts = fullName.isNotEmpty ? fullName.split(' ') : <String>[];
        final nome = parts.isNotEmpty
            ? parts[0]
            : (emailLocalPart.isNotEmpty ? emailLocalPart : 'Cliente');
        final cognome = parts.length > 1 ? parts.sublist(1).join(' ') : '';
        final dob = (holder['dob'] ?? '').trim();

        await _client.from('prenotazioni_prevendite').insert({
          'id_prevendita': ticketId,
          'id_prenotazione': reservationId,
          'id_utente': user.id,
          'nome': nome,
          'cognome': cognome,
          'data_nascita': dob.isNotEmpty ? dob : '2000-01-01',
        });
      }

      // Stock prevendite: gestito dal trigger DB trg_decrement_prevendita_stock
      // (decremento atomico server-side, nessuna race condition)
    }

    // 3. Creazione notifica di successo
    final titoloNotifica = bookingType == 'table' ? 'Tavolo Prenotato! 🥂' : 'Prevendita Acquistata! 🎟️';
    final msgNotifica = bookingType == 'table'
      ? 'La tua prenotazione per il tavolo e\' andata a buon fine. Ci vediamo alla serata!'
      : 'Hai acquistato correttamente le prevendite. Trovi il riepilogo nella sezione ordini.';

    // La notifica NON deve mai far fallire un ordine già scritto a DB: se la
    // creazione fallisce (es. RLS), logghiamo e proseguiamo verso il successo.
    try {
      await NotificationService.createNotification(
        titolo: titoloNotifica,
        messaggio: msgNotifica,
        tipo: 'prenotazione',
        relatedId: reservationId,
      );
    } catch (e) {
      debugPrint('[BookingService] notifica conferma fallita: $e');
    }

    // 4. Notifiche SCHEDULATE (in-app subito grazie a programmata_per; la push
    //    nel centro notifiche del telefono la invierà il cron server-side —
    //    STEP 6.2). Non deve mai far fallire la prenotazione già confermata.
    try {
      final evento = await _client
          .from('eventi')
          .select('inizio_evento, club_id')
          .eq('id', finalEventoId)
          .maybeSingle();
      final inizioRaw = evento?['inizio_evento'];
      final clubId = evento?['club_id'] as String?;
      final inizio =
          inizioRaw != null ? DateTime.tryParse(inizioRaw.toString()) : null;

      // 5 ore prima della serata — "preparati a divertirti".
      if (inizio != null) {
        final cinqueOrePrima = inizio.subtract(const Duration(hours: 5));
        if (cinqueOrePrima.isAfter(DateTime.now())) {
          await NotificationService.createNotification(
            titolo: 'Tra poco si balla! 🕺',
            messaggio:
                'Mancano 5 ore alla tua serata. Preparati a divertirti!',
            tipo: 'promemoria_evento',
            relatedId: reservationId,
            programmataPer: cinqueOrePrima,
          );
        }
      }

      // ~30 minuti dopo la prenotazione — il tap apre la posizione/mappa del club.
      if (clubId != null) {
        await NotificationService.createNotification(
          titolo: 'Come arrivare 📍',
          messaggio:
              'Tocca per vedere la posizione del club e come raggiungerlo.',
          tipo: 'posizione_club',
          relatedId: clubId,
          linkTipo: 'club',
          programmataPer: DateTime.now().add(const Duration(minutes: 30)),
        );
      }
    } catch (e) {
      // Scheduling notifiche non critico: la prenotazione resta valida.
      debugPrint('[BookingService] scheduling notifiche fallito: $e');
    }
  }

  /// Recupera le bottiglie (drink) disponibili.
  static Future<List<Map<String, dynamic>>> getBottiglie() async {
    final response = await _client
        .from('drink')
        .select('*');
    return List<Map<String, dynamic>>.from(response);
  }
}
