import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_export.dart';
import '../../core/models/locale_model.dart';
import '../../core/models/serata_model.dart';
import '../../core/services/analytics_service.dart';
import '../../core/utils/analytics_mixin.dart';
import '../../theme/onlist_colors.dart';
import '../../theme/onlist_text_styles.dart';
import '../../widgets/custom_top_bar.dart';
import '../../widgets/animated_press.dart';
import '../../widgets/reservation_choice_sheet.dart';
import '../../widgets/shared_footer.dart';
import '../../widgets/image_fallback.dart';
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
  late Animation<double> _sectionsFade;
  late Animation<Offset> _sectionsSlide;

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

    // Sections 600–1100ms
    _sectionsFade = _tween(0.43, 0.78);
    _sectionsSlide = _slideTween(Offset(0, 0.3), 0.43, 0.78);

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

  // ── Build ───────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: OnlistColors.screenBackground),
        child: BlocConsumer<ClubDetailBloc, ClubDetailState>(
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
                // Torna indietro
                SlideTransition(
                  position: _appBarSlide,
                  child: FadeTransition(
                    opacity: _appBarFade,
                    child: _buildBackRow(),
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
                        // Title row: nome club + bookmark a destra (Figma 10).
                        SlideTransition(
                          position: _titleSlide,
                          child: FadeTransition(
                            opacity: _titleFade,
                            child: _buildTitleRow(context, state),
                          ),
                        ),
                        // Indirizzo (tappable → apre Google Maps)
                        SlideTransition(
                          position: _subtitleSlide,
                          child: FadeTransition(
                            opacity: _subtitleFade,
                            child: _buildSubtitle(state.locale),
                          ),
                        ),
                        // Info rows: orario evento + generi musicali (no prezzo)
                        SlideTransition(
                          position: _infoSlide,
                          child: FadeTransition(
                            opacity: _infoFade,
                            child: _buildInfoRows(state.locale, state.eventoOggi),
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Prossime serate (la PRENOTA serata apre choice T/P
                        // tramite ReservationChoiceSheet — niente CTA globale)
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
      ),
      bottomNavigationBar: const SharedFooter(currentIndex: 0),
    );
  }

  // ── Torna indietro ───────────────────────────────────────────────────────
  Widget _buildBackRow() {
    return GestureDetector(
      onTap: () => NavigatorService.goBack(),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
        child: Row(
          children: [
            const Icon(Icons.arrow_back, color: OnlistColors.white, size: 28),
            const SizedBox(width: 6),
            Text('Torna indietro', style: OnlistTextStyles.title32Light),
          ],
        ),
      ),
    );
  }

  // ── Hero + badge ────────────────────────────────────────────────────────────
  Widget _buildHeroWithBadge(BuildContext context, ClubDetailState state) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Stack(
        children: [
          // Hero image: morph condiviso dalla lista/home (tag = club id).
          Hero(
            tag: 'club-img-${state.locale.id}',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: double.infinity,
                height: 217,
                color: const Color(0xFF1A1A2E),
                child: state.locale.fotoUrl != null
                    ? CachedNetworkImage(
                        imageUrl: state.locale.fotoUrl!,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => const ImageFallback(),
                      )
                    : const ImageFallback(),
              ),
            ),
          ),
          // Bookmark spostato nel title row (Figma 10).
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
                      style: OnlistTextStyles.hn(
                        fontSize: R.sp(13),
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

  // ── Title row: nome club + bookmark a destra (Figma 10) ─────────────────────
  Widget _buildTitleRow(BuildContext context, ClubDetailState state) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(13, 25, 13, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              state.locale.nome,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: OnlistTextStyles.hn(
                fontSize: R.sp(36),
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: -0.08 * 36,
              ),
            ),
          ),
          const SizedBox(width: 8),
          AnimatedPress(
            onPressed: () =>
                context.read<ClubDetailBloc>().add(ToggleFavoriteEvent()),
            child: AnimatedBuilder(
              animation: _bookmarkScale,
              builder: (_, child) => Transform.scale(
                scale: _bookmarkScale.value,
                child: child,
              ),
              child: Icon(
                state.isPreferito ? Icons.bookmark : Icons.bookmark_border,
                color: Colors.white,
                size: R.sp(32),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Subtitle (indirizzo) — tap → Google Maps ────────────────────────────────
  Widget _buildSubtitle(LocaleModel locale) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(13, 14, 13, 0),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _openMaps(locale.indirizzoCompleto),
        child: Text(
          locale.indirizzoCompleto,
          style: OnlistTextStyles.hn(
            fontSize: R.sp(16),
            fontWeight: FontWeight.w400,
            color: Colors.white.withValues(alpha: 0.6),
          ),
        ),
      ),
    );
  }

  // ── Info rows: orario evento + generi musicali (Figma 10 — niente prezzo) ──
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
          if (orario.isNotEmpty)
            Row(
              children: [
                Icon(Icons.access_time_rounded,
                    color: Colors.white.withValues(alpha: 0.7), size: 16),
                const SizedBox(width: 6),
                Text(
                  orario,
                  style: OnlistTextStyles.hn(
                    fontSize: R.sp(14),
                    fontWeight: FontWeight.w400,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
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
                    style: OnlistTextStyles.hn(
                      fontSize: R.sp(14),
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
            style: OnlistTextStyles.hn(
              fontSize: R.sp(20),
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
              style: OnlistTextStyles.hn(fontSize: R.sp(14), color: Colors.white38),
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

}

// ── Serata card (Figma 10-aggiornato) ──────────────────────────────────────────
// Card con gradiente blu cardSummary: locandina a sinistra, titolo + "OGGI"
// (se evento di oggi) + data + orario + generi a destra, bottone PRENOTA.
class _SerataCard extends StatelessWidget {
  final SerataModel serata;
  final LocaleModel locale;

  const _SerataCard({required this.serata, required this.locale});

  static const _giorniLunghi = [
    'Lunedì', 'Martedì', 'Mercoledì', 'Giovedì', 'Venerdì', 'Sabato', 'Domenica'
  ];
  static const _mesiLunghi = [
    'Gennaio', 'Febbraio', 'Marzo', 'Aprile', 'Maggio', 'Giugno',
    'Luglio', 'Agosto', 'Settembre', 'Ottobre', 'Novembre', 'Dicembre'
  ];

  String _formatData(DateTime d) =>
      '${_giorniLunghi[d.weekday - 1]} ${d.day} ${_mesiLunghi[d.month - 1]}';

  bool get _isToday {
    final now = DateTime.now();
    return serata.data.year == now.year &&
        serata.data.month == now.month &&
        serata.data.day == now.day;
  }

  @override
  Widget build(BuildContext context) {
    final status = serata.statusPosti;
    final isSoldOut = status == 'Sold Out';
    final generi = serata.generiMusicali.isNotEmpty
        ? serata.generiMusicali.join(' - ')
        : locale.generiString;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
      // Tap sulla card serata → schermata 19 (pop-up info serata).
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => NavigatorService.pushNamed(
          AppRoutes.eventInfoPopupScreen,
          arguments: {'serata': serata, 'club': locale},
        ),
        child: Container(
          height: 140,
          clipBehavior: Clip.hardEdge,
          decoration: BoxDecoration(
            gradient: OnlistColors.cardSummary,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Locandina serata (sx)
              SizedBox(
                width: 130,
                child: serata.locandinaUrl != null
                    ? CachedNetworkImage(
                        imageUrl: serata.locandinaUrl!,
                        fit: BoxFit.cover,
                        memCacheWidth: 390,
                        errorWidget: (_, __, ___) => const ImageFallback(),
                      )
                    : const ImageFallback(),
              ),
              // Info (dx)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Blocco superiore: titolo + OGGI + data + orario
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            serata.nome,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: OnlistTextStyles.hn(
                              fontSize: R.sp(22),
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              height: 22 / 22,
                              letterSpacing: -0.04 * 22,
                            ),
                          ),
                          if (_isToday) ...[
                            const SizedBox(height: 2),
                            Text(
                              'OGGI',
                              style: OnlistTextStyles.hn(
                                fontSize: R.sp(20),
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                height: 22 / 20,
                                letterSpacing: -0.06 * 20,
                              ),
                            ),
                          ],
                          const SizedBox(height: 4),
                          Text(
                            _formatData(serata.data),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: OnlistTextStyles.hn(
                              fontSize: R.sp(12),
                              fontWeight: FontWeight.w400,
                              color: Colors.white,
                            ),
                          ),
                          if (serata.orarioString.isNotEmpty)
                            Text(
                              serata.orarioString,
                              style: OnlistTextStyles.hn(
                                fontSize: R.sp(12),
                                fontWeight: FontWeight.w400,
                                color: Colors.white,
                              ),
                            ),
                        ],
                      ),
                      // Blocco inferiore: generi + bottone PRENOTA
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Text(
                              generi,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: OnlistTextStyles.hn(
                                fontSize: R.sp(11),
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withValues(alpha: 0.65),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: isSoldOut
                                ? null
                                : () => ReservationChoiceSheet.show(
                                      context,
                                      serata: serata,
                                      club: locale,
                                    ),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: isSoldOut
                                    ? Colors.white.withValues(alpha: 0.18)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                isSoldOut ? 'ESAURITO' : 'PRENOTA',
                                style: OnlistTextStyles.hn(
                                  fontSize: R.sp(13),
                                  fontWeight: FontWeight.w700,
                                  color: isSoldOut
                                      ? Colors.white60
                                      : OnlistColors.blueIntense2,
                                  letterSpacing: -0.04 * 13,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
