import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/app_export.dart';
import '../../core/services/club_service.dart';
import '../../core/utils/date_formatter.dart';
import '../../widgets/shared_footer.dart';

/// Dettaglio di una singola prevendita acquistata.
/// Riceve come arguments la Map proveniente da OrdersService.getPrevenditeOrdini().
class PrevenditaDetailScreen extends StatelessWidget {
  const PrevenditaDetailScreen({Key? key}) : super(key: key);

  static Widget builder(BuildContext context) => const PrevenditaDetailScreen();

  @override
  Widget build(BuildContext context) {
    final item = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>? ?? {};

    final prenotazione = item['prenotazioni'] as Map<String, dynamic>?;
    final evento = prenotazione?['eventi'] as Map<String, dynamic>?;
    final locale = evento?['locali'] as Map<String, dynamic>?;
    final prevendita = item['prevendite'] as Map<String, dynamic>?;

    final nomeClub = locale?['nome'] ?? '';
    final nomeEvento = evento?['nome'] ?? '';
    final data = evento?['data'];
    final tipo = prevendita?['tipo'] ?? 'Standard';
    final stato = prenotazione?['stato'] ?? 'in_attesa';
    final nome = (item['nome'] ?? '').toString();
    final cognome = (item['cognome'] ?? '').toString();
    final nomeCognome = '$nome $cognome'.trim();

    // QR code dati: id della prenotazione (univoco)
    final qrData = prenotazione?['id'] ?? item['id'] ?? 'onlist-ticket';

    String dataFormatted = '';
    if (data != null) {
      try {
        dataFormatted = DateFormatter.formatLong(DateTime.parse(data));
      } catch (_) {
        dataFormatted = data.toString();
      }
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            // ── "Torna indietro" ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: GestureDetector(
                onTap: () => NavigatorService.goBack(),
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
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    Center(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 12),
                        width: 369,
                        height: 363,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(27),
                          gradient: const LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [Color(0xFF000000), Color(0xFF1900D8)],
                            stops: [0.0, 0.8173],
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black,
                              offset: Offset(16, 27),
                              blurRadius: 25.4,
                            ),
                          ],
                        ),
                        child: Center(
                          child: QrImageView(
                            data: qrData.toString(),
                            version: QrVersions.auto,
                            size: 258,
                            backgroundColor: Colors.white,
                            padding: const EdgeInsets.all(10),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Info row
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 13),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Data',
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w400,
                                  height: 32 / 28,
                                  letterSpacing: -0.1 * 28,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                dataFormatted,
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w400,
                                  height: 28 / 28,
                                  letterSpacing: -0.1 * 28,
                                ),
                              ),
                            ],
                          ),
                          GestureDetector(
                            onTap: () async {
                              final localeId = locale?['id'] as String?;
                              if (localeId == null || localeId.isEmpty) return;
                              try {
                                final localeModel = await ClubService.getLocaleById(localeId);
                                if (localeModel == null) return;
                                NavigatorService.pushNamed(
                                  AppRoutes.clubDetailScreen,
                                  arguments: localeModel,
                                );
                              } catch (_) {}
                            },
                            child: Text(
                              nomeClub,
                              style: GoogleFonts.inter(
                                color: const Color(0xFF0009FF),
                                fontSize: 28,
                                fontWeight: FontWeight.w400,
                                height: 32 / 28,
                                letterSpacing: -0.1 * 28,
                                decoration: TextDecoration.underline,
                                decorationColor: const Color(0xFF0009FF),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Nome Cognome
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 13),
                      child: Text(
                        nomeCognome.isNotEmpty ? nomeCognome : nomeEvento,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w400,
                          height: 28 / 28,
                          letterSpacing: -0.1 * 28,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.only(right: 13),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          'Tipo di Prevendita: $tipo',
                          textAlign: TextAlign.right,
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w400,
                            height: 28 / 28,
                            letterSpacing: -0.1 * 28,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Stato badge
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 13),
                      child: Row(
                        children: [
                          Text(
                            'Stato:',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w400,
                              height: 28 / 28,
                              letterSpacing: -0.1 * 28,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _buildStatoBadge(stato),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
            _buildBottomNav(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: Image.asset(
              ImageConstant.imgLogoOnlist,
              height: 60,
              width: 60,
              fit: BoxFit.cover,
            ),
          ),
          Row(
            children: const [
              Icon(Icons.search, color: Colors.white, size: 28),
              SizedBox(width: 12),
              Icon(Icons.person_outline, color: Colors.white, size: 28),
              SizedBox(width: 4),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatoBadge(String stato) {
    String label;
    switch (stato.toLowerCase()) {
      case 'confermata':
        label = 'Confermato';
        break;
      case 'usato':
        label = 'Usato';
        break;
      case 'annullata':
        label = 'Annullato';
        break;
      default:
        label = stato;
    }
    return Container(
      width: 160,
      height: 29,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFF000000), Color(0xFF1900D8)],
          stops: [0.0, 0.8173],
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.w400,
          height: 22 / 22,
          letterSpacing: -0.1 * 22,
        ),
      ),
    );
  }

  Widget _buildBottomNav() => const SharedFooter(currentIndex: 1);
}
