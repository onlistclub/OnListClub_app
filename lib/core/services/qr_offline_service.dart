import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Segna i biglietti mostrati all'ingresso **senza connessione**, per sapere
/// dove il campo non arriva.
///
/// **Perché lo dice l'app e non il server.** Quando lo staff scansiona, il
/// database sente solo lo scanner: il telefono dell'ospite non invia niente,
/// quindi lato server è impossibile sapere se *quel* telefono avesse campo.
/// L'unico che lo sa è l'app, e lo può raccontare solo dopo, quando torna
/// online. È quello che fa questa coda.
///
/// **Come si capisce di essere offline.** Non da un'API di connettività: su
/// un wifi che non porta da nessuna parte direbbe "connesso" proprio nei
/// locali, che è il caso che interessa. Qui "offline" vuol dire che la query
/// dei biglietti è fallita davvero e la schermata sta mostrando la cache.
///
/// **Si salva l'ORA, non un sì/no.** Chi apre il biglietto in ascensore e poi
/// entra tranquillo non è un buco di copertura: il "sì" si ricava in query
/// incrociando questo momento con `checked_in_at`, che lo mette lo scanner.
///
/// Serve la migration `2026-09-27_qr_mostrato_offline.sql`.
class QrOfflineService {
  static final QrOfflineService _instance = QrOfflineService._internal();
  factory QrOfflineService() => _instance;
  QrOfflineService._internal();

  static const String _prefissoChiave = 'qr_offline_';

  /// Oltre questo non ha più senso mandarlo: un dato di copertura di due
  /// settimane fa non lo guarda nessuno, e la coda non deve crescere a vuoto.
  static const Duration _validita = Duration(days: 14);

  bool _inCorso = false;

  String? get _chiave {
    final id = Supabase.instance.client.auth.currentUser?.id;
    return id == null ? null : '$_prefissoChiave$id';
  }

  /// Il biglietto [idPrenotazionePrevendita] è stato mostrato adesso, senza
  /// rete. Finisce in coda e parte alla prima connessione utile.
  Future<void> segna(String? idPrenotazionePrevendita) async {
    if (idPrenotazionePrevendita == null || idPrenotazionePrevendita.isEmpty) {
      return;
    }
    final coda = await _leggi();
    // Un biglietto solo una volta: se lo si apre e richiude dieci volte al
    // buio resta un evento solo, quello della prima volta.
    coda.putIfAbsent(
        idPrenotazionePrevendita, () => DateTime.now().toUtc().toIso8601String());
    await _scrivi(coda);
  }

  /// Svuota la coda verso il DB. Si chiama quando si SA di avere rete, cioè
  /// subito dopo una query dei biglietti andata a buon fine.
  ///
  /// Quello che non passa resta in coda per il giro dopo: è un dato
  /// statistico, non deve mai far fallire niente di visibile.
  Future<void> invia() async {
    if (_inCorso) return;
    final coda = await _leggi();
    if (coda.isEmpty) return;
    _inCorso = true;
    try {
      final rimaste = Map<String, String>.from(coda);
      for (final voce in coda.entries) {
        try {
          await Supabase.instance.client.rpc('segna_qr_offline', params: {
            'p_id_prenotazione_prevendita': voce.key,
            'p_quando': voce.value,
          });
          rimaste.remove(voce.key);
        } catch (e) {
          debugPrint('[QrOffline] invio fallito per ${voce.key}: $e');
        }
      }
      await _scrivi(rimaste);
    } finally {
      _inCorso = false;
    }
  }

  /// Al logout: la coda è legata all'account, non al telefono.
  Future<void> svuotaTutto() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final k in prefs.getKeys().toList()) {
        if (k.startsWith(_prefissoChiave)) await prefs.remove(k);
      }
    } catch (e) {
      debugPrint('[QrOffline] svuotamento fallito: $e');
    }
  }

  /// Coda come `{ idBiglietto: istanteISO }`, già ripulita dalle voci vecchie.
  Future<Map<String, String>> _leggi() async {
    final chiave = _chiave;
    if (chiave == null) return {};
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(chiave);
      if (raw == null || raw.isEmpty) return {};
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      final limite = DateTime.now().toUtc().subtract(_validita);
      final out = <String, String>{};
      decoded.forEach((k, v) {
        final quando = DateTime.tryParse('$v');
        if (quando != null && quando.isAfter(limite)) out['$k'] = '$v';
      });
      return out;
    } catch (e) {
      debugPrint('[QrOffline] lettura fallita: $e');
      return {};
    }
  }

  Future<void> _scrivi(Map<String, String> coda) async {
    final chiave = _chiave;
    if (chiave == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (coda.isEmpty) {
        await prefs.remove(chiave);
      } else {
        await prefs.setString(chiave, jsonEncode(coda));
      }
    } catch (e) {
      debugPrint('[QrOffline] scrittura fallita: $e');
    }
  }
}
