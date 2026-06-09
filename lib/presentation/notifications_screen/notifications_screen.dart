import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/app_export.dart';
import '../../core/services/notification_service.dart';
import '../../core/models/notification_model.dart';
import '../../core/utils/analytics_mixin.dart';
import '../../theme/onlist_colors.dart';
import '../../theme/onlist_text_styles.dart';
import '../../widgets/app_loading_indicator.dart';
import '../../widgets/custom_top_bar.dart';
import '../../widgets/shared_footer.dart';
import '../../widgets/staggered_item.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({Key? key}) : super(key: key);

  static Widget builder(BuildContext context) => const NotificationsScreen();

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> with ScreenAnalytics {
  @override
  String get screenName => 'notifications';

  late Future<List<NotificationModel>> _future;
  static final DateFormat _dateFormat = DateFormat('d MMM yyyy', 'it_IT');

  @override
  void initState() {
    super.initState();
    _future = NotificationService.getNotifications();
    NotificationService.checkAndSendRecommendation();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      // Footer flottante: la lista scorre dietro la capsula (non la oscura).
      extendBody: true,
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: OnlistColors.screenBackground),
        child: SafeArea(
          child: Column(
            children: [
              const CustomTopBar(),
              Expanded(
                child: FutureBuilder<List<NotificationModel>>(
                  future: _future,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const AppLoadingIndicator();
                    }
                    if (snapshot.hasError) {
                      return Center(
                        child: Text('Errore nel caricamento',
                            style: OnlistTextStyles.hn(
                                color: Colors.white54, fontSize: R.sp(16))),
                      );
                    }
                    final notifications = snapshot.data ?? [];
                    if (notifications.isEmpty) {
                      return _buildEmptyState();
                    }
                    // Raggruppa per data (la lista arriva già newest-first dal service):
                    // una sola intestazione data, sotto tutte le notifiche di quel giorno.
                    final sections = _groupByDate(notifications);
                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 16, 12, 16 + SharedFooter.height),
                      itemCount: sections.length,
                      itemBuilder: (context, index) {
                        final section = sections[index];
                        return StaggeredItem(
                          index: index,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: EdgeInsets.only(
                                    left: 4, top: index == 0 ? 0 : 12, bottom: 8),
                                child: Text(section.label,
                                    style: OnlistTextStyles.title28Regular),
                              ),
                              ...section.notifications.map(_buildNotificationCard),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const SharedFooter(currentIndex: 3),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.notifications_none, size: 80, color: Colors.white10),
          const SizedBox(height: 16),
          Text('Nessuna notifica',
              style: OnlistTextStyles.hn(color: Colors.white54, fontSize: R.sp(18))),
        ],
      ),
    );
  }

  // Card notifica cliccabile: titolo CENTRATO su gradiente (Figma 16).
  Widget _buildNotificationCard(NotificationModel n) {
    return GestureDetector(
      onTap: () => _onNotificationTap(n),
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        height: 66,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [Color(0x33FFFFFF), Color(0x331E00FF)],
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          n.titolo,
          maxLines: 1,
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          style: OnlistTextStyles.ticketLabel,
        ),
      ),
    );
  }

  // ── Tap: naviga a una destinazione reale + marca come letta ────────────────
  Future<void> _onNotificationTap(NotificationModel n) async {
    _navigateFor(n);
    if (!n.letto) {
      await NotificationService.markAsRead(n.id);
      if (!mounted) return;
      setState(() {
        _future = NotificationService.getNotifications();
      });
    }
  }

  void _navigateFor(NotificationModel n) {
    final relatedId = n.relatedId;
    // Deep-link verso un club specifico (posizione / nuova serata con id).
    if (relatedId != null &&
        relatedId.isNotEmpty &&
        (n.linkTipo == 'club' ||
            n.tipo == 'posizione_club' ||
            n.tipo == 'nuova_serata')) {
      NavigatorService.pushNamed(AppRoutes.clubDetailScreen,
          arguments: {'id': relatedId});
      return;
    }
    switch (n.tipo) {
      case 'prenotazione':
      case 'prevendita':
      case 'promemoria_evento':
        // Riepilogo ordini (prevendite/tavoli acquistati).
        NavigatorService.pushNamed(AppRoutes.ordersScreen);
        break;
      case 'sistema':
      case 'sicurezza':
        // Avvisi account (es. "Sicurezza Account") → schermata profilo.
        NavigatorService.pushNamed(AppRoutes.profileScreen);
        break;
      case 'consiglio':
      case 'nuova_serata':
        // Scoperta: porta in home a esplorare i locali.
        NavigatorService.pushNamed(AppRoutes.homeScreen);
        break;
      default:
        NavigatorService.pushNamed(AppRoutes.ordersScreen);
    }
  }

  // ── Raggruppamento per data (preserva l'ordine newest-first del service) ───
  List<_NotifSection> _groupByDate(List<NotificationModel> items) {
    final map = <String, _NotifSection>{};
    final order = <String>[];
    for (final n in items) {
      final d = n.createdAt;
      final key = '${d.year}-${d.month}-${d.day}';
      if (!map.containsKey(key)) {
        map[key] = _NotifSection(_dateLabel(d), []);
        order.add(key);
      }
      map[key]!.notifications.add(n);
    }
    return [for (final k in order) map[k]!];
  }

  String _dateLabel(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'Oggi';
    if (diff == 1) return 'Ieri';
    return _dateFormat.format(d);
  }
}

class _NotifSection {
  final String label;
  final List<NotificationModel> notifications;
  _NotifSection(this.label, this.notifications);
}
