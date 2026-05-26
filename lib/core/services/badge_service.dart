import 'package:flutter/material.dart';

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
