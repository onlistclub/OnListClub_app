import 'package:flutter/material.dart';
import '../../core/app_export.dart';
import '../../core/utils/analytics_mixin.dart';
import '../../theme/onlist_colors.dart';
import '../../theme/onlist_text_styles.dart';
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
                    const Spacer(flex: 3),
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(16),
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
                      style: OnlistTextStyles.title36Bold.copyWith(fontSize: 24),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
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
                      width: double.infinity,
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
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
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
                    const Spacer(flex: 2),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.lock_outline,
                            color: Colors.white54, size: 14),
                        const SizedBox(width: 6),
                        const Flexible(
                          child: Text(
                            'La tua posizione è protetta e non verrà condivisa con terzi.',
                            style: TextStyle(
                                fontFamily: 'HelveticaNeue',
                                fontSize: 12,
                                color: Colors.white54),
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
      ),
    );
  }
}
