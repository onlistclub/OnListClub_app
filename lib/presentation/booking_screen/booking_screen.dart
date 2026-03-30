import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/models/locale_model.dart';
import '../../core/models/serata_model.dart';
import '../../core/utils/navigator_service.dart';

class BookingScreen extends StatelessWidget {
  const BookingScreen({Key? key}) : super(key: key);

  static Widget builder(BuildContext context) => const BookingScreen();

  /// Estrae locale e serata dagli argomenti del route.
  /// Supporta:
  ///   - Map<String, dynamic> { 'serata': SerataModel, 'club': LocaleModel }
  ///   - LocaleModel (legacy)
  static ({LocaleModel? locale, SerataModel? serata}) _parseArgs(
      BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map<String, dynamic>) {
      return (
        locale: args['club'] as LocaleModel?,
        serata: args['serata'] as SerataModel?,
      );
    }
    if (args is LocaleModel) {
      return (locale: args, serata: null);
    }
    return (locale: null, serata: null);
  }

  @override
  Widget build(BuildContext context) {
    final (:locale, :serata) = _parseArgs(context);

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // AppBar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: NavigatorService.goBack,
                    child: const Icon(Icons.arrow_back_ios_new,
                        color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Prenota',
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Serata info
                      if (serata != null) ...[
                        Text(
                          serata.nome,
                          style: GoogleFonts.inter(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: -0.08 * 28,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (locale != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            locale.nome,
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              color: Colors.white.withValues(alpha: 0.6),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                        const SizedBox(height: 6),
                        Text(
                          '${DateFormat('EEEE d MMMM', 'it_IT').format(serata.data)}'
                          '${serata.orarioString.isNotEmpty ? '  ·  ${serata.orarioString}' : ''}',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.5),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 40),
                      ] else if (locale != null) ...[
                        Text(
                          locale.nome,
                          style: GoogleFonts.inter(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: -0.08 * 28,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          locale.indirizzoCompleto,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: Colors.white.withValues(alpha: 0.5),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 40),
                      ],
                      // Placeholder
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1A1A),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFF0009FF)
                                .withValues(alpha: 0.4),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.construction_rounded,
                              color: Color(0xFF0009FF),
                              size: 40,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Prenotazione in arrivo',
                              style: GoogleFonts.inter(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'La schermata di prenotazione\nè in sviluppo.',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: Colors.white.withValues(alpha: 0.5),
                                height: 1.5,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
