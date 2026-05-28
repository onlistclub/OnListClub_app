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
            // Tab bar
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
                labelStyle: OnlistTextStyles.hn(fontWeight: FontWeight.bold, fontSize: 15),
                unselectedLabelStyle: OnlistTextStyles.hn(fontWeight: FontWeight.w400, fontSize: 15),
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

  Widget _buildPrevenditeList() {
    if (_prevendite.isEmpty) {
      return Center(
        child: Text(
          'Nessuna prevendita acquistata',
          style: OnlistTextStyles.hn(color: Colors.white54, fontSize: 16),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      itemCount: _prevendite.length,
      itemBuilder: (context, i) => _buildPrevenditaCard(_prevendite[i]),
    );
  }

  Widget _buildTavoliList() {
    if (_tavoli.isEmpty) {
      return Center(
        child: Text(
          'Nessun tavolo prenotato',
          style: OnlistTextStyles.hn(color: Colors.white54, fontSize: 16),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      itemCount: _tavoli.length,
      itemBuilder: (context, i) => _buildTavoloCard(_tavoli[i]),
    );
  }

  Widget _buildPrevenditaCard(Map<String, dynamic> item) {
    final prenotazione = item['prenotazioni'] as Map<String, dynamic>?;
    final evento = prenotazione?['eventi'] as Map<String, dynamic>?;
    final locale = evento?['locali'] as Map<String, dynamic>?;
    final prevendita = item['prevendite'] as Map<String, dynamic>?;

    final nomeClub = locale?['nome'] ?? '';
    final nomeEvento = evento?['nome'] ?? '';
    final data = evento?['data'];
    final tipo = prevendita?['tipo'] ?? 'Standard';
    final prezzo = prevendita?['prezzo'];
    final stato = prenotazione?['stato'] ?? 'in_attesa';
    final nome = '${item['nome'] ?? ''} ${item['cognome'] ?? ''}'.trim();

    String dataFormatted = '';
    if (data != null) {
      try {
        dataFormatted = DateFormatter.formatLong(DateTime.parse(data));
      } catch (_) {
        dataFormatted = data.toString();
      }
    }

    return GestureDetector(
      onTap: () => NavigatorService.pushNamed(
        AppRoutes.prevenditaDetailScreen,
        arguments: item,
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF0D0D0D),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF2A2A2A), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    nomeEvento.isNotEmpty ? nomeEvento : nomeClub,
                    style: OnlistTextStyles.hn(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (prezzo != null)
                  Text(
                    '${prezzo}€',
                    style: OnlistTextStyles.hn(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              nome.isNotEmpty ? nome : 'Ticket $tipo',
              style: OnlistTextStyles.hn(color: Colors.white54, fontSize: 13),
            ),
            if (dataFormatted.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.calendar_today, color: Colors.white38, size: 13),
                  const SizedBox(width: 5),
                  Text(dataFormatted, style: OnlistTextStyles.hn(color: Colors.white38, fontSize: 13)),
                  const SizedBox(width: 10),
                  const Icon(Icons.location_on_outlined, color: Colors.white38, size: 13),
                  const SizedBox(width: 5),
                  Text(nomeClub, style: OnlistTextStyles.hn(color: Colors.white38, fontSize: 13)),
                ],
              ),
            ],
            const SizedBox(height: 10),
            _buildStatoBadge(stato),
          ],
        ),
      ),
    );
  }

  Widget _buildTavoloCard(Map<String, dynamic> item) {
    final evento = item['eventi'] as Map<String, dynamic>?;
    final locale = evento?['locali'] as Map<String, dynamic>?;
    final tavolo = item['tavoli'] as Map<String, dynamic>?;

    final nomeClub = locale?['nome'] ?? '';
    final nomeEvento = evento?['nome'] ?? '';
    final nomeTavolo = tavolo?['nome_tavolo'] ?? '';
    final data = evento?['data'];
    final stato = item['stato'] ?? 'in_attesa';
    final nomeCliente = item['nome_cliente'] ?? '';

    String dataFormatted = '';
    if (data != null) {
      try {
        dataFormatted = DateFormatter.formatLong(DateTime.parse(data));
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
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF0D0D0D),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF2A2A2A), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    nomeEvento.isNotEmpty ? nomeEvento : nomeClub,
                    style: OnlistTextStyles.hn(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (nomeTavolo.isNotEmpty)
                  Text(
                    'Tavolo $nomeTavolo',
                    style: OnlistTextStyles.hn(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              nomeCliente,
              style: OnlistTextStyles.hn(color: Colors.white54, fontSize: 13),
            ),
            if (dataFormatted.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.calendar_today, color: Colors.white38, size: 13),
                  const SizedBox(width: 5),
                  Text(dataFormatted, style: OnlistTextStyles.hn(color: Colors.white38, fontSize: 13)),
                  const SizedBox(width: 10),
                  const Icon(Icons.location_on_outlined, color: Colors.white38, size: 13),
                  const SizedBox(width: 5),
                  Text(nomeClub, style: OnlistTextStyles.hn(color: Colors.white38, fontSize: 13)),
                ],
              ),
            ],
            const SizedBox(height: 10),
            _buildStatoBadge(stato),
          ],
        ),
      ),
    );
  }

  Widget _buildStatoBadge(String stato) {
    final bool isNegative = stato.toLowerCase() == 'annullata';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      decoration: BoxDecoration(
        gradient: isNegative
            ? const LinearGradient(colors: [Colors.red, Color(0xFF8B0000)])
            : const LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [Color(0xFF000000), Color(0xFF1900D8)],
                stops: [0.0, 0.8173],
              ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        _stateLabel(stato),
        style: OnlistTextStyles.hn(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w500,
          letterSpacing: -0.1 * 13,
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

  }
