import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_export.dart';
import '../../core/models/locale_model.dart';
import '../../core/models/serata_model.dart';
import '../../core/services/analytics_service.dart';
import '../../core/utils/analytics_mixin.dart';
import '../../widgets/custom_top_bar.dart';
import '../../widgets/shared_footer.dart';
import 'bloc/club_detail_bloc.dart';

class ClubDetailScreen extends StatefulWidget {
  const ClubDetailScreen({Key? key}) : super(key: key);

  static Widget builder(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    LocaleModel? locale;

    if (args is LocaleModel) {
      locale = args;
    } else if (args is Map<String, dynamic>) {
      locale = LocaleModel.fromMap(args);
    }

    if (locale == null) {
      WidgetsBinding.instance.addPostFrameCallback(
          (_) => Navigator.of(context, rootNavigator: true).maybePop());
      return const Scaffold(backgroundColor: Color(0xFF0D0D0D));
    }
    return BlocProvider<ClubDetailBloc>(
      create: (_) => ClubDetailBloc(ClubDetailState(locale: locale!))
        ..add(ClubDetailInitialEvent()),
      child: const ClubDetailScreen(),
    );
  }

  @override
  State<ClubDetailScreen> createState() => _ClubDetailScreenState();
}

class _ClubDetailScreenState extends State<ClubDetailScreen>
    with TickerProviderStateMixin, ScreenAnalytics {
  @override
  String get screenName => 'club_detail';

  // ── Staggered entrance animations ──────────────────────────────────────────
  late AnimationController _staggerCtrl;
  late Animation<double> _appBarFade;
  late Animation<Offset> _appBarSlide;
  late Animation<double> _heroFade;
  late Animation<double> _heroScale;
  late Animation<double> _titleFade;
  late Animation<Offset> _titleSlide;
  late Animation<double> _subtitleFade;
  late Animation<Offset> _subtitleSlide;
  late Animation<double> _infoFade;
  late Animation<Offset> _infoSlide;
  late Animation<double> _buttonFade;
  late Animation<double> _buttonScale;
  late Animation<double> _sectionsFade;
  late Animation<Offset> _sectionsSlide;
  late Animation<double> _navFade;
  late Animation<Offset> _navSlide;

  // ── Bookmark icon bounce ────────────────────────────────────────────────────
  late AnimationController _bookmarkCtrl;
  late Animation<double> _bookmarkScale;

  // ── Favorite badge slide-in/fade-out ───────────────────────────────────────
  late AnimationController _badgeCtrl;
  late Animation<Offset> _badgeSlide;
  late Animation<double> _badgeFade;

  @override
  void initState() {
    super.initState();

    // Analytics: log club visualizzato
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final locale = ModalRoute.of(context)?.settings.arguments as LocaleModel?;
      if (locale != null) {
        AnalyticsService.logClubViewed(clubId: locale.id, clubName: locale.nome);
      }
    });

    _staggerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    // AppBar 0–400ms
    _appBarFade = _tween(0, 0.28);
    _appBarSlide = _slideTween(Offset(0, -0.5), 0, 0.28);

    // Hero 100–600ms
    _heroFade = _tween(0.07, 0.43);
    _heroScale = Tween<double>(begin: 0.95, end: 1).animate(
      CurvedAnimation(
          parent: _staggerCtrl,
          curve: const Interval(0.07, 0.43, curve: Curves.easeOut)),
    );

    // Title 250–700ms
    _titleFade = _tween(0.18, 0.50);
    _titleSlide = _slideTween(Offset(0, 0.3), 0.18, 0.50);

    // Subtitle 350–800ms
    _subtitleFade = _tween(0.25, 0.57);
    _subtitleSlide = _slideTween(Offset(0, 0.3), 0.25, 0.57);

    // Info rows 420–850ms
    _infoFade = _tween(0.30, 0.61);
    _infoSlide = _slideTween(Offset(0, 0.3), 0.30, 0.61);

    // Button 450–900ms
    _buttonFade = _tween(0.32, 0.64);
    _buttonScale = Tween<double>(begin: 0.9, end: 1).animate(
      CurvedAnimation(
          parent: _staggerCtrl,
          curve: const Interval(0.32, 0.64, curve: Curves.easeOutBack)),
    );

    // Sections 600–1100ms
    _sectionsFade = _tween(0.43, 0.78);
    _sectionsSlide = _slideTween(Offset(0, 0.3), 0.43, 0.78);

    // Bottom nav 900–1400ms
    _navFade = _tween(0.64, 1.0);
    _navSlide = _slideTween(Offset(0, 1), 0.64, 1.0);

    _staggerCtrl.forward();

    // Bookmark bounce
    _bookmarkCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _bookmarkScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.35), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.35, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _bookmarkCtrl, curve: Curves.easeOut));

    // Badge slide + fade
    _badgeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _badgeSlide = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(
        CurvedAnimation(parent: _badgeCtrl, curve: Curves.easeOutBack));
    _badgeFade = CurvedAnimation(parent: _badgeCtrl, curve: Curves.easeOut);
  }

  Animation<double> _tween(double begin, double end) {
    return Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
          parent: _staggerCtrl,
          curve: Interval(begin, end, curve: Curves.easeOut)),
    );
  }

  Animation<Offset> _slideTween(Offset from, double begin, double end) {
    return Tween<Offset>(begin: from, end: Offset.zero).animate(
      CurvedAnimation(
          parent: _staggerCtrl,
          curve: Interval(begin, end, curve: Curves.easeOut)),
    );
  }

  @override
  void dispose() {
    _staggerCtrl.dispose();
    _bookmarkCtrl.dispose();
    _badgeCtrl.dispose();
    super.dispose();
  }

  // ── Badge visibility driven by BLoC state ──────────────────────────────────
  bool _lastBadge = false;

  void _syncBadgeAnimation(bool show) {
    if (show == _lastBadge) return;
    _lastBadge = show;
    if (show) {
      _badgeCtrl.forward(from: 0);
    } else {
      _badgeCtrl.reverse();
    }
  }

  // ── Open Google Maps ────────────────────────────────────────────────────────
  Future<void> _openMaps(String address) async {
    final encoded = Uri.encodeComponent(address);
    final uri = Uri.parse('https://maps.google.com/?q=$encoded');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: BlocConsumer<ClubDetailBloc, ClubDetailState>(
        listenWhen: (prev, curr) =>
            prev.showFavoriteBadge != curr.showFavoriteBadge,
        listener: (context, state) => _syncBadgeAnimation(state.showFavoriteBadge),
        buildWhen: (prev, curr) =>
            prev.locale != curr.locale ||
            prev.eventoOggi != curr.eventoOggi ||
            prev.serate != curr.serate ||
            prev.isLoading != curr.isLoading ||
            prev.isPreferito != curr.isPreferito ||
            prev.selectedBottomNavIndex != curr.selectedBottomNavIndex,
        builder: (context, state) {
          return SafeArea(
            child: Column(
              children: [
                // AppBar
                SlideTransition(
                  position: _appBarSlide,
                  child: FadeTransition(
                    opacity: _appBarFade,
                    child: const CustomTopBar(),
                  ),
                ),
                // Body
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Hero image + badge overlay
                        FadeTransition(
                          opacity: _heroFade,
                          child: ScaleTransition(
                            scale: _heroScale,
                            child: _buildHeroWithBadge(context, state),
                          ),
                        ),
                        // Club name
                        SlideTransition(
                          position: _titleSlide,
                          child: FadeTransition(
                            opacity: _titleFade,
                            child: _buildTitle(state.locale.nome),
                          ),
                        ),
                        // Address
                        SlideTransition(
                          position: _subtitleSlide,
                          child: FadeTransition(
                            opacity: _subtitleFade,
                            child: _buildSubtitle(state.locale.indirizzoCompleto),
                          ),
                        ),
                        // Info rows (time + price, genre)
                        SlideTransition(
                          position: _infoSlide,
                          child: FadeTransition(
                            opacity: _infoFade,
                            child: _buildInfoRows(state.locale, state.eventoOggi),
                          ),
                        ),
                        // CTA Button
                        FadeTransition(
                          opacity: _buttonFade,
                          child: ScaleTransition(
                            scale: _buttonScale,
                            child: _buildReserveButton(state.locale),
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Info sections
                        SlideTransition(
                          position: _sectionsSlide,
                          child: FadeTransition(
                            opacity: _sectionsFade,
                            child: _buildInfoSections(state.locale),
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Prossime serate
                        if (state.serate.isNotEmpty || !state.isLoading)
                          SlideTransition(
                            position: _sectionsSlide,
                            child: FadeTransition(
                              opacity: _sectionsFade,
                              child: _buildSerateSection(
                                  context, state.serate, state.locale),
                            ),
                          ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: const SharedFooter(currentIndex: 0),
    );
  }

  // ── AppBar ──────────────────────────────────────────────────────────────────
  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => NavigatorService.pushNamedAndRemoveUntil(
                AppRoutes.eventDetailScreen),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: Image.asset(
                ImageConstant.imgLogoOnlist,
                height: 60,
                width: 60,
                fit: BoxFit.cover,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Icon(Icons.search, color: Colors.white, size: 34),
          ),
        ],
      ),
    );
  }

  // ── Hero + badge ────────────────────────────────────────────────────────────
  Widget _buildHeroWithBadge(BuildContext context, ClubDetailState state) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Stack(
        children: [
          // Hero image
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: double.infinity,
              height: 217,
              color: const Color(0xFF1A1A2E),
              child: state.locale.fotoUrl != null
                  ? CachedNetworkImage(
                      imageUrl: state.locale.fotoUrl!,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) =>
                          const Icon(Icons.nightlife, color: Color(0xFF666666), size: 48),
                    )
                  : const Icon(Icons.nightlife, color: Color(0xFF666666), size: 48),
            ),
          ),
          // Bookmark icon (top-right)
          Positioned(
            top: 10,
            right: 10,
            child: _AnimatedPressButton(
              onPressed: () => context.read<ClubDetailBloc>().add(ToggleFavoriteEvent()),
              child: AnimatedBuilder(
                animation: _bookmarkScale,
                builder: (_, child) => Transform.scale(
                  scale: _bookmarkScale.value,
                  child: child,
                ),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    state.isPreferito ? Icons.bookmark : Icons.bookmark_border,
                    color: state.isPreferito
                        ? const Color(0xFF0009FF)
                        : Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),
          ),
          // "Club aggiunto ai preferiti" badge
          Positioned(
            top: 10,
            left: 0,
            right: 50,
            child: SlideTransition(
              position: _badgeSlide,
              child: FadeTransition(
                opacity: _badgeFade,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0009FF),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Club aggiunto ai preferiti',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Title ───────────────────────────────────────────────────────────────────
  Widget _buildTitle(String name) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(13, 25, 13, 0),
      child: Text(
        name,
        style: GoogleFonts.inter(
          fontSize: 36,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          letterSpacing: -0.08 * 36,
        ),
      ),
    );
  }

  // ── Subtitle (address) ──────────────────────────────────────────────────────
  Widget _buildSubtitle(String address) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(13, 14, 13, 0),
      child: Text(
        address,
        style: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: Colors.white.withValues(alpha: 0.6),
        ),
      ),
    );
  }

  // ── Info rows: time (dall'evento) + price, genre ───────────────────────────
  Widget _buildInfoRows(LocaleModel locale, SerataModel? evento) {
    final orario = evento?.orarioString ?? '';
    // generi: preferenza all'evento, fallback al locale
    final generi = (evento?.generiMusicali.isNotEmpty == true)
        ? evento!.generiMusicali.join(' - ')
        : locale.generiString;

    return Padding(
      padding: const EdgeInsets.fromLTRB(13, 12, 13, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: clock + orario evento + prezzo locale
          if (orario.isNotEmpty || locale.prezzoString.isNotEmpty)
            Row(
              children: [
                if (orario.isNotEmpty) ...[
                  Icon(Icons.access_time_rounded,
                      color: Colors.white.withValues(alpha: 0.7), size: 16),
                  const SizedBox(width: 6),
                  Text(
                    orario,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                ],
                if (locale.prezzoString.isNotEmpty) ...[
                  const SizedBox(width: 12),
                  Text(
                    locale.prezzoString,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ],
            ),
          // Row 2: music note + generi
          if (generi.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.music_note_rounded,
                    color: Colors.white.withValues(alpha: 0.7), size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    generi,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ── CTA button ──────────────────────────────────────────────────────────────
  Widget _buildReserveButton(LocaleModel locale) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(11, 15, 11, 0),
      child: SizedBox(
        width: double.infinity,
        height: 49,
        child: _AnimatedPressButton(
          onPressed: () => NavigatorService.pushNamed(
            '/booking_screen',
            arguments: locale,
          ),
          child: Container(
            width: double.infinity,
            height: 49,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0009FF), Color(0xFF000599)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                stops: [0.0, 0.8173],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Text(
              'RISERVA IL TUO POSTO ORA',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: -0.08 * 20,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Info sections: Come arrivare / Recensioni / Trasporti ──────────────────
  Widget _buildInfoSections(LocaleModel locale) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSection(
          title: 'Come arrivare',
          buttonLabel: 'Mappe',
          onButtonTap: () => _openMaps(locale.indirizzoCompleto),
        ),
        _buildDivider(),
        _buildSection(
          title: 'Recensioni',
          buttonLabel: 'TripAdvisor',
          onButtonTap: locale.linkTripadvisor != null
              ? () => _openUrl(locale.linkTripadvisor!)
              : null,
        ),
        _buildDivider(),
        _buildSection(
          title: 'Trasporti',
          buttonLabel: null,
          onButtonTap: null,
        ),
      ],
    );
  }

  Widget _buildSection({
    required String title,
    required String? buttonLabel,
    required VoidCallback? onButtonTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          if (buttonLabel != null) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: _AnimatedPressButton(
                onPressed: onButtonTap ?? () {},
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0009FF), Color(0xFF000599)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      stops: [0.0, 0.8173],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    buttonLabel,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Prossime serate ─────────────────────────────────────────────────────────
  Widget _buildSerateSection(
      BuildContext context, List<SerataModel> serate, LocaleModel locale) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(13, 0, 13, 14),
          child: Text(
            'Prossime serate',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
        if (serate.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13),
            child: Text(
              'Nessuna serata in programma',
              style: GoogleFonts.inter(fontSize: 14, color: Colors.white38),
            ),
          )
        else
          ...serate.map((s) => _SerataCard(
                serata: s,
                locale: locale,
              )),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 0.5,
      color: const Color(0xFF2A2A2A),
      margin: const EdgeInsets.symmetric(horizontal: 13),
    );
  }

  // ── Bottom navigation ───────────────────────────────────────────────────────
  Widget _buildBottomNav(BuildContext context, ClubDetailState state) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: Color(0xFF2A2A2A), width: 0.5),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 10),
      child: Row(
        children: [
          _buildNavItem(context, ImageConstant.imgHome, 0, state.selectedBottomNavIndex),
          _buildNavItem(context, ImageConstant.imgShoppingCart, 1, state.selectedBottomNavIndex),
          _buildNavItem(context, ImageConstant.imgBell, 2, state.selectedBottomNavIndex),
          _buildNavItem(context, ImageConstant.imgUser, 3, state.selectedBottomNavIndex),
        ],
      ),
    );
  }

  Widget _buildNavItem(
      BuildContext context, String imagePath, int index, int selected) {
    final isSelected = selected == index;
    return Expanded(
      child: GestureDetector(
        onTap: () =>
            context.read<ClubDetailBloc>().add(BottomNavItemSelectedEvent(index)),
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          height: 31,
          child: Center(
            child: AnimatedScale(
              scale: isSelected ? 1.2 : 1.0,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutBack,
              child: AnimatedOpacity(
                opacity: isSelected ? 1.0 : 0.5,
                duration: const Duration(milliseconds: 200),
                child: CustomImageView(
                  imagePath: imagePath,
                  height: 28,
                  width: 28,
                  color: isSelected ? Colors.white : const Color(0xFF888888),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Animated press button (shared) ────────────────────────────────────────────
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

// ── Serata card ────────────────────────────────────────────────────────────────
class _SerataCard extends StatelessWidget {
  final SerataModel serata;
  final LocaleModel locale;

  const _SerataCard({required this.serata, required this.locale});

  String _formatData(DateTime d) {
    const giorni = ['Lun', 'Mar', 'Mer', 'Gio', 'Ven', 'Sab', 'Dom'];
    const mesi = [
      'Gen', 'Feb', 'Mar', 'Apr', 'Mag', 'Giu',
      'Lug', 'Ago', 'Set', 'Ott', 'Nov', 'Dic'
    ];
    return '${giorni[d.weekday - 1]} ${d.day} ${mesi[d.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    final status = serata.statusPosti;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF2A2A2A), width: 0.5),
        ),
        child: Row(
          children: [
            // Locandina / fallback icon
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(10),
                bottomLeft: Radius.circular(10),
              ),
              child: SizedBox(
                width: 72,
                height: 88,
                child: serata.locandinaUrl != null
                    ? CachedNetworkImage(
                        imageUrl: serata.locandinaUrl!,
                        fit: BoxFit.cover,
                        memCacheWidth: 216,
                        memCacheHeight: 264,
                        errorWidget: (_, __, ___) => Container(
                          color: const Color(0xFF2A2A2A),
                          child: const Icon(Icons.event,
                              color: Color(0xFF555555), size: 28),
                        ),
                      )
                    : Container(
                        color: const Color(0xFF2A2A2A),
                        child: const Icon(Icons.event,
                            color: Color(0xFF555555), size: 28),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      serata.nome,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${_formatData(serata.data)}'
                      '${serata.orarioString.isNotEmpty ? '  •  ${serata.orarioString}' : ''}',
                      style: GoogleFonts.inter(
                          fontSize: 12, color: Colors.white54),
                    ),
                    if (serata.generiMusicali.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        serata.generiMusicali.join(' · '),
                        style: GoogleFonts.inter(
                            fontSize: 11,
                            color: const Color(0xFF6680FF)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (status != null) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: status == 'Sold Out'
                              ? Colors.red.withValues(alpha: 0.2)
                              : const Color(0xFFFF6B35)
                                  .withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          status,
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: status == 'Sold Out'
                                ? Colors.red
                                : const Color(0xFFFF6B35),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Prenota button + prezzo
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (serata.prezzoIngresso != null)
                    Text(
                      '€${serata.prezzoIngresso!.toStringAsFixed(0)}',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white70,
                      ),
                    ),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: status == 'Sold Out'
                        ? null
                        : () => NavigatorService.pushNamed(
                              AppRoutes.bookingScreen,
                              arguments: {
                                'locale': locale,
                                'serata': serata,
                              },
                            ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: status == 'Sold Out'
                            ? const Color(0xFF333333)
                            : const Color(0xFF0009FF),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        status == 'Sold Out' ? 'Esaurito' : 'Prenota',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: status == 'Sold Out'
                              ? Colors.white38
                              : Colors.white,
                        ),
                      ),
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
