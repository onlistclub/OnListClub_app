import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/app_export.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/services/club_service.dart';
import '../../core/models/locale_model.dart';
import '../../core/models/serata_model.dart';
import '../../core/utils/analytics_mixin.dart';
import '../../theme/onlist_colors.dart';
import '../../theme/onlist_text_styles.dart';
import '../../widgets/shared_footer.dart';
import '../../widgets/custom_top_bar.dart';
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

  void _navigateToEventDetailClub(
      BuildContext context, SerataModel serata, LocaleModel club) {
    NavigatorService.pushNamed(
      AppRoutes.eventDetailClubScreen,
      arguments: {'serata': serata, 'club': club},
    );
  }

  static final DateFormat _eventDateFormat = DateFormat('EEE d MMM', 'it_IT');

  String _formatDate(DateTime d) {
    final oggi = DateTime.now();
    if (d.year == oggi.year && d.month == oggi.month && d.day == oggi.day) {
      return 'Oggi';
    }
    final domani = oggi.add(const Duration(days: 1));
    if (d.year == domani.year && d.month == domani.month && d.day == domani.day) {
      return 'Domani';
    }
    return _eventDateFormat.format(d);
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: OnlistColors.screenBackground),
        child: BlocBuilder<HomeBloc, HomeState>(
        buildWhen: (prev, curr) =>
            prev.localeVicino != curr.localeVicino ||
            prev.upcomingEventi != curr.upcomingEventi ||
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
                        ? const Center(
                            child: CircularProgressIndicator(
                                color: Color(0xFF0009FF)))
                        : state.localeVicino == null
                            ? Center(
                                child: Text(
                                  'Nessun locale trovato.\nProva a cambiare raggio o cercare in un\'altra città.',
                                  textAlign: TextAlign.center,
                                  style: OnlistTextStyles.hn(
                                    fontSize: 16,
                                    color: Colors.white54,
                                  ),
                                ),
                              )
                            : RepaintBoundary(child: SingleChildScrollView(
                                padding: const EdgeInsets.only(bottom: 80),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Hero image
                                    FadeTransition(
                                      opacity: _heroFade,
                                      child: ScaleTransition(
                                        scale: _heroScale,
                                        child: _buildHeroImage(state),
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
                                    // CTA "RISERVA IL TUO POSTO ORA" → booking serata in evidenza
                                    if (state.upcomingEventi.isNotEmpty)
                                      SlideTransition(
                                        position: _subtitleSlide,
                                        child: FadeTransition(
                                          opacity: _subtitleFade,
                                          child: _buildReserveButton(context, state),
                                        ),
                                      ),
                                    // Events section
                                    if (state.upcomingEventi.isNotEmpty) ...[
                                      SlideTransition(
                                        position: _sectionSlide,
                                        child: FadeTransition(
                                          opacity: _sectionFade,
                                          child: _buildSectionTitle(state),
                                        ),
                                      ),
                                      SlideTransition(
                                        position: _cardsSlide,
                                        child: FadeTransition(
                                          opacity: _cardsFade,
                                          child: _buildEventCards(context, state),
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
                        fontSize: 12,
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
                        fontSize: 10,
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
                        fontSize: 10,
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

  Widget _buildHeroImage(HomeState state) {
    final fotoUrl = state.localeVicino?.fotoUrl;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 9),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: double.infinity,
              height: 217,
              color: const Color(0xFF1A1A2E),
              child: fotoUrl != null
                  ? CustomImageView(
                      imagePath: fotoUrl,
                      width: MediaQuery.of(context).size.width,
                      height: 217,
                      fit: BoxFit.cover,
                      placeHolder: ImageConstant.imgImageNotFound,
                    )
                  : const Icon(Icons.nightlife,
                      color: Color(0xFF666666), size: 48),
            ),
          ),
          // Pill "Il tuo club preferito" — solo se il club è nei preferiti
          if (state.localeVicino != null)
            Positioned(
              top: 12,
              left: 12,
              child: _FavoritePill(clubId: state.localeVicino!.id),
            ),
        ],
      ),
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
                fontSize: 36,
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

    String orario = '23:00 - 05:00';
    if (state.upcomingEventi.isNotEmpty) {
      final p = state.upcomingEventi.first;
      if (p.orarioString.isNotEmpty) {
        orario = p.orarioString;
      }
    }

    final priceStr = locale.prezzoString;
    final emptyPrice = '€' * (5 - locale.prezzoIndicativo).clamp(0, 5);

    final addr = [
      if (locale.nomeCitta != null && locale.nomeCitta!.isNotEmpty) locale.nomeCitta!,
      if (locale.indirizzo != null && locale.indirizzo!.isNotEmpty) locale.indirizzo!,
    ].join(' - ');

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 3, 14, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Indirizzo
          Opacity(
            opacity: 0.6,
            child: Text(
              addr,
              style: OnlistTextStyles.hn(
                fontSize: 16,
                color: Colors.white,
                fontWeight: FontWeight.w700,
                height: 18 / 16,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 11),
          
          // Orario e prezzo
          Row(
            children: [
              const Opacity(
                opacity: 0.6,
                child: Icon(Icons.access_time, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 6),
              Opacity(
                opacity: 0.6,
                child: Text(
                  orario,
                  style: OnlistTextStyles.hn(
                    fontSize: 16,
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    height: 18 / 16,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: priceStr,
                      style: OnlistTextStyles.hn(
                        fontSize: 16,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                        height: 22 / 16,
                      ),
                    ),
                    TextSpan(
                      text: emptyPrice,
                      style: OnlistTextStyles.hn(
                        fontSize: 16,
                        color: Colors.white.withValues(alpha: 0.3),
                        fontWeight: FontWeight.w500,
                        height: 22 / 16,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),

          // Generi musicali
          Row(
            children: [
              const Opacity(
                opacity: 0.6,
                child: Icon(Icons.music_note, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Opacity(
                  opacity: 0.6,
                  child: Text(
                    locale.generiString.isNotEmpty ? locale.generiString : 'Tutti i generi',
                    style: OnlistTextStyles.hn(
                      fontSize: 16,
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      height: 18 / 16,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Reserve CTA ──────────────────────────────────────────────────────────

  Widget _buildReserveButton(BuildContext context, HomeState state) {
    final serata = state.upcomingEventi.isNotEmpty
        ? state.upcomingEventi.first
        : null;
    final club = state.localeVicino;
    if (serata == null || club == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(11, 13, 11, 4),
      child: _AnimatedPressButton(
        onPressed: () => NavigatorService.pushNamed(
          AppRoutes.bookingScreen,
          arguments: {'serata': serata, 'club': club},
        ),
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
              fontSize: 20,
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

  // ── Section title ──────────────────────────────────────────────────────────

  Widget _buildSectionTitle(HomeState state) {
    if (state.upcomingEventi.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 9),
      child: Text(
        'Prossime serate',
        style: OnlistTextStyles.hn(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          height: 37 / 32,
          letterSpacing: -0.08 * 32,
        ),
      ),
    );
  }

  // ── Event cards ────────────────────────────────────────────────────────────

  Widget _buildEventCards(BuildContext context, HomeState state) {
    if (state.upcomingEventi.isEmpty) return const SizedBox.shrink();
    
    final club = state.localeVicino!;
    
    return Column(
      children: [
        for (int i = 0; i < state.upcomingEventi.length; i++)
          if (i == 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 7),
              child: _buildProminentEventCard(context, state.upcomingEventi[i], club),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 7),
              child: _buildEventCard(context, state.upcomingEventi[i], club),
            ),
      ],
    );
  }

  Widget _buildProminentEventCard(BuildContext context, SerataModel serata, LocaleModel club) {
    final now = DateTime.now();
    final isToday = serata.data.year == now.year && serata.data.month == now.month && serata.data.day == now.day;
    
    return _AnimatedPressButton(
      onPressed: () => _navigateToEventDetailClub(context, serata, club),
      child: Container(
        width: 369,
        height: 132,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF000000), Color(0xFF0004D4)],
            stops: [0.274, 0.7067],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Stack(
          children: [
            // Event image
            Positioned(
              left: 6,
              top: 6,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 95,
                  height: 119,
                  color: const Color(0xFF2A2A2A),
                  child: serata.locandinaUrl != null
                      ? CustomImageView(
                          imagePath: serata.locandinaUrl!,
                          width: 95,
                          height: 119,
                          fit: BoxFit.cover,
                          placeHolder: ImageConstant.imgImageNotFound,
                        )
                      : const Icon(Icons.music_note, color: Color(0xFF666666), size: 32),
                ),
              ),
            ),
            // Event info
            Positioned(
              left: 106,
              top: 6,
              child: Text(
                serata.nome.isNotEmpty ? serata.nome : 'Spring Party',
                style: OnlistTextStyles.hn(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  height: 23 / 20,
                  letterSpacing: -0.08 * 20,
                ),
              ),
            ),
            if (isToday)
              Positioned(
                left: 106,
                top: 39,
                child: Text(
                  'OGGI',
                  style: OnlistTextStyles.hn(
                    fontSize: 22.22,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    height: 26 / 22.22,
                    letterSpacing: -0.08 * 22.22,
                  ),
                ),
              ),
            Positioned(
              left: 110,
              top: 74,
              child: Text(
                _formatDate(serata.data),
                style: OnlistTextStyles.hn(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: Colors.white,
                  height: 12 / 12,
                ),
              ),
            ),
            Positioned(
              left: 110,
              top: 86.31,
              child: Text(
                serata.orarioString,
                style: OnlistTextStyles.hn(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: Colors.white,
                  height: 12 / 12,
                ),
              ),
            ),
            Positioned(
              left: 106,
              top: 109,
              child: Opacity(
                opacity: 0.5,
                child: Text(
                  serata.generiMusicali.isNotEmpty ? serata.generiMusicali.join(' - ') : club.generiString,
                  style: OnlistTextStyles.hn(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    height: 13 / 13,
                  ),
                ),
              ),
            ),
            // PRENOTA Button
            Positioned(
              left: 274,
              top: 47,
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
          ],
        ),
      ),
    );
  }

  Widget _buildEventCard(
      BuildContext context, SerataModel serata, LocaleModel club) {
    return _AnimatedPressButton(
      onPressed: () => _navigateToEventDetailClub(context, serata, club),
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
            // Event image
            Positioned(
              left: 15,
              top: 7, // 672 - 665
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 165,
                  height: 95,
                  color: const Color(0xFF2A2A2A),
                  child: serata.locandinaUrl != null
                      ? CachedNetworkImage(
                          imageUrl: serata.locandinaUrl!,
                          fit: BoxFit.cover,
                          memCacheWidth: 495,
                          memCacheHeight: 285,
                          errorWidget: (_, __, ___) => const Icon(
                            Icons.music_note,
                            color: Color(0xFF666666),
                            size: 32,
                          ),
                        )
                      : const Icon(Icons.music_note,
                          color: Color(0xFF666666), size: 32),
                ),
              ),
            ),
            // Event name
            Positioned(
              left: 189,
              top: 7,
              child: SizedBox(
                width: 159,
                child: Text(
                  serata.nome,
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
            // Date
            Positioned(
              left: 193,
              top: 49, // 714 - 665
              child: Text(
                _formatDate(serata.data),
                style: OnlistTextStyles.hn(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: Colors.white,
                  height: 12 / 12,
                ),
              ),
            ),
            // Hours
            Positioned(
              left: 193,
              top: 60, // 725 - 665
              child: Text(
                serata.orarioString,
                style: OnlistTextStyles.hn(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: Colors.white,
                  height: 12 / 12,
                ),
              ),
            ),
            // Location
            Positioned(
              left: 189,
              top: 90, // 755 - 665
              child: Opacity(
                opacity: 0.8,
                child: Text(
                  club.nomeCitta ?? 'Milano (MI)',
                  style: OnlistTextStyles.hn(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    height: 12 / 12,
                  ),
                ),
              ),
            ),
            // PRENOTA Button
            Positioned(
              left: 283, // 283
              top: 62,  // 727 - 665
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
          ],
        ),
      ),
    );
  }

}

// ── Animated press button ──────────────────────────────────────────────────────

class _AnimatedPressButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onPressed;

  const _AnimatedPressButton({
    required this.child,
    required this.onPressed,
  });

  @override
  State<_AnimatedPressButton> createState() => _AnimatedPressButtonState();
}

class _AnimatedPressButtonState extends State<_AnimatedPressButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 150),
  );
  late final Animation<double> _scale =
      Tween<double>(begin: 1.0, end: 0.95).animate(
    CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
  );

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onPressed();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(scale: _scale, child: widget.child),
    );
  }
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
          fontSize: 14,
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
