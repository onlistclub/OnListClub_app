import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/app_export.dart';
import 'bloc/location_permission_bloc.dart';

class LocationPermissionScreen extends StatelessWidget {
  const LocationPermissionScreen({Key? key}) : super(key: key);

  static Widget builder(BuildContext context) {
    return BlocProvider<LocationPermissionBloc>(
      create: (_) => LocationPermissionBloc()
        ..add(const LocationPermissionInitialEvent()),
      child: const LocationPermissionScreen(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0000FF),
      body: BlocConsumer<LocationPermissionBloc, LocationPermissionState>(
        listener: (context, state) {
          if (state.isPermissionGranted) {
            NavigatorService.pushNamedAndRemoveUntil(
                AppRoutes.eventDetailScreen);
          }
          if (state.goToManualEntry) {
            NavigatorService.pushNamedAndRemoveUntil(
                AppRoutes.locationManualScreen);
          }
          if (state.errorMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.errorMessage!)),
            );
          }
        },
        builder: (context, state) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                children: [
                  const Spacer(flex: 3),
                  // Icona posizione
                  Container(
                    width: 88,
                    height: 88,
                    decoration: const BoxDecoration(
                      color: Color(0xFF0A0066),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.location_on,
                      color: Colors.white,
                      size: 44,
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Titolo
                  Text(
                    'Abilita la posizione precisa',
                    style: GoogleFonts.inter(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  // Sottotitolo
                  Text(
                    'La tua posizione sarà usata per mostrarti\neventi e locali vicino a te.',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),
                  // Bottone Apri Impostazioni
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: state.isLoading
                          ? null
                          : () => context
                              .read<LocationPermissionBloc>()
                              .add(const OpenSettingsEvent()),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0A0066),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30)),
                      ),
                      child: state.isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2.5),
                            )
                          : Text(
                              'Apri Impostazioni',
                              style: GoogleFonts.inter(
                                  fontSize: 16, fontWeight: FontWeight.w700),
                            ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Bottone Ricordamelo dopo
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton(
                      onPressed: state.isLoading
                          ? null
                          : () => context
                              .read<LocationPermissionBloc>()
                              .add(const RemindLaterEvent()),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black87,
                        side: BorderSide.none,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30)),
                      ),
                      child: Text(
                        'Ricordamelo più tardi',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ),
                  const Spacer(flex: 2),
                  // Nota di sicurezza
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.lock_outline,
                          color: Colors.white54, size: 14),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'La tua posizione è protetta e non verrà condivisa con terzi.',
                          style: GoogleFonts.inter(
                              fontSize: 12, color: Colors.white54),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
