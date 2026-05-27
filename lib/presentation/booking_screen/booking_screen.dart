import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/models/locale_model.dart';
import '../../core/models/serata_model.dart';
import '../../core/services/analytics_service.dart';
import '../../core/utils/analytics_mixin.dart';
import '../../core/services/navigator_service.dart';
import '../../core/services/booking_service.dart';
import '../../routes/app_routes.dart';
import '../../widgets/app_loading_indicator.dart';

enum BookingStep { selection, ticketList, tableConfig, bottles }

class BookingScreen extends StatefulWidget {
  const BookingScreen({Key? key}) : super(key: key);

  static Widget builder(BuildContext context) => const BookingScreen();

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> with ScreenAnalytics {
  @override
  String get screenName => 'booking_selection';

  BookingStep _currentStep = BookingStep.selection;

  // Database Data (Initialized with samples)
  List<Map<String, dynamic>> _prevendite = [
    {
      'tipo': 'Normale',
      'prezzo': 10,
      'descrizione': '+ 2 drink omaggio',
      'validita': 'Entrata valida per questo ticket entro le 00:00 am'
    },
    {
      'tipo': 'Vip',
      'prezzo': 25,
      'descrizione': '+ 2 drink omaggio\n+ Salta fila\n+ Ticket guarda roba omaggio',
      'validita': 'Entrata valida per questo ticket entro le 00:00 am'
    }
  ];
  List<Map<String, dynamic>> _tavoli = [];
  List<Map<String, dynamic>> _bottiglie = [];
  bool _isLoading = true;
  String? _loadError;

  // Selection state
  String _selectedTable = "Seleziona";
  String? _selectedTableId;
  int _participants = 10;
  int _bottleQuantity = 1;

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

      if (!mounted) return;
      setState(() {
        if (prevendite.isNotEmpty) _prevendite = prevendite;
        if (tavoli.isNotEmpty) _tavoli = tavoli;
        if (bottiglie.isNotEmpty) _bottiglie = bottiglie;
        _isLoading = false;
        // Se il fetch non ha trovato prevendite reali, segnala che quello che
        // l'utente sta vedendo sono dati di esempio (per non far credere che
        // si possa effettivamente prenotare). NON è un errore tecnico ma serve
        // a evitare prenotazioni su dati finti.
        if (prevendite.isEmpty) {
          _loadError =
              'Nessuna prevendita trovata per questo evento. La selezione mostrata è solo di esempio.';
        }
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
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(
              child: _isLoading 
                ? const AppLoadingIndicator()
                : AnimatedSwitcher(
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
          ],
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
              style: GoogleFonts.inter(color: Colors.white, fontSize: 18),
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

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: GestureDetector(
        onTap: () {
          if (_currentStep == BookingStep.selection) {
            NavigatorService.goBack();
          } else if (_currentStep == BookingStep.ticketList ||
              _currentStep == BookingStep.tableConfig) {
            setState(() => _currentStep = BookingStep.selection);
          } else if (_currentStep == BookingStep.bottles) {
            setState(() => _currentStep = BookingStep.tableConfig);
          }
        },
        child: Row(
          children: [
            const Icon(Icons.arrow_back, color: Colors.white, size: 20),
            const SizedBox(width: 6),
            Text(
              'Torna indietro',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
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
      case BookingStep.tableConfig:
        return _buildTableConfigStep(locale, serata);
      case BookingStep.bottles:
        return _buildBottlesStep(serata);
    }
  }


  Widget _buildSelectionStep(LocaleModel? locale, SerataModel? serata) {
    return Column(
      key: const ValueKey("selection"),
      children: [
        _buildClubHeader(locale, serata),
        const SizedBox(height: 30),
        _buildSelectionButton("Tavolo", () {
          AnalyticsService.log(event: 'booking_funnel_start', metadata: {'type': 'table'});
          setState(() {
            _currentStep = BookingStep.tableConfig;
          });
        }),
        const SizedBox(height: 15),
        _buildSelectionButton("Prevendita", () {
          AnalyticsService.log(event: 'booking_funnel_start', metadata: {'type': 'ticket'});
          setState(() {
            _currentStep = BookingStep.ticketList;
          });
        }),
      ],
    );
  }

  Widget _buildClubHeader(LocaleModel? locale, SerataModel? serata) {
    return Container(
      height: 200,
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 15),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        image: const DecorationImage(
          image: AssetImage('assets/images/club_bg.png'),
          fit: BoxFit.cover,
          colorFilter: ColorFilter.mode(Colors.black38, BlendMode.darken),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              serata?.nome ?? locale?.nome ?? 'Amnesia Club',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              locale?.indirizzoCompleto ?? 'Milano - Via Alfonso Gatto',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              serata != null
                  ? '${DateFormat('MMMM d').format(serata.data)} - ${serata.orarioString}'
                  : 'Agosto 22 - 22:00 - 04:00',
              style: GoogleFonts.inter(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectionButton(String text, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
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
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 42,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.07 * 42,
          ),
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
          ? Center(child: Text("Nessuna prevendita disponibile", style: GoogleFonts.inter(color: Colors.white54)))
          : ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 15),
            itemCount: _prevendite.length,
            itemBuilder: (context, index) {
              final p = _prevendite[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 15),
                child: _buildTicketCard(
                  type: p['tipo']?.toString() ?? "Normale",
                  price: "${p['prezzo'] ?? 10}€",
                  description: p['descrizione']?.toString() ?? "+ 2 drink omaggio",
                  validity: p['validita']?.toString() ?? "Entrata valida entro le 00:00 am",
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
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF1900D8),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Ticket",
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 40,
                  fontWeight: FontWeight.w400,
                  height: 45 / 40,
                  letterSpacing: -0.1 * 40,
                ),
              ),
              Text(
                type,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w300,
                  height: 29 / 24,
                  letterSpacing: -0.06 * 24,
                ),
              ),
              const SizedBox(height: 80),
              SizedBox(
                width: 160,
                child: Text(
                  validity,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    height: 18 / 16,
                    letterSpacing: -0.1 * 16,
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            right: 0,
            top: 0,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  price,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 96,
                    fontWeight: FontWeight.w400,
                    height: 110 / 96,
                    letterSpacing: -0.08 * 96,
                  ),
                ),
                Text(
                  description,
                  textAlign: TextAlign.right,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    height: 18 / 16,
                    letterSpacing: -0.1 * 16,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: GestureDetector(
              onTap: () {
                 NavigatorService.pushNamed(AppRoutes.cartScreen, arguments: {
                   'type': 'ticket',
                   'ticketType': type,
                   'price': price,
                   'ticketId': ticketId, 
                   'id_evento': serataId,
                 });
              },
              child: Container(
                width: 133,
                height: 58,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF1500B3), Color(0xFF201064)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text(
                  "PRENOTA",
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 24,
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
  }

  Widget _buildTableConfigStep(LocaleModel? locale, SerataModel? serata) {
    return SingleChildScrollView(
      key: const ValueKey("tableConfig"),
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
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 48,
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
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 32,
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
              style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 15),
            height: 150, // Altezza fissa per la griglia o Wrap
            child: _tavoli.isEmpty 
              ? Center(child: Text("Nessun tavolo disponibile per questo evento", style: GoogleFonts.inter(color: Colors.white54)))
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
                            style: GoogleFonts.inter(
                              color: isSelected ? const Color(0xFF1D00FF) : Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
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
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
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
                        style: GoogleFonts.inter(color: Colors.white, fontSize: 42, fontWeight: FontWeight.bold),
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
                        style: GoogleFonts.inter(color: Colors.white54, fontSize: 16),
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
            child: GestureDetector(
              onTap: (_selectedTableId == null || _selectedTable == "Seleziona") 
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
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 22,
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
            style: GoogleFonts.inter(color: Colors.white, fontSize: 13)),
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
    return Column(
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
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 32,
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
    );
  }

  Widget _buildBottleCard(Map<String, dynamic> b, String? serataId) {
    return GestureDetector(
      onTap: () {
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
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              "70CL",
              style: GoogleFonts.inter(
                color: Colors.white70,
                fontSize: 14,
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
