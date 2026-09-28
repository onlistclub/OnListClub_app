import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_export.dart';
import '../../core/services/location_service.dart';
import '../../core/services/analytics_service.dart';
import '../../core/utils/analytics_mixin.dart';
import '../../theme/onlist_colors.dart';
import '../../theme/onlist_text_styles.dart';
import '../../widgets/auth_widgets.dart';
import '../../widgets/onlist_wordmark.dart';
import './bloc/authentication_bloc.dart';
import './models/authentication_model.dart';

/// Schermata di accesso — design NUOVO del 27/09
/// (`docs/figma_screen/off/NUOVO/login.css`, `off/02 - Autenticazione.png`).
///
/// Il frame è 393×852 e le coordinate di `login.css` sono ASSOLUTE su quel
/// frame (a differenza di `registrazione.css`, che le dà relative al suo
/// contenitore). Riferimenti usati qui, in px di design:
///
///   logo 206×87 a y 117 · pannello blu da y 325 a fondo schermo
///   trattino 339 · "Accedi" 365 · Email 427 · Password 512
///   "Password dimenticata?" 568 · bottone Accedi 598 · Registrati 659
///   divisore "oppure" 712 · Apple/Google 750 · fondo 852
///
/// Niente `SafeArea`: il frame di design comprende già la barra di stato (la
/// prima cosa disegnata, il logo, è a 117 px dall'alto) e il pannello deve
/// arrivare a filo del bordo inferiore, sotto la home indicator.
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

