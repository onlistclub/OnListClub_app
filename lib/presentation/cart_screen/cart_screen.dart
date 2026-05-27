import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/services/navigator_service.dart';
import '../../core/services/analytics_service.dart';
import '../../core/utils/analytics_mixin.dart';
import '../../routes/app_routes.dart';
import '../../core/services/booking_service.dart';
import '../../core/services/orders_service.dart';
import '../../widgets/custom_top_bar.dart';
import '../../widgets/shared_footer.dart';
import '../../core/services/badge_service.dart';
import 'package:intl/intl.dart';

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

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  @override
  void dispose() {
    for (final c in _nameControllers) c.dispose();
    for (final c in _dobControllers) c.dispose();
    super.dispose();
  }

  Future<void> _fetchProfile() async {
    try {
      final profile = await OrdersService.getUserProfile();
      if (profile != null && mounted) {
        setState(() {
          // Pre-compila il primo intestatario solo se ancora vuoto
          if (_nameControllers[0].text.isEmpty) {
            final fullName = "${profile['nome'] ?? ''} ${profile['cognome'] ?? ''}".trim();
            _nameControllers[0].text = fullName;
          }
          if (_dobControllers[0].text.isEmpty) {
            final dob = profile['data_nascita'];
            if (dob != null) {
              try {
                final date = DateTime.parse(dob.toString());
                _dobControllers[0].text = DateFormat('dd/MM/yyyy').format(date);
              } catch (_) {
                _dobControllers[0].text = dob.toString();
              }
            }
          }
        });
      }
    } catch (e) {
      debugPrint("Errore caricamento profilo in CartScreen: $e");
    }
  }

  Future<void> _selectDate(BuildContext context, int index) async {
    DateTime? initialDate;
    final currentDob = _dobControllers[index].text;
    if (currentDob.isNotEmpty) {
      try {
        initialDate = DateFormat('dd/MM/yyyy').parse(currentDob);
      } catch (_) {}
    }

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate ?? DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF1D00FF),
              onPrimary: Colors.white,
              surface: Color(0xFF1A1A1A),
              onSurface: Colors.white,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: Colors.white),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && mounted) {
      setState(() {
        _dobControllers[index].text = DateFormat('dd/MM/yyyy').format(picked);
      });
    }
  }

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
        nPersone: (args?['type'] == 'ticket') ? _ticketQuantity : args?['nPersone'],
        ticketHolders: (args?['type'] == 'ticket') ? _ticketHolders : null,
      );
      
      // Analytics: Pagamento riuscito
      AnalyticsService.log(
        event: 'booking_payment_success',
        metadata: {
          'type': args?['type'] ?? 'table',
          'amount': args?['price'] ?? '150€',
        },
      );
      
      // Incrementa badge notifiche
      BadgeService().incrementNotificationBadge();
      
      NavigatorService.pushNamed(AppRoutes.paymentSuccessScreen);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Errore durante il pagamento: $e")),
      );
    } finally {
      if (mounted) setState(() => _isPaying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Riceviamo i dati dal booking
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    
    // Se non ci sono args, il carrello è vuoto
    final bool isEmpty = args == null;
    
    // Identifichiamo cosa c'è nel carrello
    final String bookingType = args?['type'] as String? ?? "table"; // "ticket" o "table"
    
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const CustomTopBar(),
            _buildBackButton(),
            const SizedBox(height: 10),
            Expanded(
              child: isEmpty
                  ? _buildEmptyCart()
                  : Container(
                      margin: const EdgeInsets.symmetric(horizontal: 18),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1900D8),
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
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 36,
                                  fontWeight: FontWeight.w400,
                                  height: 41 / 36,
                                  letterSpacing: -0.07 * 36,
                                ),
                              ),
                              const SizedBox(height: 20),
                              if (bookingType == "ticket")
                                _buildTicketOrder(args)
                              else
                                _buildTableOrder(args),
                              const SizedBox(height: 8),
                            ],
                          ),
                        ),
                      ),
                    ),
            ),
            if (!isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildActionBtn("ALTRO", null, () {
                        NavigatorService.goBack();
                      }),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _buildActionBtn(
                          _isPaying ? "CARICAMENTO..." : "PAGA",
                          null,
                          _isPaying ? () {} : () => _processPayment(args)),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: const SharedFooter(currentIndex: 2),
    );
  }

  Widget _buildEmptyCart() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shopping_cart_outlined,
            color: Colors.white.withOpacity(0.3),
            size: 80,
          ),
          const SizedBox(height: 20),
          Text(
            "Il carrello è vuoto",
            style: GoogleFonts.inter(
              color: Colors.white.withOpacity(0.6),
              fontSize: 22,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            "Seleziona un tavolo o un ticket\nper aggiungere un ordine",
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: Colors.white.withOpacity(0.35),
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  int _ticketQuantity = 1;

  // Controllers persistenti per gli intestatari (ricreati solo quando cambia la quantità)
  final List<TextEditingController> _nameControllers = [TextEditingController()];
  final List<TextEditingController> _dobControllers = [TextEditingController()];

  void _addHolder() {
    setState(() {
      _ticketQuantity++;
      _nameControllers.add(TextEditingController());
      _dobControllers.add(TextEditingController());
    });
  }

  void _removeHolder() {
    if (_ticketQuantity > 1) {
      setState(() {
        _ticketQuantity--;
        _nameControllers.removeLast().dispose();
        _dobControllers.removeLast().dispose();
      });
    }
  }

  // Raccoglie i dati dagli intestatari dai controller
  List<Map<String, String>> get _ticketHolders {
    return List.generate(_ticketQuantity, (i) => {
      'name': _nameControllers[i].text,
      'dob': _dobControllers[i].text,
    });
  }

  Widget _buildTicketOrder(Map<String, dynamic>? args) {
    final ticketType = args?['ticketType'] ?? "Normale";
    final priceStr = args?['price'] ?? "10€";
    final priceVal = double.tryParse(priceStr.replaceAll("€", "").trim()) ?? 10.0;

    return Column(
      children: [
        _buildSummaryItem(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Ticket", style: GoogleFonts.inter(color: Colors.white, fontSize: 28)),
                  Text(ticketType, style: GoogleFonts.inter(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                ],
              ),
              Text(
                "${(priceVal * _ticketQuantity).toStringAsFixed(0)}€",
                style: GoogleFonts.inter(color: Colors.white, fontSize: 48, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        const SizedBox(height: 15),
        _buildSummaryItem(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Quantità", style: GoogleFonts.inter(color: Colors.white, fontSize: 18)),
              Row(
                children: [
                  GestureDetector(
                    onTap: _removeHolder,
                    child: const Icon(Icons.remove_circle_outline, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 15),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(5)),
                    child: Text("$_ticketQuantity", style: GoogleFonts.inter(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 15),
                  GestureDetector(
                    onTap: _addHolder,
                    child: const Icon(Icons.add_circle_outline, color: Colors.white, size: 28),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 15),
        ...List.generate(_ticketQuantity, (index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 15),
            child: _buildSummaryItem(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    index == 0 ? "Il tuo nominativo" : "Intestatario ${index + 1}",
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _nameControllers[index],
                    style: GoogleFonts.inter(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: "Nome e Cognome",
                      hintStyle: GoogleFonts.inter(color: Colors.white54),
                      filled: true,
                      fillColor: const Color(0xFF2A2A2A),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: () => _selectDate(context, index),
                    child: AbsorbPointer(
                      child: TextField(
                        controller: _dobControllers[index],
                        style: GoogleFonts.inter(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: "Data di nascita (GG/MM/AAAA)",
                          hintStyle: GoogleFonts.inter(color: Colors.white54),
                          filled: true,
                          fillColor: const Color(0xFF2A2A2A),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          suffixIcon: const Icon(Icons.calendar_today, color: Colors.white54, size: 20),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
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
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 38,
                  fontWeight: FontWeight.w400,
                  height: 19 / 38,
                  letterSpacing: -0.07 * 38,
                ),
              ),
              Expanded(
                child: Text(
                  selectedTable,
                  textAlign: TextAlign.right,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 60,
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
                      style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 23,
                          fontWeight: FontWeight.w400,
                          height: 19 / 23,
                          letterSpacing: -0.07 * 23),
                    ),
                  ),
                  Text(
                    "150€",
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 44,
                      fontWeight: FontWeight.w400,
                      height: 37 / 44,
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
                  border: Border.all(color: const Color(0xFF1900D8), width: 2.9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Quantità: $bottleQuantity",
                      style: GoogleFonts.inter(
                          color: Colors.black,
                          fontSize: 23,
                          fontWeight: FontWeight.w400,
                          height: 27 / 23,
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
      padding: const EdgeInsets.only(left: 10, top: 10),
      child: GestureDetector(
        onTap: () => NavigatorService.goBack(),
        child: Row(
          children: [
            const Icon(Icons.arrow_back, color: Colors.white, size: 28),
            const SizedBox(width: 10),
            Text(
              'Torna indietro',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w400,
              ),
            ),
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

  Widget _buildActionBtn(String text, Color? color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 43,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1E00FF), Color(0xFF1900D8), Color(0xFF120099)],
            stops: [0.1948, 0.3886, 0.8053],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Text(
          text,
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w700,
            height: 28 / 24,
            letterSpacing: -0.07 * 24,
          ),
        ),
      ),
    );
  }
}
