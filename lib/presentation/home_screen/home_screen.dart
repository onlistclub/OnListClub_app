import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/app_export.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/services/club_service.dart';
import '../../core/models/locale_model.dart';
import '../../core/utils/analytics_mixin.dart';
import '../../theme/onlist_colors.dart';
import '../../theme/onlist_text_styles.dart';
import '../../widgets/shared_footer.dart';
import '../../widgets/custom_top_bar.dart';
import '../../widgets/shimmer_loading.dart';
import '../../widgets/animated_press.dart';
import '../../widgets/image_fallback.dart';
import '../../core/services/notification_service.dart';
import 'bloc/home_bloc.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  static Widget builder(BuildContext context) {
    return BlocProvider<HomeBloc>(
      create: (_) => HomeBloc(const HomeState())..add(HomeInitialEvent()),
      child: const HomeScreen(),
    );
  }

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin, ScreenAnalytics {
  @override
  String get screenName => 'home';

  late AnimationController _staggerCtrl;

  late Animation<double> _appBarFade;
  late Animation<Offset> _appBarSlide;
  late Animation<double> _heroFade;
  late Animation<double> _heroScale;
  late Animation<double> _titleFade;
  late Animation<Offset> _titleSlide;
  late Animation<double> _subtitleFade;
  late Animation<Offset> _subtitleSlide;
  late Animation<double> _sectionFade;
  late Animation<Offset> _sectionSlide;
  late Animation<double> _cardsFade;
  late Animation<Offset> _cardsSlide;
  late Animation<double> _navFade;
  late Animation<Offset> _navSlide;

  @override
  void initState() {
    super.initState();
    _staggerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _appBarFade   = _fade(0.00, 0.25);
    _appBarSlide  = _slide(const Offset(0, -0.5), 0.00, 0.25);
    _heroFade     = _fade(0.07, 0.43);
    _heroScale    = Tween<double>(begin: 0.95, end: 1).animate(
      CurvedAnimation(parent: _staggerCtrl,
          curve: const Interval(0.07, 0.43, curve: Curves.easeOut)));
    _titleFade    = _fade(0.18, 0.50);
    _titleSlide   = _slide(const Offset(0, 0.3), 0.18, 0.50);
    _subtitleFade = _fade(0.25, 0.57);
    _subtitleSlide= _slide(const Offset(0, 0.3), 0.25, 0.57);
    _sectionFade  = _fade(0.43, 0.72);
    _sectionSlide = _slide(const Offset(0, 0.3), 0.43, 0.72);
    _cardsFade    = _fade(0.54, 0.86);
    _cardsSlide   = _slide(const Offset(0.15, 0), 0.54, 0.86);
    _navFade      = _fade(0.64, 1.00);
    _navSlide     = _slide(const Offset(0, 1), 0.64, 1.00);

    _staggerCtrl.forward();

    // Notifiche: controlla nuovi eventi dei preferiti
    NotificationService.checkNewEventsForFavorites();
  }

  Animation<double> _fade(double begin, double end) =>
      Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(
            parent: _staggerCtrl,
            curve: Interval(begin, end, curve: Curves.easeOut)),
      );

  Animation<Offset> _slide(Offset from, double begin, double end) =>
      Tween<Offset>(begin: from, end: Offset.zero).animate(
        CurvedAnimation(
            parent: _staggerCtrl,
            curve: Interval(begin, end, curve: Curves.easeOut)),
      );

  @override
  void dispose() {
    _staggerCtrl.dispose();
    super.dispose();
  }

  // ── Navigation helpers ─────────────────────────────────────────────────────

  /// Naviga al dettaglio club (schermata 10). Usato da:
  /// - tap sulla card hero "Il tuo club preferito"
  /// - tap su "RISERVA IL TUO POSTO ORA"
  /// - tap su una card della lista "Club consigliati"
  void _navigateToClubDetail(BuildContext context, LocaleModel club) {
    NavigatorService.pushNamed(
      AppRoutes.clubDetailScreen,
      arguments: club,
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      // Footer flottante: il contenuto scorre dietro la capsula (non la oscura).
      extendBody: true,
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: OnlistColors.screenBackground),
        child: BlocBuilder<HomeBloc, HomeState>(
        buildWhen: (prev, curr) =>
            prev.localeVicino != curr.localeVicino ||
            prev.upcomingEventi != curr.upcomingEventi ||
            prev.recommendedClubs != curr.recommendedClubs ||
            prev.isLoading != curr.isLoading ||
            prev.isGpsForced != curr.isGpsForced ||
            prev.locationSourceLabel != curr.locationSourceLabel ||
            prev.selectedBottomNavIndex != curr.selectedBottomNavIndex,
        builder: (context, state) {
          return SafeArea(
            bottom: false,
            child: Column(
                children: [
                  // AppBar — fixed at top
                  SlideTransition(
                    position: _appBarSlide,
                    child: FadeTransition(
                      opacity: _appBarFade,
                      child: const CustomTopBar(isHome: true),
                    ),
                  ),
                  // Location info & GPS toggle
                  SlideTransition(
                    position: _appBarSlide,
                    child: FadeTransition(
                      opacity: _appBarFade,
                      child: _buildLocationInfo(context, state),
                    ),
                  ),
                  // Scrollable content
                  Expanded(
                    child: state.isLoading
                        ? const _HomeSkeleton()
                        : state.localeVicino == null
                            ? Center(
                                child: Text(
                                  'Nessun locale trovato.\nProva a cambiare raggio o cercare in un\'altra città.',
                                  textAlign: TextAlign.center,
                                  style: OnlistTextStyles.hn(
                                    fontSize: R.sp(16),
                                    color: Colors.white54,
                                  ),
                                ),
                              )
                            : RepaintBoundary(child: SingleChildScrollView(
                                padding: const EdgeInsets.only(bottom: 80),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Hero image (tap → schermata 10 club detail)
                                    FadeTransition(
                                      opacity: _heroFade,
                                      child: ScaleTransition(
                                        scale: _heroScale,
                                        child: _buildHeroImage(context, state),
                                      ),
                                    ),
                                    // Club name
                                    SlideTransition(
                                      position: _titleSlide,
                                      child: FadeTransition(
                                        opacity: _titleFade,
                                        child: _buildClubName(state),
                                      ),
                                    ),
                                    // Club details
                                    SlideTransition(
                                      position: _subtitleSlide,
                                      child: FadeTransition(
                                        opacity: _subtitleFade,
                                        child: _buildClubDetails(state),
                                      ),
                                    ),
                                    // CTA "RISERVA IL TUO POSTO ORA" → schermata 10 (club detail)
                                    SlideTransition(
                                      position: _subtitleSlide,
                                      child: FadeTransition(
                                        opacity: _subtitleFade,
                                        child: _buildReserveButton(context, state),
                                      ),
                                    ),
                                    // Club consigliati (altri club vicini)
                                    if (state.recommendedClubs.isNotEmpty) ...[
                                      SlideTransition(
                                        position: _sectionSlide,
                                        child: FadeTransition(
                                          opacity: _sectionFade,
                                          child: _buildSectionTitle(),
                                        ),
                                      ),
                                      SlideTransition(
                                        position: _cardsSlide,
                                        child: FadeTransition(
                                          opacity: _cardsFade,
                                          child: _buildRecommendedCards(context, state),
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 24),
                                  ],
                                ),
                                ),
                              ),
                  ),
                ],
              ),
            );
        },
        ),
      ),
      bottomNavigationBar: SlideTransition(
        position: _navSlide,
        child: FadeTransition(
          opacity: _navFade,
          child: const SharedFooter(currentIndex: 0),
        ),
      ),
    );
  }

  // ── Location Info ────────────────────────────────────────────────────────
  
  Widget _buildLocationInfo(BuildContext context, HomeState state) {
    if (state.localeVicino == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Sinistra: icona posizione + label + chip raggio
          Expanded(
            child: Row(
              children: [
                if (state.locationSourceLabel.isNotEmpty) ...[
                  Flexible(
                    child: Text(
                      state.locationSourceLabel,
                      style: OnlistTextStyles.hn(
                        fontSize: R.sp(12),
                        color: Colors.white70,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Destra: GPS toggle
          if (!state.isGpsForced)
            GestureDetector(
              onTap: () {
                context.read<HomeBloc>().add(const HomeForceGpsEvent(true));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Ricerca tramite GPS attivata')),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A2A),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF444444)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.my_location, color: Colors.white, size: 12),
                    const SizedBox(width: 4),
                    Text(
                      'Usa GPS',
                      style: OnlistTextStyles.hn(
                        fontSize: R.sp(10),
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (state.isGpsForced)
            GestureDetector(
              onTap: () {
                context.read<HomeBloc>().add(const HomeForceGpsEvent(false));
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF0009FF).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF0009FF)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.close, color: Colors.white, size: 12),
                    const SizedBox(width: 4),
                    Text(
                      'Rimuovi GPS',
                      style: OnlistTextStyles.hn(
                        fontSize: R.sp(10),
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Hero image ─────────────────────────────────────────────────────────────
  // Tap → schermata 10 (club detail).

  Widget _buildHeroImage(BuildContext context, HomeState state) {
    final club = state.localeVicino;
    final fotoUrl = club?.fotoUrl;
    final hero = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 9),
      child: Stack(
        children: [
          // Morph Hero verso il dettaglio club (tag = club id, solo con foto).
          _heroWrap(
            tag: 'club-img-${club?.id ?? ''}',
            enabled: club != null && fotoUrl != null,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: double.infinity,
                height: 217,
                color: const Color(0xFF1A1A2E),
                child: fotoUrl != null
                    ? CachedNetworkImage(
                        imageUrl: fotoUrl,
                        width: MediaQuery.of(context).size.width,
                        height: 217,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => const ImageFallback(),
                      )
                    : const ImageFallback(),
              ),
            ),
          ),
          // Pill "Il tuo club preferito" — solo se il club è nei preferiti
          if (club != null)
            Positioned(
              top: 12,
              left: 12,
              child: _FavoritePill(clubId: club.id),
            ),
        ],
      ),
    );
    if (club == null) return hero;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _navigateToClubDetail(context, club),
      child: hero,
    );
  }

  // ── Club name ──────────────────────────────────────────────────────────────

  Widget _buildClubName(HomeState state) {
    return Padding(
      padding: const EdgeInsets.only(left: 14, top: 11, right: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              state.localeVicino?.nome ?? '',
              style: OnlistTextStyles.hn(
                fontSize: R.sp(36),
                fontWeight: FontWeight.w700,
                color: Colors.white,
                height: 41 / 36,
                letterSpacing: -0.08 * 36,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (state.localeVicino != null)
            Padding(
              padding: const EdgeInsets.only(left: 8.0),
              child: _AnimatedBookmark(clubId: state.localeVicino!.id),
            ),
        ],
      ),
    );
  }

  // ── Club details ───────────────────────────────────────────────────────────

  Widget _buildClubDetails(HomeState state) {
    final locale = state.localeVicino;
    if (locale == null) return const SizedBox.shrink();

    final addr = [
      if (locale.nomeCitta != null && locale.nomeCitta!.isNotEmpty) locale.nomeCitta!,
      if (locale.indirizzo != null && locale.indirizzo!.isNotEmpty) locale.indirizzo!,
    ].join(' - ');

    // Figma 07-aggiornato: sotto l'hero c'è solo l'indirizzo (Helvetica Neue 500 24px).
    // Le righe orario/prezzo/generi sono state rimosse per aderire al layout Figma.
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 3, 14, 0),
      child: Text(
        addr,
        style: OnlistTextStyles.hn(
          fontSize: R.sp(24),
          color: Colors.white,
          fontWeight: FontWeight.w500,
          height: 24 / 24,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  // ── Reserve CTA → schermata 10 (club detail) ────────────────────────────

  Widget _buildReserveButton(BuildContext context, HomeState state) {
    final club = state.localeVicino;
    if (club == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(11, 13, 11, 4),
      child: AnimatedPress(
        onPressed: () => _navigateToClubDetail(context, club),
        child: Container(
          width: double.infinity,
          height: 49,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [Color(0x33989898), Color(0x331E00FF)],
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(
            'RISERVA IL TUO POSTO ORA',
            style: OnlistTextStyles.hn(
              fontSize: R.sp(20),
              fontWeight: FontWeight.w700,
              color: OnlistColors.white,
              height: 23 / 20,
              letterSpacing: -0.08 * 20,
            ),
          ),
        ),
      ),
    );
  }

  // ── Section title "Club consigliati" ───────────────────────────────────────

  Widget _buildSectionTitle() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 9),
      child: Text(
        'Club consigliati',
        style: OnlistTextStyles.hn(
          fontSize: R.sp(32),
          fontWeight: FontWeight.w700,
          color: Colors.white,
          height: 37 / 32,
          letterSpacing: -0.08 * 32,
        ),
      ),
    );
  }

  // ── Club consigliati: lista altri locali vicini ──────────────────────────

  Widget _buildRecommendedCards(BuildContext context, HomeState state) {
    if (state.recommendedClubs.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        for (final club in state.recommendedClubs)
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 7),
            child: _scaleToWidth(
              designW: 369,
              designH: 108,
              child: _buildRecommendedClubCard(context, club),
            ),
          ),
      ],
    );
  }

  Widget _buildRecommendedClubCard(BuildContext context, LocaleModel club) {
    // Riusa il layout della card Figma "Club consigliati" (07-aggiornato):
    // immagine sinistra, nome + generi + città a destra, bottone PRENOTA.
    return AnimatedPress(
      onPressed: () => _navigateToClubDetail(context, club),
      child: Container(
        width: 369,
        height: 108,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF000000), Color(0xFF0009FF)],
            stops: [0.2067, 0.8173],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Stack(
          children: [
            // Foto del club
            Positioned(
              left: 15,
              top: 7,
              child: _heroWrap(
                tag: 'club-img-${club.id}',
                enabled: club.fotoUrl != null,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 165,
                    height: 95,
                    color: const Color(0xFF2A2A2A),
                    child: club.fotoUrl != null
                        ? CachedNetworkImage(
                            imageUrl: club.fotoUrl!,
                            fit: BoxFit.cover,
                            memCacheWidth: 495,
                            memCacheHeight: 285,
                            errorWidget: (_, __, ___) => const ImageFallback(),
                          )
                        : const ImageFallback(),
                  ),
                ),
              ),
            ),
            // Nome del club
            Positioned(
              left: 189,
              top: 7,
              child: SizedBox(
                width: 159,
                child: Text(
                  club.nome,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: OnlistTextStyles.hn(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    height: 37 / 32,
                    letterSpacing: -0.08 * 32,
                  ),
                ),
              ),
            ),
            // Generi musicali
            if (club.generiString.isNotEmpty)
              Positioned(
                left: 193,
                top: 54,
                child: SizedBox(
                  width: 159,
                  child: Text(
                    club.generiString,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: OnlistTextStyles.hn(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: Colors.white,
                      height: 12 / 12,
                    ),
                  ),
                ),
              ),
            // Città
            Positioned(
              left: 189,
              top: 90,
              child: Opacity(
                opacity: 0.8,
                child: Text(
                  club.nomeCitta ?? '',
                  style: OnlistTextStyles.hn(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    height: 12 / 12,
                  ),
                ),
              ),
            ),
            // PRENOTA → schermata 10 (club detail)
            Positioned(
              left: 283,
              top: 62,
              child: GestureDetector(
                onTap: () => _navigateToClubDetail(context, club),
                child: Container(
                  width: 86,
                  height: 38,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1500B3), Color(0xFF201064)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(6.48),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        offset: const Offset(0, 4),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'PRENOTA',
                    style: OnlistTextStyles.hn(
                      fontSize: 15.55,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 18 / 15.55,
                      letterSpacing: -0.1 * 15.55,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

}

// ── Hero wrap ────────────────────────────────────────────────────────────────
/// Avvolge [child] in un `Hero` solo se [enabled] (es. esiste una foto reale),
/// così l'immagine si "espande" verso il dettaglio club senza far volare un
/// placeholder quando il locale non ha foto.
Widget _heroWrap({
  required String tag,
  required bool enabled,
  required Widget child,
}) =>
    enabled ? Hero(tag: tag, child: child) : child;

// ── Skeleton di caricamento ──────────────────────────────────────────────────
// Scheletro che ricalca il layout della home (hero + titolo + dettagli + CTA +
// card consigliate) mentre i dati arrivano da Supabase. Un solo controller via
// `Shimmer`. Non scrolla: è uno stato transitorio.
class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton();

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: const SingleChildScrollView(
        physics: NeverScrollableScrollPhysics(),
        padding: EdgeInsets.only(bottom: 80),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 9),
              child: ShimmerBox(width: double.infinity, height: 217),
            ),
            SizedBox(height: 14),
            // Nome club
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 14),
              child: ShimmerBox(width: 220, height: 34, radius: 8),
            ),
            SizedBox(height: 12),
            // Righe info
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 14),
              child: ShimmerBox(width: 180, height: 14, radius: 6),
            ),
            SizedBox(height: 10),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 14),
              child: ShimmerBox(width: 140, height: 14, radius: 6),
            ),
            SizedBox(height: 16),
            // CTA
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 11),
              child: ShimmerBox(width: double.infinity, height: 49),
            ),
            SizedBox(height: 20),
            // Titolo sezione
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: ShimmerBox(width: 200, height: 30, radius: 8),
            ),
            SizedBox(height: 14),
            // Card consigliate
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: ShimmerBox(width: double.infinity, height: 108),
            ),
            SizedBox(height: 8),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: ShimmerBox(width: double.infinity, height: 108),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Scala-a-larghezza ────────────────────────────────────────────────────────
