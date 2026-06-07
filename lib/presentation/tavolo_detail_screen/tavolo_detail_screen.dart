import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/app_export.dart';
import '../../widgets/app_loading_indicator.dart';
import '../../widgets/custom_top_bar.dart';
import '../../widgets/shared_footer.dart';

/// Dettaglio prenotazione tavolo — design Figma "Notifiche x tavolo.png"
///
/// Riceve come arguments la Map da OrdersService.getTavoliOrdini()
class TavoloDetailScreen extends StatelessWidget {
  const TavoloDetailScreen({Key? key}) : super(key: key);

  static Widget builder(BuildContext context) => const TavoloDetailScreen();

  @override
  Widget build(BuildContext context) {
    final item =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>? ??
            {};

    final evento  = item['eventi']  as Map<String, dynamic>?;
    final locale  = evento?['locali'] as Map<String, dynamic>?;
    final tavolo  = item['tavoli']  as Map<String, dynamic>?;

    final nomeTavolo  = tavolo?['nome_tavolo']?.toString() ?? '';
    final piantina    = locale?['piantina_url']?.toString(); // colonna futura

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(context),
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
            const SizedBox(height: 12),
            // ── Box blu ─────────────────────────────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  width: double.infinity,
                  clipBehavior: Clip.hardEdge,
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFF1D00FF), width: 4),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── Header tavolo ──────────────────────────────────
                      Container(
                        color: Colors.black,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Tavolo n: ',
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              nomeTavolo,
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 64,
                                fontWeight: FontWeight.bold,
                                height: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // ── Piantina ───────────────────────────────────────
                      Expanded(
                        child: _buildPiantina(piantina),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildBottomNav(),
          ],
        ),
      ),
    );
  }

  Widget _buildPiantina(String? url) {
    if (url != null && url.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.contain,
        memCacheWidth: 800,
        placeholder: (_, __) => const AppLoadingIndicator(),
        errorWidget: (_, __, ___) => _piantinaMissing(),
      );
    }
    return _piantinaMissing();
  }

  Widget _piantinaMissing() {
    return Container(
      color: Colors.white,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.map_outlined, size: 64, color: Colors.black38),
            const SizedBox(height: 12),
            Text(
              'Piantina non disponibile',
              style: GoogleFonts.inter(
                color: Colors.black45,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    // Navbar fissa condivisa: stesso logo (wordmark) e stesse icone di
    // tutte le altre schermate con navbar.
    return const CustomTopBar();
  }

  Widget _buildBottomNav() => const SharedFooter(currentIndex: 1);
}
