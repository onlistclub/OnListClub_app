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

class _PaymentSuccessScreenState extends State<PaymentSuccessScreen>
    with TickerProviderStateMixin {
  List<Map<String, dynamic>> _tickets = [];
  bool _isLoading = true;

  /// Indice del biglietto aperto (null = tutti chiusi).
  int? _openedIndex;

  /// True quando del biglietto aperto si mostra il RETRO (QR).
  bool _showQr = false;

  /// Id della prenotazione appena creata, passato dal carrello negli arguments
  /// della route. Si legge in [didChangeDependencies] perché `ModalRoute.of`
  /// non è disponibile in `initState`.
  String? _idPrenotazioneRoute;
  bool _loadStarted = false;

  // ── Apertura del biglietto ────────────────────────────────────────────────
  // Aprendo un biglietto la card passa da 167 a 614 px e sparisce il titolo a
  // cascata: prima succedeva tutto in un frame, da cui il salto brusco.
  //
  // Ora l'effetto è in DUE TEMPI: la scatola cresce (AnimatedSize, 320ms
  // easeOutCubic) e il contenuto entra DOPO, con ~120ms di ritardo, in fade +
  // micro-slide verso l'alto. È il ritardo fra i due che toglie la sensazione
  // di scatto: il testo non compare mentre lo spazio non c'è ancora.
  //
  // Costo: l'unica cosa che cambia layout è l'altezza di un contenitore; il
  // contenuto usa solo Transform e Opacity (60fps anche su S7). Il QR, l'unica
  // parte pesante, sta sul retro e in quel momento non è montato.
  static const Duration _expandDuration = Duration(milliseconds: 320);
  static const Curve _expandCurve = Curves.easeOutCubic;
  late final AnimationController _openCtrl;
  late final Animation<double> _openFade;
  late final Animation<Offset> _openSlide;

  // Micro-movimento di "torna alla home": bob verticale di ±2px con ciclo
  // completo di 1.8s. Solo Transform.translate, costo nullo — si nota con la
  // coda dell'occhio senza catturare l'attenzione.
  static const double _bobAmplitude = 2;
  late final AnimationController _bobCtrl;
  late final Animation<double> _bob;

  @override
  void initState() {
    super.initState();

    _openCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 340),
    );
    // Il contenuto parte al 35% della corsa (~120ms), quando la scatola ha già
    // iniziato ad aprirsi.
    const contentInterval = Interval(0.35, 1.0, curve: Curves.easeOut);
    _openFade = CurvedAnimation(parent: _openCtrl, curve: contentInterval);
    _openSlide = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _openCtrl, curve: contentInterval));

    // reverse: true → 900ms per verso, 1.8s a ciclo completo.
    _bobCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _bob = Tween<double>(begin: -_bobAmplitude, end: _bobAmplitude)
        .animate(CurvedAnimation(parent: _bobCtrl, curve: Curves.easeInOut));

    // Il caricamento parte da didChangeDependencies: prima serve leggere
    // l'id della prenotazione dagli arguments della route.
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loadStarted) return;
    _loadStarted = true;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map && args['idPrenotazione'] != null) {
      _idPrenotazioneRoute = args['idPrenotazione'].toString();
    }
    _load();
  }

  @override
  void dispose() {
    _openCtrl.dispose();
    _bobCtrl.dispose();
    super.dispose();
  }

  /// Prenotazione col `created_at` più recente fra le righe caricate.
  /// Usato solo come rete di sicurezza: normalmente l'id arriva dalla route.
  String? _idPrenotazionePiuRecente(List<Map<String, dynamic>> all) {
    String? bestId;
    DateTime? bestAt;
    for (final r in all) {
      final pren = r['prenotazioni'] as Map<String, dynamic>?;
      final id = pren?['id']?.toString();
      if (id == null) continue;
      final at = DateTime.tryParse(pren?['created_at']?.toString() ?? '');
      // Senza created_at leggibile non si può decidere: si tiene il primo utile.
      if (at == null) {
        bestId ??= id;
        continue;
      }
      if (bestAt == null || at.isAfter(bestAt)) {
        bestAt = at;
        bestId = id;
      }
    }
    return bestId;
  }

  Future<void> _load() async {
    try {
      final all = await OrdersService.getPrevenditeOrdini();

      // L'id arriva dal carrello, che l'ha avuto da createReservation: è
      // l'ordine appena creato, senza ambiguità.
      //
      // Prima si prendeva `all.first` confidando che la query fosse ordinata
      // "dal più nuovo": ma l'ordinamento era su `id`, che è un uuid casuale
      // (`gen_random_uuid()`), quindi la prima riga era sempre la stessa a
      // caso — di qui il club sbagliato in conferma.
      String? prenotazioneId = _idPrenotazioneRoute;

      // Fallback (riapertura della route senza arguments): la prenotazione con
      // `created_at` più recente. `prenotazioni_prevendite` non ha un
      // `created_at` proprio, quindi si guarda quello della prenotazione madre.
      prenotazioneId ??= _idPrenotazionePiuRecente(all);

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
                  // Margini 18 invece dei 21 del CSS: scostamento VOLUTO da
                  // Luca per allargare il biglietto di ~6px (stesso valore di
                  // prevendita_detail_screen — sono la stessa card).
                  //
                  // Fondo 40 (era 16): col biglietto APERTO la card da 614
                  // spingeva "torna alla home" contro la footer. Sono 40px di
                  // stacco pulito in entrambi gli stati — più dei 32 del Figma,
                  // che però sotto la scritta non ha la freccia.
                  padding: EdgeInsets.fromLTRB(
                      R.sp(18), 0, R.sp(18), R.sp(40) + SharedFooter.height),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Il titolo a cascata resta solo coi biglietti chiusi
                      // (quando se ne apre uno, la card prende la schermata).
                      // AnimatedSize così anche il suo sparire è graduale e non
                      // strappa in su tutto il contenuto sotto.
                      AnimatedSize(
                        duration: _expandDuration,
                        curve: _expandCurve,
                        alignment: Alignment.topCenter,
                        child: _openedIndex == null
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(height: R.sp(49)),
                                  _buildCascadeTitle(),
                                  SizedBox(height: R.sp(45)),
                                ],
                              )
                            : SizedBox(height: R.sp(12)),
                      ),
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
                        // La scatola cresce da 167 a 614; il contenuto entra
                        // dopo (vedi _buildOpenTicket).
                        AnimatedSize(
                          duration: _expandDuration,
                          curve: _expandCurve,
                          alignment: Alignment.topCenter,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: _buildTickets(),
                          ),
                        ),
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
            child:
                Text('Buon divertimento!', style: OnlistTextStyles.body20Light),
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
            style:
                OnlistTextStyles.hn(color: Colors.white54, fontSize: R.sp(16)),
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
            onTap: () {
              setState(() {
                _openedIndex = i;
                _showQr = false;
              });
              // Fa partire fade + slide del contenuto del biglietto aperto.
              _openCtrl.forward(from: 0);
            },
          ),
        ),
    ];
  }

  /// Biglietto aperto: fronte e retro, con rotazione 3D fra le due facce
  /// ([FlipCard]).
  Widget _buildOpenTicket(Map<String, dynamic> t) {
    // Fade + micro-slide in coda all'espansione della scatola.
    return FadeTransition(
      opacity: _openFade,
      child: SlideTransition(
        position: _openSlide,
        child: _buildOpenTicketCard(t),
      ),
    );
  }

  Widget _buildOpenTicketCard(Map<String, dynamic> t) {
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
    // Il figlio è costruito UNA volta: a ogni frame si ricostruisce solo il
    // Transform, così il bob non costa nulla.
    return AnimatedBuilder(
      animation: _bob,
      builder: (context, child) => Transform.translate(
        offset: Offset(0, _bob.value),
        child: child,
      ),
      child: _tornaAllaHomeContent(),
    );
  }

  Widget _tornaAllaHomeContent() {
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
          Icon(Icons.arrow_downward, color: Colors.white, size: R.sp(30)),
        ],
      ),
    );
  }

  // ── Helper dati ────────────────────────────────────────────────────────────
  String _clubName(Map<String, dynamic> t) {
    final evento = (t['prenotazioni'] as Map<String, dynamic>?)?['eventi']
        as Map<String, dynamic>?;
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