// Scala un contenuto progettato a dimensione fissa (designW×designH) per
// riempire la larghezza disponibile mantenendo le proporzioni esatte del Figma.
// Su telefoni stretti rimpicciolisce per non sforare; su schermi larghi (tablet)
// il fattore è limitato a 1.15× e la card resta centrata con margini.
Widget _scaleToWidth({
  required double designW,
  required double designH,
  required Widget child,
}) {
  return LayoutBuilder(
    builder: (context, constraints) {
      final ratio = constraints.maxWidth / designW;
      final scale = ratio < 1.15 ? ratio : 1.15;
      return Center(
        child: SizedBox(
          width: designW * scale,
          height: designH * scale,
          child: FittedBox(
            fit: BoxFit.fill,
            child: SizedBox(width: designW, height: designH, child: child),
          ),
        ),
      );
    },
  );
}

// ── Favorite pill ───────────────────────────────────────────────────────────
// Mostra "Il tuo club preferito" solo se il club è effettivamente nei preferiti.

class _FavoritePill extends StatefulWidget {
  final String clubId;
  const _FavoritePill({required this.clubId});

  @override
  State<_FavoritePill> createState() => _FavoritePillState();
}

class _FavoritePillState extends State<_FavoritePill> {
  bool _isPreferito = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  @override
  void didUpdateWidget(covariant _FavoritePill oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.clubId != widget.clubId) _check();
  }

  Future<void> _check() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    final saved = await ClubService.isPreferito(user.id, widget.clubId);
    if (mounted) setState(() => _isPreferito = saved);
  }

  @override
  Widget build(BuildContext context) {
    if (!_isPreferito) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0x33000000), Color(0x330013FF)],
        ),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        'Il tuo club preferito',
        style: OnlistTextStyles.hn(
          fontSize: R.sp(14),
          fontWeight: FontWeight.w700,
          color: OnlistColors.white,
        ),
      ),
    );
  }
}

