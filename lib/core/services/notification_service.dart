import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/notification_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  static final _client = Supabase.instance.client;

  static Future<List<NotificationModel>> getNotifications() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];

    final response = await _client
        .from('notifiche')
        .select()
        .eq('utente_id', userId)
        .order('created_at', ascending: false);

    return (response as List).map((e) => NotificationModel.fromMap(e)).toList();
  }

  static Future<void> markAsRead(String id) async {
    await _client.from('notifiche').update({'letto': true}).eq('id', id);
  }

  static Future<void> createNotification({
    required String titolo,
    required String messaggio,
    required String tipo,
    String? relatedId,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    await _client.from('notifiche').insert({
      'utente_id': userId,
      'titolo': titolo,
      'messaggio': messaggio,
      'tipo': tipo,
      'related_id': relatedId,
    });
  }

  /// Verifica se è il momento di inviare un consiglio (ogni 4 giorni)
  static Future<void> checkAndSendRecommendation() async {
    final prefs = await SharedPreferences.getInstance();
    final lastRecStr = prefs.getString('last_recommendation_date');
    final now = DateTime.now();

    if (lastRecStr != null) {
      final lastRec = DateTime.tryParse(lastRecStr);
      if (lastRec != null && now.difference(lastRec).inDays < 4) return;
    }

    // Invia consiglio
    await createNotification(
      titolo: 'Consiglio per te! 🌟',
      messaggio: 'Abbiamo individuato una serata che potrebbe piacerti. Scoprila ora!',
      tipo: 'consiglio',
    );

    await prefs.setString('last_recommendation_date', now.toIso8601String());
  }

  /// Controlla se i club preferiti hanno aggiunto nuovi eventi
  static Future<void> checkNewEventsForFavorites() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    final prefs = await SharedPreferences.getInstance();
    final lastCheckStr = prefs.getString('last_favorite_event_check');
    final lastCheck = (lastCheckStr != null
            ? DateTime.tryParse(lastCheckStr)
            : null) ??
        DateTime.now().subtract(const Duration(days: 1));

    try {
      // 1. Prendi i preferiti
      final favs = await _client.from('preferiti').select('locale_id').eq('id_utente', userId);
      final localeIds = (favs as List).map((f) => f['locale_id'] as String).toList();
      
      if (localeIds.isEmpty) return;

      // 2. Cerca eventi creati dopo l'ultimo controllo per quei locali
      final newEvents = await _client
          .from('eventi')
          .select('nome, locali(nome)')
          .inFilter('club_id', localeIds)
          .gt('created_at', lastCheck.toIso8601String());

      for (var ev in (newEvents as List)) {
        final clubName = ev['locali']['nome'] ?? 'Un tuo club preferito';
        final eventName = ev['nome'] ?? 'una nuova serata';
        
        await createNotification(
          titolo: 'Nuova Serata! 🎉',
          messaggio: '$clubName ha aggiunto un nuovo evento: $eventName. Non mancare!',
          tipo: 'nuova_serata',
        );
      }

      await prefs.setString('last_favorite_event_check', DateTime.now().toIso8601String());
    } catch (e) {
      debugPrint('Errore checkNewEventsForFavorites: $e');
    }
  }

  /// Inviata quando viene cambiata la password
  static Future<void> sendPasswordChangeNotification() async {
    await createNotification(
      titolo: 'Sicurezza Account',
      messaggio: 'La tua password è stata aggiornata correttamente.',
      tipo: 'sistema',
    );
  }
}
