import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Biglietti tenuti sul telefono, per farli funzionare **senza connessione**.
///
/// Il QR del biglietto è una stringa fissa — `.../verify/<id>` — disegnata in
/// locale da `qr_flutter`: al momento della scansione il telefono dell'ospite
/// non parla con nessuno, è lo scanner dello staff a validare. L'unica cosa
/// che mancava all'ingresso senza campo erano i DATI: la lista arriva da una
/// query, e senza rete la query fallisce e la schermata resta vuota.
///
/// Qui l'ultima risposta buona viene salvata su `SharedPreferences` come JSON.
/// Niente database locale: i biglietti sono pochi e pesano qualche KB, mentre
/// sqflite o hive si porterebbero dietro peso sul bundle per nulla.
///
/// **Cosa si tiene:** le serate da oggi in avanti più quelle degli ultimi
/// [_conservazione]. Lo storico vecchio offline non serve a nessuno e non ha
/// motivo di restare sul telefono.
///
/// **Per utente:** la chiave porta l'id dell'account e [svuotaTutto] passa al
/// logout, così i biglietti di uno non restano addosso al prossimo che entra.
class PrevenditeCacheService {
  static final PrevenditeCacheService _instance =
      PrevenditeCacheService._internal();
  factory PrevenditeCacheService() => _instance;
  PrevenditeCacheService._internal();

  /// Quanto indietro si tengono le serate già passate.
  static const Duration _conservazione = Duration(days: 30);

  static const String _prefissoChiave = 'prevendite_cache_';

  String? get _chiave {
    final id = Supabase.instance.client.auth.currentUser?.id;
    return id == null ? null : '$_prefissoChiave$id';
  }

  /// Salva la risposta appena arrivata dal DB, sfoltita di quello che non
  /// serve più.
  Future<void> salva(List<Map<String, dynamic>> prevendite) async {
    final chiave = _chiave;
    if (chiave == null) return;
    try {
      final tenute = prevendite.where(_daTenere).toList();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(chiave, jsonEncode(tenute));
    } catch (e) {
      // Una cache che non si scrive non deve rompere l'app: al massimo la
      // prossima volta senza rete non ci sarà niente da mostrare.
      debugPrint('[PrevenditeCache] salvataggio fallito: $e');
    }
  }

  /// I biglietti salvati, o lista vuota se non c'è niente di utilizzabile.
  Future<List<Map<String, dynamic>>> leggi() async {
    final chiave = _chiave;
    if (chiave == null) return const [];
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(chiave);
      if (raw == null || raw.isEmpty) return const [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map<String, dynamic>>()
          .where(_daTenere)
          .toList();
    } catch (e) {
      debugPrint('[PrevenditeCache] lettura fallita: $e');
      return const [];
    }
  }

  /// Al logout: via i biglietti di questo utente dal telefono.
  Future<void> svuotaTutto() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final k in prefs.getKeys().toList()) {
        if (k.startsWith(_prefissoChiave)) await prefs.remove(k);
      }
    } catch (e) {
      debugPrint('[PrevenditeCache] svuotamento fallito: $e');
    }
  }

  /// Serata futura, oppure passata da meno di [_conservazione].
  ///
  /// Se la data non si riesce a leggere il biglietto si tiene: meglio un
  /// biglietto di troppo in cache che uno mancante davanti alla porta.
  static bool _daTenere(Map<String, dynamic> item) {
    final quando = _dataSerata(item) ?? _creatoIl(item);
    if (quando == null) return true;
    return quando.isAfter(DateTime.now().subtract(_conservazione));
  }

  static DateTime? _dataSerata(Map<String, dynamic> item) {
    final pren = item['prenotazioni'] as Map<String, dynamic>?;
    final evento = pren?['eventi'] as Map<String, dynamic>?;
    final raw = evento?['data'] ?? evento?['inizio_evento'];
    return raw == null ? null : DateTime.tryParse(raw.toString());
  }

  static DateTime? _creatoIl(Map<String, dynamic> item) {
    final pren = item['prenotazioni'] as Map<String, dynamic>?;
    final raw = pren?['created_at'];
    return raw == null ? null : DateTime.tryParse(raw.toString());
  }
}
