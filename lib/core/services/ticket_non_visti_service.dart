import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Biglietti comprati e non ancora aperti: accendono il pallino blu
/// sull'icona TICKET della footer.
///
/// | momento                                  | pallino TICKET |
/// |------------------------------------------|----------------|
/// | "PRENOTA ORA" riuscito                   | ACCESO         |
/// | apre il biglietto (conferma o riepilogo) | spento         |
/// | app chiusa e riaperta senza aprirlo      | ACCESO         |
///
/// Salvati sul telefono (SharedPreferences), una lista per utente: è uno
/// stato "letto/non letto" di chi usa quel telefono, non serve sul DB.
/// Ogni voce è `idPrenotazione|millisecondi` e scade dopo [_validita], così
/// una prenotazione mai aperta (o annullata altrove) non tiene il pallino
/// acceso per sempre.
class TicketNonVistiService {
  static final TicketNonVistiService _instance =
      TicketNonVistiService._internal();
  factory TicketNonVistiService() => _instance;
  TicketNonVistiService._internal();

  static const Duration _validita = Duration(days: 14);

  final ValueNotifier<bool> pallino = ValueNotifier<bool>(false);

  String? get _chiave {
    final id = Supabase.instance.client.auth.currentUser?.id;
    return id == null ? null : 'ticket_non_visti_$id';
  }

  /// Legge la lista salvata e ricalcola il pallino (avvio dello shell).
  Future<void> carica() async {
    final voci = await _leggi();
    pallino.value = voci.isNotEmpty;
  }

  /// Nuova prenotazione appena conclusa.
  Future<void> aggiungi(String idPrenotazione) async {
    if (idPrenotazione.isEmpty) return;
    final voci = await _leggi();
    voci[idPrenotazione] = DateTime.now().millisecondsSinceEpoch;
    await _scrivi(voci);
  }

  /// L'utente ha aperto il biglietto di [idPrenotazione].
  Future<void> segnaVisto(String? idPrenotazione) async {
    if (idPrenotazione == null || idPrenotazione.isEmpty) return;
    final voci = await _leggi();
    if (voci.remove(idPrenotazione) == null) return;
    await _scrivi(voci);
  }

  /// Al logout: il pallino del prossimo utente dipende solo dalla SUA lista.
  void reset() => pallino.value = false;

  Future<Map<String, int>> _leggi() async {
    final chiave = _chiave;
    if (chiave == null) return {};
    try {
      final prefs = await SharedPreferences.getInstance();
      final limite =
          DateTime.now().subtract(_validita).millisecondsSinceEpoch;
      final Map<String, int> voci = {};
      for (final v in prefs.getStringList(chiave) ?? const <String>[]) {
        final i = v.lastIndexOf('|');
        if (i <= 0) continue;
        final ts = int.tryParse(v.substring(i + 1));
        if (ts == null || ts < limite) continue;
        voci[v.substring(0, i)] = ts;
      }
      return voci;
    } catch (e) {
      debugPrint('[TicketNonVisti] lettura fallita: $e');
      return {};
    }
  }

  Future<void> _scrivi(Map<String, int> voci) async {
    pallino.value = voci.isNotEmpty;
    final chiave = _chiave;
    if (chiave == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        chiave,
        [for (final e in voci.entries) '${e.key}|${e.value}'],
      );
    } catch (e) {
      debugPrint('[TicketNonVisti] scrittura fallita: $e');
    }
  }
}
