import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../core/app_export.dart';
import '../../core/services/location_service.dart';
import '../../routes/page_transitions.dart';
import '../../theme/onlist_colors.dart';
import '../../theme/onlist_text_styles.dart';
import '../../widgets/auth_widgets.dart';
import '../../widgets/glow_card.dart';
import './bloc/verification_bloc.dart';

class VerificationScreen extends StatelessWidget {
  const VerificationScreen({Key? key}) : super(key: key);

  static Widget builder(BuildContext context) {
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final registrationTime =
        args?['registrationTime'] as DateTime? ?? DateTime.now();
    final email = args?['email'] as String? ?? '';
    final password = args?['password'] as String? ?? '';

    return BlocProvider<verificationBloc>(
      create: (context) => verificationBloc(verificationState())
        ..add(verificationInitialEvent(
          registrationTime: registrationTime,
          email: email,
          password: password,
        )),
      child: const VerificationScreen(),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Gradiente fuori dallo Scaffold: così resta a schermo pieno anche quando
    // la tastiera accorcia il body, altrimenti l'ellisse si comprime e lo
    // sfondo cambia aspetto mentre si digita il codice. Lo Scaffold
    // trasparente copre comunque il bianco di default del Material.
    return DecoratedBox(
      decoration:
          const BoxDecoration(gradient: OnlistColors.onboardingBackground),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: BlocConsumer<verificationBloc, verificationState>(
          listener: (context, state) {
            if (state.isVerified) {
              LocationService.shouldShowLocationPrompt().then((show) {
                NavigatorService.pushNamedAndRemoveUntil(
                  show
                      ? AppRoutes.locationPermissionScreen
                      : AppRoutes.eventDetailScreen,
                );
              });
            }
            if (state.errorMessage != null &&
                state.errorMessage == "Verifica prima l'email") {
              _showVerificationDialog(context);
            } else if (state.errorMessage != null &&
                state.errorMessage!.isNotEmpty) {
              showAppErrorDialog(context, state.errorMessage!);
            }
            if (state.emailResentMessage != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text(state.emailResentMessage!),
                    backgroundColor: Colors.green),
              );
            }
          },
          builder: (context, state) {
            return Stack(
              children: [
                // Seconda metà della dissolvenza: la schermata ARRIVA col
                // pannello blu acceso a tutto schermo e poi lo spegne. Sta sotto
                // al contenuto perché nel Figma testo e bottone non cambiano mai
                // — l'unica cosa che si muove è il fondo.
                const _PannelloAcceso(),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: R.sp(36)),
                  child: Column(
                    // Ogni riga occupa tutta la larghezza e centra il proprio
                    // contenuto: così il blocco non dipende dalla larghezza
                    // naturale dei testi e resta al centro dello schermo.
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Titolo a y 370 sul frame 852 (grazie.css, "Group 349").
                      const Spacer(flex: 370),
                      Text(
                        'Grazie\nper esserti registrato!',
                        style: OnlistTextStyles.hn(
                          fontSize: R.sp(32),
                          fontWeight: FontWeight.w500,
                          height: 1.2,
                          color: OnlistColors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: R.sp(25)),
                      Text(
                        // Il Figma scrive "UN EMAIL": qui con l'apostrofo, che
                        // in italiano email è femminile.
                        'A BREVE TI ARRIVERÀ UN’EMAIL DI CONFERMA',
                        style: OnlistTextStyles.hn(
                          fontSize: R.sp(12),
                          fontWeight: FontWeight.w500,
                          color: OnlistColors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: R.sp(30)),
                      GestureDetector(
                        onTap: state.isLoading
                            ? null
                            : () => context
                                .read<verificationBloc>()
                                .add(ResendEmailEvent()),
                        behavior: HitTestBehavior.opaque,
                        child: Text(
                          'Non hai ricevuto l’email? Clicca qui',
                          textAlign: TextAlign.center,
                          style: OnlistTextStyles.hn(
                            fontSize: R.sp(14),
                            color: OnlistColors.white,
                          ).copyWith(
                            decoration: TextDecoration.underline,
                            decorationColor: OnlistColors.white,
                          ),
                        ),
                      ),
                      // Il bottone sta a y 683 sul frame (grazie.css,
                      // "Group 458").
                      const Spacer(flex: 148),
                      Center(
                        child: state.isLoading
                            ? SizedBox(
                                height: R.sp(40),
                                child: const Center(
                                  child: CircularProgressIndicator(
                                      color: OnlistColors.white),
                                ),
                              )
                            // Il Figma scrive "Accedi", ma il bottone non porta
                            // al login: controlla che l'email sia stata
                            // confermata e prosegue. L'etichetta dice quello che
                            // fa, la forma è quella del design.
                            : AuthPrimaryButton(
                                label: 'Ho confermato',
                                onTap: () => context
                                    .read<verificationBloc>()
                                    .add(CheckVerificationEvent()),
                              ),
                      ),
                      SizedBox(height: R.sp(24)),
                      GestureDetector(
                        onTap: () => NavigatorService.pushNamedAndRemoveUntil(
                            AppRoutes.authenticationScreen),
                        behavior: HitTestBehavior.opaque,
                        child: Text(
                          'Torna al login',
                          textAlign: TextAlign.center,
                          style: OnlistTextStyles.hn(
                            fontSize: R.sp(14),
                            color: OnlistColors.white.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                      // Mai meno della barra di sistema, che su Android è più
                      // alta della home indicator per cui il Figma lascia posto.
                      SizedBox(
                        height: math.max(
                          R.sp(87),
                          MediaQuery.paddingOf(context).bottom + R.sp(16),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _showVerificationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Verifica Email'),
        content: const Text(
            'Per favore, verifica la tua email cliccando sul link che ti abbiamo inviato prima di accedere.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

/// Il pannello blu a tutto schermo con cui questa schermata arriva, e che dopo
/// una breve pausa si spegne lasciando lo sfondo scuro.
///
/// **Perché esiste.** Il Figma ha due frame per questa schermata, "Thx 1" e
/// "Thx 2", identici tranne che il primo ha un rettangolo blu a tutto schermo
/// e il secondo no. Non sono due schermate: sono i due estremi di una
/// transizione. Nel video del designer si vede la registrazione dissolversi
/// nel blu acceso, il blu restare un attimo e poi spegnersi. La prima metà la
/// fa la transizione di rotta ([AppTransition.dissolvenza]), la seconda questo
/// widget.
///
/// **I tempi** sono misurati fotogramma per fotogramma su quel video, non
/// scelti a occhio: 330 ms di pausa e 280 ms di spegnimento, quest'ultimo
/// LINEARE (a metà tempo il colore è a metà strada) a differenza della
/// dissolvenza in entrata, che accelera.
class _PannelloAcceso extends StatefulWidget {
  const _PannelloAcceso();

  @override
  State<_PannelloAcceso> createState() => _PannelloAccesoState();
}

class _PannelloAccesoState extends State<_PannelloAcceso>
    with SingleTickerProviderStateMixin {
  /// Quanto il pannello resta acceso dopo che la schermata è arrivata.
  static const Duration _pausa = Duration(milliseconds: 330);

  /// Quanto ci mette a spegnersi.
  static const Duration _spegnimento = Duration(milliseconds: 280);

  late final AnimationController _ctrl =
      AnimationController(vsync: this, duration: _spegnimento);
  Timer? _attesa;

  @override
  void initState() {
    super.initState();
    // La pausa parte da quando la schermata è a posto, cioè a transizione di
    // rotta finita: per questo si somma [kDurataDissolvenza].
    _attesa = Timer(kDurataDissolvenza + _pausa, () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _attesa?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _ctrl,
        // Il pannello si costruisce una volta sola: il builder qui sotto
        // cambia solo l'opacità, non ridisegna il gradiente e il glow.
        child: SizedBox.expand(
          child: GlowCard(
            gradient: OnlistColors.authPanel,
            // A tutto schermo: angoli vivi. Gli angoli tondi del frame Figma
            // sono quelli della cornice del telefono nel mockup.
            radius: 0,
            borderRadius: BorderRadius.zero,
            glowColor: OnlistColors.authPanelGlow,
            glowSigma: R.sp(50), // CSS `inset 0 2px 100px`: sigma = blur / 2
            glowOffset: Offset(0, R.sp(2)),
          ),
        ),
        builder: (context, child) {
          // Finito lo spegnimento il pannello esce di scena: lasciarlo a
          // opacità 0 costerebbe un livello di composizione a schermo intero
          // per tutto il tempo in cui la schermata resta aperta.
          if (_ctrl.isCompleted) return const SizedBox.shrink();
          return Opacity(opacity: 1.0 - _ctrl.value, child: child);
        },
      ),
    );
  }
}
