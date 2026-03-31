import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/app_export.dart';
import '../../core/models/locale_model.dart';
import '../../core/models/serata_model.dart';
import '../../widgets/custom_image_view.dart';
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

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late AnimationController _staggerCtrl;

  late Animation<double> _appBarFade;
  late Animation<Offset> _appBarSlide;
  late Animation<double> _heroFade;
  late Animation<double> _heroScale;
  late Animation<double> _titleFade;
  late Animation<Offset> _titleSlide;
  late Animation<double> _subtitleFade;
  late Animation<Offset> _subtitleSlide;
  late Animation<double> _buttonFade;
  late Animation<double> _buttonScale;
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
    _buttonFade   = _fade(0.32, 0.64);
    _buttonScale  = Tween<double>(begin: 0.9, end: 1).animate(
      CurvedAnimation(parent: _staggerCtrl,
          curve: const Interval(0.32, 0.64, curve: Curves.easeOutBack)));
    _sectionFade  = _fade(0.43, 0.72);
    _sectionSlide = _slide(const Offset(0, 0.3), 0.43, 0.72);
    _cardsFade    = _fade(0.54, 0.86);
    _cardsSlide   = _slide(const Offset(0.15, 0), 0.54, 0.86);
    _navFade      = _fade(0.64, 1.00);
    _navSlide     = _slide(const Offset(0, 1), 0.64, 1.00);

    _staggerCtrl.forward();
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

  void _onReservaTapped(BuildContext context, HomeState state) {
    final club = state.localeVicino;
    if (club == null) return;
    final eventi = state.upcomingEventi;
    if (eventi.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nessuna serata disponibile al momento')),
      );
      return;
    }
    if (eventi.length == 1) {
      _navigateToEventDetailClub(context, eventi.first, club);
      return;
    }
    _showEventPicker(context, eventi, club);
  }

  void _showEventPicker(
      BuildContext context, List<SerataModel> eventi, LocaleModel club) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF555555),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Scegli la serata',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 8),
            ...eventi.map(
              (e) => ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 52,
                    height: 52,
                    color: const Color(0xFF2A2A2A),
                    child: e.locandinaUrl != null
                        ? Image.network(e.locandinaUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(
                                Icons.music_note,
                                color: Color(0xFF666666)))
                        : const Icon(Icons.music_note,
                            color: Color(0xFF666666)),
                  ),
                ),
                title: Text(
                  e.nome,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                subtitle: Text(
                  '${_formatDate(e.data)}  ·  ${e.orarioString}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.white54,
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _navigateToEventDetailClub(context, e, club);
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }

  String _formatDate(DateTime d) {
    final oggi = DateTime.now();
    if (d.year == oggi.year && d.month == oggi.month && d.day == oggi.day) {
      return 'Oggi';
    }
    final domani = oggi.add(const Duration(days: 1));
    if (d.year == domani.year && d.month == domani.month && d.day == domani.day) {
      return 'Domani';
    }
    return DateFormat('EEE d MMM', 'it_IT').format(d);
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: BlocBuilder<HomeBloc, HomeState>(
        builder: (context, state) {
          return SafeArea(
            child: Column(
              children: [
                // AppBar
                SlideTransition(
                  position: _appBarSlide,
                  child: FadeTransition(
                    opacity: _appBarFade,
                    child: _buildAppBar(),
                  ),
                ),
                // Radius label — commentato, ora accessibile dalla ricerca
                // SlideTransition(
                //   position: _radiusSlide,
                //   child: FadeTransition(
                //     opacity: _radiusFade,
                //     child: _buildRadiusLabel(context, state),
                //   ),
                // ),
                // Scrollable content
                Expanded(
                  child: state.isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                              color: Color(0xFF0009FF)))
                      : SingleChildScrollView(
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
                              // Club address
                              SlideTransition(
                                position: _subtitleSlide,
                                child: FadeTransition(
                                  opacity: _subtitleFade,
                                  child: _buildClubAddress(state),
                                ),
                              ),
                              // RISERVA button
                              FadeTransition(
                                opacity: _buttonFade,
                                child: ScaleTransition(
                                  scale: _buttonScale,
                                  child: _buildReserveButton(context, state),
                                ),
                              ),
                              // Events section
                              if (state.upcomingEventi.isNotEmpty) ...[
                                const SizedBox(height: 20),
                                SlideTransition(
                                  position: _sectionSlide,
                                  child: FadeTransition(
                                    opacity: _sectionFade,
                                    child: _buildSectionTitle(state),
                                  ),
                                ),
                                const SizedBox(height: 12),
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
                // Bottom nav
                SlideTransition(
                  position: _navSlide,
                  child: FadeTransition(
                    opacity: _navFade,
                    child: _buildBottomNav(context, state),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── AppBar ─────────────────────────────────────────────────────────────────

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: Image.asset(
              ImageConstant.imgLogoOnlist,
              height: 60,
              width: 60,
              fit: BoxFit.cover,
            ),
          ),
          Row(
            children: [
              GestureDetector(
                onTap: () =>
                    NavigatorService.pushNamed(AppRoutes.nearbyClubsScreen),
                child: const Icon(Icons.search, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 12),
              const Icon(Icons.person_outline, color: Colors.white, size: 28),
              const SizedBox(width: 10),
            ],
          ),
        ],
      ),
    );
  }


  // ── Hero image ─────────────────────────────────────────────────────────────

  Widget _buildHeroImage(HomeState state) {
    final fotoUrl = state.localeVicino?.fotoUrl;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 14, 10, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: double.infinity,
          height: 217,
          color: const Color(0xFF1A1A2E),
          child: fotoUrl != null
              ? Image.network(
                  fotoUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.nightlife,
                    color: Color(0xFF666666),
                    size: 48,
                  ),
                )
              : const Icon(Icons.nightlife,
                  color: Color(0xFF666666), size: 48),
        ),
      ),
    );
  }

  // ── Club name ──────────────────────────────────────────────────────────────

  Widget _buildClubName(HomeState state) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(13, 22, 13, 0),
      child: Text(
        state.localeVicino?.nome ?? '',
        style: GoogleFonts.inter(
          fontSize: 36,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          letterSpacing: -0.08 * 36,
        ),
      ),
    );
  }

  // ── Club address ───────────────────────────────────────────────────────────

  Widget _buildClubAddress(HomeState state) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(13, 10, 13, 0),
      child: Text(
        state.localeVicino?.indirizzoCompleto ?? '',
        style: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: Colors.white.withValues(alpha: 0.6),
        ),
      ),
    );
  }

  // ── RISERVA button ─────────────────────────────────────────────────────────

  Widget _buildReserveButton(BuildContext context, HomeState state) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(11, 16, 11, 0),
      child: _AnimatedPressButton(
        onPressed: () => _onReservaTapped(context, state),
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

  // ── Section title ──────────────────────────────────────────────────────────

  Widget _buildSectionTitle(HomeState state) {
    final hasToday = state.upcomingEventi.any((e) {
      final now = DateTime.now();
      return e.data.year == now.year &&
          e.data.month == now.month &&
          e.data.day == now.day;
    });
    final label = hasToday && state.upcomingEventi.length == 1
        ? 'Questa sera'
        : 'Prossime serate';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 13),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }

  // ── Event cards ────────────────────────────────────────────────────────────

  Widget _buildEventCards(BuildContext context, HomeState state) {
    final club = state.localeVicino!;
    return Column(
      children: state.upcomingEventi.map((serata) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(13, 0, 13, 10),
          child: _buildEventCard(context, serata, club),
        );
      }).toList(),
    );
  }

  Widget _buildEventCard(
      BuildContext context, SerataModel serata, LocaleModel club) {
    final isToday = () {
      final now = DateTime.now();
      return serata.data.year == now.year &&
          serata.data.month == now.month &&
          serata.data.day == now.day;
    }();

    return _AnimatedPressButton(
      onPressed: () => _navigateToEventDetailClub(context, serata, club),
      child: Container(
        height: 95,
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            // Event image
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(10)),
              child: Container(
                width: 165,
                height: 95,
                color: const Color(0xFF2A2A2A),
                child: serata.locandinaUrl != null
                    ? Image.network(
                        serata.locandinaUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.music_note,
                          color: Color(0xFF666666),
                          size: 32,
                        ),
                      )
                    : const Icon(Icons.music_note,
                        color: Color(0xFF666666), size: 32),
              ),
            ),
            const SizedBox(width: 10),
            // Event info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Date badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: isToday
                            ? const Color(0xFF0009FF).withValues(alpha: 0.25)
                            : const Color(0xFF333333),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        isToday ? 'Questa sera' : _formatDate(serata.data),
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isToday
                              ? const Color(0xFF6680FF)
                              : Colors.white60,
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    // Event name
                    Text(
                      serata.nome,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: -0.08 * 18,
                      ),
                    ),
                    if (serata.orarioString.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        serata.orarioString,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: Colors.white.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
          ],
        ),
      ),
    );
  }

  // ── Bottom nav ─────────────────────────────────────────────────────────────

  Widget _buildBottomNav(BuildContext context, HomeState state) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFF2A2A2A), width: 0.5)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 10),
      child: Row(
        children: [
          _buildNavItem(context, ImageConstant.imgHome, 0,
              state.selectedBottomNavIndex),
          _buildNavItem(context, ImageConstant.imgShoppingCart, 1,
              state.selectedBottomNavIndex),
          _buildNavItem(
              context, ImageConstant.imgBell, 2, state.selectedBottomNavIndex),
          _buildNavItem(
              context, ImageConstant.imgUser, 3, state.selectedBottomNavIndex),
        ],
      ),
    );
  }

  Widget _buildNavItem(
      BuildContext context, String imagePath, int index, int selected) {
    final isSelected = index == selected;
    return Expanded(
      child: GestureDetector(
        onTap: () =>
            context.read<HomeBloc>().add(HomeBottomNavSelectedEvent(index)),
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
