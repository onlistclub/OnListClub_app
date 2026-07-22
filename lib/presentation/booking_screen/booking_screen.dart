import 'dart:ui' show ImageFilter;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/models/locale_model.dart';
import '../../core/models/serata_model.dart';
import '../../core/services/analytics_service.dart';
import '../../core/utils/analytics_mixin.dart';
import '../../core/services/navigator_service.dart';
import '../../core/services/booking_service.dart';
import '../../core/services/orders_service.dart';
import '../../core/utils/age_gate.dart';
import '../../core/utils/responsive.dart';
import '../../routes/app_routes.dart';
import '../../theme/onlist_colors.dart';
import '../../theme/onlist_text_styles.dart';
import '../../widgets/app_loading_indicator.dart';
import '../../widgets/image_fallback.dart';
import '../../widgets/onlist_price_text.dart';
import '../../widgets/onlist_primary_button.dart';
import '../../widgets/onlist_ticket_title.dart';
import '../../widgets/animated_press.dart';
import '../../widgets/custom_top_bar.dart';
import '../../widgets/shared_footer.dart';

enum BookingStep { selection, ticketList, ticketDetail, tableConfig, bottles }

class BookingScreen extends StatefulWidget {
  const BookingScreen({Key? key}) : super(key: key);

  static Widget builder(BuildContext context) => const BookingScreen();

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> with ScreenAnalytics {
  @override
  String get screenName => 'booking_selection';

  // La schermata parte direttamente dalla lista prevendite (la selezione Tavolo/Prevendita è temporaneamente nascosta).
  BookingStep _currentStep = BookingStep.ticketList;

  // Dati letti SEMPRE dal DB (Supabase). Nessun sample/placeholder: se il DB
  // non restituisce nulla la UI mostra l'empty state, non dati finti.
  List<Map<String, dynamic>> _prevendite = [];
  List<Map<String, dynamic>> _tavoli = [];
  List<Map<String, dynamic>> _bottiglie = [];
  bool _isLoading = true;
  String? _loadError;

  // Data di nascita utente per il gate d'età (eventi 16+/18+). Null = sconosciuta
  // → nessun blocco (fail-open, non blocchiamo per un dato mancante).
  DateTime? _userDob;

  // Selection state
  String _selectedTable = "Seleziona";
  String? _selectedTableId;
  int _participants = 10;
  int _bottleQuantity = 1;
  Map<String, dynamic>? _selectedTicket;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchData();
    });
  }

  Future<void> _fetchData() async {
    final args = _parseArgs(context);
    if (args.serata == null) {
      setState(() => _isLoading = false);
      return;
    }

    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final prevendite = await BookingService.getPrevendite(args.serata!.id);
      final tavoli = await BookingService.getTavoli(args.serata!.id);
      final bottiglie = await BookingService.getBottiglie();
      final dob = await _loadUserDob();

      if (!mounted) return;
      setState(() {
        // Assegnazione diretta: il DB è l'unica fonte. Se è vuoto, le liste
        // restano vuote e la UI mostra l'empty state corretto.
        _prevendite = prevendite;
        _tavoli = tavoli;
        _bottiglie = bottiglie;
        _userDob = dob;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Errore nel caricamento dati booking: $e");
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError =
            'Errore nel caricamento delle prevendite. Tira giù per riprovare.';
      });
    }

    // Notifica l'utente dopo il primo frame, senza dipendere da posizionare
    // un widget banner specifico nella UI (che è molto stratificata).
    if (_loadError != null && mounted) {
      final msg = _loadError!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Riprova',
              onPressed: _fetchData,
            ),
          ),
        );
      });
    }
  }

  /// Data di nascita utente da `utenti.data_nascita` (per il gate d'età).
  Future<DateTime?> _loadUserDob() async {
    try {
      final profile = await OrdersService.getUserProfile();
      final dobStr = profile?['data_nascita'] as String?;
      return dobStr != null ? DateTime.tryParse(dobStr) : null;
    } catch (_) {
      return null;
    }
  }

  static ({LocaleModel? locale, SerataModel? serata}) _parseArgs(
      BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;

    if (args is Map) {
      final clubData = args['club'] ?? args['locale'];
      final serataData = args['serata'];

      LocaleModel? locale;
      if (clubData is LocaleModel) {
        locale = clubData;
      } else if (clubData is Map<String, dynamic>) {
        locale = LocaleModel.fromMap(clubData);
      }

      SerataModel? serata;
      if (serataData is SerataModel) {
        serata = serataData;
      } else if (serataData is Map<String, dynamic>) {
        serata = SerataModel.fromMap(serataData);
      }

      return (locale: locale, serata: serata);
    }

    if (args is LocaleModel) {
      return (locale: args, serata: null);
    }
    return (locale: null, serata: null);
  }

  @override
  Widget build(BuildContext context) {
    final (:locale, :serata) = _parseArgs(context);

    if (serata == null) {
      return _buildNoSerataView();
    }

    return Scaffold(
      backgroundColor: Colors.black,
      // Footer flottante: il contenuto scorre dietro la capsula (non la oscura).
      extendBody: true,
      // Footer: unica e globale, montata da RootShell (non qui).
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: OnlistColors.screenBackground),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              const CustomTopBar(),
              _buildTopBar(),
              Expanded(
                child: _isLoading
                  ? const AppLoadingIndicator()
                  : _wrapAgeGate(
                      serata,
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 400),
                        transitionBuilder: (Widget child, Animation<double> animation) {
                          return FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0.1, 0),
                                end: Offset.zero,
                              ).animate(animation),
                              child: child,
                            ),
                          );
                        },
                        child: _buildBody(locale, serata),
                      ),
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoSerataView() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.event_busy, color: Colors.white, size: 64),
            const SizedBox(height: 20),
            Text(
              "Nessuna serata selezionata.\nImpossibile procedere.",
              textAlign: TextAlign.center,
              style: OnlistTextStyles.hn(color: Colors.white, fontSize: R.sp(18)),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () => NavigatorService.goBack(),
              child: const Text("Torna indietro"),
            ),
          ],
        ),
      ),
    );
  }

  // ── Gate d'età (eventi 16+/18+) ────────────────────────────────────────────
  // L'evento resta visibile ovunque; qui, sulla prenotazione, se l'utente è
  // troppo giovane il contenuto viene "blurrato" e al tocco compare il messaggio
  // che l'evento è riservato ai N+.
  Widget _wrapAgeGate(SerataModel? serata, Widget body) {
    final minAge = AgeGate.blockedMinAge(
      etaMinima: serata?.etaMinima,
      dob: _userDob,
    );
    if (minAge == null) return body;

    return Stack(
      fit: StackFit.expand,
      children: [
        body,
        Positioned.fill(
          child: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _showAgeBlockDialog(minAge),
                child: Container(
                  color: Colors.black.withValues(alpha: 0.35),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.lock_outline,
                          color: Colors.white, size: 48),
                      SizedBox(height: R.sp(16)),
                      Text(
                        'Evento riservato ai $minAge+',
                        textAlign: TextAlign.center,
                        style: OnlistTextStyles.hn(
                          color: Colors.white,
                          fontSize: R.sp(22),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: R.sp(8)),
                      Text(
                        'Tocca per maggiori informazioni',
                        textAlign: TextAlign.center,
                        style: OnlistTextStyles.hn(
                          color: Colors.white70,
                          fontSize: R.sp(14),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showAgeBlockDialog(int minAge) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(
          'Evento riservato ai $minAge+',
          style: OnlistTextStyles.hn(
              color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Questo evento è riservato ai maggiori di $minAge anni. '
          'Non puoi effettuare la prenotazione.',
          style: OnlistTextStyles.hn(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Ho capito',
                style: OnlistTextStyles.hn(
                    color: OnlistColors.blueElectric,
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      // Respiro sopra/sotto come il design ufficiale (arrow sotto la barra logo).
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: GestureDetector(
        onTap: () {
          if (_currentStep == BookingStep.selection ||
              _currentStep == BookingStep.ticketList ||
              _currentStep == BookingStep.tableConfig) {
            NavigatorService.goBack();
          } else if (_currentStep == BookingStep.ticketDetail) {
            setState(() => _currentStep = BookingStep.ticketList);
          } else if (_currentStep == BookingStep.bottles) {
            setState(() => _currentStep = BookingStep.tableConfig);
          }
        },
        child: Row(
          children: [
            const Icon(Icons.arrow_back, color: Colors.white, size: 28),
            const SizedBox(width: 6),
            // Figma: "Torna indietro" 32/w300/-0.03 (come cart/club/prevendita).
            Text('Torna indietro', style: OnlistTextStyles.title32Light),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(LocaleModel? locale, SerataModel? serata) {
    switch (_currentStep) {
      case BookingStep.selection:
        return _buildSelectionStep(locale, serata);
      case BookingStep.ticketList:
        return _buildTicketListStep(serata);
      case BookingStep.ticketDetail:
        return _buildTicketDetailStep(serata);
      case BookingStep.tableConfig:
        return _buildTableConfigStep(locale, serata);
      case BookingStep.bottles:
        return _buildBottlesStep(serata);
    }
  }

  /// Pagina di scelta Tavolo / Prevendita (la "pagina grossa").
  Widget _buildSelectionStep(LocaleModel? locale, SerataModel? serata) {
    return SingleChildScrollView(
      key: const ValueKey("selection"),
      padding: EdgeInsets.only(bottom: 24 + SharedFooter.height),
      child: Column(
        children: [
          _buildClubHeader(locale, serata),
          const SizedBox(height: 30),
          _buildSelectionButton("Tavolo", () {
            AnalyticsService.log(
                event: 'booking_funnel_start', metadata: {'type': 'table'});
            setState(() => _currentStep = BookingStep.tableConfig);
          }),
          const SizedBox(height: 15),
          _buildSelectionButton("Prevendita", () {
            AnalyticsService.log(
                event: 'booking_funnel_start', metadata: {'type': 'ticket'});
            setState(() => _currentStep = BookingStep.ticketList);
          }),
        ],
      ),
    );
  }

  Widget _buildSelectionButton(String text, VoidCallback onTap) {
    return AnimatedPress(
      onPressed: onTap,
      child: Container(
        width: double.infinity,
        height: 130,
        margin: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: const Color(0xFF1900D8),
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Text(
          text,
          style: OnlistTextStyles.hn(
            color: Colors.white,
            fontSize: R.sp(42),
            fontWeight: FontWeight.bold,
            letterSpacing: -0.07 * 42,
          ),
        ),
      ),
    );
  }

  Widget _buildClubHeader(LocaleModel? locale, SerataModel? serata) {
    // Immagine dal DB: priorità alla locandina della serata, poi alla foto del
    // locale. Niente più sfondo hardcoded: se mancano entrambe (o l'URL non
    // carica) si mostra il fallback unico.
    final imageUrl = serata?.locandinaUrl ?? locale?.fotoUrl;
    // Il seed segue la stessa priorità dell'URL, così lo stock mostrato resta
    // legato all'entità di cui stiamo mostrando l'immagine.
    final seed = serata?.id ?? locale?.id;

    return Container(
      // minHeight (non height fissa): se il titolo va a capo su 2 righe il box
      // cresce invece di andare in overflow (il vecchio height:200 tagliava 18px).
      constraints: const BoxConstraints(minHeight: 200),
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 15),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // Sfondo: immagine reale dal DB con fallback su errore/assenza.
            Positioned.fill(
              child: (imageUrl != null && imageUrl.isNotEmpty)
                  ? CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) =>
                          const ColoredBox(color: OnlistColors.blueDeep),
                      errorWidget: (_, __, ___) => ImageFallback(seed: seed),
                    )
                  : ImageFallback(seed: seed),
            ),
            // Overlay scuro per la leggibilità del testo.
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(color: Colors.black38),
              ),
            ),
            // Contenuto testuale (dimensiona lo Stack, da cui il minHeight cresce).
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    serata?.nome ?? locale?.nome ?? '',
                    style: OnlistTextStyles.hn(
                      color: Colors.white,
                      fontSize: R.sp(32),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    locale?.indirizzoCompleto ?? '',
                    style: OnlistTextStyles.hn(
                      color: Colors.white,
                      fontSize: R.sp(16),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    serata != null
                        ? '${DateFormat('MMMM d').format(serata.data)} - ${serata.orarioString}'
                        : '',
                    style: OnlistTextStyles.hn(
                      color: Colors.white70,
                      fontSize: R.sp(14),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTicketListStep(SerataModel? serata) {
    return Column(
      key: const ValueKey("tickets"),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Expanded(
          child: _prevendite.isEmpty 
          ? Center(child: Text("Nessuna prevendita disponibile", style: OnlistTextStyles.hn(color: Colors.white54)))
          : ListView.builder(
            padding: EdgeInsets.fromLTRB(15, 0, 15, SharedFooter.height),
            itemCount: _prevendite.length,
            itemBuilder: (context, index) {
              final p = _prevendite[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 15),
                child: _buildTicketCard(
                  type: p['tipo']?.toString() ?? '',
                  price: p['prezzo'] != null ? "${_formatPrice(p['prezzo'])}€" : "—",
                  description: p['descrizione']?.toString() ?? '',
                  // Nota di entrata composta dal limite d'ingresso della serata
                  // (fallback al vecchio campo prevendite.validita).
                  validity:
                      serata?.notaEntrata ?? (p['validita']?.toString() ?? ''),
                  ticketId: (p['id_prevendita'] ?? p['id'])?.toString(),
                  serataId: serata?.id,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTicketCard({
    required String type,
    required String price,
    required String description,
    required String validity,
    String? ticketId,
    String? serataId,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Card sulle proporzioni Figma (370×280): l'altezza segue la larghezza,
        // così specifica (a destra) e PRENOTA (in basso) NON si sovrappongono.
        // I 4 blocchi sono ancorati ai 4 angoli.
        final cardH = constraints.maxWidth * 280 / 370;
        return Container(
          height: cardH,
          padding: const EdgeInsets.fromLTRB(22, 13, 16, 18),
          decoration: BoxDecoration(
            // Ufficiale "Ticket disponibili": rgba(0,0,0,.5) → rgba(0,21,255,.5).
            gradient: OnlistColors.cardTicketAvailable,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Stack(
            children: [
              // Ticket + tipo (alto-sinistra)
              Align(
                alignment: Alignment.topLeft,
                // Sottotipo ancorato sotto la "k" di "Ticket". Δ verticale dal
                // Figma (carrello-ticket.css: "Ticket" top 13, "Normale" top 43
                // su font 39.52 → 0.76em).
                child: OnlistTicketTitle(
                  type: _displayType(type),
                  titleStyle: OnlistTextStyles.hn(
                    color: Colors.white,
                    fontSize: R.sp(40),
                    fontWeight: FontWeight.w400,
                    height: 45 / 40,
                    letterSpacing: -0.1 * 40,
                  ),
                  typeStyle: OnlistTextStyles.hn(
                    color: Colors.white,
                    fontSize: R.sp(24),
                    fontWeight: FontWeight.w300,
                    height: 29 / 24,
                    letterSpacing: -0.06 * 24,
                  ),
                  typeTopEm: 0.76,
                ),
              ),
              // Prezzo + specifica (alto-destra)
              Align(
                alignment: Alignment.topRight,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    OnlistPriceText(
                      price,
                      style: OnlistTextStyles.hn(
                        color: Colors.white,
                        fontSize: R.sp(96),
                        fontWeight: FontWeight.w400,
                        height: 110 / 96,
                        letterSpacing: -0.08 * 96,
                      ),
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      width: 180,
                      child: Text(
                        description,
                        textAlign: TextAlign.right,
                        style: OnlistTextStyles.hn(
                          color: Colors.white,
                          fontSize: R.sp(16),
                          fontWeight: FontWeight.w400,
                          height: 18 / 16,
                          letterSpacing: -0.1 * 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Entrata valida (basso-sinistra)
              Align(
                alignment: Alignment.bottomLeft,
                child: SizedBox(
                  width: 175,
                  child: Text(
                    validity,
                    style: OnlistTextStyles.hn(
                      color: Colors.white,
                      fontSize: R.sp(16),
                      fontWeight: FontWeight.w400,
                      height: 18 / 16,
                      letterSpacing: -0.1 * 16,
                    ),
                  ),
                ),
              ),
              // PRENOTA (basso-destra) → dettaglio ticket
              Align(
                alignment: Alignment.bottomRight,
                child: AnimatedPress(
                  onPressed: () {
                    setState(() {
                      _selectedTicket = {
                        'type': type,
                        'price': price,
                        'description': description,
                        'validity': validity,
                        'ticketId': ticketId,
                        'serataId': serataId,
                      };
                      _currentStep = BookingStep.ticketDetail;
                    });
                  },
                  child: Container(
                    width: 133,
                    height: 58,
                    decoration: BoxDecoration(
                      gradient: OnlistColors.bookButton,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      "PRENOTA",
                      style: OnlistTextStyles.hn(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: R.sp(24),
                        height: 28 / 24,
                        letterSpacing: -0.1 * 24,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── 12/13 — Dettaglio singolo ticket (Normale/Vip) ──────────────────────────
  Widget _buildTicketDetailStep(SerataModel? serata) {
    final t = _selectedTicket ?? const {};
    final String type = t['type']?.toString() ?? '';
    // Safe-format: se il prezzo arriva come "12.0€" o "12.0" lo normalizziamo
    // a "12€" (per coerenza col Figma, che non mostra mai il decimale .0).
    final String price = _normalizePriceString(t['price']?.toString() ?? '—');
    final String description = t['description']?.toString() ?? '';
    // Nota di entrata: preferisci il limite d'ingresso della serata; se assente,
    // usa quella già passata dalla card (fallback a prevendite.validita).
    final String validity =
        serata?.notaEntrata ?? (t['validity']?.toString() ?? '');

    return Column(
      key: const ValueKey("ticketDetail"),
      children: [
        const SizedBox(height: 8),
        Expanded(
          child: Container(
            // Card inset dai bordi come Figma 12/13 (carrello-ticket-vip.css:
            // Rectangle 164 a left 21 su 393 → margini laterali ~20px, angoli
            // arrotondati visibili su tutti i lati).
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.fromLTRB(22, 24, 22, 24),
            decoration: BoxDecoration(
              gradient: OnlistColors.cardSingleTicket,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Sottotipo "Vip"/"Normale": Capitalized (NON tutto maiuscolo),
                // ancorato sotto la "k" di "Ticket". Δ verticale dal Figma
                // (carrello-ticket-vip.css: "Ticket" top 171, "Normale" top 204
                // su font 40 → 0.825em).
                OnlistTicketTitle(
                  type: _displayType(type),
                  titleStyle: OnlistTextStyles.ticketTitleLg,
                  typeStyle: OnlistTextStyles.ticketSubtitleLg,
                  typeTopEm: 0.825,
                ),
                const Spacer(),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: OnlistPriceText(price,
                      style: OnlistTextStyles.price192),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(description,
                      textAlign: TextAlign.right,
                      style: OnlistTextStyles.body24Regular),
                ),
                // Vuoti proporzionali al Figma (A:B:C ≈ 1:5:1, CSS 24:113:23):
                // prezzo in alto (~27%), avviso in basso (~86%), niente vuoto
                // grande in fondo. Spacer1/Spacer3 = flex 1 (default).
                const Spacer(flex: 5),
                Center(
                  child: Text(validity,
                      textAlign: TextAlign.center,
                      style: OnlistTextStyles.body24Regular),
                ),
                const Spacer(),
              ],
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(12, 12, 12, 20 + SharedFooter.height),
          child: OnlistPrimaryButton(
            label: 'AGGIUNGI AL CARRELLO',
            onPressed: () {
              // Funnel: aggiunta prevendita al carrello.
              AnalyticsService.logAddToCart(
                type: 'ticket',
                eventId: (t['serataId'] ?? serata?.id) as String?,
                price: price,
              );
              NavigatorService.pushNamed(AppRoutes.cartScreen, arguments: {
                'type': 'ticket',
                'ticketType': type,
                'price': price,
                'description': description,
                'ticketId': t['ticketId'],
                'id_evento': t['serataId'] ?? serata?.id,
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTableConfigStep(LocaleModel? locale, SerataModel? serata) {
    return SingleChildScrollView(
      key: const ValueKey("tableConfig"),
      padding: EdgeInsets.only(bottom: 24 + SharedFooter.height),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildClubHeader(locale, serata),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15),
            child: Row(
              children: [
                Expanded(
                  child: _buildConfigBox(
                    title: "Numero partecipanti",
                    content: Center(
                      child: Text(
                        "$_participants",
                        style: OnlistTextStyles.hn(
                          color: Colors.white,
                          fontSize: R.sp(48),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildConfigBox(
                    title: "Tavolo Selezionato",
                    content: Center(
                      child: Text(
                        _selectedTable == "Seleziona" ? "---" : _selectedTable,
                        style: OnlistTextStyles.hn(
                          color: Colors.white,
                          fontSize: R.sp(32),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 15),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15),
            child: Text(
              "Scegli il tuo tavolo",
              style: OnlistTextStyles.hn(color: Colors.white, fontSize: R.sp(18), fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 15),
            height: 150, // Altezza fissa per la griglia o Wrap
            child: _tavoli.isEmpty 
              ? Center(child: Text("Nessun tavolo disponibile per questo evento", style: OnlistTextStyles.hn(color: Colors.white54)))
              : GridView.builder(
                  shrinkWrap: true,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 1.5,
                  ),
                  itemCount: _tavoli.length,
                  itemBuilder: (context, index) {
                    final t = _tavoli[index];
                    final String name = t['nome_tavolo']?.toString() ?? "T";
                    final dynamic rawId = t['id'] ?? t['id_tavolo'] ?? t['idTavolo'];
                    final String? id = rawId?.toString();
                    final bool isSelected = (_selectedTableId != null && _selectedTableId == id) || (_selectedTableId == null && _selectedTable == name && name != "Seleziona");

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedTable = name;
                          _selectedTableId = id ?? name; // Fallback al nome se l'ID è proprio introvabile
                          final int cap = int.tryParse(t['capacita']?.toString() ?? "10") ?? 10;
                          if (_participants > cap) _participants = cap;
                        });
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: Center(
                          child: Text(
                            name,
                            style: OnlistTextStyles.hn(
                              color: isSelected ? const Color(0xFF1D00FF) : Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: R.sp(16),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
          ),
          
          if (_selectedTableId != null) ...[
            const SizedBox(height: 25),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Quante persone sarete?",
                    style: OnlistTextStyles.hn(color: Colors.white, fontSize: R.sp(18), fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _buildCircBtn(Icons.remove, () {
                        if (_participants > 1) setState(() => _participants--);
                      }),
                      const SizedBox(width: 20),
                      Text(
                        "$_participants",
                        style: OnlistTextStyles.hn(color: Colors.white, fontSize: R.sp(42), fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 20),
                      _buildCircBtn(Icons.add, () {
                        int cap = 10;
                        try {
                          final t = _tavoli.firstWhere(
                            (e) => (e['id']?.toString() == _selectedTableId) || (e['nome_tavolo']?.toString() == _selectedTableId),
                          );
                          cap = int.tryParse(t['capacita']?.toString() ?? "10") ?? 10;
                        } catch (_) {}
                        
                        if (_participants < cap) setState(() => _participants++);
                      }),
                      const SizedBox(width: 20),
                      Text(
                        "(Max: ${(() {
                          try {
                            final t = _tavoli.firstWhere(
                              (e) => (e['id']?.toString() == _selectedTableId) || (e['nome_tavolo']?.toString() == _selectedTableId),
                            );
                            return t['capacita'] ?? 10;
                          } catch (_) {
                            return 10;
                          }
                        })()})",
                        style: OnlistTextStyles.hn(color: Colors.white54, fontSize: R.sp(16)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 40),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15),
            child: AnimatedPress(
              onPressed: (_selectedTableId == null || _selectedTable == "Seleziona")
                ? () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Per favore, seleziona prima un tavolo")),
                    );
                  }
                : () {
                    setState(() => _currentStep = BookingStep.bottles);
                  },
              child: Container(
                width: double.infinity,
                height: 50,
                decoration: BoxDecoration(
                  color: (_selectedTableId == null || _selectedTable == "Seleziona") ? Colors.grey : const Color(0xFF1D00FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text(
                  "PRENOTA",
                  style: OnlistTextStyles.hn(
                    color: Colors.white,
                    fontSize: R.sp(22),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfigBox({required String title, required Widget content}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: OnlistTextStyles.hn(color: Colors.white, fontSize: R.sp(13))),
        const SizedBox(height: 4),
        Container(
          height: 100,
          decoration: BoxDecoration(
            color: const Color(0xFF1D00FF),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Stack(
            children: [
              content,
              Positioned(
                right: 8,
                top: 20,
                bottom: 20,
                child: Container(
                  width: 2,
                  color: Colors.black26,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBottlesStep(SerataModel? serata) {
    return Padding(
      padding: EdgeInsets.only(bottom: SharedFooter.height),
      child: Column(
        key: const ValueKey("bottles"),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 15),
              decoration: BoxDecoration(
                color: const Color(0xFF1D00FF),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      "Bottiglie",
                      style: OnlistTextStyles.hn(
                        color: Colors.white,
                        fontSize: R.sp(32),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 15),
                      itemCount: _bottiglie.length,
                      itemBuilder: (context, index) {
                        final b = _bottiglie[index];
                        return _buildBottleCard(b, serata?.id);
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: Container(
                      width: 100,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottleCard(Map<String, dynamic> b, String? serataId) {
    return AnimatedPress(
      onPressed: () {
        // Funnel: aggiunta tavolo (+ bottiglia) al carrello.
        AnalyticsService.logAddToCart(type: 'table', eventId: serataId);
        NavigatorService.pushNamed(AppRoutes.cartScreen, arguments: {
          'type': 'table',
          'table': _selectedTable,
          'tableId': _selectedTableId,
          'quantity': _bottleQuantity,
          'bottle': b['nome'],
          'drinkId': b['id'],
          'id_evento': serataId,
          'nPersone': _participants,
        });
      },
      child: Container(
        width: 180,
        margin: const EdgeInsets.only(right: 15, bottom: 20),
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          children: [
            const SizedBox(height: 15),
            Text(
              b['nome']?.toString().toUpperCase().replaceAll(" ", "\n") ?? "VODKA",
              textAlign: TextAlign.center,
              style: OnlistTextStyles.hn(
                color: Colors.white,
                fontSize: R.sp(22),
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              "70CL",
              style: OnlistTextStyles.hn(
                color: Colors.white70,
                fontSize: R.sp(14),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Image.asset(
                'assets/images/img_grey_goose.png',
                fit: BoxFit.contain,
                errorBuilder: (c, e, s) => const Icon(Icons.wine_bar,
                    color: Colors.white, size: 100),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  /// Normalizza il tipo ticket per la UI: prima lettera maiuscola, resto
  /// minuscolo (es. "VIP" → "Vip", "normale" → "Normale"). Il design non usa
  /// il tutto-maiuscolo per il sottotipo.
  static String _displayType(String t) {
    final s = t.trim();
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1).toLowerCase();
  }

  /// Normalizza una stringa di prezzo già formata (es. "12.0€") rimuovendo
  /// il `.0` finale prima del simbolo. Non tocca i prezzi con decimali validi.
  static String _normalizePriceString(String s) {
    final m = RegExp(r'^(\d+)\.0+(\D?.*)$').firstMatch(s);
    if (m != null) return '${m.group(1)}${m.group(2)}';
    return s;
  }

  /// Formatta il prezzo togliendo il `.0` se il valore è intero (12.0 → "12",
  /// 12.5 → "12.50"). Evita il "12.0€" che il design non prevede.
  static String _formatPrice(dynamic p) {
    if (p is num) {
      if (p == p.truncate()) return p.toInt().toString();
      return p.toStringAsFixed(2);
    }
    final parsed = double.tryParse(p?.toString() ?? '');
    if (parsed != null) {
      if (parsed == parsed.truncate()) return parsed.toInt().toString();
      return parsed.toStringAsFixed(2);
    }
    return p?.toString() ?? '';
  }

  Widget _buildCircBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white, width: 2),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 28),
      ),
    );
  }
}
