import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/app_export.dart';
import '../../core/services/orders_service.dart';
import '../../theme/onlist_colors.dart';
import '../../theme/onlist_text_styles.dart';
import '../../widgets/custom_top_bar.dart';
import '../../widgets/shared_footer.dart';

/// Dettaglio di una singola prevendita acquistata (18 — con QR).
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

    final tipo = prevendita?['tipo'] ?? 'Normale';
    final prezzo = prevendita?['prezzo'];
    final stato = _annullata
        ? 'annullata'
        : (prenotazione?['stato'] ?? 'in_attesa');
    // ID della singola riga prenotazioni_prevendite (item['id']):
    // è il codice che il sito web scanner legge per identificare univocamente
    // questo biglietto. NON usare prenotazione['id'] (che è l'ID dell'ordine
    // madre e può raggruppare più biglietti). Ogni prenotazioni_prevendite
    // ha il suo UUID univoco → ogni biglietto ha il suo QR distinto.
    final idPrenotazione = (prenotazione?['id'] ?? item['id'])?.toString();
    // ID univoco di questa riga prenotazioni_prevendite — è ciò che il QR codifica.
    final idPrenotazionePrevendita = item['id']?.toString();
    // QR scannerizzabile: l'URL di verifica contiene l'ID prenotazioni_prevendite.
    // Il sito web (/staff) chiama scan_ticket(_qr_code) con questo UUID.
    final qrData = idPrenotazionePrevendita != null
        ? 'https://www.onlistclub.com/verify/$idPrenotazionePrevendita'
        : (idPrenotazione != null
            ? 'https://www.onlistclub.com/verify/$idPrenotazione'
            : 'onlist-ticket');
    final prezzoNum = prezzo is num ? prezzo : num.tryParse('$prezzo');
    final prezzoStr = prezzoNum == null
        ? '—'
        : '${prezzoNum % 1 == 0 ? prezzoNum.toInt() : prezzoNum}€';
    // Quantità dai dati reali della prenotazione.
    final quantita = (item['quantita'] ?? prenotazione?['quantita'] ?? 1) as int;
    // Testo "extra" accanto al prezzo: descrizione reale della prevendita dal
    // DB (es. "+ 2 drink omaggio"). NOTA: `drink_omaggio` non è una colonna
    // esistente in `prevendite`/`eventi` — l'unica sorgente vera è
    // `descrizione`. Qui è già protetto dall'overflow dal FittedBox del
    // prezzo, che rimpicciolisce tutta la riga se serve.
    final descrizione = (prevendita?['descrizione'] as String?)?.trim();
    final String? extraText =
        (descrizione != null && descrizione.isNotEmpty) ? descrizione : null;

    return Scaffold(
      backgroundColor: Colors.black,
      // Footer flottante: il contenuto scorre dietro la capsula (non la oscura).
      extendBody: true,
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: OnlistColors.screenBackground),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              const CustomTopBar(),
              _buildBackRow(),
              Expanded(
                // La card si "allunga" per riempire lo spazio verticale
                // disponibile (Figma 18: bordo alto, QR centrato, ANNULLA
                // vicino al fondo). ATTENZIONE: questa schermata contiene un
                // QrImageView (pacchetto qr_flutter), che avvolge SEMPRE il
                // proprio contenuto in un LayoutBuilder interno (non
                // modificabile, è nel codice del pacchetto). Sia
                // IntrinsicHeight sia SliverFillRemaining calcolano le
                // dimensioni intrinseche dei discendenti e vanno in crash
                // non appena raggiungono quel LayoutBuilder ("LayoutBuilder
                // does not support returning intrinsic dimensions").
                // Soluzione: calcoliamo l'altezza della card ESPLICITAMENTE
                // con LayoutBuilder (qui, fuori da qualunque scroll/sliver) e
                // la imponiamo con un SizedBox — questo NON richiede mai le
                // dimensioni intrinseche dei figli, quindi è sicuro anche
                // con il QR dentro.
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    const double topGap = 12;
                    final double bottomGap = 24 + SharedFooter.height;
                    const double chiudiGap = 20;
                    // Stima blocco "Chiudi QR Code": testo(~20) + gap(6) +
                    // cerchio(28).
                    const double chiudiBlockH = 56;
                    final double cardH = (constraints.maxHeight -
                            topGap -
                            bottomGap -
                            chiudiGap -
                            chiudiBlockH)
                        .clamp(420.0, double.infinity);
                    return SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(16, topGap, 16, bottomGap),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Card grande con tutto dentro (Figma 18). SizedBox
                          // forza un'altezza esatta/bounded, così Expanded/
                          // Spacer dentro il Container funzionano senza mai
                          // richiedere dimensioni intrinseche.
                          SizedBox(
                            height: cardH,
                            child: Container(
                              width: double.infinity,
                              padding:
                                  const EdgeInsets.fromLTRB(16, 16, 16, 20),
                              decoration: BoxDecoration(
                                gradient: OnlistColors.cardSummary,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // "Ticket x N" + "Ticket {tipo}" con più
                                  // respiro tra i due (Figma 18: il
                                  // sottotitolo è staccato dal numero).
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('Ticket x $quantita',
                                          style: OnlistTextStyles.ticketLabel),
                                      const SizedBox(width: 18),
                                      Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.only(
                                              top: 14),
                                          child: Text('Ticket $tipo',
                                              style: OnlistTextStyles
                                                  .ticketSubtitleXs,
                                              maxLines: 1,
                                              overflow:
                                                  TextOverflow.ellipsis),
                                        ),
                                      ),
                                    ],
                                  ),
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(prezzoStr,
                                            style: OnlistTextStyles.price96),
                                        if (extraText != null) ...[
                                          const SizedBox(width: 10),
                                          Padding(
                                            padding: const EdgeInsets.only(
                                                bottom: 32),
                                            child: Text(extraText,
                                                style: OnlistTextStyles
                                                    .body24Regular),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  // Gap fisso (era Spacer flessibile): il QR
                                  // deve stare vicino al prezzo come nel
                                  // Figma ufficiale, non centrato a metà
                                  // dello spazio libero.
                                  SizedBox(height: R.sp(28)),
                                  Center(
                                    child: Container(
                                      padding: const EdgeInsets.all(10),
                                      color: Colors.white,
                                      // ShaderMask ricolora solo i pixel
                                      // opachi del QR (i moduli scuri) con
                                      // la sfumatura viola ufficiale — il QR
                                      // resta un vero QrImageView generato
                                      // dai dati reali (qrData), quindi
                                      // scannerizzabile e collegato
                                      // all'ordine. backgroundColor deve
                                      // restare transparent: il bianco è
                                      // dato dal Container esterno, così lo
                                      // sfondo non viene toccato dallo
                                      // shader (BlendMode.srcIn colora solo
                                      // ciò che ha alpha > 0).
                                      child: ShaderMask(
                                        shaderCallback: (bounds) =>
                                            const LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            OnlistColors.blueElectric,
                                            OnlistColors.blueDeep,
                                          ],
                                        ).createShader(bounds),
                                        blendMode: BlendMode.srcIn,
                                        child: QrImageView(
                                          data: qrData,
                                          version: QrVersions.auto,
                                          // Box totale (QR + padding 10x2)
                                          // proporzionato al Figma ufficiale
                                          // (258×258 su frame 393 di
                                          // riferimento), responsive via
                                          // R.width invece di px fissi.
                                          size: ((R.width * (258 / 393)) - 20)
                                              .clamp(160.0, 320.0),
                                          backgroundColor: Colors.transparent,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const Spacer(),
                                  // ANNULLA PREVENDITA (pill)
                                  if (stato.toString().toLowerCase() !=
                                      'annullata')
                                    Center(
                                      child: GestureDetector(
                                        onTap: _isAnnullando
                                            ? null
                                            : () =>
                                                _annulla(idPrenotazione),
                                        child: Container(
                                          width: 219,
                                          height: 35,
                                          decoration: BoxDecoration(
                                            color: Colors.white
                                                .withValues(alpha: 0.13),
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                          alignment: Alignment.center,
                                          child: _isAnnullando
                                              ? const SizedBox(
                                                  width: 18,
                                                  height: 18,
                                                  child:
                                                      CircularProgressIndicator(
                                                          color:
                                                              Colors.white,
                                                          strokeWidth: 2),
                                                )
                                              : Text('ANNULLA PREVENDITA',
                                                  style: OnlistTextStyles
                                                      .button20Bold),
                                        ),
                                      ),
                                    )
                                  else
                                    Center(
                                      child: Text('PREVENDITA ANNULLATA',
                                          style: OnlistTextStyles
                                              .button20Bold
                                              .copyWith(
                                                  color: Colors.redAccent)),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          // Chiudi QR Code
                          Center(
                            child: GestureDetector(
                              onTap: () => NavigatorService.goBack(),
                              behavior: HitTestBehavior.opaque,
                              child: Column(
                                children: [
                                  Text('Chiudi QR Code',
                                      style: OnlistTextStyles.link15),
                                  const SizedBox(height: 6),
                                  Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: Colors.white, width: 2),
                                    ),
                                    child: const Icon(Icons.arrow_upward,
                                        color: Colors.white, size: 18),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
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
}
