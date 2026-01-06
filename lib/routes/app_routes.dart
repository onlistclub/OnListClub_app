import 'package:flutter/material.dart';
import '../presentation/authentication_screen/authentication_screen.dart';
import '../presentation/sign_up_screen/sign_up_screen.dart';
import '../presentation/verification_screen/verification_screen.dart';
import '../presentation/verification_failure_screen/verification_failure_screen.dart';
import '../presentation/event_detail_screen/event_detail_screen.dart';

import '../presentation/app_navigation_screen/app_navigation_screen.dart';

class AppRoutes {
  static const String authenticationScreen = '/authentication_screen';
  static const String signUpScreen = '/sign_up_screen';
  static const String verificationScreen = '/verification_screen';
  static const String verificationFailureScreen = '/verification_failure_screen';
  static const String eventDetailScreen = '/event_detail_screen';

  static const String appNavigationScreen = '/app_navigation_screen';
  static const String initialRoute = '/authentication_screen';

  static Map<String, WidgetBuilder> get routes => {
        authenticationScreen: AuthenticationScreen.builder,
        signUpScreen: SignUpScreen.builder,
        verificationScreen: VerificationScreen.builder,
        verificationFailureScreen: VerificationFailureScreen.builder,
        eventDetailScreen: EventDetailScreen.builder,
        appNavigationScreen: AppNavigationScreen.builder
      };
}
