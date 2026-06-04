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

class _OrdersScreenState extends State<OrdersScreen> with SingleTickerProviderStateMixin, ScreenAnalytics {
  @override
  String get screenName => 'orders_list';

  late TabController _tabController;
  List<Map<String, dynamic>> _prevendite = [];
  List<Map<String, dynamic>> _tavoli = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        OrdersService.getPrevenditeOrdini(),
        OrdersService.getTavoliOrdini(),
      ]);
      setState(() {
        _prevendite = results[0];
        _tavoli = results[1];
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
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: OnlistColors.screenBackground),
        child: SafeArea(
          child: Column(
            children: [
              const CustomTopBar(),
              // ── "← Torna indietro" (Figma 17) ─────────────────────────────
              Padding(
                padding: EdgeInsets.fromLTRB(16, R.sp(4), 16, R.sp(6)),
                child: GestureDetector(
                  onTap: _onBackTap,
                  behavior: HitTestBehavior.opaque,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.arrow_back, color: Colors.white, size: R.sp(20)),
                      SizedBox(width: R.sp(6)),
                      Text(
                        'Torna indietro',
                        style: OnlistTextStyles.hn(
                          color: Colors.white,
                          fontSize: R.sp(16),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // ── Tab bar (manteniamo separazione Prevendite/Tavoli) ────────
              Container(
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0xFF2A2A2A), width: 0.5)),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicatorColor: Colors.white,
                  indicatorWeight: 2,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white38,
                  labelStyle: OnlistTextStyles.hn(fontWeight: FontWeight.bold, fontSize: R.sp(15)),
                  unselectedLabelStyle: OnlistTextStyles.hn(fontWeight: FontWeight.w400, fontSize: R.sp(15)),
                  tabs: const [
                    Tab(text: 'Prevendite'),
                    Tab(text: 'Tavoli'),
                  ],
                ),
              ),
              Expanded(
                child: _isLoading
                    ? const AppLoadingIndicator()
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          _buildPrevenditeList(),
                          _buildTavoliList(),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const SharedFooter(currentIndex: 1),
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
      padding: EdgeInsets.fromLTRB(16, R.sp(12), 16, R.sp(24)),
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

  Widget _buildTavoliList() {
    if (_tavoli.isEmpty) {
      return Center(
        child: Text(
          'Nessun tavolo prenotato',
          style: OnlistTextStyles.hn(color: Colors.white54, fontSize: R.sp(16)),
        ),
      );
    }
    final sections = _groupByDate(_tavoli, _tavoloDate);
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(16, R.sp(12), 16, R.sp(24)),
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
              ...section.items.map(_buildTavoloCard),
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
          fontSize: R.sp(32),
          fontWeight: FontWeight.w700,
          height: 41 / 36,
          letterSpacing: -0.07 * 32,
        ),
      ),
    );
  }

  // ── Card prevendita (gradiente blu cardSummary, Figma 17) ──────────────────
  Widget _buildPrevenditaCard(Map<String, dynamic> item) {
    final prenotazione = item['prenotazioni'] as Map<String, dynamic>?;
    final evento = prenotazione?['eventi'] as Map<String, dynamic>?;
    final prevendita = item['prevendite'] as Map<String, dynamic>?;

    final tipo = (prevendita?['tipo'] ?? 'normale').toString().toLowerCase();
    final prezzo = prevendita?['prezzo'];
    final quantita = (item['quantita'] ?? prenotazione?['quantita'] ?? 1) as int;
    final stato = (prenotazione?['stato'] ?? 'in_attesa').toString();
    final drinkOmaggio = (prevendita?['drink_omaggio'] ?? evento?['drink_omaggio']) as int?;

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
                        fontSize: R.sp(32),
                        fontWeight: FontWeight.w400,
                        letterSpacing: -0.1 * 32,
                        height: 1.05,
                      ),
                    ),
                    SizedBox(width: R.sp(10)),
                    Padding(
                      padding: EdgeInsets.only(bottom: R.sp(4)),
                      child: Text(
                        'Ticket ${_capitalize(tipo)}',
                        style: OnlistTextStyles.hn(
                          color: Colors.white,
                          fontSize: R.sp(16),
                          fontWeight: FontWeight.w300,
                          letterSpacing: -0.06 * 16,
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
                        '$prezzo€',
                        style: OnlistTextStyles.hn(
                          color: Colors.white,
                          fontSize: R.sp(72),
                          fontWeight: FontWeight.w400,
                          letterSpacing: -0.08 * 72,
                          height: 1.0,
                        ),
                      ),
                    if (drinkOmaggio != null && drinkOmaggio > 0) ...[
                      SizedBox(width: R.sp(8)),
                      Padding(
                        padding: EdgeInsets.only(bottom: R.sp(10)),
                        child: Text(
                          '+ $drinkOmaggio drink omaggio',
                          style: OnlistTextStyles.hn(
                            color: Colors.white,
                            fontSize: R.sp(13),
                            fontWeight: FontWeight.w400,
                            letterSpacing: -0.1 * 13,
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
                      SizedBox(height: R.sp(2)),
                      Icon(Icons.keyboard_arrow_down, color: Colors.white, size: R.sp(22)),
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

  // ── Card tavolo (stessa estetica gradiente per coerenza) ───────────────────
  Widget _buildTavoloCard(Map<String, dynamic> item) {
    final evento = item['eventi'] as Map<String, dynamic>?;
    final tavolo = item['tavoli'] as Map<String, dynamic>?;

    final nomeTavolo = (tavolo?['nome_tavolo'] ?? '').toString();
    final stato = (item['stato'] ?? 'in_attesa').toString();
    final nomeCliente = (item['nome_cliente'] ?? '').toString();
    final data = evento?['data'];

    String dataFormatted = '';
    if (data != null) {
      try {
        dataFormatted = DateFormatter.formatLong(DateTime.parse(data.toString()));
      } catch (_) {
        dataFormatted = data.toString();
      }
    }

    return GestureDetector(
      onTap: () => NavigatorService.pushNamed(
        AppRoutes.tavoloDetailScreen,
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
                Text(
                  nomeTavolo.isNotEmpty ? 'Tavolo $nomeTavolo' : 'Tavolo',
                  style: OnlistTextStyles.hn(
                    color: Colors.white,
                    fontSize: R.sp(32),
                    fontWeight: FontWeight.w400,
                    letterSpacing: -0.1 * 32,
                    height: 1.05,
                  ),
                ),
                if (nomeCliente.isNotEmpty) ...[
                  SizedBox(height: R.sp(4)),
                  Text(
                    'Riservato a $nomeCliente',
                    style: OnlistTextStyles.hn(
                      color: Colors.white,
                      fontSize: R.sp(16),
                      fontWeight: FontWeight.w300,
                      letterSpacing: -0.06 * 16,
                    ),
                  ),
                ],
                if (dataFormatted.isNotEmpty) ...[
                  SizedBox(height: R.sp(6)),
                  Text(
                    dataFormatted,
                    style: OnlistTextStyles.hn(
                      color: Colors.white,
                      fontSize: R.sp(13),
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
                SizedBox(height: R.sp(12)),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Vedi piantina',
                        style: OnlistTextStyles.hn(
                          color: Colors.white,
                          fontSize: R.sp(15),
                          fontWeight: FontWeight.w400,
                          letterSpacing: -0.1 * 15,
                        ),
                      ),
                      SizedBox(height: R.sp(2)),
                      Icon(Icons.keyboard_arrow_down, color: Colors.white, size: R.sp(22)),
                    ],
                  ),
                ),
              ],
            ),
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

  DateTime? _tavoloDate(Map<String, dynamic> item) {
    final evento = item['eventi'] as Map<String, dynamic>?;
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
      ..sort((a, b) {
        if (a.date == null) return 1;
        if (b.date == null) return -1;
        return a.date!.compareTo(b.date!);
      });
    return list.map((b) => _DateSection(_dateLabel(b.date), b.items)).toList();
  }

  String _dateLabel(DateTime? d) {
    if (d == null) return 'Senza data';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final eventDay = DateTime(d.year, d.month, d.day);
    final diff = eventDay.difference(today).inDays;
    if (diff == 0) return 'Oggi';
    if (diff == 1) return 'Domani';
    return DateFormatter.formatLong(d);
  }

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return '${s[0].toUpperCase()}${s.substring(1)}';
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
