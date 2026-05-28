import 'package:flutter/material.dart';

import '../../core/app_export.dart';
import '../../core/services/location_service.dart';
import '../../core/services/analytics_service.dart';
import '../../core/utils/analytics_mixin.dart';
import '../../theme/onlist_colors.dart';
import '../../theme/onlist_text_styles.dart';
import './bloc/authentication_bloc.dart';
import './models/authentication_model.dart';

class AuthenticationScreen extends StatefulWidget {
  const AuthenticationScreen({Key? key}) : super(key: key);

  static Widget builder(BuildContext context) {
    return BlocProvider<AuthenticationBloc>(
      create: (context) => AuthenticationBloc(AuthenticationState(
        authenticationModel: AuthenticationModel(),
      ))
        ..add(AuthenticationInitialEvent()),
      child: const AuthenticationScreen(),
    );
  }

  @override
  State<AuthenticationScreen> createState() => _AuthenticationScreenState();
}

class _AuthenticationScreenState extends State<AuthenticationScreen> with ScreenAnalytics {
  @override
  String get screenName => 'authentication';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: OnlistColors.onboardingBackground),
        child: BlocConsumer<AuthenticationBloc, AuthenticationState>(
          listener: (context, state) {
            if (state.isLoginSuccess) {
              AnalyticsService.log(event: 'login_success');
              LocationService.shouldShowLocationPrompt().then((show) {
                NavigatorService.pushNamedAndRemoveUntil(
                  show
                      ? AppRoutes.locationPermissionScreen
                      : AppRoutes.eventDetailScreen,
                );
              });
            }
            if (state.needsProfileCompletion) {
              AnalyticsService.log(event: 'registration_oauth_started');
              NavigatorService.pushNamed(
                AppRoutes.completeProfileScreen,
                arguments: {
                  'nome': state.oauthNome,
                  'cognome': state.oauthCognome,
                  'email': state.oauthEmail,
                },
              );
            }
            if (state.errorMessage != null && state.errorMessage!.isNotEmpty) {
              AnalyticsService.log(event: 'login_error', metadata: {'error': state.errorMessage});
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(state.errorMessage!)),
              );
            }
          },
          builder: (context, state) {
            return SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                child: Form(
                  key: state.formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 72),
                      Text('Accedi', style: OnlistTextStyles.display40Regular),
                      const SizedBox(height: 40),
                      _UnderlineField(
                        controller: state.emailController,
                        label: 'Email',
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Inserisci la tua email';
                          if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                              .hasMatch(v)) {
                            return 'Email non valida';
                          }
                          return null;
                        },
                        onChanged: (v) => context
                            .read<AuthenticationBloc>()
                            .add(EmailChangedEvent(email: v)),
                      ),
                      const SizedBox(height: 28),
                      _UnderlinePasswordField(
                        controller: state.passwordController,
                        onChanged: (v) => context
                            .read<AuthenticationBloc>()
                            .add(PasswordChangedEvent(password: v)),
                      ),
                      const SizedBox(height: 40),
                      // Bottoni Accedi / Registrati — impilati e centrati (Figma)
                      Center(
                        child: Column(
                          children: [
                            _WhiteButton(
                              label: 'Accedi',
                              onTap: () => _onTapAccedi(context, state),
                            ),
                            const SizedBox(height: 16),
                            _WhiteButton(
                              label: 'Registrati',
                              onTap: () {
                                AnalyticsService.log(event: 'registration_email_started');
                                NavigatorService.pushNamed(AppRoutes.signUpScreen);
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 60),
                      if (state.isLoading)
                        const Center(
                          child: CircularProgressIndicator(color: OnlistColors.white),
                        )
                      else ...[
                        _AppleButton(
                          onTap: () {
                            AnalyticsService.log(event: 'login_attempt', metadata: {'method': 'apple'});
                            context
                                .read<AuthenticationBloc>()
                                .add(AppleSignInEvent());
                          },
                        ),
                        const SizedBox(height: 12),
                        _GoogleButton(
                          onTap: () {
                            AnalyticsService.log(event: 'login_attempt', metadata: {'method': 'google'});
                            context
                                .read<AuthenticationBloc>()
                                .add(GoogleSignInEvent());
                          },
                        ),
                      ],
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _onTapAccedi(BuildContext context, AuthenticationState state) {
    if (state.formKey?.currentState?.validate() ?? false) {
      AnalyticsService.log(event: 'login_attempt', metadata: {'method': 'email'});
      context.read<AuthenticationBloc>().add(LoginButtonPressedEvent());
    }
  }
}

// ── Underline text field ───────────────────────────────────────────────────────

const TextStyle _kInputStyle = TextStyle(
  fontFamily: 'HelveticaNeue',
  fontSize: 16,
  fontWeight: FontWeight.w400,
  color: OnlistColors.white,
);

InputDecoration _underlineDecoration({Widget? suffixIcon}) {
  return InputDecoration(
    isDense: true,
    filled: false,
    contentPadding: const EdgeInsets.only(top: 8, bottom: 6),
    enabledBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: OnlistColors.white, width: 2)),
    focusedBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: OnlistColors.white, width: 2)),
    errorBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: Colors.redAccent, width: 2)),
    focusedErrorBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: Colors.redAccent, width: 2)),
    errorStyle: const TextStyle(color: Colors.white70),
    suffixIcon: suffixIcon,
  );
}

