import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/app_export.dart';
import '../../core/utils/analytics_mixin.dart';
import '../../widgets/custom_top_bar.dart';
import '../../widgets/image_fallback.dart';
import './bloc/event_detail_bloc.dart';
import './models/event_detail_model.dart';

class EventDetailScreen extends StatefulWidget {
  const EventDetailScreen({Key? key}) : super(key: key);

  static Widget builder(BuildContext context) {
    return BlocProvider<EventDetailBloc>(
      create: (context) => EventDetailBloc(EventDetailState(
        eventDetailModel: EventDetailModel(),
      ))
        ..add(EventDetailInitialEvent()),
      child: const EventDetailScreen(),
    );
  }

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen>
    with TickerProviderStateMixin, ScreenAnalytics {
  @override
  String get screenName => 'event_detail';

  late AnimationController _staggerController;
  late AnimationController _heroController;

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
  late Animation<double> _cardFade;
  late Animation<Offset> _cardSlide;
  late Animation<double> _navFade;
  late Animation<Offset> _navSlide;

  @override
  void initState() {
    super.initState();

    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _heroController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _appBarFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _staggerController, curve: const Interval(0, 0.28, curve: Curves.easeOut)),
    );
    _appBarSlide = Tween<Offset>(begin: const Offset(0, -0.5), end: Offset.zero).animate(
      CurvedAnimation(parent: _staggerController, curve: const Interval(0, 0.28, curve: Curves.easeOut)),
    );
    _heroFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _staggerController, curve: const Interval(0.07, 0.43, curve: Curves.easeOut)),
    );
    _heroScale = Tween<double>(begin: 0.95, end: 1).animate(
      CurvedAnimation(parent: _staggerController, curve: const Interval(0.07, 0.43, curve: Curves.easeOut)),
    );
    _titleFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _staggerController, curve: const Interval(0.18, 0.50, curve: Curves.easeOut)),
    );
    _titleSlide = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(parent: _staggerController, curve: const Interval(0.18, 0.50, curve: Curves.easeOut)),
    );
    _subtitleFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _staggerController, curve: const Interval(0.25, 0.57, curve: Curves.easeOut)),
    );
    _subtitleSlide = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(parent: _staggerController, curve: const Interval(0.25, 0.57, curve: Curves.easeOut)),
    );
    _buttonFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _staggerController, curve: const Interval(0.32, 0.64, curve: Curves.easeOut)),
    );
    _buttonScale = Tween<double>(begin: 0.9, end: 1).animate(
      CurvedAnimation(parent: _staggerController, curve: const Interval(0.32, 0.64, curve: Curves.easeOutBack)),
    );
    _sectionFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _staggerController, curve: const Interval(0.43, 0.75, curve: Curves.easeOut)),
    );
    _sectionSlide = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(parent: _staggerController, curve: const Interval(0.43, 0.75, curve: Curves.easeOut)),
    );
    _cardFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _staggerController, curve: const Interval(0.54, 0.86, curve: Curves.easeOut)),
    );
    _cardSlide = Tween<Offset>(begin: const Offset(0.15, 0), end: Offset.zero).animate(
      CurvedAnimation(parent: _staggerController, curve: const Interval(0.54, 0.86, curve: Curves.easeOut)),
    );
    _navFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _staggerController, curve: const Interval(0.64, 1.0, curve: Curves.easeOut)),
    );
    _navSlide = Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero).animate(
      CurvedAnimation(parent: _staggerController, curve: const Interval(0.64, 1.0, curve: Curves.easeOut)),
    );

    _staggerController.forward();
  }

  @override
  void dispose() {
    _staggerController.dispose();
    _heroController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: BlocBuilder<EventDetailBloc, EventDetailState>(
        buildWhen: (prev, curr) =>
            prev.hottestClub != curr.hottestClub ||
            prev.eventoOggi != curr.eventoOggi ||
            prev.selectedBottomNavIndex != curr.selectedBottomNavIndex,
        builder: (context, state) {
          return SafeArea(
            child: Column(
              children: [
                SlideTransition(
                  position: _appBarSlide,
                  child: FadeTransition(
                    opacity: _appBarFade,
                    child: _buildAppBar(context),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FadeTransition(
                          opacity: _heroFade,
                          child: ScaleTransition(
                            scale: _heroScale,
                            child: _buildHeroImage(state),
                          ),
                        ),
                        SlideTransition(
                          position: _titleSlide,
                          child: FadeTransition(
                            opacity: _titleFade,
                            child: _buildEventTitle(state),
                          ),
                        ),
                        SlideTransition(
                          position: _subtitleSlide,
                          child: FadeTransition(
                            opacity: _subtitleFade,
                            child: _buildEventSubtitle(state),
                          ),
                        ),
                        FadeTransition(
                          opacity: _buttonFade,
                          child: ScaleTransition(
                            scale: _buttonScale,
                            child: _buildReserveButton(context, state),
                          ),
                        ),
                        if (state.eventoOggi != null) ...[
                          const SizedBox(height: 15),
                          SlideTransition(
                            position: _sectionSlide,
                            child: FadeTransition(
                              opacity: _sectionFade,
                              child: _buildTonightTitle(context),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SlideTransition(
                            position: _cardSlide,
                            child: FadeTransition(
                              opacity: _cardFade,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 13),
                                child: _buildEventCard(
                                  name: state.eventoOggi!.nome,
                                  time: state.eventoOggi!.orarioString,
                                  imageUrl: state.eventoOggi!.locandinaUrl,
                                ),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
                SlideTransition(
                  position: _navSlide,
                  child: FadeTransition(
                    opacity: _navFade,
                    child: _buildBottomNavigationBar(context),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    // Navbar fissa condivisa: stesso logo (wordmark) e stesse icone
    // (logo + ricerca + persona) di tutte le altre schermate con navbar.
    return const CustomTopBar();
  }

  Widget _buildHeroImage(EventDetailState state) {
    final fotoUrl = state.hottestClub?.fotoUrl;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: double.infinity,
          height: 217,
          color: const Color(0xFF1A1A2E),
          child: fotoUrl != null
              ? CachedNetworkImage(
                  imageUrl: fotoUrl,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => const ImageFallback(),
                )
              : const ImageFallback(),
        ),
      ),
    );
  }

  Widget _buildEventTitle(EventDetailState state) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(13, 25, 13, 0),
      child: Text(
        state.hottestClub?.nome ?? '',
        style: GoogleFonts.inter(
          fontSize: 36,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          letterSpacing: -0.08 * 36,
        ),
      ),
    );
  }

  Widget _buildEventSubtitle(EventDetailState state) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(13, 14, 13, 0),
      child: Text(
        state.hottestClub?.indirizzoCompleto ?? '',
        style: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: Colors.white.withValues(alpha: 0.6),
        ),
      ),
    );
  }

  Widget _buildReserveButton(BuildContext context, EventDetailState state) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(11, 15, 11, 0),
      child: SizedBox(
        width: double.infinity,
        height: 49,
        child: _AnimatedPressButton(
          onPressed: () {
            if (state.hottestClub != null) {
              NavigatorService.pushNamed(
                AppRoutes.clubDetailScreen,
                arguments: state.hottestClub,
              );
            }
          },
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

  Widget _buildTonightTitle(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 13),
      child: Text(
        'Questa sera',
        style: GoogleFonts.inter(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildEventCard({
    required String name,
    required String time,
    String? imageUrl,
  }) {
    return _AnimatedPressButton(
      onPressed: () {},
      child: Container(
        height: 95,
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: 165,
                height: 95,
                color: const Color(0xFF2A2A2A),
                child: imageUrl != null
                    ? CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        memCacheWidth: 495,
                        memCacheHeight: 285,
                        errorWidget: (_, __, ___) => const ImageFallback(),
                      )
                    : const ImageFallback(),
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: GoogleFonts.inter(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: -0.08 * 32,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    time,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: Colors.white.withValues(alpha: 0.5),
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

  Widget _buildBottomNavigationBar(BuildContext context) {
    return BlocBuilder<EventDetailBloc, EventDetailState>(
      builder: (context, state) {
        return Container(
          decoration: const BoxDecoration(
            border: Border(
              top: BorderSide(color: Color(0xFF2A2A2A), width: 0.5),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 10),
          child: Row(
            children: [
              _buildNavItem(context, imagePath: ImageConstant.imgHome, index: 0, isSelected: state.selectedBottomNavIndex == 0),
              _buildNavItem(context, imagePath: ImageConstant.imgShoppingCart, index: 1, isSelected: state.selectedBottomNavIndex == 1),
              _buildNavItem(context, imagePath: ImageConstant.imgBell, index: 2, isSelected: state.selectedBottomNavIndex == 2),
              _buildNavItem(context, imagePath: ImageConstant.imgUser, index: 3, isSelected: state.selectedBottomNavIndex == 3),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNavItem(
    BuildContext context, {
    required String imagePath,
    required int index,
    bool isSelected = false,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: () => context.read<EventDetailBloc>().add(BottomNavItemSelectedEvent(index)),
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
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onPressed();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: widget.child,
      ),
    );
  }
}
