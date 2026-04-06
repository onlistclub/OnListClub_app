import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/app_export.dart';
import '../../core/services/location_service.dart';
import './bloc/authentication_bloc.dart';
import './models/authentication_model.dart';

class AuthenticationScreen extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0000FF),
      body: BlocConsumer<AuthenticationBloc, AuthenticationState>(
        listener: (context, state) {
          if (state.isLoginSuccess) {
            LocationService.shouldShowLocationPrompt().then((show) {
              NavigatorService.pushNamedAndRemoveUntil(
                show
                    ? AppRoutes.locationPermissionScreen
                    : AppRoutes.eventDetailScreen,
              );
            });
          }
          if (state.needsProfileCompletion) {
            NavigatorService.pushNamed(
              AppRoutes.completeProfileScreen,
              arguments: {
                'nome': state.oauthNome,
                'cognome': state.oauthCognome,
              },
            );
          }
          if (state.errorMessage != null && state.errorMessage!.isNotEmpty) {
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
                    // Titolo
                    Text(
                      'Accedi',
                      style: GoogleFonts.inter(
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 40),
                    // Campo Email
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
                    // Campo Password
                    _UnderlinePasswordField(
                      controller: state.passwordController,
                      onChanged: (v) => context
                          .read<AuthenticationBloc>()
                          .add(PasswordChangedEvent(password: v)),
                    ),
                    const SizedBox(height: 40),
                    // Bottoni Accedi / Registrati affiancati e centrati
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _BlackButton(
                          label: 'Accedi',
                          onTap: () => _onTapAccedi(context, state),
                          width: 130,
                        ),
                        const SizedBox(width: 16),
                        _BlackButton(
                          label: 'Registrati',
                          onTap: () =>
                              NavigatorService.pushNamed(AppRoutes.signUpScreen),
                          width: 130,
                        ),
                      ],
                    ),
                    const SizedBox(height: 60),
                    // OAuth buttons
                    if (state.isLoading)
                      const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      )
                    else ...[
                      _AppleButton(
                        onTap: () => context
                            .read<AuthenticationBloc>()
                            .add(AppleSignInEvent()),
                      ),
                      const SizedBox(height: 12),
                      _GoogleButton(
                        onTap: () => context
                            .read<AuthenticationBloc>()
                            .add(GoogleSignInEvent()),
                      ),
                      const SizedBox(height: 12),
                      _StaffButton(
                        onTap: () =>
                            ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content:
                                  Text('Accesso staff disponibile a breve')),
                        ),
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
    );
  }

  void _onTapAccedi(BuildContext context, AuthenticationState state) {
    if (state.formKey?.currentState?.validate() ?? false) {
      context.read<AuthenticationBloc>().add(LoginButtonPressedEvent());
    }
  }
}

// ── Underline text field ───────────────────────────────────────────────────────

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
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: GoogleFonts.inter(
          fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.inter(
            fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
        enabledBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: Colors.white, width: 1.5)),
        focusedBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: Colors.white, width: 2)),
        errorBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: Colors.redAccent, width: 1.5)),
        focusedErrorBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: Colors.redAccent, width: 2)),
        errorStyle: const TextStyle(color: Colors.white70),
        filled: false,
        contentPadding: const EdgeInsets.only(bottom: 8),
      ),
      validator: validator,
      onChanged: onChanged,
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
    return TextFormField(
      controller: widget.controller,
      obscureText: _obscure,
      style: GoogleFonts.inter(
          fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
      decoration: InputDecoration(
        labelText: 'Password',
        labelStyle: GoogleFonts.inter(
            fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
        enabledBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: Colors.white, width: 1.5)),
        focusedBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: Colors.white, width: 2)),
        errorBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: Colors.redAccent, width: 1.5)),
        focusedErrorBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: Colors.redAccent, width: 2)),
        errorStyle: const TextStyle(color: Colors.white70),
        filled: false,
        contentPadding: const EdgeInsets.only(bottom: 8),
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
    );
  }
}

// ── Buttons ───────────────────────────────────────────────────────────────────

class _BlackButton extends StatelessWidget {
  const _BlackButton(
      {required this.label, required this.onTap, this.width});

  final String label;
  final VoidCallback onTap;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: 48,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30)),
        ),
        child: Text(label,
            style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white)),
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
      height: 52,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.apple, color: Colors.white, size: 22),
        label: Text('Continua con Apple',
            style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white)),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30)),
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
      height: 52,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: SizedBox(
          width: 20,
          height: 20,
          child: CustomPaint(painter: _GoogleLogoPainter()),
        ),
        label: Text('Continua con Google',
            style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87)),
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          side: BorderSide.none,
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30)),
        ),
      ),
    );
  }
}

class _StaffButton extends StatelessWidget {
  const _StaffButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF0A0066),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30)),
        ),
        child: Text('Accedi come Staff',
            style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white)),
      ),
    );
  }
}

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
