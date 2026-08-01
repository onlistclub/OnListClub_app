import 'package:flutter/material.dart';

import '../../core/app_export.dart';
import '../../core/services/orders_service.dart';
import '../../theme/onlist_colors.dart';
import '../../theme/onlist_text_styles.dart';
import '../../widgets/custom_top_bar.dart';
import '../../widgets/flip_card.dart';
import '../../widgets/shared_footer.dart';
import '../../widgets/ticket_cards.dart';

/// Dettaglio di una singola prevendita acquistata — biglietto aperto.
///
/// Design ufficiale NUOVO ("Riepilogo ordini e clic biglietto singolo" +
/// "…e si girA dopo ANIMAZIONE"): due facce dello stesso biglietto, gli
/// stessi widget condivisi usati dalla schermata di conferma ordine:
/// - fronte [TicketFrontCard]: tipo ticket, quantità, dati personali reali,
///   pagamento, "VISUALIZZA QR CODE" e "ANNULLA PREVENDITA";
/// - retro [TicketBackCard]: locale, evento e QR code reale (lo scanner
///   /staff legge l'URL /verify/<uuid> → RPC `scan_ticket`).
///
/// Il passaggio fronte↔retro è una rotazione 3D ([FlipCard]).
///
/// Riceve come arguments la Map proveniente da OrdersService.getPrevenditeOrdini().
class PrevenditaDetailScreen extends StatefulWidget {
  const PrevenditaDetailScreen({Key? key}) : super(key: key);

  static Widget builder(BuildContext context) => const PrevenditaDetailScreen();

  @override
  State<PrevenditaDetailScreen> createState() => _PrevenditaDetailScreenState();
}

class _PrevenditaDetailScreenState extends State<PrevenditaDetailScreen> {
  bool _isAnnullando = false;
  bool _annullata = false;

  /// True quando si mostra il RETRO del biglietto (QR).
  bool _showQr = false;

  Future<void> _annulla(String? idPrenotazione) async {
    if (idPrenotazione == null || idPrenotazione.isEmpty) return;
    final conferma = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Annulla prevendita',
            style: TextStyle(color: Colors.white, fontFamily: 'HelveticaNeue')),
        content: const Text(
          'Sei sicuro di voler annullare questa prevendita? L\'operazione non è reversibile.',
          style: TextStyle(color: Colors.white70, fontFamily: 'HelveticaNeue'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sì, annulla',
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (conferma != true) return;

    setState(() => _isAnnullando = true);
    try {
      await OrdersService.annullaPrevendita(idPrenotazione);
      if (!mounted) return;
      setState(() {
        _isAnnullando = false;
        _annullata = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Prevendita annullata')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isAnnullando = false);
      showAppErrorDialog(context, 'Errore annullamento: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = ModalRoute.of(context)?.settings.arguments
            as Map<String, dynamic>? ??
        {};

    final prenotazione = item['prenotazioni'] as Map<String, dynamic>?;
    final prevendita = item['prevendite'] as Map<String, dynamic>?;
    final evento = prenotazione?['eventi'] as Map<String, dynamic>?;

    final localeNome =
        ((evento?['locali'] as Map<String, dynamic>?)?['nome'] ?? 'Locale')
            .toString();
    final stato = _annullata
        ? 'annullata'
        : (prenotazione?['stato'] ?? 'in_attesa');
    final isAnnullata = stato.toString().toLowerCase() == 'annullata';
    // ID della prenotazione madre: è quello che la RPC `annulla_prevendita`
    // si aspetta. NON confonderlo con item['id'] (riga prenotazioni_prevendite).
    final idPrenotazione = (prenotazione?['id'] ?? item['id'])?.toString();
    // ID univoco di QUESTA riga prenotazioni_prevendite — è ciò che il QR
    // codifica: ogni biglietto ha il suo QR distinto.
    final idPrenotazionePrevendita = item['id']?.toString();
    final qrData = idPrenotazionePrevendita != null
        ? 'https://www.onlistclub.com/verify/$idPrenotazionePrevendita'
        : (idPrenotazione != null
            ? 'https://www.onlistclub.com/verify/$idPrenotazione'
            : 'onlist-ticket');
    final descrizione = (prevendita?['descrizione'] as String?)?.trim();
    final quantita = (item['quantita'] ?? prenotazione?['quantita'] ?? 1) as int;

    return Scaffold(
      // Design NUOVO: sfondo NERO FISSO.
      backgroundColor: Colors.black,
      // Footer flottante: il contenuto scorre dietro la capsula.
      extendBody: true,
      body: ColoredBox(
        color: Colors.black,
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              const CustomTopBar(),
              _buildBackRow(),
              Expanded(
                child: SingleChildScrollView(
                  // CSS NUOVO: card 350 su 393 → margini ~21.
                  padding: EdgeInsets.fromLTRB(R.sp(21), R.sp(2), R.sp(21),
                      R.sp(24) + SharedFooter.height),
                  // Il biglietto RUOTA in 3D tra fronte e retro ([FlipCard]):
                  // si gira col tap ovunque sulla card, oltre che dai bottoni.
                  child: FlipCard(
                    showBack: _showQr,
                    onTap: () => setState(() => _showQr = !_showQr),
                    back: TicketBackCard(
                      clubName: localeNome,
                      quantita: quantita,
                      descrizione: descrizione,
                      eventoNome: (evento?['nome'] ?? '').toString(),
                      eventoSottotitolo: null,
                      dataEvento: _formatData(evento?['data']),
                      qrData: qrData,
                      onHide: () => setState(() => _showQr = false),
                    ),
                    front: TicketFrontCard(
                      ticketType:
                          (prevendita?['tipo'] ?? 'normale').toString(),
                      quantita: quantita,
                      descrizione: descrizione,
                      nome: (item['nome'] ?? '—').toString(),
                      cognome: (item['cognome'] ?? '—').toString(),
                      prezzo: _formatPrezzo(prevendita?['prezzo']),
                      onShowQr: () => setState(() => _showQr = true),
                      onCollapse: () => NavigatorService.goBack(),
                      onAnnulla:
                          isAnnullata ? null : () => _annulla(idPrenotazione),
                      isAnnullando: _isAnnullando,
                      annullataLabel:
                          isAnnullata ? 'PREVENDITA ANNULLATA' : null,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const SharedFooter(currentIndex: 0),
    );
  }

  Widget _buildBackRow() {
    return GestureDetector(
      onTap: () => NavigatorService.goBack(),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        child: Row(
          children: [
            const Icon(Icons.arrow_back, color: OnlistColors.white, size: 28),
            const SizedBox(width: 6),
            Text('Torna indietro', style: OnlistTextStyles.title32Light),
          ],
        ),
      ),
    );
  }

  String _formatPrezzo(dynamic v) {
    final n = v is num ? v : num.tryParse('$v');
    if (n == null) return '—';
    return n % 1 == 0 ? '${n.toInt()}€' : '$n€';
  }

  String _formatData(dynamic raw) {
    if (raw == null) return '';
    final d = DateTime.tryParse(raw.toString());
    if (d == null) return '';
    return '${d.day}/${d.month}/${d.year}';
  }
}
