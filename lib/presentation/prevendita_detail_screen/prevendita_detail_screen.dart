import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/app_export.dart';
import '../../core/services/orders_service.dart';
import '../../theme/onlist_colors.dart';
import '../../theme/onlist_text_styles.dart';
import '../../widgets/custom_top_bar.dart';
import '../../widgets/dashed_line.dart';
import '../../widgets/shared_footer.dart';
import '../../widgets/ticket_shape.dart';

/// Dettaglio di una singola prevendita acquistata — "ticket aperto".
///
/// Design ufficiale "(NUOVO) - Riepilogo Ticket Specifico": card-scontrino
/// 350×600 (Rectangle 268) a forma di biglietto ([TicketShape], tacche alla
/// seconda linea tratteggiata), con nome locale, "Ticket x N" + descrizione,
/// dati personali reali, pill PREZZO, nome evento e CODICE A BARRE decorativo.
///
/// Il barcode è GRAFICO (design): il codice funzionale resta il QR — tap sul
/// barcode → overlay bianco a schermo intero col QR vero (massima
/// scansionabilità nei locali bui). Il sito /staff scansiona il QR e chiama
/// `scan_ticket`; nessuna modifica all'infrastruttura.
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

  /// Overlay a schermo intero col QR VERO (il codice funzionale). Fondo bianco
  /// pieno → contrasto massimo per lo scanner dello staff nei locali bui.
  void _showQrOverlay(String qrData, String codice) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog.fullscreen(
        backgroundColor: Colors.white,
        child: GestureDetector(
          onTap: () => Navigator.pop(ctx),
          behavior: HitTestBehavior.opaque,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                QrImageView(
                  data: qrData,
                  version: QrVersions.auto,
                  size: (R.width * 0.75).clamp(200.0, 320.0),
                  backgroundColor: Colors.white,
                ),
                SizedBox(height: R.sp(16)),
                Text(
                  codice,
                  style: GoogleFonts.inter(
                    color: Colors.black,
                    fontSize: R.sp(16),
                    fontWeight: FontWeight.w500,
                    letterSpacing: 2,
                  ),
                ),
                SizedBox(height: R.sp(24)),
                Text(
                  'Tocca per chiudere',
                  style: GoogleFonts.inter(
                    color: Colors.black45,
                    fontSize: R.sp(13),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Numero leggibile sotto il barcode (design "59012"): etichetta VISIVA
  // derivata dall'UUID del biglietto (prime 5 cifre), non un codice
  // interrogabile — il codice funzionale è il QR.
  String _barcodeLabel(String? uuid) {
    if (uuid == null || uuid.isEmpty) return '00000';
    final digits = uuid.replaceAll(RegExp(r'[^0-9]'), '');
    return digits.length >= 5 ? digits.substring(0, 5) : digits.padRight(5, '0');
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
    final eventoNome = (evento?['nome'] ?? '').toString();
    final nome = (item['nome'] ?? '—').toString();
    final cognome = (item['cognome'] ?? '—').toString();
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
    final quantita = (item['quantita'] ?? prenotazione?['quantita'] ?? 1) as int;
    // Descrizione reale della prevendita dal DB (es. "+ 2 drink omaggio").
    final descrizione = (prevendita?['descrizione'] as String?)?.trim();
    final barcodeLabel = _barcodeLabel(idPrenotazionePrevendita);
    final isAnnullata = stato.toString().toLowerCase() == 'annullata';

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
                child: SingleChildScrollView(
                  // CSS: card 350 su 393 → ~21px per lato; top card 163 con
                  // "Torna indietro" che finisce a 149. Gap superiore ridotto
                  // per avvicinare la card al "Torna indietro" (feedback device).
                  padding: EdgeInsets.fromLTRB(
                      R.sp(21), R.sp(2), R.sp(21), R.sp(24) + SharedFooter.height),
                  child: SizedBox(
                    // Altezza fissa del biglietto come da CSS (Rectangle 268:
                    // 350×600): i gap interni sommano esattamente a 600.
                    height: R.sp(600),
                    width: double.infinity,
                    child: TicketShape(
                      // CSS Ellipse 18: centro tacche a y 490 su card a 163
                      // → 327/600, esattamente sulla linea tratteggiata 2.
                      notches: const [
                        TicketNotch(
                            centerYFraction: 327 / 600,
                            radiusDesign: 20), // Ellipse 18: Ø~41
                      ],
                      borderWidthDesign: 3,
                      borderColor: OnlistColors.ticketCardBorderOpen,
                      child: Column(
                        children: [
                          SizedBox(height: R.sp(24)),
                          // Nome locale (CSS "Gattopardo": 64/-0.1em, grassetto).
                          SizedBox(
                            height: R.sp(63),
                            width: double.infinity,
                            child: Padding(
                              padding:
                                  EdgeInsets.symmetric(horizontal: R.sp(26)),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  localeNome,
                                  style: OnlistTextStyles.hn(
                                    color: Colors.white,
                                    fontSize: R.sp(64),
                                    fontWeight: FontWeight.w700,
                                    height: 63 / 64,
                                    letterSpacing: -0.1 * 64,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: R.sp(14)),
                          // "Ticket x 1" + "+ 2 drink omaggio" (24/-0.05em).
                          Padding(
                            padding: EdgeInsets.only(left: R.sp(26), right: R.sp(20)),
                            child: Row(
                              children: [
                                Text(
                                  'Ticket x $quantita',
                                  style: OnlistTextStyles.hn(
                                    color: Colors.white,
                                    fontSize: R.sp(24),
                                    fontWeight: FontWeight.w400,
                                    height: 1.0,
                                    letterSpacing: -0.05 * 24,
                                  ),
                                ),
                                if (descrizione != null &&
                                    descrizione.isNotEmpty) ...[
                                  SizedBox(width: R.sp(28)),
                                  Flexible(
                                    child: Text(
                                      descrizione,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: OnlistTextStyles.hn(
                                        color: Colors.white,
                                        fontSize: R.sp(24),
                                        fontWeight: FontWeight.w400,
                                        height: 1.0,
                                        letterSpacing: -0.05 * 24,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          SizedBox(height: R.sp(15)),
                          // Linea tratteggiata 1 (CSS Line 15: 297, dashed 1px).
                          const DashedLine(widthDesign: 297),
                          SizedBox(height: R.sp(18)),
                          // "Dati personali" (40/-0.1em, grassetto).
                          Padding(
                            padding: EdgeInsets.only(left: R.sp(25)),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Dati personali',
                                style: OnlistTextStyles.hn(
                                  color: Colors.white,
                                  fontSize: R.sp(40),
                                  fontWeight: FontWeight.w700,
                                  height: 1.0,
                                  letterSpacing: -0.1 * 40,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: R.sp(10)),
                          _personalDataRow('Nome : $nome', leftDesign: 29),
                          SizedBox(height: R.sp(5)),
                          _personalDataRow('Cognome : $cognome', leftDesign: 28),
                          SizedBox(height: R.sp(17)),
                          // Pill PREZZO (CSS Rectangle 269: 297×37, radius 13).
                          Container(
                            width: R.sp(297),
                            height: R.sp(37),
                            decoration: BoxDecoration(
                              color: OnlistColors.ticketPricePill,
                              borderRadius: BorderRadius.circular(R.sp(13)),
                            ),
                            padding: EdgeInsets.only(
                                left: R.sp(7), right: R.sp(11)),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'PREZZO',
                                  style: OnlistTextStyles.hn(
                                    color: Colors.white,
                                    fontSize: R.sp(32),
                                    fontWeight: FontWeight.w500,
                                    height: 1.0,
                                  ),
                                ),
                                Text(
                                  prezzoStr,
                                  style: OnlistTextStyles.hn(
                                    color: Colors.white,
                                    fontSize: R.sp(32),
                                    fontWeight: FontWeight.w500,
                                    height: 1.0,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: R.sp(28)),
                          // Linea tratteggiata 2 (CSS Line 16: 278) —
                          // all'altezza esatta delle tacche laterali.
                          const DashedLine(widthDesign: 278),
                          SizedBox(height: R.sp(19)),
                          // Nome evento (16/w500/-0.03em, centrato).
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: R.sp(26)),
                            child: Text(
                              eventoNome,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: OnlistTextStyles.hn(
                                color: Colors.white,
                                fontSize: R.sp(16),
                                fontWeight: FontWeight.w500,
                                height: 1.0,
                                letterSpacing: -0.03 * 16,
                              ),
                            ),
                          ),
                          SizedBox(height: R.sp(7)),
                          // Barcode decorativo (CSS barcode 2: 289×97) +
                          // numero. Tap → overlay col QR VERO scansionabile.
                          GestureDetector(
                            onTap: () => _showQrOverlay(qrData, barcodeLabel),
                            behavior: HitTestBehavior.opaque,
                            child: SizedBox(
                              width: R.sp(289),
                              height: R.sp(97),
                              child: Column(
                                children: [
                                  SizedBox(height: R.sp(7)),
                                  SizedBox(
                                    width: R.sp(289),
                                    height: R.sp(68),
                                    child: const CustomPaint(
                                      painter: _BarcodeBarsPainter(),
                                    ),
                                  ),
                                  SizedBox(height: R.sp(7)),
                                  // CSS "5901234123457": Inter 12 centrato.
                                  Text(
                                    barcodeLabel,
                                    style: GoogleFonts.inter(
                                      color: Colors.white,
                                      fontSize: R.sp(12),
                                      height: 15 / 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          SizedBox(height: R.sp(17)),
                          // ANNULLA PREVENDITA (CSS Rectangle 270: 186×33,
                          // bianco 20%, bordo 1px bianco 45%, radius 18).
                          SizedBox(
                            height: R.sp(33),
                            child: isAnnullata
                                ? Center(
                                    child: Text(
                                      'PREVENDITA ANNULLATA',
                                      style: OnlistTextStyles.hn(
                                        color: Colors.redAccent,
                                        fontSize: R.sp(16),
                                        fontWeight: FontWeight.w500,
                                        letterSpacing: -0.1 * 16,
                                      ),
                                    ),
                                  )
                                : GestureDetector(
                                    onTap: _isAnnullando
                                        ? null
                                        : () => _annulla(idPrenotazione),
                                    child: Container(
                                      width: R.sp(186),
                                      height: R.sp(33),
                                      decoration: BoxDecoration(
                                        color: Colors.white
                                            .withValues(alpha: 0.2),
                                        border: Border.all(
                                          color: Colors.white
                                              .withValues(alpha: 0.45),
                                          width: 1,
                                        ),
                                        borderRadius:
                                            BorderRadius.circular(R.sp(18)),
                                      ),
                                      alignment: Alignment.center,
                                      child: _isAnnullando
                                          ? const SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(
                                                  color: Colors.white,
                                                  strokeWidth: 2),
                                            )
                                          : Text(
                                              'ANNULLA PREVENDITA',
                                              style: OnlistTextStyles.hn(
                                                color: Colors.white,
                                                fontSize: R.sp(16),
                                                fontWeight: FontWeight.w500,
                                                height: 1.0,
                                                letterSpacing: -0.1 * 16,
                                              ),
                                            ),
                                    ),
                                  ),
                          ),
                          SizedBox(height: R.sp(20)),
                          // "Nascondi QR Code" + cerchio freccia su → chiude.
                          GestureDetector(
                            onTap: () => NavigatorService.goBack(),
                            behavior: HitTestBehavior.opaque,
                            child: Column(
                              children: [
                                Text(
                                  'Nascondi QR Code',
                                  style: OnlistTextStyles.hn(
                                    color: Colors.white,
                                    fontSize: R.sp(15),
                                    fontWeight: FontWeight.w400,
                                    height: 1.0,
                                    letterSpacing: -0.1 * 15,
                                  ),
                                ),
                                SizedBox(height: R.sp(8)),
                                Container(
                                  width: R.sp(28),
                                  height: R.sp(28),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: Colors.white, width: 2),
                                  ),
                                  child: Icon(Icons.arrow_upward,
                                      color: Colors.white, size: R.sp(18)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      // Footer: unica e globale, montata da RootShell (non qui).
    );
  }

  // Riga dati personali (CSS "Nome : Mario": 16/-0.1em).
  Widget _personalDataRow(String text, {required double leftDesign}) {
    return Padding(
      padding: EdgeInsets.only(left: R.sp(leftDesign)),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          style: OnlistTextStyles.hn(
            color: Colors.white,
            fontSize: R.sp(16),
            fontWeight: FontWeight.w400,
            height: 1.0,
            letterSpacing: -0.1 * 16,
          ),
        ),
      ),
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

/// Barre del codice a barre DECORATIVO, riprodotte esattamente dall'SVG del
/// design (CSS "barcode 2": ogni barra come coppia left%/right% del blocco).
/// Non codifica nulla: il codice funzionale è il QR nell'overlay.
class _BarcodeBarsPainter extends CustomPainter {
  const _BarcodeBarsPainter();

  // Coppie (left%, right%) dei Vector del CSS ufficiale.
  static const List<List<double>> _bars = [
    [1.32, 97.1], [3.69, 95.51], [6.07, 91.56], [10.03, 87.6],
    [14.78, 83.64], [17.15, 82.06], [18.73, 79.68], [21.9, 76.52],
    [24.27, 74.14], [27.44, 70.18], [30.61, 67.81], [32.98, 64.64],
    [36.15, 62.27], [40.11, 59.1], [43.27, 55.94], [44.85, 52.77],
    [48.02, 50.4], [50.4, 47.23], [53.56, 45.65], [55.14, 42.48],
    [58.31, 40.11], [62.27, 35.36], [65.44, 33.77], [67.02, 29.82],
    [70.98, 26.65], [74.14, 24.27], [76.52, 21.11], [79.68, 17.94],
    [82.85, 15.57], [86.02, 13.19], [88.39, 10.03], [92.35, 5.28],
    [95.51, 3.69], [97.1, 1.32],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white;
    for (final bar in _bars) {
      final left = bar[0] / 100 * size.width;
      final right = bar[1] / 100 * size.width;
      canvas.drawRect(
        Rect.fromLTRB(left, 0, size.width - right, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_BarcodeBarsPainter oldDelegate) => false;
}
