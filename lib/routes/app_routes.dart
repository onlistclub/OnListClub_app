/// Mappa centralizzata delle rotte dell'app.
///
/// Espone `AppRoutes.<screenName>` (stringa-rotta) e la mappa `routes` consumata
/// da `MaterialApp` in `main.dart`. Quando si aggiunge una schermata, registrarla
/// qui per essere navigabile via `Navigator.pushNamed` / `NavigatorService`.
library;

import 'package:flutter/material.dart';
import 'page_transitions.dart';
import '../presentation/splash_screen/splash_screen.dart';
import '../presentation/authentication_screen/authentication_screen.dart';
import '../presentation/sign_up_screen/sign_up_screen.dart';
import '../presentation/verification_screen/verification_screen.dart';
import '../presentation/verification_failure_screen/verification_failure_screen.dart';
import '../presentation/home_screen/home_screen.dart';
import '../presentation/complete_profile_screen/complete_profile_screen.dart';
import '../presentation/location_permission_screen/location_permission_screen.dart';
import '../presentation/location_manual_screen/location_manual_screen.dart';
import '../presentation/club_detail_screen/club_detail_screen.dart';
import '../presentation/booking_screen/booking_screen.dart';
import '../presentation/nearby_clubs_screen/nearby_clubs_screen.dart';
import '../presentation/profile_screen/profile_screen.dart';
import '../presentation/notifications_screen/notifications_screen.dart';
import '../presentation/cart_screen/cart_screen.dart';
import '../presentation/orders_screen/orders_screen.dart';
import '../presentation/payment_success_screen/payment_success_screen.dart';
import '../presentation/prevendita_detail_screen/prevendita_detail_screen.dart';
import '../presentation/tavolo_detail_screen/tavolo_detail_screen.dart';
import '../presentation/event_info_popup_screen/event_info_popup_screen.dart';

class AppRoutes {
  static const String splashScreen             = '/splash_screen';
  static const String authenticationScreen     = '/authentication_screen';
  static const String signUpScreen             = '/sign_up_screen';
  static const String verificationScreen       = '/verification_screen';
  static const String verificationFailureScreen = '/verification_failure_screen';

  /// Home principale dell'app (ex event_detail_screen).
  static const String homeScreen               = '/home_screen';
  /// Alias retrocompatibile: tutte le navigazioni verso eventDetailScreen
  /// finiscono sulla nuova Home.
  static const String eventDetailScreen        = '/home_screen';

  static const String completeProfileScreen    = '/complete_profile_screen';
  static const String locationPermissionScreen = '/location_permission_screen';
  static const String locationManualScreen     = '/location_manual_screen';
  static const String clubDetailScreen         = '/club_detail_screen';
  static const String bookingScreen            = '/booking_screen';

  /// Lista locali vicini all'utente filtrati per raggio.
  static const String nearbyClubsScreen        = '/nearby_clubs_screen';

  static const String profileScreen            = '/profile_screen';
  static const String notificationsScreen      = '/notifications_screen';
  static const String cartScreen               = '/cart_screen';
  static const String ordersScreen              = '/orders_screen';
  static const String paymentSuccessScreen     = '/payment_success_screen';
  static const String prevenditaDetailScreen   = '/prevendita_detail_screen';
  static const String tavoloDetailScreen       = '/tavolo_detail_screen';

  /// Pop-up info serata (Figma `off/19`). Riceve {serata, club} come args.
  static const String eventInfoPopupScreen     = '/event_info_popup_screen';

  static const String initialRoute = splashScreen;

  /// Rotte che usano la transizione `fade` (ingressi atmosferici / pari livello):
  /// gli avanzamenti gerarchici (dettagli, booking, cart…) usano invece lo
  /// shared-axis orizzontale. Vedi `page_transitions.dart`.
  static const Set<String> _fadeRoutes = {
    splashScreen,
    authenticationScreen,
    homeScreen,
    verificationFailureScreen,
    paymentSuccessScreen,
  };

  /// Genera ogni rotta applicando la transizione unica dell'app. Sostituisce la
  /// mappa `routes:` di `MaterialApp` per dare a TUTTE le schermate lo stesso
  /// linguaggio di movimento (vedi `main.dart`).
  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    final builder = routes[settings.name];
    if (builder == null) return null;
    final transition = _fadeRoutes.contains(settings.name)
        ? AppTransition.fade
        : AppTransition.sharedAxis;
    return buildAppRoute(settings, builder, transition);
  }

  static Map<String, WidgetBuilder> get routes => {
        splashScreen:              SplashScreen.builder,
        authenticationScreen:      AuthenticationScreen.builder,
        signUpScreen:              SignUpScreen.builder,
        verificationScreen:        VerificationScreen.builder,
        verificationFailureScreen: VerificationFailureScreen.builder,
        homeScreen:                HomeScreen.builder,
        completeProfileScreen:     CompleteProfileScreen.builder,
        locationPermissionScreen:  LocationPermissionScreen.builder,
        locationManualScreen:      LocationManualScreen.builder,
        clubDetailScreen:          ClubDetailScreen.builder,
        bookingScreen:             BookingScreen.builder,
        nearbyClubsScreen:         NearbyClubsScreen.builder,
        profileScreen:             ProfileScreen.builder,
        notificationsScreen:       NotificationsScreen.builder,
        cartScreen:                CartScreen.builder,
        ordersScreen:               OrdersScreen.builder,
        paymentSuccessScreen:       PaymentSuccessScreen.builder,
        prevenditaDetailScreen:     PrevenditaDetailScreen.builder,
        tavoloDetailScreen:         TavoloDetailScreen.builder,
        eventInfoPopupScreen:       EventInfoPopupScreen.builder,
      };
}
