import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/app_export.dart';
import '../../widgets/custom_image_view.dart';
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
    with TickerProviderStateMixin {
  late AnimationController _staggerController;
  late AnimationController _heroController;

  // Staggered animations
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
      duration: Duration(milliseconds: 1400),
    );

    _heroController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 800),
    );

    // AppBar: 0ms - 400ms
    _appBarFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _staggerController, curve: Interval(0, 0.28, curve: Curves.easeOut)),
    );
    _appBarSlide = Tween<Offset>(begin: Offset(0, -0.5), end: Offset.zero).animate(
      CurvedAnimation(parent: _staggerController, curve: Interval(0, 0.28, curve: Curves.easeOut)),
    );

    // Hero image: 100ms - 600ms
    _heroFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _staggerController, curve: Interval(0.07, 0.43, curve: Curves.easeOut)),
    );
    _heroScale = Tween<double>(begin: 0.95, end: 1).animate(
      CurvedAnimation(parent: _staggerController, curve: Interval(0.07, 0.43, curve: Curves.easeOut)),
    );

    // Title: 250ms - 700ms
    _titleFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _staggerController, curve: Interval(0.18, 0.50, curve: Curves.easeOut)),
    );
    _titleSlide = Tween<Offset>(begin: Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(parent: _staggerController, curve: Interval(0.18, 0.50, curve: Curves.easeOut)),
    );

    // Subtitle: 350ms - 800ms
    _subtitleFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _staggerController, curve: Interval(0.25, 0.57, curve: Curves.easeOut)),
    );
    _subtitleSlide = Tween<Offset>(begin: Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(parent: _staggerController, curve: Interval(0.25, 0.57, curve: Curves.easeOut)),
    );

    // Button: 450ms - 900ms
    _buttonFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _staggerController, curve: Interval(0.32, 0.64, curve: Curves.easeOut)),
    );
    _buttonScale = Tween<double>(begin: 0.9, end: 1).animate(
      CurvedAnimation(parent: _staggerController, curve: Interval(0.32, 0.64, curve: Curves.easeOutBack)),
    );

    // "Questa sera" section: 600ms - 1050ms
    _sectionFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _staggerController, curve: Interval(0.43, 0.75, curve: Curves.easeOut)),
    );
    _sectionSlide = Tween<Offset>(begin: Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(parent: _staggerController, curve: Interval(0.43, 0.75, curve: Curves.easeOut)),
    );

    // Event card: 750ms - 1200ms
    _cardFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _staggerController, curve: Interval(0.54, 0.86, curve: Curves.easeOut)),
    );
    _cardSlide = Tween<Offset>(begin: Offset(0.15, 0), end: Offset.zero).animate(
      CurvedAnimation(parent: _staggerController, curve: Interval(0.54, 0.86, curve: Curves.easeOut)),
    );

    // Bottom nav: 900ms - 1400ms
    _navFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _staggerController, curve: Interval(0.64, 1.0, curve: Curves.easeOut)),
    );
    _navSlide = Tween<Offset>(begin: Offset(0, 1), end: Offset.zero).animate(
      CurvedAnimation(parent: _staggerController, curve: Interval(0.64, 1.0, curve: Curves.easeOut)),
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
      backgroundColor: Color(0xFF0D0D0D),
      body: BlocBuilder<EventDetailBloc, EventDetailState>(
        builder: (context, state) {
          return SafeArea(
            child: Column(
              children: [
                // AppBar with slide down + fade
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
                        // Hero image with scale + fade
                        FadeTransition(
                          opacity: _heroFade,
                          child: ScaleTransition(
                            scale: _heroScale,
                            child: _buildHeroImage(context),
                          ),
                        ),
                        // Title with slide up + fade
                        SlideTransition(
                          position: _titleSlide,
                          child: FadeTransition(
                            opacity: _titleFade,
                            child: _buildEventTitle(context),
                          ),
                        ),
                        // Subtitle with slide up + fade
                        SlideTransition(
                          position: _subtitleSlide,
                          child: FadeTransition(
                            opacity: _subtitleFade,
                            child: _buildEventSubtitle(context),
                          ),
                        ),
                        // Button with scale + fade
                        FadeTransition(
                          opacity: _buttonFade,
                          child: ScaleTransition(
                            scale: _buttonScale,
                            child: _buildReserveButton(context),
                          ),
                        ),
                        SizedBox(height: 15),
                        // Section title with slide up + fade
                        SlideTransition(
                          position: _sectionSlide,
                          child: FadeTransition(
                            opacity: _sectionFade,
                            child: _buildTonightTitle(context),
                          ),
                        ),
                        SizedBox(height: 12),
                        // Card with slide right + fade
                        SlideTransition(
                          position: _cardSlide,
                          child: FadeTransition(
                            opacity: _cardFade,
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 13),
                              child: _buildEventCard(
                                name: 'The Club',
                                time: '23:00 - 04:00',
                                imageUrl:
                                    'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=400&q=80',
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
                // Bottom nav with slide up + fade
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
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
          Padding(
            padding: EdgeInsets.only(right: 10),
            child: Icon(
              Icons.search,
              color: Colors.white,
              size: 34,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroImage(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: double.infinity,
          height: 217,
          decoration: BoxDecoration(
            color: Color(0xFF1A1A2E),
            image: DecorationImage(
              image: NetworkImage(
                'https://images.unsplash.com/photo-1545128485-c400e7702796?w=800&q=80',
              ),
              fit: BoxFit.cover,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEventTitle(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(13, 25, 13, 0),
      child: Text(
        'Amnesia Club',
        style: GoogleFonts.inter(
          fontSize: 36,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          letterSpacing: -0.08 * 36,
        ),
      ),
    );
  }

  Widget _buildEventSubtitle(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(13, 14, 13, 0),
      child: Text(
        'Milano - Via Alfonso Gatto',
        style: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: Colors.white.withValues(alpha: 0.6),
        ),
      ),
    );
  }

  Widget _buildReserveButton(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(11, 15, 11, 0),
      child: SizedBox(
        width: double.infinity,
        height: 49,
        child: _AnimatedPressButton(
          onPressed: () {
            context.read<EventDetailBloc>().add(ReserveButtonPressedEvent());
          },
          child: Container(
            width: double.infinity,
            height: 49,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF0009FF),
                  Color(0xFF000599),
                ],
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
      padding: EdgeInsets.symmetric(horizontal: 13),
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
          color: Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: 165,
                height: 95,
                color: Color(0xFF2A2A2A),
                child: imageUrl != null
                    ? Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.music_note,
                          color: Color(0xFF666666),
                          size: 32,
                        ),
                      )
                    : Icon(
                        Icons.music_note,
                        color: Color(0xFF666666),
                        size: 32,
                      ),
              ),
            ),
            SizedBox(width: 9),
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
                  SizedBox(height: 4),
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
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: Color(0xFF2A2A2A),
                width: 0.5,
              ),
            ),
          ),
          padding: EdgeInsets.symmetric(horizontal: 36, vertical: 10),
          child: Row(
            children: [
              _buildNavItem(
                context,
                imagePath: ImageConstant.imgHome,
                index: 0,
                isSelected: state.selectedBottomNavIndex == 0,
              ),
              _buildNavItem(
                context,
                imagePath: ImageConstant.imgShoppingCart,
                index: 1,
                isSelected: state.selectedBottomNavIndex == 1,
              ),
              _buildNavItem(
                context,
                imagePath: ImageConstant.imgBell,
                index: 2,
                isSelected: state.selectedBottomNavIndex == 2,
              ),
              _buildNavItem(
                context,
                imagePath: ImageConstant.imgUser,
                index: 3,
                isSelected: state.selectedBottomNavIndex == 3,
              ),
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
        onTap: () {
          context.read<EventDetailBloc>().add(
                BottomNavItemSelectedEvent(index),
              );
        },
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          height: 31,
          child: Center(
            child: AnimatedScale(
              scale: isSelected ? 1.2 : 1.0,
              duration: Duration(milliseconds: 200),
              curve: Curves.easeOutBack,
              child: AnimatedOpacity(
                opacity: isSelected ? 1.0 : 0.5,
                duration: Duration(milliseconds: 200),
                child: CustomImageView(
                  imagePath: imagePath,
                  height: 28,
                  width: 28,
                  color: isSelected ? Colors.white : Color(0xFF888888),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Animated button with press scale effect
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
      duration: Duration(milliseconds: 150),
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
