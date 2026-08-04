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
import '../presentation/root_shell/root_shell.dart';
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
  /// gli avanzamenti gerarchici (booking, cart…) usano invece lo shared-axis
  /// orizzontale. `clubDetailScreen` è qui perché è destinazione di un `Hero`
  /// (immagine del locale): con il fade la pagina non scivola e il morph
  /// dell'immagine resta il protagonista del movimento. Vedi `page_transitions.dart`.
  static const Set<String> _fadeRoutes = {
    splashScreen,
    authenticationScreen,
    homeScreen,
    clubDetailScreen,
    verificationFailureScreen,
    paymentSuccessScreen,
  };

  /// Rotte che entrano come un POP-UP: piccole e trasparenti, si aprono con un
  /// rimbalzo. È una rotta a tutti gli effetti, ma deve dare la sensazione di
  /// un pannello che scatta in primo piano sopra il dettaglio del club.
  static const Set<String> _popupRoutes = {
    eventInfoPopupScreen,
  };

  /// Schermate SENZA swipe-back. Sono il flusso pre-home (splash → auth →
  /// registrazione → posizione), dove "indietro" non deve esistere perché più
  /// indietro della home non c'è nulla, più `paymentSuccess`: lì la prenotazione
  /// è già creata e tornare al carrello non ha senso.
  ///
  /// Tutto il resto (club, booking, cart, ordini, profilo, notifiche…) è
  /// navigazione gerarchica a valle della home e il gesto è attivo. È comunque
  /// una difesa in più: `AppPageRoute` disabilita il gesto da sé quando la rotta
  /// è la prima dello stack, come sono di fatto queste schermate (ci si arriva
  /// con `pushNamedAndRemoveUntil`).
  static const Set<String> _noBackGestureRoutes = {
    splashScreen,
    authenticationScreen,
    signUpScreen,
    verificationScreen,
    verificationFailureScreen,
    completeProfileScreen,
    locationPermissionScreen,
    homeScreen,
    paymentSuccessScreen,
  };

  /// Rotte di DETTAGLIO che vivono dentro lo shell persistente ([RootShell]):
  /// vengono spinte sul suo Navigator annidato (footer fissa + swipe verticale +
  /// schermata precedente preservata). Tutto ciò che NON è qui (splash, auth,
  /// flusso posizione, `homeScreen`/shell) resta sul Navigator radice.
  /// Usato da [NavigatorService] per decidere il navigator di destinazione.
  static const Set<String> shellRoutes = {
    clubDetailScreen,
    bookingScreen,
    nearbyClubsScreen,
    profileScreen,
    notificationsScreen,
    cartScreen,
    ordersScreen,
    paymentSuccessScreen,
    prevenditaDetailScreen,
    tavoloDetailScreen,
    eventInfoPopupScreen,
  };

  /// Genera ogni rotta applicando la transizione unica dell'app. Sostituisce la
  /// mappa `routes:` di `MaterialApp` per dare a TUTTE le schermate lo stesso
  /// linguaggio di movimento (vedi `main.dart`).
  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    final builder = routes[settings.name];
    if (builder == null) return null;
    final AppTransition transition;
    if (_popupRoutes.contains(settings.name)) {
      transition = AppTransition.popup;
    } else if (_fadeRoutes.contains(settings.name)) {
      transition = AppTransition.fade;
    } else {
      transition = AppTransition.sharedAxis;
    }
    return buildAppRoute(
      settings,
      builder,
      transition,
      enableBackGesture: !_noBackGestureRoutes.contains(settings.name),
    );
  }

  static Map<String, WidgetBuilder> get routes => {
        splashScreen:              SplashScreen.builder,
        authenticationScreen:      AuthenticationScreen.builder,
        signUpScreen:              SignUpScreen.builder,
        verificationScreen:        VerificationScreen.builder,
        verificationFailureScreen: VerificationFailureScreen.builder,
        // La Home è ospitata dallo shell persistente (footer fissa + tab con
        // stato preservato). Le vecchie navigazioni verso `homeScreen` (splash,
        // footer legacy, ecc.) montano quindi lo shell sulla tab Home.
        homeScreen:                RootShell.builder,
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
