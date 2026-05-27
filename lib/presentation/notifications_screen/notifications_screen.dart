import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/app_export.dart';
import '../../core/services/notification_service.dart';
import '../../core/models/notification_model.dart';
import '../../core/utils/analytics_mixin.dart';
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

  @override
  void initState() {
    super.initState();
    _future = NotificationService.getNotifications();
    NotificationService.checkAndSendRecommendation(); // Controlla consiglio ogni volta che apre
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            const CustomTopBar(),
            _buildTopBar(),
            Expanded(
              child: FutureBuilder<List<NotificationModel>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const AppLoadingIndicator();
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Errore nel caricamento', style: GoogleFonts.inter(color: Colors.white54)));
                  }
                  final notifications = snapshot.data ?? [];
                  if (notifications.isEmpty) {
                    return _buildEmptyState();
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    itemCount: notifications.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final n = notifications[index];
                      return _buildNotificationCard(n);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const SharedFooter(currentIndex: 3),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          Text(
            'Notifiche',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.notifications_none, size: 80, color: Colors.white10),
          const SizedBox(height: 16),
          Text(
            'Nessuna notifica',
            style: GoogleFonts.inter(color: Colors.white54, fontSize: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(NotificationModel n) {
    IconData icon;
    Color iconColor;
    switch (n.tipo) {
      case 'prenotazione':
        icon = Icons.confirmation_number_outlined;
        iconColor = Colors.greenAccent;
        break;
      case 'consiglio':
        icon = Icons.star_outline;
        iconColor = Colors.amberAccent;
        break;
      case 'sistema':
        icon = Icons.security;
        iconColor = Colors.blueAccent;
        break;
      default:
        icon = Icons.notifications_outlined;
        iconColor = Colors.white70;
    }

    return GestureDetector(
      onTap: () {
        if (n.tipo == 'prenotazione' && n.relatedId != null) {
          NavigatorService.pushNamed(AppRoutes.ordersScreen); // O una pagina dettaglio specifica se esiste
        }
        if (!n.letto) {
          NotificationService.markAsRead(n.id);
          setState(() {
            _future = NotificationService.getNotifications();
          });
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: n.letto ? const Color(0xFF1A1A1A) : const Color(0xFF252525),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: n.letto ? Colors.transparent : const Color(0xFF1D00FF).withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        n.titolo,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (!n.letto)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFF1D00FF),
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    n.messaggio,
                    style: GoogleFonts.inter(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
