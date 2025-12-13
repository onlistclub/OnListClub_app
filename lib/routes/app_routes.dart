import 'package:flutter/material.dart';
import '../presentation/authentication_screen/authentication_screen.dart';
import '../presentation/event_detail_screen/event_detail_screen.dart';

import '../presentation/app_navigation_screen/app_navigation_screen.dart';

class AppRoutes {
  static const String authenticationScreen = '/authentication_screen';
  static const String eventDetailScreen = '/event_detail_screen';

  static const String appNavigationScreen = '/app_navigation_screen';
  static const String initialRoute = '/';

  static Map<String, WidgetBuilder> get routes => {
        authenticationScreen: AuthenticationScreen.builder,
        eventDetailScreen: EventDetailScreen.builder,
        appNavigationScreen: AppNavigationScreen.builder,
        initialRoute: AppNavigationScreen.builder
      };
}
