import 'package:flutter/material.dart';
import '../../core/services/navigator_service.dart';
import '../../core/services/analytics_service.dart';
import '../../core/utils/analytics_mixin.dart';
import '../../routes/app_routes.dart';
import '../../core/services/booking_service.dart';
import '../../core/utils/responsive.dart';
import '../../theme/onlist_colors.dart';
import '../../theme/onlist_text_styles.dart';
import '../../widgets/custom_top_bar.dart';
import '../../widgets/shared_footer.dart';
import '../../widgets/onlist_primary_button.dart';
import '../../widgets/app_error_dialog.dart';
import '../../core/services/badge_service.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({Key? key}) : super(key: key);

  static Widget builder(BuildContext context) => const CartScreen();

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> with ScreenAnalytics {
  @override
  String get screenName => 'cart';

  bool _isPaying = false;

  Future<void> _processPayment(Map<String, dynamic>? args) async {
    setState(() => _isPaying = true);
    try {
      await BookingService.createReservation(
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

      BadgeService().incrementNotificationBadge();
      NavigatorService.pushNamed(AppRoutes.paymentSuccessScreen);
    } catch (e) {
      if (mounted) showAppErrorDialog(context, "Errore durante l'ordine: $e");
    } finally {
      if (mounted) setState(() => _isPaying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final bool isEmpty = args == null;
    final String bookingType = args?['type'] as String? ?? "table";

    return Scaffold(
      backgroundColor: Colors.black,
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: OnlistColors.screenBackground),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              const CustomTopBar(),
              _buildBackButton(),
              const SizedBox(height: 10),
              Expanded(
                child: isEmpty
                    ? _buildEmptyCart()
                    : (bookingType == "ticket"
                        ? _buildTicketCartView(args)
                        : _buildTableCartView(args)),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const SharedFooter(currentIndex: 2),
    );
  }

  // ── 14 — Carrello con ticket ────────────────────────────────────────────────
  Widget _buildTicketCartView(Map<String, dynamic>? args) {
    final ticketType = args?['ticketType']?.toString() ?? "Normale";
    final priceStr = args?['price']?.toString() ?? "10€";
    final priceVal = double.tryParse(priceStr.replaceAll("€", "").trim()) ?? 10.0;
    final total = priceVal.toStringAsFixed(0);

    return Column(
      children: [
        // Card sintetica (Figma: 353x175, gradiente #1E00FF -> #020011)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
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
                      Text("Ticket x 1",
                          style: OnlistTextStyles.ticketLabel),
                      const SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.only(top: 14),
                        child: Text("Ticket $ticketType",
                            style: OnlistTextStyles.ticketSubtitleXs),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text("$total€", style: OnlistTextStyles.price96),
                      const SizedBox(width: 10),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 18),
                        child: Text("+ 2 drink omaggio",
                            style: OnlistTextStyles.body24Regular),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
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

  Widget _buildEmptyCart() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shopping_cart_outlined,
            color: Colors.white.withValues(alpha: 0.3),
            size: 80,
          ),
          const SizedBox(height: 20),
          Text(
            "Il carrello è vuoto",
            style: OnlistTextStyles.hn(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: R.sp(22),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            "Seleziona un tavolo o un ticket\nper aggiungere un ordine",
            textAlign: TextAlign.center,
            style: OnlistTextStyles.hn(
              color: Colors.white.withValues(alpha: 0.35),
              fontSize: R.sp(15),
            ),
          ),
        ],
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
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: OnlistColors.bluePrimary, width: 2.9),
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
                    const Icon(Icons.keyboard_arrow_down, color: Colors.black, size: 34),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBackButton() {
    return Padding(
      padding: const EdgeInsets.only(left: 12, top: 4),
      child: GestureDetector(
        onTap: () => NavigatorService.goBack(),
        behavior: HitTestBehavior.opaque,
        child: Row(
          children: [
            const Icon(Icons.arrow_back, color: Colors.white, size: 28),
            const SizedBox(width: 6),
            Text('Torna indietro', style: OnlistTextStyles.title32Light),
          ],
        ),
      ),
    );
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
