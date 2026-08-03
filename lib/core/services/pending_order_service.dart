import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Ordini lasciati a metà nella scelta ticket.
///
/// L'ordine entra in sospeso appena l'utente apre la lista ticket di una
/// serata, e viene scritto SUBITO su Supabase: se l'app viene chiusa di colpo
/// un secondo dopo, la riga c'è già e al riavvio il carrello lo ritrova.
/// Scrivere all'uscita invece che all'ingresso perderebbe proprio il caso più
/// interessante, cioè l'abbandono.
///
/// **Pallino blu sulla footer** — è una notifica letto/non letto:
/// | momento                          | riga                | pallino |
/// |----------------------------------|---------------------|---------|
/// | entra nella lista ticket         | creata, visto=false | spento  |
/// | esce senza concludere            | resta               | ACCESO  |
/// | app uccisa lì dentro, e riaperta | resta               | ACCESO  |
/// | apre il carrello                 | visto=true          | spento  |
/// | rientra ed esce di nuovo         | visto=false         | ACCESO  |
/// | "PRENOTA ORA"                    | cancellata          | spento  |
///
/// Mentre l'utente è DENTRO la lista ticket il pallino resta spento anche se
/// la riga è già `visto=false`: quel "sono dentro adesso" sta solo in memoria
/// ([_eventoAperto]), e proprio perché non sopravvive alla chiusura dell'app
/// il riavvio riaccende il pallino da sé, senza codice dedicato.
///
/// Singleton con [ValueNotifier] come [BadgeService]: la footer ci si aggancia
/// con un `ValueListenableBuilder` e si ridisegna solo lei.
class PendingOrderService {
  static final PendingOrderService _instance = PendingOrderService._internal();
  factory PendingOrderService() => _instance;
  PendingOrderService._internal();

  static const String _table = 'ordini_in_sospeso';

  /// Validità di un ordine in sospeso.
  ///
  /// Il taglio in lettura usa l'orologio del telefono; `created_at` invece lo
  /// scrive il server (`default now()`), quindi il dato salvato resta
  /// affidabile a prescindere. Spostare indietro l'ora del telefono al più
  /// farebbe riapparire un sospeso già scaduto — nessun vantaggio per nessuno,
  /// non ci sono sconti né posti bloccati legati alla scadenza.
  static const Duration validita = Duration(hours: 48);

  SupabaseClient get _client => Supabase.instance.client;
  String? get _userId => _client.auth.currentUser?.id;

  /// Acceso quando c'è almeno un sospeso valido e non ancora visto.
  final ValueNotifier<bool> pallino = ValueNotifier<bool>(false);

  /// Cambia a ogni scrittura sui sospesi. Il carrello ci si aggancia per
  /// ricaricare la lista: nello shell la schermata resta MONTATA in un
  /// IndexedStack, quindi `initState` non torna più e senza questo segnale
  /// mostrerebbe dati vecchi.
  final ValueNotifier<int> revisione = ValueNotifier<int>(0);

  void _segnalaCambio() => revisione.value++;

  /// Serata di cui l'utente sta guardando i ticket PROPRIO ORA. Solo in
  /// memoria: vedi la nota in testa alla classe.
  String? _eventoAperto;

  // ── Scritture ─────────────────────────────────────────────────────────────

  /// L'utente è entrato nella lista ticket di [idEvento].
  ///
  /// Mette (o rimette) l'ordine in sospeso e spegne il pallino finché resta
  /// dentro. Non solleva: un carrello che non si aggiorna non deve impedire
  /// di comprare un biglietto.
  Future<void> apri(String idEvento) async {
    _eventoAperto = idEvento;
    pallino.value = false;

    final utente = _userId;
    if (utente == null) return;
    try {
      await _client.from(_table).upsert(
        {
          'id_utente': utente,
          'id_evento': idEvento,
          'visto': false,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
        onConflict: 'id_utente,id_evento',
      );
      _segnalaCambio();
    } catch (e) {
      debugPrint('[PendingOrderService] apri fallito: $e');
    }
  }

  /// L'utente ha lasciato la lista ticket di [idEvento] senza concludere: da
  /// qui in poi il sospeso è una notifica da mostrare.
  ///
  /// Chiude solo se è ancora la serata aperta: se nel frattempo ne è stata
  /// aperta un'altra, il `dispose` della prima non deve spegnere lo stato
  /// "sono dentro" della seconda (accenderebbe il pallino mentre ci sta).
  Future<void> chiudi(String idEvento) async {
    if (_eventoAperto != idEvento) return;
    _eventoAperto = null;
    await aggiornaPallino();
  }

  /// L'ordine è stato concluso: il sospeso non serve più.
  Future<void> completa(String idEvento) async {
    if (_eventoAperto == idEvento) _eventoAperto = null;

    final utente = _userId;
    if (utente == null) return;
    try {
      await _client
          .from(_table)
          .delete()
          .eq('id_utente', utente)
          .eq('id_evento', idEvento);
      _segnalaCambio();
    } catch (e) {
      debugPrint('[PendingOrderService] completa fallito: $e');
    }
    await aggiornaPallino();
  }

  /// L'utente ha aperto il carrello: la notifica è stata vista.
  ///
  /// Le righe RESTANO — sparisce solo il pallino, le card del carrello no.
  Future<void> segnaVisti() async {
    pallino.value = false;

    final utente = _userId;
    if (utente == null) return;
    try {
      await _client
          .from(_table)
          .update({'visto': true})
          .eq('id_utente', utente)
          .eq('visto', false);
      _segnalaCambio();
    } catch (e) {
      debugPrint('[PendingOrderService] segnaVisti fallito: $e');
    }
  }

  /// Cancella tutto (usato al logout: il carrello del prossimo utente non
  /// deve mostrare i sospesi di quello precedente).
  void reset() {
    _eventoAperto = null;
    pallino.value = false;
  }

  // ── Letture ───────────────────────────────────────────────────────────────

  /// Sospesi ancora validi, dal più recente. Ogni mappa porta con sé la serata
  /// e il locale, così il carrello disegna la card senza altre query.
  Future<List<Map<String, dynamic>>> carica() async {
    final utente = _userId;
    if (utente == null) return [];
    try {
      final righe = await _client
          .from(_table)
          .select(
            // `eventi(*)`, non i soli campi per la card: riprendendo l'ordine
            // ricostruiamo un SerataModel completo, e senza `eta_minima` il
            // gate 16+/18+ della booking screen verrebbe scavalcato.
            'id, id_evento, visto, created_at, '
            'eventi(*, locali(id, nome, foto_url))',
          )
          .eq('id_utente', utente)
          .gt('created_at', _limiteValidita())
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(righe);
    } catch (e) {
      debugPrint('[PendingOrderService] carica fallito: $e');
      return [];
    }
  }

  /// Ricalcola il pallino: acceso se esiste almeno un sospeso valido, non
  /// visto, e diverso da quello che l'utente sta guardando in questo momento.
  Future<void> aggiornaPallino() async {
    final utente = _userId;
    if (utente == null) {
      pallino.value = false;
      return;
    }
    try {
      final righe = await _client
          .from(_table)
          .select('id_evento')
          .eq('id_utente', utente)
          .eq('visto', false)
          .gt('created_at', _limiteValidita());

      pallino.value = List<Map<String, dynamic>>.from(righe)
          .any((r) => r['id_evento']?.toString() != _eventoAperto);
    } catch (e) {
      debugPrint('[PendingOrderService] aggiornaPallino fallito: $e');
    }
  }

  String _limiteValidita() =>
      DateTime.now().toUtc().subtract(validita).toIso8601String();
}
