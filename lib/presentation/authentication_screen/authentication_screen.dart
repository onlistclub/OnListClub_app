import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

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
      // Sfondo nero: evita la striscia bianca (scaffold di default) nella zona
      // safe-area in basso, dove il gradiente termina comunque in nero.
      backgroundColor: OnlistColors.black,
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
              showAppErrorDialog(context, state.errorMessage!);
            }
          },
          builder: (context, state) {
            return SafeArea(
              child: SingleChildScrollView(
                // Margine laterale proporzionale (Figma: left 39 su 393 ≈ 9.9%)
                padding: EdgeInsets.symmetric(horizontal: R.w(9.9), vertical: 24),
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
                      const SizedBox(height: 40),
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
                            const SizedBox(height: 22),
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
                        const SizedBox(height: 22),
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
    // Campo compatto come nel Figma: la riga sta vicino alla label e il testo
    // digitato si appoggia sulla riga (vedi textAlignVertical: bottom).
    contentPadding: const EdgeInsets.only(top: 2, bottom: 2),
    enabledBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: OnlistColors.white, width: 3)),
    focusedBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: OnlistColors.white, width: 3)),
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
          textAlignVertical: TextAlignVertical.bottom,
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
          textAlignVertical: TextAlignVertical.bottom,
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

  // Logo "G" ufficiale di Google (brand colors: #4285F4 / #34A853 / #FBBC05 / #EA4335).
  // SVG inline per evitare di aggiungere un asset.
  static const String _googleGSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48">
  <path fill="#4285F4" d="M45.12 24.5c0-1.56-.14-3.06-.4-4.5H24v8.51h11.84c-.51 2.75-2.06 5.08-4.39 6.64v5.52h7.11c4.16-3.83 6.56-9.47 6.56-16.17z"/>
  <path fill="#34A853" d="M24 46c5.94 0 10.92-1.97 14.56-5.33l-7.11-5.52c-1.97 1.32-4.49 2.1-7.45 2.1-5.73 0-10.58-3.87-12.31-9.07H4.34v5.7C7.96 41.07 15.4 46 24 46z"/>
  <path fill="#FBBC05" d="M11.69 28.18C11.25 26.86 11 25.45 11 24s.25-2.86.69-4.18v-5.7H4.34C2.85 17.09 2 20.45 2 24c0 3.55.85 6.91 2.34 9.88l7.35-5.7z"/>
  <path fill="#EA4335" d="M24 10.75c3.23 0 6.13 1.11 8.41 3.29l6.31-6.31C34.91 4.18 29.93 2 24 2 15.4 2 7.96 6.93 4.34 14.12l7.35 5.7c1.73-5.2 6.58-9.07 12.31-9.07z"/>
</svg>
''';

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 47,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: SvgPicture.string(_googleGSvg, width: 24, height: 24),
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
  fontSize: 19.48, // Figma: SF Pro/Roboto 19.48px
  fontWeight: FontWeight.w500,
  color: Color(0xBD000000), // rgba(0,0,0,0.74)
);

