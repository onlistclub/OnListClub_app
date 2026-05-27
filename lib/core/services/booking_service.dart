import 'package:supabase_flutter/supabase_flutter.dart';
import 'notification_service.dart';

/// Accesso alle tabelle `prevendite` e `prenotazioni_tavoli` su Supabase.
///
/// Espone i metodi usati dal flusso di acquisto: lettura disponibilità,
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

  static Future<List<Map<String, dynamic>>> getTavoli(String eventoId) async {
    final evento = await _client.from('eventi').select('club_id').eq('id', eventoId).single();
    final clubId = evento['club_id'] as String;

    final response = await _client
        .from('tavoli')
        .select('*, prenotazioni_tavolo(*)')
        .eq('id_locale', clubId);
    
    final allTavoli = List<Map<String, dynamic>>.from(response);
    
    return allTavoli.where((t) {
      final pRaw = t['prenotazioni_tavolo'];
      final List? prenotazioni = pRaw is List ? pRaw : null;
      if (prenotazioni == null || prenotazioni.isEmpty) return true;
      
      // Disponibile se NON ha prenotazioni confermate per questo evento
      return !prenotazioni.any((p) => p['id_evento'] == eventoId && p['stato'] != 'annullata');
    }).toList();
  }

  /// Recupera TUTTI i tavoli per un evento (per la mappa).
  /// Determina lo stato (occupato/libero) in base alla presenza in prenotazioni_tavolo.
  static Future<List<Map<String, dynamic>>> getAllTavoliByEvento(String eventoId) async {
    final evento = await _client.from('eventi').select('club_id').eq('id', eventoId).single();
    final clubId = evento['club_id'] as String;

    final response = await _client
        .from('tavoli')
        .select('*, prenotazioni_tavolo(*)')
        .eq('id_locale', clubId);
    
    final data = List<Map<String, dynamic>>.from(response);
    
    return data.map((t) {
      final pRaw = t['prenotazioni_tavolo'];
      final List? prenotazioni = pRaw is List ? pRaw : null;
      bool occupies = false;
      
      if (prenotazioni != null && prenotazioni.isNotEmpty) {
        // È occupato se c'è almeno una prenotazione per questo evento non annullata
        occupies = prenotazioni.any((p) => p['id_evento'] == eventoId && p['stato'] != 'annullata');
      }
      
      return {
        ...t,
        'isOccupato': occupies, // Iniettiamo lo stato calcolato
      };
    }).toList();
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

    // R3/R4: Recupera nome reale dal profilo utente (non più da email)
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
        throw Exception("id_evento non può essere vuoto per calcolare la prenotazione_tavolo del locale ${tavoloData['id_locale']}");
      } catch (e) {
        throw Exception("Errore nel recupero dati tavolo: $e");
      }
    }
    if (finalEventoId.isEmpty) throw Exception("Errore DEBUG: id_evento è vuoto.");

    // --- CALCOLO PREZZO TOTALE + VALIDAZIONE DISPONIBILITÀ ---
    // Rileggiamo prezzo e disponibilità subito prima dell'insert per ridurre
    // la finestra di race condition (overbooking). La sicurezza definitiva
    // resta lato DB: trigger `trg_decrement_prevendita_stock` per le prevendite
    // e — quando sarà aggiunto — un unique constraint su (id_evento, id_tavolo)
    // per i tavoli.
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
            'Prevendita non più disponibile: restano $disponibili biglietti, ne servono $numBiglietti.');
      }
      prezzoTotale = (prevendita['prezzo'] as num).toDouble() * numBiglietti;
    } else if (bookingType == 'table' && validTavoloId != null) {
      // Verifica che il tavolo non sia già stato prenotato per questo evento.
      final occupazione = await _client
          .from('prenotazioni_tavolo')
          .select('id_prenotazione, stato')
          .eq('id_tavolo', validTavoloId)
          .eq('id_evento', finalEventoId);
      final occupato = (occupazione as List).any((p) {
        final stato = (p as Map)['stato'] as String?;
        return stato != null && stato != 'annullata';
      });
      if (occupato) {
        throw Exception(
            'Tavolo non più disponibile: è stato appena prenotato da un altro utente.');
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
      ? 'La tua prenotazione per il tavolo è andata a buon fine. Ci vediamo alla serata!'
      : 'Hai acquistato correttamente le prevendite. Trovi il riepilogo nella sezione ordini.';

    await NotificationService.createNotification(
      titolo: titoloNotifica,
      messaggio: msgNotifica,
      tipo: 'prenotazione',
      relatedId: reservationId,
    );
  }

  /// Recupera le bottiglie (drink) disponibili.
  static Future<List<Map<String, dynamic>>> getBottiglie() async {
    final response = await _client
        .from('drink')
        .select('*');
    return List<Map<String, dynamic>>.from(response);
  }
}
