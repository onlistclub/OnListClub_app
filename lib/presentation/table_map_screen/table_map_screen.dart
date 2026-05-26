import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/utils/navigator_service.dart';
import '../../core/services/booking_service.dart';
import '../../widgets/app_loading_indicator.dart';

class TableMapScreen extends StatefulWidget {
  const TableMapScreen({Key? key}) : super(key: key);

  static Widget builder(BuildContext context) => const TableMapScreen();

  @override
  State<TableMapScreen> createState() => _TableMapScreenState();
}

class _TableMapScreenState extends State<TableMapScreen> {
  List<Map<String, dynamic>> _tavoli = [];
  bool _isLoading = true;
  String? _selectedTableId;
  String? _selectedTableName;

  @override
  void initState() {
    super.initState();
    _loadTavoli();
  }

  Future<void> _loadTavoli() async {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final eventoId = args?['id_evento'] as String?;

    if (eventoId != null) {
      // Carichiamo TUTTI i tavoli della serata, non solo i liberi
      final tavoli = await BookingService.getAllTavoliByEvento(eventoId);
      setState(() {
        _tavoli = tavoli;
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _isLoading 
                ? const AppLoadingIndicator()
                : _buildMapContent(),
            ),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(15),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => NavigatorService.goBack(),
            child: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 15),
          Text(
            "Torna indietro",
            style: GoogleFonts.inter(color: Colors.white, fontSize: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildMapContent() {
    return SingleChildScrollView(
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 15),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Stack(
              children: [
                // Immagine della pianta dei tavoli
                CachedNetworkImage(
                  imageUrl:
                      'https://img.freepik.com/premium-vector/vector-blueprint-club-clubhouse-plan_441769-123.jpg',
                  fit: BoxFit.contain,
                ),
                
                // Sovrapposizione dinamica dei tavoli dal DB
                // Nota: In un caso reale useresti coordinate x,y salvate nel DB per ogni tavolo.
                // Qui simuliamo una griglia sopra la mappa.
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5,
                    childAspectRatio: 1.5,
                  ),
                  itemCount: _tavoli.length,
                  itemBuilder: (context, index) {
                    final t = _tavoli[index];
                    final bool isOccupied = t['isOccupato'] == true;
                    final bool isSelected = _selectedTableId == t['id'];

                    return GestureDetector(
                      onTap: isOccupied ? null : () {
                        setState(() {
                          _selectedTableId = t['id'];
                          _selectedTableName = t['nome_tavolo'];
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: isOccupied 
                            ? Colors.red.withOpacity(0.5) 
                            : (isSelected ? Colors.blue : Colors.green.withOpacity(0.5)),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: isSelected ? Colors.white : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            t['nome_tavolo'] ?? "T",
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _buildLegend(),
        ],
      ),
    );
  }

  Widget _buildLegend() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _legendItem(Colors.green, "Libero"),
          _legendItem(Colors.red, "Occupato"),
          _legendItem(Colors.blue, "Selezionato"),
        ],
      ),
    );
  }

  Widget _legendItem(Color color, String text) {
    return Row(
      children: [
        Container(width: 12, height: 12, color: color),
        const SizedBox(width: 8),
        Text(text, style: const TextStyle(color: Colors.white, fontSize: 12)),
      ],
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: GestureDetector(
        onTap: _selectedTableId == null ? null : () {
          NavigatorService.goBack(result: {
            'selectedTableId': _selectedTableId,
            'selectedTableName': _selectedTableName,
          });
        },
        child: Container(
          width: double.infinity,
          height: 60,
          decoration: BoxDecoration(
            color: _selectedTableId == null ? Colors.grey : const Color(0xFF1D00FF),
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(
            "CONTINUA L'ORDINE",
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
