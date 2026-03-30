import 'package:flutter/material.dart';
import '../presentation/authentication_screen/authentication_screen.dart';
import '../presentation/sign_up_screen/sign_up_screen.dart';
import '../presentation/verification_screen/verification_screen.dart';
import '../presentation/verification_failure_screen/verification_failure_screen.dart';
import '../presentation/home_screen/home_screen.dart';
import '../presentation/complete_profile_screen/complete_profile_screen.dart';
import '../presentation/app_navigation_screen/app_navigation_screen.dart';
import '../presentation/location_permission_screen/location_permission_screen.dart';
import '../presentation/location_manual_screen/location_manual_screen.dart';
import '../presentation/club_detail_screen/club_detail_screen.dart';
import '../presentation/booking_screen/booking_screen.dart';
import '../presentation/event_detail_club_screen/event_detail_club_screen.dart';
import '../presentation/nearby_clubs_screen/nearby_clubs_screen.dart';

class AppRoutes {
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
  static const String appNavigationScreen      = '/app_navigation_screen';
  static const String locationPermissionScreen = '/location_permission_screen';
  static const String locationManualScreen     = '/location_manual_screen';
  static const String clubDetailScreen         = '/club_detail_screen';
  static const String bookingScreen            = '/booking_screen';

  /// Dettaglio di una singola serata (event name + club name).
  static const String eventDetailClubScreen    = '/event_detail_club_screen';

  /// Lista locali vicini all'utente filtrati per raggio.
  static const String nearbyClubsScreen        = '/nearby_clubs_screen';

  static const String initialRoute = '/authentication_screen';

  static Map<String, WidgetBuilder> get routes => {
        authenticationScreen:      AuthenticationScreen.builder,
        signUpScreen:              SignUpScreen.builder,
        verificationScreen:        VerificationScreen.builder,
        verificationFailureScreen: VerificationFailureScreen.builder,
        homeScreen:                HomeScreen.builder,
        completeProfileScreen:     CompleteProfileScreen.builder,
        appNavigationScreen:       AppNavigationScreen.builder,
        locationPermissionScreen:  LocationPermissionScreen.builder,
        locationManualScreen:      LocationManualScreen.builder,
        clubDetailScreen:          ClubDetailScreen.builder,
        bookingScreen:             BookingScreen.builder,
        eventDetailClubScreen:     EventDetailClubScreen.builder,
        nearbyClubsScreen:         NearbyClubsScreen.builder,
      };
}
