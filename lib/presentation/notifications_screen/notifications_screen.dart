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
                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
                      itemCount: notifications.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 16),
                      itemBuilder: (context, index) =>
                          _buildNotificationCard(notifications[index]),
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

  // Layout minimal (Figma 16): label data + card gradiente con titolo grande.
  Widget _buildNotificationCard(NotificationModel n) {
    return GestureDetector(
      onTap: () {
        if (n.tipo == 'prenotazione' && n.relatedId != null) {
          NavigatorService.pushNamed(AppRoutes.ordersScreen);
        }
        if (!n.letto) {
          NotificationService.markAsRead(n.id);
          setState(() {
            _future = NotificationService.getNotifications();
          });
        }
      },
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_dateFormat.format(n.createdAt),
              style: OnlistTextStyles.title28Regular),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            height: 66,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            alignment: Alignment.centerLeft,
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
              overflow: TextOverflow.ellipsis,
              style: OnlistTextStyles.ticketLabel,
            ),
          ),
        ],
      ),
    );
  }
}
