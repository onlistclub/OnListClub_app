import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_export.dart';
import '../../core/models/locale_model.dart';
import '../../core/models/serata_model.dart';
import '../../widgets/custom_top_bar.dart';
import 'bloc/event_detail_club_bloc.dart';

class EventDetailClubScreen extends StatefulWidget {
  const EventDetailClubScreen({Key? key}) : super(key: key);

  static Widget builder(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    SerataModel? serata;
    LocaleModel? club;

    if (args is Map) {
      final sData = args['serata'];
      final cData = args['club'] ?? args['locale'];

      if (sData is SerataModel) {
        serata = sData;
      } else if (sData is Map<String, dynamic>) {
        serata = SerataModel.fromMap(sData);
      }

      if (cData is LocaleModel) {
        club = cData;
      } else if (cData is Map<String, dynamic>) {
        club = LocaleModel.fromMap(cData);
      }
    }

    if (serata == null || club == null) {
      WidgetsBinding.instance.addPostFrameCallback(
          (_) => Navigator.of(context, rootNavigator: true).maybePop());
      return const Scaffold(backgroundColor: Color(0xFF0D0D0D));
    }
    return BlocProvider<EventDetailClubBloc>(
      create: (_) => EventDetailClubBloc(
        EventDetailClubState(club: club!, serata: serata!),
      )..add(EventDetailClubInitialEvent()),
      child: const EventDetailClubScreen(),
    );
  }

  @override
  State<EventDetailClubScreen> createState() => _EventDetailClubScreenState();
}

