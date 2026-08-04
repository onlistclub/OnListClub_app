import 'package:flutter/material.dart';
import '../../core/services/navigator_service.dart';
import '../../core/services/analytics_service.dart';
import '../../core/utils/analytics_mixin.dart';
import '../../routes/app_routes.dart';
import '../../core/services/booking_service.dart';
import '../../core/services/cart_service.dart';
import '../../core/services/pending_order_service.dart';
import '../root_shell/root_shell.dart';
import '../../widgets/ticket_cards.dart';
import '../../core/utils/responsive.dart';
import '../../theme/onlist_colors.dart';
import '../../theme/onlist_text_styles.dart';
import '../../widgets/back_row.dart';
import '../../widgets/top_bar_slot.dart';
import '../../widgets/shared_footer.dart';
import '../../widgets/onlist_price_text.dart';
import '../../widgets/onlist_primary_button.dart';
import '../../widgets/app_error_dialog.dart';
import '../../core/services/badge_service.dart';

/// Carrello: **ordini lasciati in sospeso** e stato vuoto.
///
/// Quando l'utente apre la lista ticket di una serata, l'ordine finisce in
/// sospeso (`PendingOrderService`). Se esce senza concludere lo ritrova qui
/// sotto "Completa ordine", e il tocco sulla card lo riporta alla lista dei
/// ticket di quella serata. I sospesi valgono 48 ore.
///
/// Senza sospesi si vede lo stato vuoto del CSS `Carrello_vuoto`, con
/// "ordina ora" che porta alla Home.
///
/// ─────────────────────────────────────────────────────────────────────────
/// RIEPILOGO CARRELLO DISATTIVATO (MVP) — il passaggio di checkout qui sotto
/// è FUORI dal flusso d'acquisto.
///
/// Nel documento correzioni 1.1 il riepilogo carrello è stato tolto: l'utente
/// prenota al "PRENOTA ORA" del dettaglio ticket, che ora crea l'ordine e va
/// dritto alla conferma (vedi `booking_screen.prenotaOra`).
///
/// **Il codice qui resta completo e funzionante**, per scelta esplicita: non è
/// stato cancellato niente, né la UI né [_processPayment]. Per riattivare il
/// passaggio dal carrello bastano due mosse:
///  1. in `booking_screen`, rimettere la vecchia `addToCart` — naviga a
///     `AppRoutes.cartScreen` con gli stessi arguments che oggi passa a
///     `createReservation`;
///  2. togliere questo commento.
///
/// La schermata resta raggiungibile dal tab carrello della footer, dove mostra
/// l'ultimo ordine in memoria o lo stato vuoto: non fa parte del flusso, ma non
/// è nemmeno una schermata rotta.
class CartScreen extends StatefulWidget {
  const CartScreen({Key? key}) : super(key: key);

