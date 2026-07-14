import 'package:flutter/material.dart';
import '../../core/app_export.dart';
import '../../core/services/orders_service.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/utils/analytics_mixin.dart';
import '../../theme/onlist_colors.dart';
import '../../theme/onlist_text_styles.dart';
import '../../widgets/app_loading_indicator.dart';
import '../../widgets/custom_top_bar.dart';
import '../../widgets/shared_footer.dart';
import '../../widgets/staggered_item.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({Key? key}) : super(key: key);

  static Widget builder(BuildContext context) => const OrdersScreen();

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> with ScreenAnalytics {
  @override
  String get screenName => 'orders_list';

  List<Map<String, dynamic>> _prevendite = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // MVP: la sezione "Tavoli" è nascosta a livello di design; carichiamo solo le
  // prevendite (i tavoli restano gestiti a DB per un ripristino futuro).
  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final prevendite = await OrdersService.getPrevenditeOrdini();
      setState(() {
        _prevendite = prevendite;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint('[OrdersScreen] Errore: $e');
    }
  }

  void _onBackTap() {
    if (Navigator.canPop(context)) {
      NavigatorService.goBack();
    } else {
      NavigatorService.pushNamedAndRemoveUntil(AppRoutes.homeScreen);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      // Footer flottante: le liste scorrono dietro la capsula (non la oscura).
      extendBody: true,
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: OnlistColors.screenBackground),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              const CustomTopBar(),
              // ── "← Torna indietro" (Figma 17) ─────────────────────────────
              // Icona 28 + testo title32Light. Respiro sopra/sotto come il
              // design ufficiale (riepilogo-ordini.css: arrow top 112 sotto la
              // barra logo, sezione "Oggi" a top 171).
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                child: GestureDetector(
                  onTap: _onBackTap,
                  behavior: HitTestBehavior.opaque,
                  child: Row(
                    children: [
                      const Icon(Icons.arrow_back, color: Colors.white, size: 28),
                      const SizedBox(width: 6),
                      Text('Torna indietro', style: OnlistTextStyles.title32Light),
                    ],
                  ),
                ),
              ),
              // MVP: nessuna tab. Mostriamo solo le prevendite (Tavoli nascosti).
              Expanded(
                child: _isLoading
                    ? const AppLoadingIndicator()
                    : _buildPrevenditeList(),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const SharedFooter(currentIndex: 0),
    );
  }

  // ── Lista prevendite raggruppate per data evento ───────────────────────────
  Widget _buildPrevenditeList() {
    if (_prevendite.isEmpty) {
      return Center(
        child: Text(
          'Nessuna prevendita acquistata',
          style: OnlistTextStyles.hn(color: Colors.white54, fontSize: R.sp(16)),
        ),
      );
    }
    final sections = _groupByDate(_prevendite, _prevenditaDate);
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(16, R.sp(12), 16, R.sp(24) + SharedFooter.height),
      itemCount: sections.length,
      itemBuilder: (context, i) {
        final section = sections[i];
        return StaggeredItem(
          index: i,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader(section.label),
              SizedBox(height: R.sp(10)),
              ...section.items.map(_buildPrevenditaCard),
              SizedBox(height: R.sp(18)),
            ],
          ),
        );
      },
    );
  }

  // ── Header sezione (Oggi / Domani / data) ──────────────────────────────────
  Widget _buildSectionHeader(String label) {
    return Padding(
      padding: EdgeInsets.only(left: R.sp(4)),
      child: Text(
        label,
        style: OnlistTextStyles.hn(
          color: Colors.white,
          fontSize: R.sp(36), // CSS "Oggi": 36/w700/-0.07
          fontWeight: FontWeight.w700,
          height: 41 / 36,
          letterSpacing: -0.07 * 36,
        ),
      ),
    );
  }

  // ── Card prevendita (gradiente blu cardSummary, Figma 17) ──────────────────
  Widget _buildPrevenditaCard(Map<String, dynamic> item) {
    final prenotazione = item['prenotazioni'] as Map<String, dynamic>?;
    final prevendita = item['prevendite'] as Map<String, dynamic>?;

    final tipo = (prevendita?['tipo'] ?? 'normale').toString().toLowerCase();
    final prezzo = prevendita?['prezzo'];
    final quantita = (item['quantita'] ?? prenotazione?['quantita'] ?? 1) as int;
    final stato = (prenotazione?['stato'] ?? 'in_attesa').toString();
    // Testo "extra" accanto al prezzo: descrizione reale della prevendita dal
    // DB (es. "+ 2 drink omaggio", "Ingresso + 1 shot"). NOTA: `drink_omaggio`
    // non è una colonna esistente in `prevendite`/`eventi` — l'unica sorgente
    // vera è `descrizione`. L'overflow che aveva causato la rimozione di
    // questo campo è ora gestito da Flexible+maxLines+ellipsis sotto.
    final descrizione = (prevendita?['descrizione'] as String?)?.trim();
    final String? extraText =
        (descrizione != null && descrizione.isNotEmpty) ? descrizione : null;

    return GestureDetector(
      onTap: () => NavigatorService.pushNamed(
        AppRoutes.prevenditaDetailScreen,
        arguments: item,
      ),
      child: Container(
        margin: EdgeInsets.only(bottom: R.sp(14)),
        padding: EdgeInsets.symmetric(horizontal: R.sp(18), vertical: R.sp(16)),
        decoration: BoxDecoration(
          gradient: OnlistColors.cardSummary,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // "Ticket x N" + "Ticket {tipo}"
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Ticket x $quantita',
                      style: OnlistTextStyles.hn(
                        color: Colors.white,
                        fontSize: R.sp(40), // CSS "Ticket x 1": 39.52
                        fontWeight: FontWeight.w400,
                        letterSpacing: -0.1 * 40,
                        height: 1.0,
                      ),
                    ),
                    SizedBox(width: R.sp(10)),
                    Padding(
                      padding: EdgeInsets.only(bottom: R.sp(6)),
                      child: Text(
                        'Ticket ${_capitalize(tipo)}',
                        style: OnlistTextStyles.hn(
                          color: Colors.white,
                          fontSize: R.sp(20), // CSS "Ticket normale": 20 Light
                          fontWeight: FontWeight.w300,
                          letterSpacing: -0.06 * 20,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: R.sp(6)),
                // Prezzo gigante + "+ X drink omaggio"
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (prezzo != null)
                      Text(
                        '${_fmtPrezzo(prezzo)}€',
                        style: OnlistTextStyles.hn(
                          color: Colors.white,
                          fontSize: R.sp(96), // CSS prezzo: 96/-0.1
                          fontWeight: FontWeight.w400,
                          letterSpacing: -0.1 * 96,
                          height: 1.0,
                        ),
                      ),
                    if (extraText != null) ...[
                      SizedBox(width: R.sp(8)),
                      Flexible(
                        child: Padding(
                          padding: EdgeInsets.only(bottom: R.sp(18)),
                          child: Text(
                            extraText,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: OnlistTextStyles.hn(
                              color: Colors.white,
                              fontSize: R.sp(24), // CSS "+drink omaggio": 24/-0.1
                              fontWeight: FontWeight.w400,
                              letterSpacing: -0.1 * 24,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                SizedBox(height: R.sp(10)),
                // "Visualizza QR Code" + freccia giù
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Visualizza QR Code',
                        style: OnlistTextStyles.hn(
                          color: Colors.white,
                          fontSize: R.sp(15),
                          fontWeight: FontWeight.w400,
                          letterSpacing: -0.1 * 15,
                        ),
                      ),
                      SizedBox(height: R.sp(6)),
                      // CSS Ellipse 9: cerchio 28 bordo 2px con freccia giù dentro.
                      Container(
                        width: R.sp(28),
                        height: R.sp(28),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: Icon(Icons.arrow_downward,
                            color: Colors.white, size: R.sp(16)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            // Stato (solo se annullata/usato — altrimenti card pulita come Figma)
            if (_shouldShowStatePill(stato))
              Positioned(
                top: 0,
                right: 0,
                child: _buildStatePill(stato),
              ),
          ],
        ),
      ),
    );
  }

  // ── Pill stato (solo casi non standard) ────────────────────────────────────
  bool _shouldShowStatePill(String stato) {
    final s = stato.toLowerCase();
    return s == 'annullata' || s == 'usato';
  }

  Widget _buildStatePill(String stato) {
    final s = stato.toLowerCase();
    final isCanceled = s == 'annullata';
    return Container(
      padding: EdgeInsets.symmetric(horizontal: R.sp(10), vertical: R.sp(4)),
      decoration: BoxDecoration(
        color: isCanceled ? Colors.redAccent : Colors.white24,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        _stateLabel(stato).toUpperCase(),
        style: OnlistTextStyles.hn(
          color: Colors.white,
          fontSize: R.sp(11),
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  String _stateLabel(String stato) {
    switch (stato.toLowerCase()) {
      case 'confermata': return 'Confermato';
      case 'usato': return 'Usato';
      case 'annullata': return 'Annullato';
      case 'in_attesa': return 'In attesa';
      default: return stato;
    }
  }

  // ── Raggruppamento per data evento ─────────────────────────────────────────
  DateTime? _prevenditaDate(Map<String, dynamic> item) {
    final evento = (item['prenotazioni'] as Map<String, dynamic>?)?['eventi'] as Map<String, dynamic>?;
    return _parseDate(evento?['data']);
  }

  DateTime? _parseDate(dynamic raw) {
    if (raw == null) return null;
    try {
      return DateTime.parse(raw.toString());
    } catch (_) {
      return null;
    }
  }

  List<_DateSection> _groupByDate(
    List<Map<String, dynamic>> items,
    DateTime? Function(Map<String, dynamic>) dateGetter,
  ) {
    final buckets = <String, _Bucket>{};
    for (final item in items) {
      final d = dateGetter(item);
      final key = d == null
          ? '_none_'
          : '${d.year}-${d.month}-${d.day}';
      buckets.putIfAbsent(key, () => _Bucket(d)).items.add(item);
    }
    final list = buckets.values.toList()
      // Ordine decrescente: prima le date più recenti (dal più nuovo al più vecchio).
      ..sort((a, b) {
        if (a.date == null) return 1;
        if (b.date == null) return -1;
        return b.date!.compareTo(a.date!);
      });
    return list.map((b) => _DateSection(_dateLabel(b.date), b.items)).toList();
  }

  // Etichetta data della sezione:
  // - oggi → "Oggi", ieri → "Ieri", domani → "Domani"
  // - stesso anno di quello corrente → "27 giu" (giorno + mese)
  // - anno diverso → "27 giu 2026" (con anno)
  String _dateLabel(DateTime? d) {
    if (d == null) return 'Senza data';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final eventDay = DateTime(d.year, d.month, d.day);
    final diff = eventDay.difference(today).inDays;
    if (diff == 0) return 'Oggi';
    if (diff == 1) return 'Domani';
    if (diff == -1) return 'Ieri';
    return d.year == now.year
        ? DateFormatter.formatDayMonth(d)
        : DateFormatter.formatLong(d);
  }

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return '${s[0].toUpperCase()}${s.substring(1)}';
  }

  // Prezzo senza decimali quando è un intero (10.0 → "10", 12.5 → "12.5").
  String _fmtPrezzo(dynamic v) {
    final n = v is num ? v : num.tryParse('$v');
    if (n == null) return '$v';
    return n % 1 == 0 ? n.toInt().toString() : n.toString();
  }
}

class _Bucket {
  final DateTime? date;
  final List<Map<String, dynamic>> items = [];
  _Bucket(this.date);
}

class _DateSection {
  final String label;
  final List<Map<String, dynamic>> items;
  _DateSection(this.label, this.items);
}