class _EventDetailClubScreenState extends State<EventDetailClubScreen>
    with TickerProviderStateMixin {
  // ── Staggered entrance ─────────────────────────────────────────────────────
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

  // ── Bookmark bounce ────────────────────────────────────────────────────────
  late AnimationController _bookmarkCtrl;
  late Animation<double> _bookmarkScale;

  // ── Favorite badge ─────────────────────────────────────────────────────────
  late AnimationController _badgeCtrl;
  late Animation<Offset> _badgeSlide;
  late Animation<double> _badgeFade;

  @override
  void initState() {
    super.initState();

    _staggerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _appBarFade    = _fade(0.00, 0.28);
    _appBarSlide   = _slide(const Offset(0, -0.5), 0.00, 0.28);
    _heroFade      = _fade(0.07, 0.43);
    _heroScale     = Tween<double>(begin: 0.95, end: 1).animate(
      CurvedAnimation(parent: _staggerCtrl,
          curve: const Interval(0.07, 0.43, curve: Curves.easeOut)));
    _titleFade     = _fade(0.18, 0.50);
    _titleSlide    = _slide(const Offset(0, 0.3), 0.18, 0.50);
    _subtitleFade  = _fade(0.25, 0.57);
    _subtitleSlide = _slide(const Offset(0, 0.3), 0.25, 0.57);
    _infoFade      = _fade(0.30, 0.61);
    _infoSlide     = _slide(const Offset(0, 0.3), 0.30, 0.61);
    _buttonFade    = _fade(0.32, 0.64);
    _buttonScale   = Tween<double>(begin: 0.9, end: 1).animate(
      CurvedAnimation(parent: _staggerCtrl,
          curve: const Interval(0.32, 0.64, curve: Curves.easeOutBack)));
    _sectionsFade  = _fade(0.43, 0.78);
    _sectionsSlide = _slide(const Offset(0, 0.3), 0.43, 0.78);

    _staggerCtrl.forward();

    _bookmarkCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _bookmarkScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.35), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.35, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _bookmarkCtrl, curve: Curves.easeOut));

    _badgeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _badgeSlide = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _badgeCtrl, curve: Curves.easeOutBack));
    _badgeFade = CurvedAnimation(parent: _badgeCtrl, curve: Curves.easeOut);
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
    _bookmarkCtrl.dispose();
    _badgeCtrl.dispose();
    super.dispose();
  }

  bool _lastBadge = false;
  void _syncBadge(bool show) {
    if (show == _lastBadge) return;
    _lastBadge = show;
    if (show) {
      _bookmarkCtrl.forward(from: 0);
      _badgeCtrl.forward(from: 0);
    } else {
      _badgeCtrl.reverse();
    }
  }

  Future<void> _openMaps(String address) async {
    final uri = Uri.parse(
        'https://maps.google.com/?q=${Uri.encodeComponent(address)}');
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

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: BlocConsumer<EventDetailClubBloc, EventDetailClubState>(
        listener: (_, state) => _syncBadge(state.showFavoriteBadge),
        builder: (context, state) {
          return SafeArea(
            child: Column(
              children: [
                // AppBar
                SlideTransition(
                  position: _appBarSlide,
                  child: FadeTransition(
                      opacity: _appBarFade, child: const CustomTopBar()),
                ),
                // Content
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Hero + bookmark + badge
                        FadeTransition(
                          opacity: _heroFade,
                          child: ScaleTransition(
                            scale: _heroScale,
                            child: _buildHeroWithBadge(context, state),
                          ),
                        ),
                        // Event name (GRANDE TITOLO)
                        SlideTransition(
                          position: _titleSlide,
                          child: FadeTransition(
                            opacity: _titleFade,
                            child: _buildEventName(state.serata.nome),
                          ),
                        ),
                        // Club name (SOTTOTITOLO — non l'indirizzo)
                        SlideTransition(
                          position: _subtitleSlide,
                          child: FadeTransition(
                            opacity: _subtitleFade,
                            child: _buildClubName(state.club.nome),
                          ),
                        ),
                        // Info rows
                        SlideTransition(
                          position: _infoSlide,
                          child: FadeTransition(
                            opacity: _infoFade,
                            child: _buildInfoRows(state),
                          ),
                        ),
                        // CTA button
                        FadeTransition(
                          opacity: _buttonFade,
                          child: ScaleTransition(
                            scale: _buttonScale,
                            child: _buildReserveButton(context, state),
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Info sections
                        SlideTransition(
                          position: _sectionsSlide,
                          child: FadeTransition(
                            opacity: _sectionsFade,
                            child: _buildInfoSections(state.club),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── Hero + bookmark + badge ────────────────────────────────────────────────

  Widget _buildHeroWithBadge(
      BuildContext context, EventDetailClubState state) {
    // Preferenza: locandina serata, fallback: foto club
    final imgUrl = state.serata.locandinaUrl ?? state.club.fotoUrl;

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
              child: imgUrl != null
                  ? CachedNetworkImage(
                      imageUrl: imgUrl,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => const Icon(
                          Icons.nightlife,
                          color: Color(0xFF666666),
                          size: 48),
                    )
                  : const Icon(Icons.nightlife,
                      color: Color(0xFF666666), size: 48),
            ),
          ),
          // Bookmark button
          Positioned(
            top: 10,
            right: 10,
            child: _AnimatedPressButton(
              onPressed: () => context
                  .read<EventDetailClubBloc>()
                  .add(EventDetailClubToggleFavoriteEvent()),
              child: AnimatedBuilder(
                animation: _bookmarkScale,
                builder: (_, child) =>
                    Transform.scale(scale: _bookmarkScale.value, child: child),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    state.isPreferito
                        ? Icons.bookmark
                        : Icons.bookmark_border,
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
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 6),
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

  // ── Event name (titolo principale) ─────────────────────────────────────────

  Widget _buildEventName(String nome) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(13, 25, 13, 0),
      child: Text(
        nome,
        style: GoogleFonts.inter(
          fontSize: 36,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          letterSpacing: -0.08 * 36,
        ),
      ),
    );
  }

  // ── Club name (sottotitolo — al posto dell'indirizzo) ──────────────────────

  Widget _buildClubName(String nomeClub) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(13, 10, 13, 0),
      child: Text(
        nomeClub,
        style: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: Colors.white.withValues(alpha: 0.6),
        ),
      ),
    );
  }

  // ── Info rows: orario, prezzo, generi ──────────────────────────────────────

  Widget _buildInfoRows(EventDetailClubState state) {
    final serata = state.serata;
    final club = state.club;
    final orario = serata.orarioString;
    final generi = serata.generiMusicali.isNotEmpty
        ? serata.generiMusicali.join(' - ')
        : club.generiString;

    return Padding(
      padding: const EdgeInsets.fromLTRB(13, 12, 13, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (orario.isNotEmpty || club.prezzoString.isNotEmpty)
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
                        color: Colors.white.withValues(alpha: 0.7)),
                  ),
                ],
                if (club.prezzoString.isNotEmpty) ...[
                  const SizedBox(width: 12),
                  Text(
                    club.prezzoString,
                    style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.7)),
                  ),
                ],
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
                    style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.7)),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ── RISERVA button ─────────────────────────────────────────────────────────

  Widget _buildReserveButton(
      BuildContext context, EventDetailClubState state) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(11, 15, 11, 0),
      child: _AnimatedPressButton(
        onPressed: () => NavigatorService.pushNamed(
          AppRoutes.bookingScreen,
          arguments: {'serata': state.serata, 'club': state.club},
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
    );
  }

  // ── Info sections ──────────────────────────────────────────────────────────

  Widget _buildInfoSections(LocaleModel club) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSection(
          title: 'Come arrivare',
          buttonLabel: 'Mappe',
          onTap: () => _openMaps(club.indirizzoCompleto),
        ),
        _buildDivider(),
        _buildSection(
          title: 'Recensioni',
          buttonLabel: 'TripAdvisor',
          onTap: club.linkTripadvisor != null
              ? () => _openUrl(club.linkTripadvisor!)
              : null,
        ),
        _buildDivider(),
        _buildSection(
          title: 'Trasporti',
          buttonLabel: null,
          onTap: null,
        ),
      ],
    );
  }

  Widget _buildSection({
    required String title,
    required String? buttonLabel,
    required VoidCallback? onTap,
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
            _AnimatedPressButton(
              onPressed: onTap ?? () {},
              child: Container(
                width: double.infinity,
                height: 44,
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
          ],
        ],
      ),
    );
  }

  Widget _buildDivider() => Container(
        height: 0.5,
        color: const Color(0xFF2A2A2A),
        margin: const EdgeInsets.symmetric(horizontal: 13),
      );

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
