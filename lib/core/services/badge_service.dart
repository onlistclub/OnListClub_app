import 'package:flutter/material.dart';

/// Singleton che pubblica i contatori dei badge dell'app (oggi solo
/// notifiche non lette).
///
/// Espone un `ValueNotifier<int>` letto dalla bottom nav (`SharedFooter`)
/// con `ValueListenableBuilder`. Aggiornato da `NotificationService` quando
/// arrivano nuove notifiche o vengono marcate come lette.
class BadgeService {
  static final BadgeService _instance = BadgeService._internal();
  factory BadgeService() => _instance;
  BadgeService._internal();

  final ValueNotifier<int> notificationBadgeCount = ValueNotifier<int>(0);

  void incrementNotificationBadge() {
    notificationBadgeCount.value++;
  }

  void clearNotificationBadge() {
    notificationBadgeCount.value = 0;
  }
}
