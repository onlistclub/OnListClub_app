import 'package:flutter/material.dart';
import '../../core/app_export.dart';
import '../../core/utils/analytics_mixin.dart';
import '../../theme/onlist_colors.dart';
import 'bloc/location_permission_bloc.dart';

class LocationPermissionScreen extends StatefulWidget {
  const LocationPermissionScreen({Key? key}) : super(key: key);

  static Widget builder(BuildContext context) {
    return BlocProvider<LocationPermissionBloc>(
      create: (_) => LocationPermissionBloc()
        ..add(const LocationPermissionInitialEvent()),
      child: const LocationPermissionScreen(),
    );
  }

  @override
  State<LocationPermissionScreen> createState() => _LocationPermissionScreenState();
}

class _LocationPermissionScreenState extends State<LocationPermissionScreen> with ScreenAnalytics {
  @override
  String get screenName => 'location_permission';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Stesso identico sfondo di login/registrazione: nero di base + gradiente
      // radiale onboarding (evita anche eventuali bordi bianchi dello scaffold).
      backgroundColor: OnlistColors.black,
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: OnlistColors.onboardingBackground),
        child: BlocConsumer<LocationPermissionBloc, LocationPermissionState>(
          listener: (context, state) {
            if (state.isPermissionGranted) {
              NavigatorService.pushNamedAndRemoveUntil(
                  AppRoutes.eventDetailScreen);
            }
            if (state.goToManualEntry) {
              NavigatorService.pushNamedAndRemoveUntil(
                  AppRoutes.locationManualScreen);
            }
            if (state.errorMessage != null && state.errorMessage!.isNotEmpty) {
              showAppErrorDialog(context, state.errorMessage!);
            }
          },
          builder: (context, state) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  children: [
                    // Distribuzione verticale come Figma off/05 (icona ~29%,
                    // testo sicurezza ~82%): spacer proporzionali, non incollati.
                    const Spacer(flex: 25),
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.location_on,
                        color: OnlistColors.white,
                        size: 44,
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'Abilita la posizione precisa',
                      // Figma: 24 / w700 / line 28 / letter-spacing +0.87.
                      // NON usare title36Bold.copyWith: porterebbe il suo
                      // letterSpacing negativo (-2.88) schiacciando il testo a 24px.
                      style: const TextStyle(
                        fontFamily: 'HelveticaNeue',
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        height: 28 / 24,
                        letterSpacing: 0.87,
                        color: OnlistColors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'La tua posizione sarà usata per mostrarti\neventi e locali vicino a te.',
                      style: TextStyle(
                        fontFamily: 'HelveticaNeue',
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                        color: OnlistColors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 40),
                    SizedBox(
                      // Bottoni più stretti come Figma off/05 (width 280/393 ≈ 71%).
                      width: R.w(71),
                      height: 49,
                      child: ElevatedButton(
                        onPressed: state.isLoading
                            ? null
                            : () => context
                                .read<LocationPermissionBloc>()
                                .add(const OpenSettingsEvent()),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: OnlistColors.blueButtonPrimary,
                          foregroundColor: OnlistColors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                        child: state.isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2.5),
                              )
                            : const Text(
                                'Apri Impostazioni',
                                style: TextStyle(
                                    fontFamily: 'HelveticaNeue',
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: OnlistColors.white),
                              ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      // Bottoni più stretti come Figma off/05 (width 280/393 ≈ 71%).
                      width: R.w(71),
                      height: 49,
                      child: OutlinedButton(
                        onPressed: state.isLoading
                            ? null
                            : () => context
                                .read<LocationPermissionBloc>()
                                .add(const RemindLaterEvent()),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: OnlistColors.white,
                          foregroundColor: OnlistColors.textSecondary,
                          side: BorderSide.none,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                        child: const Text(
                          'Ricordamelo più tardi',
                          style: TextStyle(
                            fontFamily: 'HelveticaNeue',
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: OnlistColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                    const Spacer(flex: 9),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.lock_outline,
                            color: Colors.white54, size: 14),
                        const SizedBox(width: 6),
                        const Flexible(
                          child: Text(
                            'La tua posizione è protetta e non verrà condivisa con terzi.',
                            // Font del design (SF Pro Text → HelveticaNeue), 12/line 16.
                            style: TextStyle(
                                fontFamily: 'HelveticaNeue',
                                fontSize: 12,
                                height: 16 / 12,
                                fontWeight: FontWeight.w400,
                                color: Colors.white54),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(flex: 13),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
