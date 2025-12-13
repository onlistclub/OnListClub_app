import 'package:equatable/equatable.dart';
import '../../../core/app_export.dart';

/// This class is used in the [EventDetailScreen] screen.

// ignore_for_file: must_be_immutable
class EventDetailModel extends Equatable {
  EventDetailModel({
    this.eventTitle,
    this.eventSubtitle,
    this.eventDateTime,
    this.upcomingEvents,
    this.cartCount,
    this.notificationCount,
  }) {
    eventTitle = eventTitle ?? "Sabato Sera ";
    eventSubtitle = eventSubtitle ?? "Disco Club";
    eventDateTime = eventDateTime ?? "Agosto 22 - 22:00 - 03:00 ";
    upcomingEvents = upcomingEvents ??
        [
          UpcomingEventModel(
            dayName: "Sabato",
            dateTime: "Agosto 23 - 23:00 - 04:00",
          ),
          UpcomingEventModel(
            dayName: "Venerdì",
            dateTime: "Agosto 29 - 22:00 - 04:00",
          ),
        ];
    cartCount = cartCount ?? "1000";
    notificationCount = notificationCount ?? "1";
  }

  String? eventTitle;
  String? eventSubtitle;
  String? eventDateTime;
  List<UpcomingEventModel>? upcomingEvents;
  String? cartCount;
  String? notificationCount;

  EventDetailModel copyWith({
    String? eventTitle,
    String? eventSubtitle,
    String? eventDateTime,
    List<UpcomingEventModel>? upcomingEvents,
    String? cartCount,
    String? notificationCount,
  }) {
    return EventDetailModel(
      eventTitle: eventTitle ?? this.eventTitle,
      eventSubtitle: eventSubtitle ?? this.eventSubtitle,
      eventDateTime: eventDateTime ?? this.eventDateTime,
      upcomingEvents: upcomingEvents ?? this.upcomingEvents,
      cartCount: cartCount ?? this.cartCount,
      notificationCount: notificationCount ?? this.notificationCount,
    );
  }

  @override
  List<Object?> get props => [
        eventTitle,
        eventSubtitle,
        eventDateTime,
        upcomingEvents,
        cartCount,
        notificationCount,
      ];
}

class UpcomingEventModel extends Equatable {
  UpcomingEventModel({
    this.dayName,
    this.dateTime,
  }) {
    dayName = dayName ?? "";
    dateTime = dateTime ?? "";
  }

  String? dayName;
  String? dateTime;

  UpcomingEventModel copyWith({
    String? dayName,
    String? dateTime,
  }) {
    return UpcomingEventModel(
      dayName: dayName ?? this.dayName,
      dateTime: dateTime ?? this.dateTime,
    );
  }

  @override
  List<Object?> get props => [dayName, dateTime];
}
