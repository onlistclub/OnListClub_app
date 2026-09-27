import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../routes/app_routes.dart';
import 'navigator_service.dart';

/// Gestisce i deep link custom scheme `onlistclub://` ricevuti dalle email
/// transazionali (email di conferma prevendita, welcome, QR).
///
/// Schemi supportati:
/// - `onlistclub://home` → torna sulla Home dello shell principale
/// - `onlistclub://orders` → apre la lista Ordini
/// - `onlistclub://orders?id=<uuid>` → apre la lista Ordini e preseleziona la
///   prevendita `id` (che viene poi passata come argomento a `OrdersScreen`,
///   dove `_checkDeepLinkTarget` la trova nella lista e apre il dettaglio).
///
/// Lo schema custom è registrato in `ios/Runner/Info.plist` e in
/// `android/app/src/main/AndroidManifest.xml`. Qui gestiamo solo il lato Dart:
/// intercettiamo l'URI ricevuto e lo mappiamo alle route dell'app.
///
/// Il servizio gestisce due sorgenti di URI:
/// 1. `getInitialLink()` — l'URI che ha lanciato l'app da freddo (l'app era
///    chiusa quando l'utente ha cliccato il link dell'email).
/// 2. `uriLinkStream` — URI ricevuti mentre l'app è in background (l'utente
///    torna nell'app cliccando il link).
///
/// Se il deep link arriva prima che l'utente sia loggato, l'URI viene salvato
/// come "pending" e riprocessato quando la sessione Supabase diventa attiva.
class DeepLinkService {
  static final AppLinks _appLinks = AppLinks();
  static StreamSubscription<Uri>? _linkSub;
  static StreamSubscription<AuthState>? _authSub;
  static Uri? _pendingUri;
  static bool _initialized = false;

  /// Inizializza gli stream di deep link. Idempotente: chiamate multiple
  /// non montano più listener.
  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    // Link iniziale (app aperta da freddo dal link nell'email).
    try {
      final initial = await _appLinks.getInitialLink();
      if (initial != null) {
        debugPrint('[DeepLinkService] initial link: $initial');
        _handleUri(initial);
      }
    } catch (e) {
      debugPrint('[DeepLinkService] getInitialLink error: $e');
    }

    // Link ricevuti mentre l'app è in background.
    _linkSub = _appLinks.uriLinkStream.listen(
      (uri) {
        debugPrint('[DeepLinkService] stream link: $uri');
        _handleUri(uri);
      },
      onError: (Object e) {
        debugPrint('[DeepLinkService] uriLinkStream error: $e');
      },
    );

    // Quando arriva un SIGNED_IN, se abbiamo un URI in pending, lo riprocessiamo:
    // capita quando l'utente clicca il link dell'email prima di essere loggato
    // (es. app pulita, deep link → schermata di login → dopo il login si va
    // dove il link voleva portare).
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((state) {
      if (state.event == AuthChangeEvent.signedIn && _pendingUri != null) {
        final pending = _pendingUri!;
        _pendingUri = null;
        debugPrint('[DeepLinkService] retrying pending link after sign-in: $pending');
        _handleUri(pending);
      }
    });
  }

  static Future<void> dispose() async {
    await _linkSub?.cancel();
    _linkSub = null;
    await _authSub?.cancel();
    _authSub = null;
    _initialized = false;
  }

  /// Mappa l'URI ricevuto sulla navigazione dell'app.
  ///
  /// Se l'utente non è ancora loggato, l'URI viene salvato come pending e
  /// riprocessato al successivo SIGNED_IN.
  static void _handleUri(Uri uri) {
    // Accetta solo il nostro schema custom, ignora tutto il resto (redirect
    // OAuth, universal links per il web, ecc. — quelli sono gestiti altrove).
    if (uri.scheme != 'onlistclub') {
      debugPrint('[DeepLinkService] ignorato schema=${uri.scheme}');
      return;
    }

    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      debugPrint('[DeepLinkService] utente non loggato, salvo pending: $uri');
      _pendingUri = uri;
      return;
    }

    // `host` = la prima parte dopo `onlistclub://` (es. "orders", "home").
    // Alcune combinazioni possono finire in `path` invece che `host` a seconda
    // di come è formattata l'URI: coprire entrambi rende il matching robusto.
    final target = uri.host.isNotEmpty
        ? uri.host.toLowerCase()
        : uri.path.replaceAll('/', '').toLowerCase();

    switch (target) {
      case 'orders':
        final id = uri.queryParameters['id'];
        if (id != null && id.isNotEmpty) {
          debugPrint('[DeepLinkService] apro Ordini con id=$id');
          // arguments non-null → NavigatorService pusha la route (non fa
          // switch tab), così OrdersScreen legge args e apre il dettaglio.
          NavigatorService.pushNamed(
            AppRoutes.ordersScreen,
            arguments: {'id': id},
          );
        } else {
          debugPrint('[DeepLinkService] apro Ordini (tab)');
          NavigatorService.pushNamed(AppRoutes.ordersScreen);
        }
        break;
      case 'home':
      case '':
        debugPrint('[DeepLinkService] apro Home');
        NavigatorService.pushNamed(AppRoutes.homeScreen);
        break;
      default:
        debugPrint('[DeepLinkService] target sconosciuto: $target');
    }
  }
}