  static Widget builder(BuildContext context) => const CartScreen();

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen>
    with ScreenAnalytics, SingleTickerProviderStateMixin {
  @override
  String get screenName => 'cart';

  bool _isPaying = false;

  // ── Ordini in sospeso ─────────────────────────────────────────────────────
  /// Ordini lasciati a metà (entro le 48h), col loro evento e locale.
  List<Map<String, dynamic>> _sospesi = [];
  bool _sospesiCaricati = false;

  /// Micro-movimento di "ordina ora": stesso bob di ±2px di "torna alla home"
  /// nell'ordine effettuato, come richiesto. Solo Transform.translate.
  static const double _bobAmplitude = 2;
  late final AnimationController _bobCtrl;
  late final Animation<double> _bob;
  // Evita di ri-sincronizzare CartService().current a ogni rebuild (vedi
  // didChangeDependencies): senza questa guardia, il setState nel finally
  // di _processPayment rifaceva il build e RISCRIVEVA il carrello appena
  // svuotato da CartService().clear(), facendolo sembrare "sempre pieno".
  bool _cartSynced = false;

  @override
  void initState() {
    super.initState();
    // reverse: true → 900ms per verso, 1.8s a ciclo completo.
    _bobCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _bob = Tween<double>(begin: -_bobAmplitude, end: _bobAmplitude)
        .animate(CurvedAnimation(parent: _bobCtrl, curve: Curves.easeInOut));

    // Nello shell questa schermata resta MONTATA: `initState` gira una volta
    // sola. La lista si aggiorna dal segnale del servizio (nuovo sospeso,
    // ordine concluso, notifica vista).
    PendingOrderService().revisione.addListener(_caricaSospesi);
    _caricaSospesi();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      reportLoadTime('load_time_carrello');
    });
  }

  @override
  void dispose() {
    PendingOrderService().revisione.removeListener(_caricaSospesi);
    _bobCtrl.dispose();
    super.dispose();
  }

  Future<void> _caricaSospesi() async {
    final righe = await PendingOrderService().carica();
    if (!mounted) return;
    setState(() {
      _sospesi = righe;
      _sospesiCaricati = true;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_cartSynced) {
      _cartSynced = true;
      final routeArgs =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (routeArgs != null) {
        CartService().current = routeArgs;
      }
    }
  }

  Future<void> _processPayment(Map<String, dynamic>? args) async {
    setState(() => _isPaying = true);
    try {
      final prenotazioneId = await BookingService.createReservation(
        bookingType: args?['type'] ?? 'table',
        ticketId: args?['ticketId'],
        tavoloId: args?['tableId'],
        drinkId: args?['drinkId'],
        bottleQuantity: args?['quantity'] ?? 1,
        eventoId: args?['id_evento'] ?? '',
        nPersone: (args?['type'] == 'ticket') ? 1 : args?['nPersone'],
        ticketHolders: null,
      );

      AnalyticsService.log(
        event: 'booking_payment_success',
        metadata: {
          'type': args?['type'] ?? 'table',
          'amount': args?['price'] ?? '150€',
        },
      );
      // Funnel: prenotazione completata (evento richiesto dal foglio).
      AnalyticsService.logBookingComplete(
        type: args?['type'] ?? 'table',
        eventId: args?['id_evento'] as String?,
        amount: args?['price'],
      );

      CartService().clear();
      BadgeService().incrementNotificationBadge();
      // L'id della prenotazione appena creata viaggia con la route: la
      // schermata di conferma mostra QUESTO ordine, senza doverlo indovinare.
      NavigatorService.pushNamed(
        AppRoutes.paymentSuccessScreen,
        arguments: {'idPrenotazione': prenotazioneId},
      );
    } catch (e) {
      // Registra l'errore per la TAB Errori (http_error se è un errore Supabase).
      AnalyticsService.reportError(e, screen: 'cart');
      if (mounted) showAppErrorDialog(context, "Errore durante l'ordine: $e");
    } finally {
      if (mounted) setState(() => _isPaying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final routeArgs =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    // Con arguments si arriva dal riepilogo carrello (oggi disattivato); dalla
    // tab carrello invece no, e lì si vedono gli ordini in sospeso.
    // NOTA: la sincronizzazione di CartService().current con routeArgs
    // avviene UNA SOLA VOLTA in didChangeDependencies (non qui in build,
    // che gira a ogni rebuild — vedi commento su _cartSynced).
    final bool cameFromBooking = routeArgs != null;
    final args = routeArgs ?? CartService().current;
    final bool isEmpty = args == null;
    final String bookingType = args?['type'] as String? ?? "table";

    final bool haSospesi = isEmpty && _sospesi.isNotEmpty;

    // Sfondo NERO PIENO come il CSS ufficiale dei due carrelli
    // (`background: #000000`), non più il gradiente screenBackground: è la
    // stessa scelta già fatta per il dettaglio club nel design nuovo.
    return ColoredBox(
      color: Colors.black,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        // Footer flottante: il contenuto scorre dietro la capsula (non la oscura).
        extendBody: true,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              const TopBarSlot(),
              // Il "Torna indietro" c'è in entrambi i mock nuovi, quindi ora
              // si vede sempre. Arrivando dalla tab carrello non c'è nulla da
              // spopolare: come in Ordini, riporta alla Home come TAB.
              cameFromBooking
                  ? const BackRow()
                  : BackRow(onTap: () => _tornaAllaHome(context)),
              const SizedBox(height: 10),
              Expanded(
                child: haSospesi
                    ? _buildSospesiView()
                    : Padding(
                        padding: EdgeInsets.only(bottom: SharedFooter.height),
                        child: isEmpty
                            // Finché i sospesi non sono arrivati non si
                            // annuncia "il carrello è vuoto": eviterebbe un
                            // lampo di vuoto prima delle card.
                            ? (_sospesiCaricati
                                ? _buildEmptyCart()
                                : const SizedBox.shrink())
                            : (bookingType == "ticket"
                                ? _buildTicketCartView(args)
                                : _buildTableCartView(args)),
                      ),
              ),
            ],
          ),
        ),
        // La footer è quella globale dello shell (non montata qui).
      ),
    );
  }

  // ── Carrello con un ordine in sospeso ──────────────────────────────────────
  // CSS "Carrello in sospeso": titolo 36/500 a left 30 top 170, card 350×167
  // a top 220 — la stessa [TicketCollapsedCard] del riepilogo ordini, con
  // "Continua l'ordine" al posto di "Visualizza QR Code" (un ordine in sospeso
  // il QR non ce l'ha: non è ancora concluso).
  Widget _buildSospesiView() {
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(
          R.sp(21), 0, R.sp(21), SharedFooter.height + R.sp(16)),
      itemCount: _sospesi.length + 1,
      separatorBuilder: (_, __) => SizedBox(height: R.sp(18)),
      itemBuilder: (context, i) {
        if (i == 0) {
          return Padding(
            // CSS: titolo a left 30 (qui 9 oltre il padding 21) e 20 sopra
            // la card (170 + 36 di riga → card a 220... 14 di respiro).
            padding: EdgeInsets.only(left: R.sp(9), bottom: R.sp(14)),
            child: Text(
              'Completa ordine',
              style: OnlistTextStyles.hn(
                color: Colors.white,
                fontSize: R.sp(36),
                fontWeight: FontWeight.w500,
                height: 36 / 36,
                letterSpacing: -0.03 * 36,
              ),
            ),
          );
        }
        final sospeso = _sospesi[i - 1];
        return TicketCollapsedCard(
          clubName: _clubDelSospeso(sospeso),
          label: "Continua l'ordine",
          onTap: () => _riprendiOrdine(sospeso),
        );
      },
    );
  }

  String _clubDelSospeso(Map<String, dynamic> sospeso) {
    final evento = sospeso['eventi'] as Map<String, dynamic>?;
    final locale = evento?['locali'] as Map<String, dynamic>?;
    return (locale?['nome'] ?? 'Locale').toString();
  }

  /// Riporta l'utente alla LISTA TICKET della serata lasciata a metà.
  void _riprendiOrdine(Map<String, dynamic> sospeso) {
    final evento = sospeso['eventi'] as Map<String, dynamic>?;
    if (evento == null) return;
    AnalyticsService.log(
      event: 'pending_order_resumed',
      metadata: {'evento': evento['id']?.toString() ?? ''},
    );
    // La booking screen si aspetta {'serata': ..., 'locale': ...}. L'evento
    // arriva COMPLETO dall'embed (`eventi(*)`), quindi il SerataModel
    // ricostruito ha anche `eta_minima`: il gate d'età resta attivo.
    NavigatorService.pushNamed(
      AppRoutes.bookingScreen,
      arguments: {
        'serata': evento,
        'locale': evento['locali'],
      },
    );
  }

  // ── 14 — Carrello con ticket ────────────────────────────────────────────────
  Widget _buildTicketCartView(Map<String, dynamic>? args) {
    final ticketType = args?['ticketType']?.toString() ?? "Normale";
    final priceStr = args?['price']?.toString() ?? "10€";
    final priceVal =
        double.tryParse(priceStr.replaceAll("€", "").trim()) ?? 10.0;
    final total = priceVal.toStringAsFixed(0);
    // Descrizione reale del ticket (es. "+ 2 drink omaggio"), passata da
    // booking_screen. Prima era una stringa hardcoded sempre visibile anche
    // per ticket senza drink omaggio.
    final description = args?['description']?.toString().trim() ?? '';

    return Column(
      children: [
        // Card sintetica (gradiente #1E00FF -> #020011) con margine laterale,
        // in linea con le altre card della schermata (niente edge-to-edge).
        // Il gradiente è verificato a pixel contro il CSS: scarto 1÷5.
        // Le misure erano px FISSI: ora R.sp, come tutto il resto dell'app.
        Container(
          width: double.infinity,
          margin: EdgeInsets.symmetric(horizontal: R.sp(18)),
          padding: EdgeInsets.fromLTRB(R.sp(18), R.sp(14), R.sp(18), R.sp(18)),
          decoration: BoxDecoration(
            gradient: OnlistColors.cardSummary,
            borderRadius: BorderRadius.circular(R.sp(10)),
            // CSS: box-shadow 0px 4px 4px rgba(0,0,0,0.25) — mancava.
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                offset: Offset(0, R.sp(4)),
                blurRadius: R.sp(4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // "Ticket x 1" a sinistra, "Ticket Normale" piccolo a destra
              // allineato in alto (Figma 14): niente più offset verticale.
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      "Ticket x 1",
                      style: OnlistTextStyles.ticketLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(width: R.sp(8)),
                  Padding(
                    padding: EdgeInsets.only(top: R.sp(6)),
                    child: Text("Ticket $ticketType",
                        style: OnlistTextStyles.ticketSubtitleXs),
                  ),
                ],
              ),
              SizedBox(height: R.sp(4)),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    OnlistPriceText("$total€", style: OnlistTextStyles.price96),
                    if (description.isNotEmpty) ...[
                      SizedBox(width: R.sp(10)),
                      // Descrizione sale verso il centro verticale del prezzo
                      // (Figma 14): bottom padding maggiore = stringa più in
                      // alto rispetto al baseline del 96px.
                      Padding(
                        padding: EdgeInsets.only(bottom: R.sp(32)),
                        child: Text(description,
                            style: OnlistTextStyles.body24Regular),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        Padding(
          padding: EdgeInsets.fromLTRB(R.sp(18), R.sp(12), R.sp(18), R.sp(24)),
          child: OnlistPrimaryButton(
            label: 'ORDINA IL TUO POSTO ORA',
            isLoading: _isPaying,
            onPressed: _isPaying ? null : () => _processPayment(args),
          ),
        ),
      ],
    );
  }

  // ── Carrello con tavolo (layout conservato) ─────────────────────────────────
  Widget _buildTableCartView(Map<String, dynamic>? args) {
    return Column(
      children: [
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 18),
            decoration: BoxDecoration(
              color: OnlistColors.bluePrimary,
              borderRadius: BorderRadius.circular(10),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(15),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Ordine",
                      style: OnlistTextStyles.hn(
                        color: Colors.white,
                        fontSize: R.sp(36),
                        fontWeight: FontWeight.w400,
                        height: 41 / 36,
                        letterSpacing: -0.07 * 36,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildTableOrder(args),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
          child: OnlistPrimaryButton(
            label: _isPaying ? 'CARICAMENTO...' : 'ORDINA IL TUO POSTO ORA',
            isLoading: _isPaying,
            onPressed: _isPaying ? null : () => _processPayment(args),
          ),
        ),
      ],
    );
  }

  // ── Carrello vuoto (CSS "Carrello_vuoto") ─────────────────────────────────
  // Messaggio centrato nello spazio libero e "ordina ora" ancorato sopra la
  // footer, fuori dallo scroll: stessa struttura di "torna alla home"
  // nell'ordine effettuato. Le quote assolute del CSS (411 / 447 / 699) non
  // si possono ricopiare su schermi di altezza diversa: il messaggio si
  // centra, il blocco in fondo si àncora — che è ciò che il design descrive.
  Widget _buildEmptyCart() {
    return Column(
      children: [
        Expanded(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 30/500/-0.03em, bianco 68%.
                Text(
                  'Il carrello è vuoto',
                  style: OnlistTextStyles.hn(
                    color: OnlistColors.white.withValues(alpha: 0.68),
                    fontSize: R.sp(30),
                    fontWeight: FontWeight.w500,
                    height: 30 / 30,
                    letterSpacing: -0.03 * 30,
                  ),
                ),
                // CSS: sottotitolo a 447, titolo a 411 con riga 30 → 6.
                SizedBox(height: R.sp(6)),
                // 17/500/-0.03em su 2 righe centrate, stesso bianco 68%.
                Text(
                  'Seleziona un tavolo o un ticket\nper aggiungere un ordine',
                  textAlign: TextAlign.center,
                  style: OnlistTextStyles.hn(
                    color: OnlistColors.white.withValues(alpha: 0.68),
                    fontSize: R.sp(17),
                    fontWeight: FontWeight.w500,
                    height: 17 / 17,
                    letterSpacing: -0.03 * 17,
                  ),
                ),
              ],
            ),
          ),
        ),
        _buildOrdinaOra(),
        // CSS: la freccia chiude a 754, la capsula della footer parte a 777.
        // La clearance della footer la mette già il chiamante.
        SizedBox(height: R.sp(23)),
      ],
    );
  }

  /// "ordina ora" + freccia giù: stesso identico trattamento di "torna alla
  /// home" nell'ordine effettuato — gradiente `#FFFFFF → #0018C6` in
  /// ShaderMask e bob verticale di ±2px. Cambia solo il corpo (24 vs 20).
  Widget _buildOrdinaOra() {
    return AnimatedBuilder(
      animation: _bob,
      // Il figlio è costruito UNA volta: a ogni frame si ricostruisce solo il
      // Transform, così il bob non costa nulla.
      builder: (context, child) => Transform.translate(
        offset: Offset(0, _bob.value),
        child: child,
      ),
      child: GestureDetector(
        // "Seleziona un tavolo o un ticket": i club si scelgono dalla Home.
        onTap: () => _tornaAllaHome(context),
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
                'ordina ora',
                style: OnlistTextStyles.hn(
                  color: Colors.white,
                  fontSize: R.sp(24),
                  fontWeight: FontWeight.w500,
                  height: 24 / 24,
                  letterSpacing: -0.05 * 24,
                ),
              ),
            ),
            // CSS: testo a 699 (h 24) e freccia a 736 → 13.
            SizedBox(height: R.sp(13)),
            Icon(Icons.arrow_downward, color: Colors.white, size: R.sp(30)),
          ],
        ),
      ),
    );
  }

  Widget _buildTableOrder(Map<String, dynamic>? args) {
    final selectedTable = args?['table'] as String? ?? "C3";
    final bottleQuantity = args?['quantity'] as int? ?? 1;
    final bottleName = args?['bottle'] as String? ?? "GREY GOOSE";

    return Column(
      children: [
        _buildSummaryItem(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Tavolo n:",
                style: OnlistTextStyles.hn(
                  color: Colors.white,
                  fontSize: R.sp(38),
                  fontWeight: FontWeight.w400,
                  letterSpacing: -0.07 * 38,
                ),
              ),
              Expanded(
                child: Text(
                  selectedTable,
                  textAlign: TextAlign.right,
                  overflow: TextOverflow.ellipsis,
                  style: OnlistTextStyles.hn(
                      color: Colors.white,
                      fontSize: R.sp(60),
                      fontWeight: FontWeight.w400,
                      letterSpacing: -0.07 * 60),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 15),
        _buildSummaryItem(
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      bottleName.toUpperCase().replaceAll(" ", "\n"),
                      style: OnlistTextStyles.hn(
                          color: Colors.white,
                          fontSize: R.sp(23),
                          fontWeight: FontWeight.w400,
                          letterSpacing: -0.07 * 23),
                    ),
                  ),
                  Text(
                    "150€",
                    style: OnlistTextStyles.hn(
                      color: Colors.white,
                      fontSize: R.sp(44),
                      fontWeight: FontWeight.w400,
                      letterSpacing: -0.07 * 44,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border:
                      Border.all(color: OnlistColors.bluePrimary, width: 2.9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Quantità: $bottleQuantity",
                      style: OnlistTextStyles.hn(
                          color: Colors.black,
                          fontSize: R.sp(23),
                          fontWeight: FontWeight.w400,
                          letterSpacing: -0.07 * 23),
                    ),
                    const Icon(Icons.keyboard_arrow_down,
                        color: Colors.black, size: 34),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Dentro lo shell la Home è una TAB: cambiarla preserva lo stato invece di
  /// ricostruire la schermata. Fuori (schermate legacy) resta la navigazione.
  void _tornaAllaHome(BuildContext context) {
    final shell = RootShellScope.of(context);
    if (shell != null) {
      shell.switchToTab(1);
      return;
    }
    NavigatorService.pushNamedAndRemoveUntil(AppRoutes.homeScreen);
  }

  Widget _buildSummaryItem({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(10),
      ),
      child: child,
    );
  }
}
