import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/app_export.dart';
import '../../core/services/orders_service.dart';
import '../../core/utils/date_formatter.dart';
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore annullamento: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = ModalRoute.of(context)?.settings.arguments
            as Map<String, dynamic>? ??
        {};

    final prenotazione = item['prenotazioni'] as Map<String, dynamic>?;
    final evento = prenotazione?['eventi'] as Map<String, dynamic>?;
    final prevendita = item['prevendite'] as Map<String, dynamic>?;

    final nomeEvento = evento?['nome'] ?? '';
    final data = evento?['data'];
    final tipo = prevendita?['tipo'] ?? 'Normale';
    final prezzo = prevendita?['prezzo'];
    final stato = _annullata
        ? 'annullata'
        : (prenotazione?['stato'] ?? 'in_attesa');
    final nome = (item['nome'] ?? '').toString();
    final cognome = (item['cognome'] ?? '').toString();
    final nomeCognome = '$nome $cognome'.trim();
    final idPrenotazione = (prenotazione?['id'] ?? item['id'])?.toString();
    final qrData = idPrenotazione ?? 'onlist-ticket';
    final prezzoStr = prezzo != null ? '$prezzo€' : '10€';

    String dataFormatted = '';
    if (data != null) {
      try {
        dataFormatted = DateFormatter.formatLong(DateTime.parse(data));
      } catch (_) {
        dataFormatted = data.toString();
      }
    }

    return Scaffold(
      backgroundColor: Colors.black,
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
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Card grande con tutto dentro (Figma 18)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                        decoration: BoxDecoration(
                          gradient: OnlistColors.cardSummary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Ticket x 1',
                                      style: OnlistTextStyles.ticketLabel),
                                  const SizedBox(width: 8),
                                  Padding(
                                    padding: const EdgeInsets.only(top: 14),
                                    child: Text('Ticket $tipo',
                                        style: OnlistTextStyles.ticketSubtitleXs),
                                  ),
                                ],
                              ),
                            ),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(prezzoStr, style: OnlistTextStyles.price96),
                                  const SizedBox(width: 10),
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 18),
                                    child: Text('+ 2 drink omaggio',
                                        style: OnlistTextStyles.body24Regular),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            // QR
                            Center(
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                color: Colors.white,
                                child: QrImageView(
                                  data: qrData,
                                  version: QrVersions.auto,
                                  size: (R.width * 0.62).clamp(160.0, 238.0),
                                  backgroundColor: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            // ANNULLA PREVENDITA (pill)
                            if (stato.toString().toLowerCase() != 'annullata')
                              Center(
                                child: GestureDetector(
                                  onTap: _isAnnullando
                                      ? null
                                      : () => _annulla(idPrenotazione),
                                  child: Container(
                                    width: 219,
                                    height: 35,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.13),
                                      borderRadius: BorderRadius.circular(10),
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
                                        : Text('ANNULLA PREVENDITA',
                                            style: OnlistTextStyles.button20Bold),
                                  ),
                                ),
                              )
                            else
                              Center(
                                child: Text('PREVENDITA ANNULLATA',
                                    style: OnlistTextStyles.button20Bold
                                        .copyWith(color: Colors.redAccent)),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Info aggiuntive
                      if (dataFormatted.isNotEmpty)
                        Text('Data: $dataFormatted',
                            style: OnlistTextStyles.hn(
                                color: Colors.white,
                                fontSize: R.sp(16),
                                fontWeight: FontWeight.w500)),
                      if (nomeCognome.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(nomeCognome,
                            style: OnlistTextStyles.hn(
                                color: Colors.white70, fontSize: R.sp(14))),
                      ] else if (nomeEvento.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(nomeEvento,
                            style: OnlistTextStyles.hn(
                                color: Colors.white70, fontSize: R.sp(14))),
                      ],
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
                                child: const Icon(Icons.keyboard_arrow_down,
                                    color: Colors.white, size: 18),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const SharedFooter(currentIndex: 1),
    );
  }

  Widget _buildBackRow() {
    return GestureDetector(
      onTap: () => NavigatorService.goBack(),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
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
