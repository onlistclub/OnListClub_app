import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/app_export.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/services/club_service.dart';
import '../../core/models/locale_model.dart';
import '../../core/models/serata_model.dart';
import '../../core/services/analytics_service.dart';
import '../../core/utils/analytics_mixin.dart';
import '../../core/utils/date_formatter.dart';
import '../../theme/onlist_colors.dart';
import '../../theme/onlist_text_styles.dart';
import '../../widgets/top_bar_slot.dart';
import '../../widgets/glow_card.dart';
import '../../widgets/shimmer_loading.dart';
import '../../widgets/animated_press.dart';
import '../../widgets/card_prenota_button.dart';
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

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin, ScreenAnalytics {
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

  @override
  void initState() {
    super.initState();
    _staggerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _appBarFade = _fade(0.00, 0.25);
    _appBarSlide = _slide(const Offset(0, -0.5), 0.00, 0.25);
    _heroFade = _fade(0.07, 0.43);
    _heroScale = Tween<double>(begin: 0.95, end: 1).animate(CurvedAnimation(
        parent: _staggerCtrl,
        curve: const Interval(0.07, 0.43, curve: Curves.easeOut)));
    _titleFade = _fade(0.18, 0.50);
    _titleSlide = _slide(const Offset(0, 0.3), 0.18, 0.50);
    _subtitleFade = _fade(0.25, 0.57);
    _subtitleSlide = _slide(const Offset(0, 0.3), 0.25, 0.57);
    _sectionFade = _fade(0.43, 0.72);
    _sectionSlide = _slide(const Offset(0, 0.3), 0.43, 0.72);
    _cardsFade = _fade(0.54, 0.86);
    _cardsSlide = _slide(const Offset(0.15, 0), 0.54, 0.86);

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
  ///
  /// [elemento] dice quale di questi è stato toccato (evento `home_tap`).
  void _navigateToClubDetail(
    BuildContext context,
    LocaleModel club, {
    required String elemento,
  }) {
    AnalyticsService.logHomeTap(
      elemento: elemento,
      clubId: club.id,
      clubName: club.nome,
    );
    NavigatorService.pushNamed(
      AppRoutes.clubDetailScreen,
      arguments: club,
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Design NUOVO: sfondo NERO FISSO dietro tutte le schermate (niente
      // gradiente screenBackground).
      backgroundColor: Colors.black,
      // Footer flottante: il contenuto scorre dietro la capsula (non la oscura).
      extendBody: true,
      body: ColoredBox(
        color: Colors.black,
        child: BlocConsumer<HomeBloc, HomeState>(
          // Reagisce a: (1) GPS forzato non disponibile → messaggio; (2) fine del
          // caricamento dati (isLoading true→false) → tempo di caricamento Home.
          listenWhen: (prev, curr) =>
              (!prev.gpsUnavailable && curr.gpsUnavailable) ||
              (prev.isLoading && !curr.isLoading),
          listener: (context, state) {
            if (!state.isLoading) {
              // Dati Home pronti: registra il tempo di caricamento (load_time_home).
              reportLoadTime('load_time_home');
            }
            if (state.gpsUnavailable) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content:
                      Text('GPS non disponibile. Mostro l\'ultima posizione.'),
                ),
              );
            }
          },
          buildWhen: (prev, curr) =>
              prev.localeVicino != curr.localeVicino ||
              prev.upcomingEventi != curr.upcomingEventi ||
              prev.recommendedClubs != curr.recommendedClubs ||
              prev.isLoading != curr.isLoading ||
              prev.nextSerataByClub != curr.nextSerataByClub ||
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
                      child: const TopBarSlot(isHome: true),
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
                            : RepaintBoundary(
                                child: SingleChildScrollView(
                                  padding: const EdgeInsets.only(bottom: 80),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Hero image (tap → schermata 10 club detail)
                                      FadeTransition(
                                        opacity: _heroFade,
                                        child: ScaleTransition(
                                          scale: _heroScale,
                                          child:
                                              _buildHeroImage(context, state),
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
                                          child: _buildReserveButton(
                                              context, state),
                                        ),
                                      ),
                                      // Club consigliati (altri club vicini)
                                      if (state
                                          .recommendedClubs.isNotEmpty) ...[
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
                                            child: _buildRecommendedCards(
                                                context, state),
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
      // La footer NON è più qui: la monta lo shell globale ([RootShell]), così
      // resta fissa. La Home vive sempre come tab dentro lo shell.
    );
  }

  // ── Hero image ─────────────────────────────────────────────────────────────
  // Tap → schermata 10 (club detail).

  Widget _buildHeroImage(BuildContext context, HomeState state) {
    final club = state.localeVicino;
    final fotoUrl = club?.fotoUrl;
    // Figma 07-aggiornato (home.css): l'immagine NON è edge-to-edge, ha margini
    // laterali (~10px) e raggio 10px. Il padding orizzontale viene applicato in
    // fondo alla funzione così anche la pill "Il tuo club preferito" resta
    // relativa all'immagine.
    final hero = Stack(
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
                      errorWidget: (_, __, ___) =>
                          ImageFallback(seed: club?.id),
                    )
                  : ImageFallback(seed: club?.id),
            ),
          ),
        ),
        // Pill "Il tuo club preferito" — solo se il club è nei preferiti.
        // CSS NUOVO/home.css: pill a 12,17 dal bordo della foto.
        if (club != null)
          Positioned(
            top: R.sp(17),
            left: R.sp(12),
            child: _FavoritePill(clubId: club.id),
          ),
      ],
    );
    if (club == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: hero,
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _navigateToClubDetail(context, club, elemento: 'hero'),
        child: hero,
      ),
    );
  }

  // ── Club name ──────────────────────────────────────────────────────────────
  // CSS NUOVO/home.css: "Amnesia Club" 36/700/-0.08 a left 13, 25px sotto
  // l'hero. Niente bookmark in Home (resta nel dettaglio club).

  Widget _buildClubName(HomeState state) {
    return Padding(
      padding: EdgeInsets.only(left: R.sp(13), top: R.sp(25), right: R.sp(13)),
      child: Text(
        state.localeVicino?.nome ?? '',
        style: OnlistTextStyles.hn(
          fontSize: R.sp(36),
          fontWeight: FontWeight.w700,
          color: Colors.white,
          height: 36 / 36, // Figma: line-height 36px = font-size
          letterSpacing: -0.08 * 36,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  // ── Club details ───────────────────────────────────────────────────────────

  Widget _buildClubDetails(HomeState state) {
    final locale = state.localeVicino;
    if (locale == null) return const SizedBox.shrink();

    final addr = [
      if (locale.nomeCitta != null && locale.nomeCitta!.isNotEmpty)
        locale.nomeCitta!,
      if (locale.indirizzo != null && locale.indirizzo!.isNotEmpty)
        locale.indirizzo!,
    ].join(' - ');

    // CSS NUOVO/home.css (16/09): indirizzo 22/400 a left 13, 2px sotto il
    // nome (nome top 360 + 36 → indirizzo top 398).
    return Padding(
      padding: EdgeInsets.fromLTRB(R.sp(13), R.sp(2), R.sp(13), 0),
      child: Text(
        addr,
        style: OnlistTextStyles.hn(
          fontSize: R.sp(22),
          color: Colors.white,
          fontWeight: FontWeight.w400,
          height: 22 / 22,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  // ── Reserve CTA → schermata 10 (club detail) ────────────────────────────
  // CSS NUOVO/home.css Frame 350: pill 368×49 r18, radial
  // `#0077FF 32.69% → #0000FF` col picco a sinistra (3.12%, 32.65%) e glow
  // interno ciano `inset 0 0 23.8 rgba(0,255,255,0.57)`; testo Inter 700 20.

  Widget _buildReserveButton(BuildContext context, HomeState state) {
    final club = state.localeVicino;
    if (club == null) return const SizedBox.shrink();

    return Padding(
      // CSS: CTA top 431, indirizzo chiude a 420 → 11.
      padding: EdgeInsets.fromLTRB(R.sp(12.5), R.sp(11), R.sp(12.5), 0),
      child: AnimatedPress(
        onPressed: () =>
            _navigateToClubDetail(context, club, elemento: 'riserva_posto'),
        child: SizedBox(
          width: double.infinity,
          height: R.sp(49),
          child: GlowCard(
            // Ellisse 242.5×32.3 come da CSS (prima era un cerchio di 242.5:
            // il picco chiaro si spalmava in verticale 7.5× oltre il dovuto).
            gradient: OnlistColors.homeReserveCTA,
            radius: R.sp(18),
            glowColor: const Color(0x9100FFFF), // rgba(0,255,255,0.57)
            glowSigma: R.sp(11.9), // blur CSS 23.8 → sigma ≈ 11.9
            child: Center(
              child: Text(
                'RISERVA IL TUO POSTO ORA',
                style: GoogleFonts.inter(
                  fontSize: R.sp(20),
                  fontWeight: FontWeight.w700,
                  color: OnlistColors.white,
                  height: 24 / 20,
                  letterSpacing: -0.08 * R.sp(20),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Section title "Club consigliati" ───────────────────────────────────────

  Widget _buildSectionTitle() {
    // CSS NUOVO/home.css (16/09): 36/41/700/-0.08 a left 13, prima card 6px
    // sotto il riquadro del testo (528 → 534). Sopra il CSS darebbe 7 dalla
    // CTA: usiamo 14, scostamento VOLUTO da Luca per staccare il titolo.
    return Padding(
      padding: EdgeInsets.fromLTRB(R.sp(13), R.sp(14), R.sp(13), R.sp(6)),
      child: Text(
        'Club consigliati',
        style: OnlistTextStyles.hn(
          fontSize: R.sp(36),
          fontWeight: FontWeight.w700,
          color: Colors.white,
          height: 41 / 36,
          letterSpacing: -0.08 * R.sp(36),
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
            // CSS NUOVO (16/09): card a left 13, passo 114 → 12 tra le card.
            padding: EdgeInsets.fromLTRB(R.sp(13), 0, R.sp(13), R.sp(12)),
            child: _scaleToWidth(
              designW: _cardW,
              designH: _cardH,
              child: _buildRecommendedClubCard(
                  context, club, state.nextSerataByClub[club.id]),
            ),
          ),
      ],
    );
  }

  static const double _cardW = 367;
  static const double _cardH = 102;

  /// Card club, CSS NUOVO/home.css (16/09) Rectangle 297: 367×102 r7.
  /// Righe a destra della foto: prossima serata ("Dom 19 Apr"), orario,
  /// città. Senza serate in programma la data sparisce e l'orario del locale
  /// sale al suo posto.
  /// NB: siamo dentro _scaleToWidth(367×102) → px design puri, niente R.sp.
  Widget _buildRecommendedClubCard(
      BuildContext context, LocaleModel club, SerataModel? serata) {
    final String orario = serata?.orarioString ??
        (club.orarioString.isNotEmpty ? club.orarioString : club.generiString);
    final TextStyle riga = OnlistTextStyles.hn(
      fontSize: 19,
      fontWeight: FontWeight.w400,
      color: Colors.white,
      height: 19 / 19,
    );

    return AnimatedPress(
      onPressed: () =>
          _navigateToClubDetail(context, club, elemento: 'consigliati_card'),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(7),
        child: SizedBox(
          width: _cardW,
          height: _cardH,
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: OnlistColors.homeClubCard,
            ),
            child: Stack(
              children: [
                // Foto 153×88 r3 a (6,8).
                Positioned(
                  left: 6,
                  top: 8,
                  child: _heroWrap(
                    tag: 'club-img-${club.id}',
                    enabled: club.fotoUrl != null,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: Container(
                        width: 153,
                        height: 88,
                        color: const Color(0xFF2A2A2A),
                        child: club.fotoUrl != null
                            ? CachedNetworkImage(
                                imageUrl: club.fotoUrl!,
                                fit: BoxFit.cover,
                                memCacheWidth: 459,
                                memCacheHeight: 264,
                                errorWidget: (_, __, ___) =>
                                    ImageFallback(seed: club.id),
                              )
                            : ImageFallback(seed: club.id),
                      ),
                    ),
                  ),
                ),
                // Nome (166,6) 32/37/700/-0.08.
                Positioned(
                  left: 166,
                  top: 6,
                  right: 8,
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
                // Data (167,43) e orario (167,63), 19/400. Larghezza fino al
                // bottone PRENOTA (x 294), che l'orario affianca.
                if (serata != null)
                  Positioned(
                    left: 167,
                    top: 43,
                    width: 123,
                    child: Text(
                      DateFormatter.formatBreve(serata.data),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: riga,
                    ),
                  ),
                if (orario.isNotEmpty)
                  Positioned(
                    left: 167,
                    top: serata != null ? 63 : 43,
                    width: 123,
                    child: Text(
                      orario,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: riga,
                    ),
                  ),
                // Città (167,84) 12/500 all'80%.
                Positioned(
                  left: 167,
                  top: 84,
                  width: 123,
                  child: Opacity(
                    opacity: 0.8,
                    child: Text(
                      club.nomeCitta ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: OnlistTextStyles.hn(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                        height: 12 / 12,
                      ),
                    ),
                  ),
                ),
                // PRENOTA (294,67) 67×26 r7 (Rectangle 298).
                Positioned(
                  left: 294,
                  top: 67,
                  child: CardPrenotaButton(
                    onTap: () => _navigateToClubDetail(context, club,
                        elemento: 'consigliati_prenota'),
                  ),
                ),
              ],
            ),
          ),
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
              padding: EdgeInsets.symmetric(horizontal: 10),
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
              padding: EdgeInsets.symmetric(horizontal: 13),
              child: ShimmerBox(width: double.infinity, height: 102),
            ),
            SizedBox(height: 12),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 13),
              child: ShimmerBox(width: double.infinity, height: 102),
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

// (Il bookmark accanto al nome è stato rimosso dalla Home col design NUOVO:
// il salvataggio del club resta nelle schermate di dettaglio.)