class _UnderlineField extends StatelessWidget {
  const _UnderlineField({
    required this.label,
    this.controller,
    this.keyboardType,
    this.validator,
    this.onChanged,
  });

  final String label;
  final TextEditingController? controller;
  final TextInputType? keyboardType;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: OnlistTextStyles.formLabel22),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          style: _kInputStyle,
          decoration: _underlineDecoration(),
          validator: validator,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _UnderlinePasswordField extends StatefulWidget {
  const _UnderlinePasswordField(
      {required this.onChanged, this.controller});

  final ValueChanged<String> onChanged;
  final TextEditingController? controller;

  @override
  State<_UnderlinePasswordField> createState() =>
      _UnderlinePasswordFieldState();
}

class _UnderlinePasswordFieldState extends State<_UnderlinePasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Password', style: OnlistTextStyles.formLabel22),
        TextFormField(
          controller: widget.controller,
          obscureText: _obscure,
          style: _kInputStyle,
          decoration: _underlineDecoration(
            suffixIcon: IconButton(
              icon: Icon(
                  _obscure ? Icons.visibility_off : Icons.visibility,
                  color: Colors.white70,
                  size: 20),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
          validator: (v) {
            if (v == null || v.isEmpty) return 'Inserisci la password';
            if (v.length < 6) return 'Minimo 6 caratteri';
            return null;
          },
          onChanged: widget.onChanged,
        ),
      ],
    );
  }
}

// ── Buttons ───────────────────────────────────────────────────────────────────

class _WhiteButton extends StatelessWidget {
  const _WhiteButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      height: 40,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: OnlistColors.white,
          foregroundColor: OnlistColors.black,
          elevation: 0,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ),
        child: Text(label, style: OnlistTextStyles.button16Bold),
      ),
    );
  }
}

class _AppleButton extends StatelessWidget {
  const _AppleButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 47,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.apple, color: OnlistColors.black, size: 24),
        label: Text('Continua con Apple', style: _kSocialLabel),
        style: ElevatedButton.styleFrom(
          backgroundColor: OnlistColors.white,
          foregroundColor: OnlistColors.black,
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(11)),
        ),
      ),
    );
  }
}

class _GoogleButton extends StatelessWidget {
  const _GoogleButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 47,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: SizedBox(
          width: 22,
          height: 22,
          child: CustomPaint(painter: _GoogleLogoPainter()),
        ),
        label: Text('Continua con Google', style: _kSocialLabel),
        style: ElevatedButton.styleFrom(
          backgroundColor: OnlistColors.white,
          foregroundColor: OnlistColors.black,
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(11)),
        ),
      ),
    );
  }
}

const TextStyle _kSocialLabel = TextStyle(
  fontFamily: 'HelveticaNeue',
  fontSize: 16,
  fontWeight: FontWeight.w500,
  color: Color(0xBD000000), // rgba(0,0,0,0.74)
);

// ── Google logo painter ────────────────────────────────────────────────────────

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2;
    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r),
        -1.4, 1.9, true, paint);
    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r),
        -3.3, 1.9, true, paint);
    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r),
        2.5, 1.0, true, paint);
    paint.color = const Color(0xFF34A853);
    canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r),
        3.5, 0.9, true, paint);
    paint.color = Colors.white;
    canvas.drawCircle(Offset(cx, cy), r * 0.62, paint);
    paint.color = const Color(0xFF4285F4);
    canvas.drawRect(
        Rect.fromLTWH(cx, cy - r * 0.22, r, r * 0.44), paint);
    canvas.drawCircle(
        Offset(cx, cy), r * 0.62, Paint()..color = Colors.white);
    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: r * 0.62),
        -0.3, 0.6, true, paint);
    canvas.drawCircle(
        Offset(cx, cy), r * 0.38, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
