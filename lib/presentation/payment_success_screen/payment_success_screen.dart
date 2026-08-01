import 'package:flutter/material.dart';

import '../../core/services/navigator_service.dart';
import '../../core/services/orders_service.dart';
import '../../core/utils/responsive.dart';
import '../../routes/app_routes.dart';
import '../../theme/onlist_text_styles.dart';
import '../../widgets/custom_top_bar.dart';
import '../../widgets/flip_card.dart';
import '../../widgets/shared_footer.dart';
import '../../widgets/ticket_cards.dart';

/// Conferma ordine + "Visualizza ticket" (design NUOVO "Ordine Effettuato").
///
/// Tre stati della stessa schermata:
/// 1. biglietti CHIUSI ([TicketCollapsedCard]) sotto il titolo a cascata;
/// 2. biglietto APERTO, fronte ([TicketFrontCard]) con dati e pagamento;
/// 3. biglietto APERTO, retro ([TicketBackCard]) col QR code reale.
///
/// Il passaggio fronte↔retro è una rotazione 3D ([FlipCard]).
///
/// I dati arrivano dal DB: si caricano le righe `prenotazioni_prevendite`
/// della prenotazione più recente (la query di [OrdersService] è già ordinata
/// per id decrescente), cioè l'ordine appena creato.
class PaymentSuccessScreen extends StatefulWidget {
  const PaymentSuccessScreen({Key? key}) : super(key: key);

  static Widget builder(BuildContext context) => const PaymentSuccessScreen();

  @override
  State<PaymentSuccessScreen> createState() => _PaymentSuccessScreenState();
}

class _PaymentSuccessScreenState extends State<PaymentSuccessScreen> {
  List<Map<String, dynamic>> _tickets = [];
  bool _isLoading = true;

  /// Indice del biglietto aperto (null = tutti chiusi).
  int? _openedIndex;

