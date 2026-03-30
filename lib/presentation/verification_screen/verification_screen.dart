import 'package:flutter/material.dart';
import '../../core/app_export.dart';
import '../../core/services/location_service.dart';
import '../../widgets/custom_button.dart';
import './bloc/verification_bloc.dart';

class VerificationScreen extends StatelessWidget {
  const VerificationScreen({Key? key}) : super(key: key);

  static Widget builder(BuildContext context) {
    // Arguments passed from SignUp
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final registrationTime = args?['registrationTime'] as DateTime? ?? DateTime.now();
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
      backgroundColor: Color(0xFF0000FF), // Bright Blue
      body: BlocConsumer<verificationBloc, verificationState>(
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
             NavigatorService.pushNamedAndRemoveUntil(AppRoutes.verificationFailureScreen);
          }
          if (state.errorMessage != null && state.errorMessage == "Verifica prima l'email") {
            _showVerificationDialog(context);
          } else if (state.errorMessage != null) {
             ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.errorMessage!)),
            );
          }
          
          if (state.emailResentMessage != null) {
             ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.emailResentMessage!), backgroundColor: Colors.green),
            );
          }
        },
        builder: (context, state) {
          final hours = state.remainingTime.inHours;
          final minutes = state.remainingTime.inMinutes.remainder(60);
          final seconds = state.remainingTime.inSeconds.remainder(60);
          final timerText = '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

          return Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 24.h),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Spacer(),
                Text(
                  "Grazie\nper esserti registrato!",
                  style: TextStyleHelper.instance.headline32ExtraBoldSFCompact.copyWith(
                    color: Colors.white,
                    height: 1.2,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 24.h),
                Text(
                  "A BREVE TI ARRIVERÀ UN EMAIL DI CONFERMA",
                  style: TextStyleHelper.instance.title16ExtraBoldSFCompact.copyWith(
                    color: Colors.white,
                    fontSize: 12.fSize,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 16.h),
                TextButton(
                  onPressed: state.isLoading ? null : () {
                    context.read<verificationBloc>().add(ResendEmailEvent());
                  },
                  child: Text(
                    "Non hai ricevuto l'email? Clicca qui per rinviarla",
                    style: TextStyle(
                      color: Colors.white, 
                      decoration: TextDecoration.underline,
                      fontSize: 14.fSize,
                    ),
                  ),
                ),
                SizedBox(height: 24.h),
                state.isLoading 
                ? CircularProgressIndicator(color: Colors.white)
                : CustomButton(
                  text: 'Accedi',
                  onPressed: () {
                    context.read<verificationBloc>().add(CheckVerificationEvent());
                  },
                  backgroundColor: Colors.black,
                  textColor: Colors.white,
                  borderRadius: 30.h,
                  padding: EdgeInsets.symmetric(
                    horizontal: 30.h,
                    vertical: 12.h,
                  ),
                  fontSize: 16.fSize,
                  fontFamily: 'SF Compact',
                  fontWeight: FontWeight.w800,
                ),
                SizedBox(height: 24.h),
                Text(
                  "Tempo rimanente per la verifica:\n$timerText",
                  style: TextStyleHelper.instance.body14LightSFPro.copyWith(
                    color: Colors.white70,
                  ),
                  textAlign: TextAlign.center,
                ),
                Spacer(),
                TextButton(
                  onPressed: () {
                     NavigatorService.pushNamedAndRemoveUntil(AppRoutes.authenticationScreen);
                  },
                  child: Text(
                    "Torna al login",
                    style: TextStyle(color: Colors.white70, fontSize: 14.fSize),
                  ),
                ),
                SizedBox(height: 20.h),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showVerificationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Verifica Email"),
        content: Text("Per favore, verifica la tua email cliccando sul link che ti abbiamo inviato prima di accedere."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("OK"),
          ),
        ],
      ),
    );
  }
}
