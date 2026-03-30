import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/models/locale_model.dart';
import '../../core/services/club_service.dart';
import '../../core/utils/navigator_service.dart';
import '../../core/utils/user_profile_manager.dart';
import '../../routes/app_routes.dart';

class NearbyClubsScreen extends StatefulWidget {
  const NearbyClubsScreen({Key? key}) : super(key: key);

  static Widget builder(BuildContext context) => const NearbyClubsScreen();

  @override
  State<NearbyClubsScreen> createState() => _NearbyClubsScreenState();
}

class _NearbyClubsScreenState extends State<NearbyClubsScreen> {
  late Future<_NearbyData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_NearbyData> _load() async {
    final raggio = await UserProfileManager().getRaggioKm();

    double? lat;
    double? lng;
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.low,
            timeLimit: Duration(seconds: 5),
          ),
        );
        lat = pos.latitude;
        lng = pos.longitude;
      }
    } catch (_) {}

    final clubs =
        await ClubService.getLocaliVicini(lat, lng, raggioKm: raggio.toDouble());
    return _NearbyData(clubs: clubs, raggio: raggio, lat: lat, lng: lng);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // AppBar
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: NavigatorService.goBack,
                    child: const Icon(Icons.arrow_back_ios_new,
                        color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  FutureBuilder<_NearbyData>(
                    future: _future,
                    builder: (_, snap) {
                      final raggio = snap.data?.raggio ?? 20;
                      return Text(
                        'Locali a raggio di: $raggio km',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            // Content
            Expanded(
              child: FutureBuilder<_NearbyData>(
                future: _future,
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const Center(
                      child: CircularProgressIndicator(
                          color: Color(0xFF0009FF)),
                    );
                  }
                  if (snap.hasError || snap.data == null) {
                    return Center(
                      child: Text(
                        'Errore nel caricamento',
                        style: GoogleFonts.inter(color: Colors.white54),
                      ),
                    );
                  }
                  final data = snap.data!;
                  if (data.clubs.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Nessun locale trovato nel raggio di ${data.raggio} km.',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            color: Colors.white54,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 13, vertical: 8),
                    itemCount: data.clubs.length,
                    separatorBuilder: (_, __) => Container(
                      height: 0.5,
                      color: const Color(0xFF2A2A2A),
                      margin: const EdgeInsets.symmetric(vertical: 4),
                    ),
                    itemBuilder: (context, i) {
                      final club = data.clubs[i];
                      return _ClubListTile(
                        club: club,
                        userLat: data.lat,
                        userLng: data.lng,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Club list tile ─────────────────────────────────────────────────────────────

class _ClubListTile extends StatelessWidget {
  final LocaleModel club;
  final double? userLat;
  final double? userLng;

  const _ClubListTile({
    required this.club,
    required this.userLat,
    required this.userLng,
  });

  String? _distanceLabel() {
    if (userLat == null || userLng == null || club.lat == null || club.lng == null) {
      return null;
    }
    final dist = ClubService.distanceKm(userLat!, userLng!, club.lat!, club.lng!);
    return dist < 1
        ? '${(dist * 1000).round()} m'
        : '${dist.toStringAsFixed(1)} km';
  }

  @override
  Widget build(BuildContext context) {
    final distLabel = _distanceLabel();
    return GestureDetector(
      onTap: () => NavigatorService.pushNamed(
        AppRoutes.clubDetailScreen,
        arguments: club,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            // Club image
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 60,
                height: 60,
                color: const Color(0xFF2A2A2A),
                child: club.fotoUrl != null
                    ? Image.network(
                        club.fotoUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(
                            Icons.nightlife,
                            color: Color(0xFF666666)),
                      )
                    : const Icon(Icons.nightlife, color: Color(0xFF666666)),
              ),
            ),
            const SizedBox(width: 14),
            // Club info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    club.nome,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  if (club.indirizzoCompleto.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      club.indirizzoCompleto,
                      style: GoogleFonts.inter(
                          fontSize: 12, color: Colors.white54),
                    ),
                  ],
                  if (club.generiString.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      club.generiString,
                      style: GoogleFonts.inter(
                          fontSize: 11, color: const Color(0xFF6680FF)),
                    ),
                  ],
                ],
              ),
            ),
            // Distance badge
            if (distLabel != null) ...[
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                      color: const Color(0xFF333333), width: 0.5),
                ),
                child: Text(
                  distLabel,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white70,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NearbyData {
  final List<LocaleModel> clubs;
  final int raggio;
  final double? lat;
  final double? lng;

  _NearbyData(
      {required this.clubs,
      required this.raggio,
      required this.lat,
      required this.lng});
}
