import 'package:flutter/material.dart';
import '../../core/app_export.dart';
import '../../widgets/custom_button.dart';

class VerificationFailureScreen extends StatelessWidget {
  const VerificationFailureScreen({Key? key}) : super(key: key);

  static Widget builder(BuildContext context) {
    return const VerificationFailureScreen();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: 24.h),
        color: appTheme.red_900, // Or a suitable error color/theme
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 80.h,
              color: Colors.white,
            ),
            SizedBox(height: 24.h),
            Text(
              "Tempo scaduto",
              style: TextStyleHelper.instance.headline32ExtraBoldSFCompact.copyWith(
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16.h),
            Text(
              "Il link di verifica è scaduto (validità 4 ore).\nPer favore, effettua nuovamente la registrazione.",
              style: TextStyleHelper.instance.title16ExtraBoldSFCompact.copyWith(
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 40.h),
            CustomButton(
              text: 'Nuova Registrazione',
              onPressed: () {
                // Navigate back to Sign Up (and clear stack if needed, but pushNamed is fine for now)
                NavigatorService.pushNamedAndRemoveUntil(AppRoutes.signUpScreen);
              },
              backgroundColor: appTheme.white_A700,
              textColor: appTheme.black_900,
              borderRadius: 10.h,
              padding: EdgeInsets.symmetric(
                horizontal: 30.h,
                vertical: 2.h,
              ),
              fontSize: 16.fSize,
              fontFamily: 'SF Compact',
              fontWeight: FontWeight.w800,
            ),
          ],
        ),
      ),
    );
  }
}