class _AuthenticationScreenState extends State<AuthenticationScreen>
    with ScreenAnalytics {
  @override
  String get screenName => 'authentication';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Sfondo nero: evita la striscia bianca (scaffold di default) nella zona
      // safe-area in basso, dove il gradiente termina comunque in nero.
      backgroundColor: OnlistColors.black,
      // La tastiera si sovrappone al pannello senza spostare/spingere il
      // layout: i campi Email/Password restano fissi mentre si scrive.
      resizeToAvoidBottomInset: false,
      body: GestureDetector(
        // Tap fuori dai campi → chiude la tastiera (richiesta UX dell'utente).
        behavior: HitTestBehavior.opaque,
        onTap: () => FocusScope.of(context).unfocus(),
        child: DecoratedBox(
          decoration:
              const BoxDecoration(gradient: OnlistColors.onboardingBackground),
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
                // Niente più schermata "completa profilo": apriamo la
                // registrazione standard con i campi noti pre-riempiti.
                // L'email è già verificata dal provider OAuth, quindi al
                // submit salteremo la verifica.
                NavigatorService.pushNamed(
                  AppRoutes.signUpScreen,
                  arguments: {
                    'oauthVerified': true,
                    'nome': state.oauthNome,
                    'cognome': state.oauthCognome,
                    'email': state.oauthEmail,
                    'telefono': state.oauthTelefono,
                    'dataNascita': state.oauthDataNascita,
                  },
                );
              }
              if (state.errorMessage != null &&
                  state.errorMessage!.isNotEmpty) {
                AnalyticsService.log(
                    event: 'login_error',
                    metadata: {'error': state.errorMessage});
                showAppErrorDialog(context, state.errorMessage!);
              }
            },
            builder: (context, state) {
              return Column(
                children: [
                  // ── 0 → 325: sfondo scuro con il logo ──────────────────
                  Expanded(
                    flex: 325,
                    child: Column(
                      children: [
                        // Il riquadro del widget è quello delle sole lettere:
                        // l'immagine 206×87 a y 117 ha le lettere alte 62,2 a
                        // y 141,7 (l'alone della pallina sfora sopra).
                        const Spacer(flex: 142),
                        OnlistWordmark(height: R.sp(62.2)),
                        const Spacer(flex: 121),
                      ],
                    ),
                  ),
                  // ── 325 → 852: pannello blu ────────────────────────────
                  Expanded(
                    flex: 527,
                    child: AuthPanel(
                      child: Form(
                        key: state.formKey,
                        // I `flex` degli Spacer sono i gap del Figma in px:
                        // si stringono tutti insieme quando compare il testo
                        // di un errore di validazione, senza overflow.
                        child: Column(
                          children: [
                            const Spacer(flex: 14),
                            const AuthDash(),
                            const Spacer(flex: 23),
                            Text(
                              'Accedi',
                              style: OnlistTextStyles.hn(
                                fontSize: R.sp(36),
                                fontWeight: FontWeight.w400,
                                height: 1.0,
                                color: OnlistColors.white,
                              ),
                            ),
                            const Spacer(flex: 26),
                            SizedBox(
                              width: R.sp(AuthMetrics.fieldW),
                              child: AuthPillField(
                                hint: 'Email',
                                controller: state.emailController,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                validator: (v) {
                                  if (v == null || v.isEmpty) {
                                    return 'Inserisci la tua email';
                                  }
                                  if (!RegExp(
                                          r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                                      .hasMatch(v)) {
                                    return 'Email non valida';
                                  }
                                  return null;
                                },
                                onChanged: (v) => context
                                    .read<AuthenticationBloc>()
                                    .add(EmailChangedEvent(email: v)),
                              ),
                            ),
                            const Spacer(flex: 37),
                            SizedBox(
                              width: R.sp(AuthMetrics.fieldW),
                              child: AuthPasswordField(
                                controller: state.passwordController,
                                textInputAction: TextInputAction.done,
                                validator: (v) {
                                  if (v == null || v.isEmpty) {
                                    return 'Inserisci la password';
                                  }
                                  if (v.length < 6) return 'Minimo 6 caratteri';
                                  return null;
                                },
                                onChanged: (v) => context
                                    .read<AuthenticationBloc>()
                                    .add(PasswordChangedEvent(password: v)),
                              ),
                            ),
                            const Spacer(flex: 8),
                            SizedBox(
                              width: R.sp(AuthMetrics.fieldW),
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: GestureDetector(
                                  onTap: () =>
                                      _passwordDimenticata(context, state),
                                  behavior: HitTestBehavior.opaque,
                                  child: Text(
                                    'Password dimenticata?',
                                    style: OnlistTextStyles.hn(
                                      fontSize: R.sp(10),
                                      fontWeight: FontWeight.w500,
                                      color: OnlistColors.white,
                                    ).copyWith(
                                      decoration: TextDecoration.underline,
                                      decorationColor: OnlistColors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const Spacer(flex: 18),
                            AuthPrimaryButton(
                              label: 'Accedi',
                              onTap: () => _onTapAccedi(context, state),
                            ),
                            const Spacer(flex: 21),
                            AuthSmallButton(
                              label: 'Registrati',
                              onTap: () {
                                AnalyticsService.log(
                                    event: 'registration_email_started');
                                NavigatorService.pushNamed(
                                    AppRoutes.signUpScreen);
                              },
                            ),
                            const Spacer(flex: 17),
                            const _DivisoreOppure(),
                            const Spacer(flex: 29),
                            SizedBox(
                              height: R.sp(54),
                              child: state.isLoading
                                  ? const Center(
                                      child: CircularProgressIndicator(
                                          color: OnlistColors.white),
                                    )
                                  : Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        _AppleButton(
                                          onTap: () {
                                            AnalyticsService.log(
                                                event: 'login_attempt',
                                                metadata: {'method': 'apple'});
                                            context
                                                .read<AuthenticationBloc>()
                                                .add(AppleSignInEvent());
                                          },
                                        ),
                                        SizedBox(width: R.sp(9)),
                                        _GoogleButton(
                                          onTap: () {
                                            AnalyticsService.log(
                                                event: 'login_attempt',
                                                metadata: {'method': 'google'});
                                            context
                                                .read<AuthenticationBloc>()
                                                .add(GoogleSignInEvent());
                                          },
                                        ),
                                      ],
                                    ),
                            ),
                            // Ultimo margine fisso, non uno Spacer: sotto ci
                            // può essere la barra di navigazione di Android,
                            // più alta della home indicator per cui il Figma
                            // lascia 48 px. Si prende il maggiore dei due,
                            // così i bottoni social non finiscono mai sotto.
                            SizedBox(
                              height: math.max(
                                R.sp(48),
                                MediaQuery.paddingOf(context).bottom + R.sp(8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  void _onTapAccedi(BuildContext context, AuthenticationState state) {
    if (state.formKey?.currentState?.validate() ?? false) {
      AnalyticsService.log(
          event: 'login_attempt', metadata: {'method': 'email'});
      context.read<AuthenticationBloc>().add(LoginButtonPressedEvent());
    }
  }

  /// "Password dimenticata?" — manda il link di reimpostazione.
  ///
  /// Il link è nuovo in questo design. Finora il reset si poteva chiedere solo
  /// dal profilo, cioè da dentro l'app: ma chi ha dimenticato la password è
  /// esattamente chi NON riesce a entrare. Stessa chiamata e stesso
  /// `redirectTo` del profilo, così il flusso via browser resta uno solo.
  Future<void> _passwordDimenticata(
      BuildContext context, AuthenticationState state) async {
    final controller = TextEditingController(
      text: state.emailController?.text.trim() ?? '',
    );

    final conferma = await showAdaptiveDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog.adaptive(
        title: const Text('Password dimenticata'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Ti mandiamo un link per reimpostarla. A che email?'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.emailAddress,
              autofocus: true,
              decoration: const InputDecoration(hintText: 'la-tua@email.it'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Invia'),
          ),
        ],
      ),
    );

    final email = controller.text.trim();
    controller.dispose();
    if (conferma != true || !context.mounted) return;

    if (email.isEmpty ||
        !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      showAppErrorDialog(context, 'Inserisci un indirizzo email valido.');
      return;
    }

    AnalyticsService.log(event: 'password_reset_requested');
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(
        email,
        redirectTo: 'https://www.onlistclub.com/reset-password',
      );
    } catch (e) {
      // Non diciamo se l'email esiste o no: sarebbe un modo per scoprire chi è
      // iscritto. Il messaggio resta lo stesso in ogni caso.
      debugPrint('[Auth] resetPasswordForEmail: $e');
    }
    if (!context.mounted) return;
    showAppErrorDialog(
      context,
      'Se esiste un account con questa email, riceverai il link per reimpostare la password.',
      title: 'Email inviata',
    );
  }
}

// ── Divisore "oppure" ─────────────────────────────────────────────────────────

/// Due righe da 145 px con "oppure" in mezzo (CSS "Group 464": 351 px a x 21).
class _DivisoreOppure extends StatelessWidget {
  const _DivisoreOppure();

  @override
  Widget build(BuildContext context) {
    final Widget riga = Container(
      width: R.sp(145),
      height: 1,
      color: OnlistColors.white,
    );
    return SizedBox(
      width: R.sp(351),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          riga,
          Text(
            'oppure',
            style: OnlistTextStyles.hn(
              fontSize: R.sp(10),
              fontWeight: FontWeight.w400,
              color: OnlistColors.white,
            ),
          ),
          riga,
        ],
      ),
    );
  }
}

// ── Bottoni social ────────────────────────────────────────────────────────────

// Misure dell'INCHIOSTRO dei due loghi rispetto alla dimensione richiesta.
//
// Servono perché i due loghi riempiono il proprio riquadro in modo molto
// diverso, e montandoli fianco a fianco con lo stesso distacco il risultato è
// quello segnalato nel documento "LAST - Dettagli design da correggere": mela
// staccata dalla scritta, G appiccicata. Misurato sul tuo screenshot: 31 px di
// spazio dopo la mela contro quasi zero dopo la G, a parità di `SizedBox`.
//
// I valori della mela sono misurati su uno SCREENSHOT DEL TELEFONO: a
// `size: 28,36` l'inchiostro è 18,0 × 21,3 px, centrato nel suo riquadro.
//
// Non fidarsi di una sonda in `flutter test` per queste misure: il primo
// tentativo dava 76×75 (quasi quadrata) con il centro 13 px più in alto, e
// quei numeri hanno mandato la mela 4 px sotto la scritta. Nei widget test il
// font delle icone Material non si carica e si finisce per misurare il
// rettangolo di sostituzione, non il glifo. La mela vera è più ALTA che larga.
//
// Quelli della G sono calcolati sul viewBox 48 dell'SVG qui sotto: il disegno
// occupa x 2…45,1 e y 2…46.
const double _kInkApplePerLato = 0.635;
const double _kInkAppleAltezza = 0.75;
const double _kInkGooglePerLato = 0.898;
const double _kInkGoogleAltezza = 0.917;

/// Dimensione del logo Google come da Figma (login.css: 23,2×23,2).
const double _kGoogleSize = 23.2;

/// Altezza del disegno vero, uguale per i due loghi: è quella della G alla
/// misura del Figma, e la mela ci viene portata sopra.
const double _kAltezzaLogo = _kGoogleSize * _kInkGoogleAltezza;

/// Dimensione da chiedere a `Icons.apple` perché il suo disegno risulti alto
/// quanto quello della G.
const double _kAppleSize = _kAltezzaLogo / _kInkAppleAltezza;

/// Riquadro stretto sull'INCHIOSTRO del logo invece che sulla sua cornice.
///
/// Così i 5 px di distacco del Figma sono 5 px veri per entrambi i bottoni, e
/// i due loghi risultano della stessa altezza e allineati alla scritta.
class _LogoInchiostro extends StatelessWidget {
  const _LogoInchiostro({
    required this.child,
    required this.larghezza,
    required this.altezza,
  });

  final Widget child;
  final double larghezza;
  final double altezza;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: larghezza,
      height: altezza,
      // L'OverflowBox centra il disegno nel riquadro e lo lascia sforare: il
      // riquadro serve a misurare lo spazio che il logo occupa nella riga,
      // non a ritagliarlo.
      child: OverflowBox(
        maxWidth: double.infinity,
        maxHeight: double.infinity,
        child: child,
      ),
    );
  }
}

/// Pillola social: icona + etichetta, entrambe centrate (CSS: padding 0 15,
/// gap 5, raggio 62, altezza 54).
class _SocialPill extends StatelessWidget {
  const _SocialPill({
    required this.onTap,
    required this.icon,
    required this.label,
    required this.width,
    required this.background,
    required this.labelColor,
  });

  final VoidCallback onTap;
  final Widget icon;
  final String label;
  final double width;
  final Color background;
  final Color labelColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: R.sp(width),
      height: R.sp(54),
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: background,
          foregroundColor: labelColor,
          elevation: 0,
          padding: EdgeInsets.symmetric(horizontal: R.sp(15)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(R.sp(62)),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon,
            SizedBox(width: R.sp(5)),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.visible,
                softWrap: false,
                style: OnlistTextStyles.hn(
                  fontSize: R.sp(19),
                  // Il Figma dice 590 (SF Pro Semibold). Nel bundle non c'è la
                  // faccia 600: chiederla cade comunque sul 700, quindi lo
                  // scriviamo esplicito (vedi OnlistTextStyles).
                  fontWeight: FontWeight.w700,
                  color: labelColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AppleButton extends StatelessWidget {
  const _AppleButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _SocialPill(
      onTap: onTap,
      width: 128,
      background: OnlistColors.authButtonLight,
      labelColor: OnlistColors.black,
      icon: _LogoInchiostro(
        larghezza: R.sp(_kAppleSize * _kInkApplePerLato),
        altezza: R.sp(_kAltezzaLogo),
        // Niente spostamento: la mela è già centrata nel suo riquadro. Un
        // tentativo di "correggerla" verso il basso l'aveva mandata fuori
        // asse rispetto alla scritta (vedi il commento sulle misure sopra).
        child: Icon(Icons.apple,
            color: OnlistColors.black, size: R.sp(_kAppleSize)),
      ),
      label: 'Apple',
    );
  }
}

class _GoogleButton extends StatelessWidget {
  const _GoogleButton({required this.onTap});
  final VoidCallback onTap;

  // Logo "G" ufficiale di Google (brand colors: #4285F4 / #34A853 / #FBBC05 /
  // #EA4335). SVG inline per evitare di aggiungere un asset.
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
    return _SocialPill(
      onTap: onTap,
      width: 136,
      background: OnlistColors.authButtonGoogle,
      labelColor: OnlistColors.white,
      icon: _LogoInchiostro(
        larghezza: R.sp(_kGoogleSize * _kInkGooglePerLato),
        altezza: R.sp(_kAltezzaLogo),
        // La G è già centrata nel suo riquadro: niente da spostare.
        child: SvgPicture.string(_googleGSvg,
            width: R.sp(_kGoogleSize), height: R.sp(_kGoogleSize)),
      ),
      label: 'Google',
    );
  }
}
