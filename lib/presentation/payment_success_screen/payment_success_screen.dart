import 'package:flutter/material.dart';

import '../../core/services/navigator_service.dart';
import '../../core/services/orders_service.dart';
import '../../core/services/pending_order_service.dart';
import '../../core/services/ticket_non_visti_service.dart';
import '../../core/utils/responsive.dart';
import '../../routes/app_routes.dart';
import '../../theme/onlist_text_styles.dart';
import '../../widgets/top_bar_slot.dart';
import '../../widgets/flip_card.dart';
import '../../widgets/shared_footer.dart';
import '../../widgets/ticket_cards.dart';

/// Conferma ordine + "Visualizza ticket" (design NUOVO "Ordine Effettuato").
///
/// Tre stati della stessa schermata:
/// 1. biglietti CHIUSI ([TicketCollapsedCard]) sotto "ORDINE effettuato";
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
  // Aprendo un biglietto la card passa da 140 a 614 px e sparisce
  // l'intestazione: prima succedeva tutto in un frame, da cui il salto brusco.
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

  // Col biglietto APERTO "torna alla home" non sta fisso sopra la footer (si
  // sovrapporrebbe alla card, alta 614): sta in coda allo scroll e compare con
  // una dissolvenza quando si arriva in fondo (doc correzioni 19/09).
  final ScrollController _scrollCtrl = ScrollController();
  bool _tornaHomeInFondo = false;

  /// Quanto manca al fondo perché "torna alla home" si mostri.
  static const double _sogliaFondo = 24;

  void _aggiornaTornaHome() {
    if (!_scrollCtrl.hasClients) return;
    final pos = _scrollCtrl.position;
    final bool inFondo =
        pos.pixels >= pos.maxScrollExtent - _sogliaFondo;
    if (inFondo != _tornaHomeInFondo) {
      setState(() => _tornaHomeInFondo = inFondo);
    }
  }

  @override
  void initState() {
    super.initState();
    PendingOrderService().sospendiPerConferma();

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

    _scrollCtrl.addListener(_aggiornaTornaHome);

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
    // Lasciata la conferma: se restano ordini in sospeso il pallino del
    // carrello si riaccende.
    PendingOrderService().riprendiDopoConferma();
    _scrollCtrl.dispose();
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

  /// Distanza della freccia di "torna alla home" dalla capsula della footer
  /// (CSS: freccia 746+30 = 776, capsula a 781).
  static const double _tornaHomeSopraFooter = 5;

  /// Ingombro di "torna alla home" fisso: testo 20 + freccia 30 + stacco.
  static double get _tornaHomeIngombro =>
      R.sp(20 + 30 + _tornaHomeSopraFooter);

  @override
  Widget build(BuildContext context) {
    // "torna alla home" coi biglietti chiusi sta FISSO appena sopra la footer,
    // con la freccia che punta all'icona Home (doc correzioni 16/09). Con un
    // biglietto aperto (614px) invece torna in coda allo scroll: fisso finiva
    // sopra la card.
    final bool tornaHomeFisso = _openedIndex == null;
    // Design NUOVO: sfondo NERO FISSO.
    return Scaffold(
      backgroundColor: Colors.black,
      // Footer flottante: il contenuto scorre dietro la capsula.
      extendBody: true,
      body: ColoredBox(
        color: Colors.black,
        child: Stack(
          children: [
            SafeArea(
          bottom: false,
          child: Column(
            children: [
              const TopBarSlot(),
              Expanded(
                child: SingleChildScrollView(
                  controller: _scrollCtrl,
                  // Margini 18 invece dei 21 del CSS: scostamento VOLUTO da
                  // Luca per allargare il biglietto di ~6px (stesso valore di
                  // prevendita_detail_screen — sono la stessa card).
                  padding: EdgeInsets.fromLTRB(
                      R.sp(18),
                      0,
                      R.sp(18),
                      SharedFooter.height +
                          (tornaHomeFisso ? _tornaHomeIngombro : 0)),
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
                        // CSS: top bar chiude a ~118, ORDINE a 139,
                        // "Visualizza ticket" a 275.
                        child: _openedIndex == null
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(height: R.sp(21)),
                                  _buildHeader(),
                                  SizedBox(height: R.sp(24)),
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
                        // La scatola cresce da 140 a 614; il contenuto entra
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
                      if (!tornaHomeFisso) ...[
                        SizedBox(height: R.sp(18)),
                        AnimatedOpacity(
                          opacity: _tornaHomeInFondo ? 1 : 0,
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOut,
                          child: Center(child: _buildTornaAllaHome()),
                        ),
                        SizedBox(height: R.sp(8)),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
            ),
            if (tornaHomeFisso)
              Positioned(
                left: 0,
                right: 0,
                bottom: SharedFooter.height + R.sp(_tornaHomeSopraFooter),
                child: Center(child: _buildTornaAllaHome()),
              ),
          ],
        ),
      ),
      // Footer: unica e globale, montata da RootShell (non qui).
    );
  }

  // ── Intestazione "ORDINE effettuato" + spunta ────────────────────────────
  // Nel CSS il blocco è: ORDINE 341×88 a (24,139), "effettuato" 39 con la
  // linea di base a ~240, spunta Ø23 a (269,204) appoggiata sull'ultima
  // lettera.
  //
  // Col nostro font "ORDINE" alla larghezza del CSS (341) viene alto 67 e non
  // 88: le lettere sono più strette di quelle del Figma. Per non rompere il
  // gruppo, tutto ciò che sta sotto — corpo di "effettuato", spunta, quote
  // verticali — è riscalato dello stesso fattore, così la parola piccola
  // resta appoggiata alla grande come nel disegno.
  static const double _ordineW = 341;
  static const double _ordineH = 67;

  /// Quanto il nostro "ORDINE" è più basso di quello del Figma.
  static const double _k = _ordineH / 88;

  /// Corpo di "effettuato": 42 darebbe i 169 del CSS, riscalato con il resto.
  static const double _effettuatoFs = 42 * _k;

  static const double _headerH = 105 * _k;

  Widget _buildHeader() {
    // Linea di base di "effettuato": 101 sotto il bordo alto di ORDINE nel
    // CSS. Con height 1 la base cade al 78.3% del corpo (ascent 71.4 su 91.2
    // di OnlistHN).
    final double baseEffettuato = 101 * _k;
    final double topEffettuato = baseEffettuato - _effettuatoFs * 0.783;
    // Larghezza reale di "effettuato" (3.988 em con crenatura -0.07em): la
    // spunta si appoggia 12 px design prima della sua fine, come nel CSS.
    final double largEffettuato = _effettuatoFs * 3.988;
    final double spunta = 23 * _k;

    return SizedBox(
      height: R.sp(_headerH),
      width: double.infinity,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: R.sp(24 - 18),
            top: 0,
            width: R.sp(_ordineW),
            height: R.sp(_ordineH),
            child: ShaderMask(
              blendMode: BlendMode.srcIn,
              shaderCallback: (bounds) => const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.white, Colors.white, Color(0x00FFFFFF)],
                stops: [0.0, 0.6298, 1.0],
              ).createShader(bounds),
              // fill su un riquadro che ha già le proporzioni dei glifi:
              // riempie i 341 senza deformare le lettere.
              child: const FittedBox(fit: BoxFit.fill, child: _OrdineGlifi()),
            ),
          ),
          Positioned(
            left: R.sp((112 - 24) * _k + (24 - 18)),
            top: R.sp(topEffettuato),
            child: Text(
              'effettuato',
              style: OnlistTextStyles.hn(
                color: Colors.white,
                fontSize: R.sp(_effettuatoFs),
                fontWeight: FontWeight.w700,
                height: 1.0,
                letterSpacing: -0.07 * R.sp(_effettuatoFs),
              ),
            ),
          ),
          Positioned(
            left: R.sp((112 - 24) * _k + (24 - 18) + largEffettuato - 12 * _k),
            top: R.sp(65 * _k),
            child: Container(
              width: R.sp(spunta),
              height: R.sp(spunta),
              decoration: const BoxDecoration(
                color: Color(0xFF0009FF),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(Icons.check_rounded,
                  color: Colors.white, size: R.sp(spunta * 0.74)),
            ),
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
              // Biglietto aperto: si spegne il pallino dei TICKET.
              TicketNonVistiService().segnaVisto(
                  (_tickets[i]['prenotazioni'] as Map<String, dynamic>?)?['id']
                      ?.toString());
              setState(() {
                _openedIndex = i;
                _showQr = false;
              });
              // Fa partire fade + slide del contenuto del biglietto aperto.
              _openCtrl.forward(from: 0);
              // La card cambia altezza: ricontrolla se siamo già in fondo.
              WidgetsBinding.instance
                  .addPostFrameCallback((_) => _aggiornaTornaHome());
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
    // Accanto alla quantità va il NUMERO delle offerte ("+ 3 Plus"), contato
    // sulle voci della descrizione del DB; l'elenco per esteso resta sotto
    // "Dettagli" prima dell'acquisto (doc correzioni 19/09).
    final plus = contaPlus((prevendita?['descrizione'] as String?) ??
        (prevendita?['riepilogo'] as String?));
    final quantita = (t['quantita'] ?? prenotazione?['quantita'] ?? 1) as int;

    return FlipCard(
      showBack: _showQr,
      // Tap ovunque sulla card = gira il biglietto (i bottoni interni
      // mantengono la loro azione).
      onTap: () => setState(() => _showQr = !_showQr),
      back: TicketBackCard(
        clubName: _clubName(t),
        quantita: quantita,
        plus: plus,
        eventoNome: (evento?['nome'] ?? '').toString(),
        eventoSottotitolo: null,
        dataEvento: _formatData(evento?['data']),
        qrData: _qrData(t),
        onHide: () => setState(() => _showQr = false),
      ),
      front: TicketFrontCard(
        ticketType: (prevendita?['tipo'] ?? 'normale').toString(),
        quantita: quantita,
        plus: plus,
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
          // CSS: la freccia (box 30 a 746) parte 3px prima della fine del
          // testo (729+20): il glifo ha già margine interno, quindi niente
          // spazio in mezzo.
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


/// "ORDINE" ritagliato ESATTAMENTE sui glifi, così il riquadro che lo contiene
/// non conta lo spazio vuoto sopra e sotto le maiuscole e la parola parte dal
/// bordo alto come nel CSS.
///
/// Misure di OnlistHN-Bold a corpo 100 (height 1): linea di base a 78.3,
/// maiuscole alte 73 (con l'overshoot della O) e 2 sotto la base → i glifi
/// occupano da 5.3 a 80.3, cioè 75 di altezza.
///
/// La crenatura resta quella del design (−0.02em): stringerla fino a far
/// entrare la parola negli 88 px di altezza del CSS faceva sovrapporre la "I"
/// alle lettere vicine, e "ORDINE" si leggeva "ORDNE".
class _OrdineGlifi extends StatelessWidget {
  const _OrdineGlifi();

  static const double _corpo = 100;
  static const double _altezzaGlifi = 75;

  /// Allinea il box di 100 dentro i 75 visibili con il bordo alto delle
  /// maiuscole (5.3) sul bordo: (75−100)·(a+1)/2 = −5.3 → a = −0.576.
  static const double _allineamentoY = -0.576;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: Align(
        alignment: const Alignment(0, _allineamentoY),
        heightFactor: _altezzaGlifi / _corpo,
        child: Text(
          'ORDINE',
          maxLines: 1,
          textScaler: TextScaler.noScaling,
          style: OnlistTextStyles.hn(
            color: Colors.white,
            fontSize: _corpo,
            fontWeight: FontWeight.w700,
            height: 1.0,
            letterSpacing: -0.02 * _corpo,
          ),
        ),
      ),
    );
  }
}