// ── Animated Bookmark ───────────────────────────────────────────────────────

class _AnimatedBookmark extends StatefulWidget {
  final String clubId;
  const _AnimatedBookmark({Key? key, required this.clubId}) : super(key: key);
  @override
  _AnimatedBookmarkState createState() => _AnimatedBookmarkState();
}

class _AnimatedBookmarkState extends State<_AnimatedBookmark> with SingleTickerProviderStateMixin {
  bool isSaved = false;
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.4), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.4, end: 1.0), weight: 50),
    ]).animate(_ctrl);
    
    _checkPreferito();
  }

  Future<void> _checkPreferito() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    final saved = await ClubService.isPreferito(user.id, widget.clubId);
    if (mounted) {
      setState(() => isSaved = saved);
    }
  }

  Future<void> _togglePreferito() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final newState = !isSaved;
    setState(() => isSaved = newState);
    _ctrl.forward(from: 0.0);

    try {
      if (newState) {
        await ClubService.addPreferito(user.id, widget.clubId);
      } else {
        await ClubService.removePreferito(user.id, widget.clubId);
      }
    } catch (_) {
      // Revert in caso di errore
      if (mounted) {
        setState(() => isSaved = !newState);
      }
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _togglePreferito,
      child: AnimatedBuilder(
        animation: _scale,
        builder: (context, child) {
          return Transform.scale(
            scale: _scale.value,
            child: Icon(
              isSaved ? Icons.bookmark : Icons.bookmark_border,
              color: Colors.white,
              size: 48,
            ),
          );
        },
      ),
    );
  }
}