  /// True quando del biglietto aperto si mostra il RETRO (QR).
  bool _showQr = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final all = await OrdersService.getPrevenditeOrdini();
      // Le righe dell'ordine appena creato: quelle della prenotazione più
      // recente (la query è ordinata per id desc → la prima è la più nuova).
      final firstPrenotazione =
          (all.isNotEmpty ? all.first['prenotazioni'] as Map<String, dynamic>? : null);
      final prenotazioneId = firstPrenotazione?['id']?.toString();
      final tickets = prenotazioneId == null
          ? <Map<String, dynamic>>[]
          : all
              .where((r) =>
                  (r['prenotazioni'] as Map<String, dynamic>?)?['id']
                      ?.toString() ==
                  prenotazioneId)
              .toList();
      if (!mounted) return;
      setState(() {
        _tickets = tickets;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('[PaymentSuccess] Errore caricamento ticket: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Design NUOVO: sfondo NERO FISSO.
    return Scaffold(
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
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                      R.sp(21), 0, R.sp(21), R.sp(16) + SharedFooter.height),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Il titolo a cascata resta solo coi biglietti chiusi
                      // (quando se ne apre uno, la card prende la schermata).
                      if (_openedIndex == null) ...[
                        SizedBox(height: R.sp(49)),
                        _buildCascadeTitle(),
                        SizedBox(height: R.sp(45)),
                      ] else
                        SizedBox(height: R.sp(12)),
                      // "Visualizza ticket" 36/400/-0.07em.
                      Text(
                        'Visualizza ticket',
                        style: OnlistTextStyles.hn(
                          color: Colors.white,
                          fontSize: R.sp(36),
                          fontWeight: FontWeight.w400,
                          height: 36 / 36,
                          letterSpacing: -0.07 * 36,
                        ),
                      ),
                      SizedBox(height: R.sp(22)),
                      if (_isLoading)
                        Padding(
                          padding: EdgeInsets.only(top: R.sp(40)),
                          child: const Center(
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
                          ),
                        )
                      else
                        ..._buildTickets(),
                      SizedBox(height: R.sp(40)),
                      // "torna alla home" — testo in gradiente + freccia giù
                      // (CSS: linear-gradient(90deg, #FFF, #0018C6)).
                      Center(child: _buildTornaAllaHome()),
                    ],
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

  // ── Titolo "a cascata" (CSS: ORDINE 64/300, EFFETTUATO 36, sottotitolo 20)
  Widget _buildCascadeTitle() {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 19),
            child: Text('ORDINE', style: OnlistTextStyles.display64Light),
          ),
          const Padding(
            padding: EdgeInsets.only(left: 142),
            child: Text('EFFETTUATO', style: OnlistTextStyles.title36Light),
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.only(left: 192),
            child: Text('Buon divertimento!',
                style: OnlistTextStyles.body20Light),
          ),
        ],
      ),
    );
  }

  // ── Biglietti: chiusi, oppure quello aperto (fronte/retro) ─────────────────
  List<Widget> _buildTickets() {
    if (_tickets.isEmpty) {
      return [
        Padding(
          padding: EdgeInsets.only(top: R.sp(20)),
          child: Text(
            'Nessun ticket da mostrare per questo ordine.',
            style: OnlistTextStyles.hn(
                color: Colors.white54, fontSize: R.sp(16)),
          ),
        ),
      ];
    }

    if (_openedIndex != null) {
      return [_buildOpenTicket(_tickets[_openedIndex!])];
    }

    return [
      for (var i = 0; i < _tickets.length; i++)
        Padding(
          padding: EdgeInsets.only(bottom: R.sp(18)),
          child: TicketCollapsedCard(
            clubName: _clubName(_tickets[i]),
            onTap: () => setState(() {
              _openedIndex = i;
              _showQr = false;
            }),
          ),
        ),
    ];
  }

  /// Biglietto aperto: fronte e retro, con rotazione 3D fra le due facce
  /// ([FlipCard]).
  Widget _buildOpenTicket(Map<String, dynamic> t) {
    final prenotazione = t['prenotazioni'] as Map<String, dynamic>?;
    final prevendita = t['prevendite'] as Map<String, dynamic>?;
    final evento = prenotazione?['eventi'] as Map<String, dynamic>?;
    final descrizione = (prevendita?['descrizione'] as String?)?.trim();
    final quantita = (t['quantita'] ?? prenotazione?['quantita'] ?? 1) as int;

    return FlipCard(
      showBack: _showQr,
      // Tap ovunque sulla card = gira il biglietto (i bottoni interni
      // mantengono la loro azione).
      onTap: () => setState(() => _showQr = !_showQr),
      back: TicketBackCard(
        clubName: _clubName(t),
        quantita: quantita,
        descrizione: descrizione,
        eventoNome: (evento?['nome'] ?? '').toString(),
        eventoSottotitolo: null,
        dataEvento: _formatData(evento?['data']),
        qrData: _qrData(t),
        onHide: () => setState(() => _showQr = false),
      ),
      front: TicketFrontCard(
        ticketType: (prevendita?['tipo'] ?? 'normale').toString(),
        quantita: quantita,
        descrizione: descrizione,
        nome: (t['nome'] ?? '—').toString(),
        cognome: (t['cognome'] ?? '—').toString(),
        prezzo: _formatPrezzo(prevendita?['prezzo']),
        onShowQr: () => setState(() => _showQr = true),
        onCollapse: () => setState(() {
          _openedIndex = null;
          _showQr = false;
        }),
      ),
    );
  }

  Widget _buildTornaAllaHome() {
    return GestureDetector(
      onTap: () =>
          NavigatorService.pushNamedAndRemoveUntil(AppRoutes.homeScreen),
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [Color(0xFFFFFFFF), Color(0xFF0018C6)],
            ).createShader(bounds),
            blendMode: BlendMode.srcIn,
            child: Text(
              'torna alla home',
              style: OnlistTextStyles.hn(
                color: Colors.white,
                fontSize: R.sp(20),
                fontWeight: FontWeight.w500,
                height: 20 / 20,
                letterSpacing: -0.05 * 20,
              ),
            ),
          ),
          SizedBox(height: R.sp(9)),
          Icon(Icons.arrow_downward,
              color: Colors.white, size: R.sp(30)),
        ],
      ),
    );
  }

  // ── Helper dati ────────────────────────────────────────────────────────────
  String _clubName(Map<String, dynamic> t) {
    final evento =
        (t['prenotazioni'] as Map<String, dynamic>?)?['eventi'] as Map<String, dynamic>?;
    return ((evento?['locali'] as Map<String, dynamic>?)?['nome'] ?? 'Locale')
        .toString();
  }

  /// QR scansionabile: URL di verifica con l'UUID della riga
  /// `prenotazioni_prevendite` (il sito /staff chiama `scan_ticket`).
  String _qrData(Map<String, dynamic> t) {
    final id = t['id']?.toString();
    return id != null
        ? 'https://www.onlistclub.com/verify/$id'
        : 'onlist-ticket';
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
