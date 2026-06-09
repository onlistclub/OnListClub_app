import 'package:flutter/material.dart';
import '../../core/app_export.dart';
import '../../core/services/location_service.dart';
import '../../theme/onlist_colors.dart';
import '../../theme/onlist_text_styles.dart';
import './bloc/verification_bloc.dart';

class VerificationScreen extends StatelessWidget {
  const VerificationScreen({Key? key}) : super(key: key);

  static Widget builder(BuildContext context) {
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final registrationTime =
        args?['registrationTime'] as DateTime? ?? DateTime.now();
    final email = args?['email'] as String? ?? '';
    final password = args?['password'] as String? ?? '';

    return BlocProvider<verificationBloc>(
      create: (context) => verificationBloc(verificationState())
        ..add(verificationInitialEvent(
          registrationTime: registrationTime,
          email: email,
          password: password,
        )),
      child: const VerificationScreen(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: OnlistColors.onboardingBackground),
        child: BlocConsumer<verificationBloc, verificationState>(
        listener: (context, state) {
          if (state.isVerified) {
            LocationService.shouldShowLocationPrompt().then((show) {
              NavigatorService.pushNamedAndRemoveUntil(
                show
                    ? AppRoutes.locationPermissionScreen
                    : AppRoutes.eventDetailScreen,
              );
            });
          }
          if (state.isExpired) {
            NavigatorService.pushNamedAndRemoveUntil(
                AppRoutes.verificationFailureScreen);
          }
          if (state.errorMessage != null &&
              state.errorMessage == "Verifica prima l'email") {
            _showVerificationDialog(context);
          } else if (state.errorMessage != null && state.errorMessage!.isNotEmpty) {
            showAppErrorDialog(context, state.errorMessage!);
          }
          if (state.emailResentMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text(state.emailResentMessage!),
                  backgroundColor: Colors.green),
            );
          }
        },
        builder: (context, state) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(),
                  // Titolo
                  Text(
                    'Grazie\nper esserti registrato!',
                    style: OnlistTextStyles.title32Medium.copyWith(height: 1.2),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  // Sottotitolo
                  Text(
                    'A BREVE TI ARRIVERÀ UN EMAIL DI CONFERMA',
                    style: OnlistTextStyles.caption12Medium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  // Reinvia email
                  TextButton(
                    onPressed: state.isLoading
                        ? null
                        : () => context
                            .read<verificationBloc>()
                            .add(ResendEmailEvent()),
                    child: Text(
                      "Non hai ricevuto l'email? Clicca qui",
                      style: const TextStyle(
                        fontFamily: 'HelveticaNeue',
                        fontSize: 14,
                        color: Colors.white,
                        decoration: TextDecoration.underline,
                        decorationColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Bottone Accedi
                  state.isLoading
                      ? const CircularProgressIndicator(color: OnlistColors.white)
                      : SizedBox(
                          width: 150,
                          height: 40,
                          child: ElevatedButton(
                            onPressed: () => context
                                .read<verificationBloc>()
                                .add(CheckVerificationEvent()),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: OnlistColors.white,
                              foregroundColor: OnlistColors.black,
                              elevation: 0,
                              padding: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                            child: Text('Accedi', style: OnlistTextStyles.button16Bold),
                          ),
                        ),
                  const Spacer(),
                  // Torna al login
                  TextButton(
                    onPressed: () => NavigatorService.pushNamedAndRemoveUntil(
                        AppRoutes.authenticationScreen),
                    child: const Text(
                      'Torna al login',
                      style: TextStyle(
                          fontFamily: 'HelveticaNeue',
                          fontSize: 14,
                          color: Colors.white70),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          );
        },
        ),
      ),
    );
  }

  void _showVerificationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Verifica Email'),
        content: const Text(
            'Per favore, verifica la tua email cliccando sul link che ti abbiamo inviato prima di accedere.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
