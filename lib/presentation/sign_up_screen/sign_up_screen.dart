import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_export.dart';
import '../../core/legal/legal_versions.dart';
import '../../core/services/location_service.dart';
import '../../core/utils/age_calculator.dart';
import '../../core/services/analytics_service.dart';
import '../../core/utils/analytics_mixin.dart';
import '../../theme/onlist_colors.dart';
import '../../theme/onlist_text_styles.dart';
import '../../widgets/auth_widgets.dart';
import '../../widgets/onlist_wordmark.dart';
import '../../widgets/phone_field/onlist_phone_field.dart';
import './bloc/sign_up_bloc.dart';
import './models/sign_up_model.dart';

/// Stesso controllo email della schermata di accesso.
const String _kEmailPattern = r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({Key? key}) : super(key: key);

  static Widget builder(BuildContext context) {
    // Args opzionali: arrivano quando lo screen è aperto dopo un login OAuth
    // (Google/Apple) per pre-riempire i campi noti e saltare la verifica
    // email a fine flusso. Letti QUI (context della route, valido) e non
    // dentro `create:`, perché lì `ModalRoute.of` lancerebbe un errore:
    // provider vieta di ascoltare un InheritedWidget in una callback `create`,
    // che viene eseguita una sola volta e non gestisce gli aggiornamenti.
    final args = ModalRoute.of(context)?.settings.arguments as Map?;
    return BlocProvider<SignUpBloc>(
      create: (ctx) {
        final bloc = SignUpBloc(SignUpState(signUpModel: SignUpModel()))
          ..add(SignUpInitialEvent());
        if (args != null) {
          bloc.add(SignUpPrefillEvent(
            nome: args['nome'] as String?,
            cognome: args['cognome'] as String?,
            email: args['email'] as String?,
            telefono: args['telefono'] as String?,
            dataNascita: args['dataNascita'] as DateTime?,
            oauthVerified: args['oauthVerified'] == true,
          ));
        }
        return bloc;
      },
      child: const SignUpScreen(),
    );
  }

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> with ScreenAnalytics {
  @override
  String get screenName => 'sign_up';

  @override
  Widget build(BuildContext context) {
    // Il gradiente sta FUORI dallo Scaffold: `resizeToAvoidBottomInset`
    // accorcia il body all'apertura della tastiera e, siccome il raggio
    // dell'ellisse è una frazione della dimensione del box, il gradiente si
    // comprimerebbe cambiando aspetto mentre si scrive. Qui resta a schermo
    // pieno; lo Scaffold trasparente ci si appoggia sopra (e copre anche il
    // default Material bianco che causava lampi bianchi in transizione).
    return DecoratedBox(
      decoration:
          const BoxDecoration(gradient: OnlistColors.onboardingBackground),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        // Il pannello blu è ancorato alle proporzioni dello schermo: se la
        // tastiera accorciasse il body, salterebbe su e giù a ogni campo
        // toccato. Resta fermo, e il form scorre sotto la tastiera grazie al
        // padding con `viewInsets` dentro lo SingleChildScrollView.
        resizeToAvoidBottomInset: false,
        body: GestureDetector(
          // Tap fuori dai campi → chiude la tastiera (richiesta UX dell'utente).
          behavior: HitTestBehavior.opaque,
          onTap: () => FocusScope.of(context).unfocus(),
          child: BlocConsumer<SignUpBloc, SignUpState>(
            listener: (context, state) {
              if (state.isSuccess) {
                AnalyticsService.log(event: 'registration_email_success');
                if (state.oauthVerified) {
                  // Email già verificata dal provider OAuth: niente schermata di
                  // verifica, andiamo direttamente alla concessione posizione
                  // (o alla città se la posizione è già stata gestita).
                  LocationService.shouldShowLocationPrompt().then((show) {
                    NavigatorService.pushNamedAndRemoveUntil(
                      show
                          ? AppRoutes.locationPermissionScreen
                          : AppRoutes.homeScreen,
                    );
                  });
                } else {
                  NavigatorService.pushNamedAndRemoveUntil(
                    AppRoutes.verificationScreen,
                    arguments: {
                      'registrationTime': DateTime.now(),
                      'email': state.signUpModel?.email,
                      'password': state.signUpModel?.password,
                    },
                  );
                }
              }
              if (state.errorMessage != null &&
                  state.errorMessage!.isNotEmpty) {
                AnalyticsService.log(
                    event: 'registration_error',
                    metadata: {'error': state.errorMessage});
                if (state.errorMessage == SignUpBloc.emailTakenMessage) {
                  _showEmailTakenDialog(context);
                } else {
                  showAppErrorDialog(context, state.errorMessage!);
                }
              }
            },
            builder: (context, state) {
              return Column(
                children: [
                  // ── 0 → 205: sfondo scuro con il logo ────────────────────
                  Expanded(
                    flex: 205,
                    child: Column(
                      children: [
                        // Immagine 206×87 a y 60: le sole lettere sono alte
                        // 62,2 e partono a y 84,7 (l’alone della pallina
                        // sfora sopra il riquadro).
                        const Spacer(flex: 85),
                        OnlistWordmark(height: R.sp(62.2)),
                        const Spacer(flex: 58),
                      ],
                    ),
                  ),
                  // ── 205 → 852: pannello blu ──────────────────────────────
                  Expanded(
                    flex: 647,
                    child: AuthPanel(
                      child: Form(
                        key: state.formKey,
                        child: Column(
                          children: [
                            SizedBox(height: R.sp(18)),
                            const AuthDash(),
                            SizedBox(height: R.sp(30)),
                            Text(
                              'Registrati',
                              style: OnlistTextStyles.hn(
                                fontSize: R.sp(36),
                                fontWeight: FontWeight.w400,
                                height: 1.0,
                                color: OnlistColors.white,
                              ),
                            ),
                            SizedBox(height: R.sp(34)),
                            // I campi scorrono. Il Figma ne disegna cinque, qui
                            // ce ne sono sei — il telefono finisce in
                            // `utenti_numeri_telefono` e senza non si completa
                            // la registrazione — più la spunta legale
                            // obbligatoria, che nel Figma non c’è. Su schermi
                            // corti si scorre invece di andare in overflow.
                            Expanded(
                              child: SingleChildScrollView(
                                // In fondo: il margine di respiro, mai meno
                                // della barra di sistema (su Android è più
                                // alta della home indicator), più l'altezza
                                // della tastiera — che qui non accorcia il
                                // body, quindi va lasciata come spazio da
                                // scorrere.
                                padding: EdgeInsets.only(
                                  bottom: math.max(
                                        R.sp(40),
                                        MediaQuery.paddingOf(context).bottom +
                                            R.sp(8),
                                      ) +
                                      MediaQuery.viewInsetsOf(context).bottom,
                                ),
                                child: Column(
                                  children: [
                                    SizedBox(
                                      width: R.sp(AuthMetrics.fieldW),
                                      child: AuthPillField(
                                        hint: 'Nome',
                                        controller: state.firstNameController,
                                        textInputAction: TextInputAction.next,
                                        validator: (v) {
                                          if (v == null || v.length < 2) {
                                            return 'Il nome deve avere almeno 2 caratteri';
                                          }
                                          return null;
                                        },
                                        onChanged: (v) => context
                                            .read<SignUpBloc>()
                                            .add(FirstNameChangedEvent(
                                                firstName: v)),
                                      ),
                                    ),
                                    SizedBox(height: R.sp(38)),
                                    SizedBox(
                                      width: R.sp(AuthMetrics.fieldW),
                                      child: AuthPillField(
                                        hint: 'Cognome',
                                        controller: state.lastNameController,
                                        textInputAction: TextInputAction.next,
                                        validator: (v) {
                                          if (v == null || v.length < 2) {
                                            return 'Il cognome deve avere almeno 2 caratteri';
                                          }
                                          return null;
                                        },
                                        onChanged: (v) => context
                                            .read<SignUpBloc>()
                                            .add(LastNameChangedEvent(
                                                lastName: v)),
                                      ),
                                    ),
                                    SizedBox(height: R.sp(38)),
                                    GestureDetector(
                                      onTap: () => _selectDate(context, state),
                                      child: AbsorbPointer(
                                        child: SizedBox(
                                          width: R.sp(AuthMetrics.fieldW),
                                          child: AuthPillField(
                                            hint: 'Data di nascita',
                                            controller: state.dobController,
                                            validator: (_) {
                                              if (state.signUpModel?.dob ==
                                                  null) {
                                                return 'Inserisci la data di nascita';
                                              }
                                              final age = DateTime.now().year -
                                                  state.signUpModel!.dob!.year;
                                              if (age < 14) {
                                                return 'Devi avere almeno 14 anni';
                                              }
                                              return null;
                                            },
                                            onChanged: (_) {},
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (state.signUpModel?.dob != null) ...[
                                      SizedBox(height: R.sp(6)),
                                      SizedBox(
                                        width: R.sp(AuthMetrics.fieldW),
                                        child: Text(
                                          AgeCalculator.isAdult(
                                                  state.signUpModel!.dob!)
                                              ? 'Utente maggiorenne'
                                              : 'Utente minorenne',
                                          style: OnlistTextStyles.hn(
                                            fontSize: R.sp(13),
                                            color: AgeCalculator.isAdult(
                                                    state.signUpModel!.dob!)
                                                ? Colors.greenAccent
                                                : Colors.orangeAccent,
                                          ),
                                        ),
                                      ),
                                    ],
                                    SizedBox(height: R.sp(38)),
                                    SizedBox(
                                      width: R.sp(AuthMetrics.fieldW),
                                      child: AuthPillField(
                                        hint: 'Email',
                                        controller: state.emailController,
                                        keyboardType:
                                            TextInputType.emailAddress,
                                        textInputAction: TextInputAction.next,
                                        // Con OAuth l’email è quella verificata
                                        // dal provider e identifica l'account:
                                        // modificarla qui creerebbe un
                                        // disallineamento con l’identità
                                        // Google/Apple.
                                        readOnly: state.oauthVerified,
                                        validator: (v) {
                                          if (v == null || v.isEmpty) {
                                            return 'Inserisci la tua email';
                                          }
                                          if (!RegExp(_kEmailPattern)
                                              .hasMatch(v)) {
                                            return 'Email non valida';
                                          }
                                          return null;
                                        },
                                        onChanged: (v) => context
                                            .read<SignUpBloc>()
                                            .add(EmailChangedEvent(email: v)),
                                      ),
                                    ),
                                    // Con OAuth (Google/Apple) l’autenticazione
                                    // è già fatta dal provider: la password non
                                    // serve e il campo è nascosto.
                                    if (!state.oauthVerified) ...[
                                      SizedBox(height: R.sp(38)),
                                      SizedBox(
                                        width: R.sp(AuthMetrics.fieldW),
                                        child: AuthPasswordField(
                                          controller: state.passwordController,
                                          textInputAction: TextInputAction.next,
                                          validator: (v) {
                                            if (v == null || v.length < 8) {
                                              return 'La password deve avere almeno 8 caratteri';
                                            }
                                            return null;
                                          },
                                          onChanged: (v) => context
                                              .read<SignUpBloc>()
                                              .add(PasswordChangedEvent(
                                                  password: v)),
                                        ),
                                      ),
                                    ],
                                    SizedBox(height: R.sp(38)),
                                    SizedBox(
                                      width: R.sp(AuthMetrics.fieldW),
                                      child: OnlistPhoneField(
                                        controller: state.phoneController,
                                        initialIso: 'IT',
                                        stile: OnlistPhoneFieldStyle.pill,
                                        hintText: 'Telefono',
                                        onChanged: (iso, _, nn, e164) {
                                          context.read<SignUpBloc>().add(
                                              PhoneChangedEvent(
                                                  phone: e164,
                                                  countryIso: iso,
                                                  nationalNumber: nn));
                                        },
                                      ),
                                    ),
                                    SizedBox(height: R.sp(38)),
                                    // Spunta obbligatoria: Privacy Policy +
                                    // Termini. Il bottone "Registrati" resta
                                    // disabilitato finché non è spuntata
                                    // (guardia duplicata anche in SignUpBloc).
                                    SizedBox(
                                      width: R.sp(AuthMetrics.fieldW),
                                      child: _LegalConsentCheckbox(
                                        checked: state.legalConsent,
                                        onChanged: (v) => context
                                            .read<SignUpBloc>()
                                            .add(LegalConsentChangedEvent(
                                                accepted: v)),
                                      ),
                                    ),
                                    SizedBox(height: R.sp(32)),
                                    if (state.isLoading)
                                      const CircularProgressIndicator(
                                          color: OnlistColors.white)
                                    else
                                      AuthPrimaryButton(
                                        label: 'Registrati',
                                        enabled: state.legalConsent,
                                        onTap: () {
                                          AnalyticsService.log(
                                              event: 'registration_attempt');
                                          context
                                              .read<SignUpBloc>()
                                              .add(SubmitSignUpEvent());
                                        },
                                      ),
                                    SizedBox(height: R.sp(20)),
                                    GestureDetector(
                                      onTap: () => NavigatorService.goBack(),
                                      child: Text(
                                        'Hai già un account? Accedi',
                                        style: OnlistTextStyles.hn(
                                          fontSize: R.sp(14),
                                          color: OnlistColors.white,
                                        ).copyWith(
                                          decoration: TextDecoration.underline,
                                          decorationColor: OnlistColors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
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

  Future<void> _selectDate(BuildContext context, SignUpState state) async {
    final now = DateTime.now();
    // Default a 18 anni fa esatti (year-aware: niente drift dovuto ai bisestili
    // che con Duration(days: 365*18) faceva atterrare al 2008 anziché al 2007).
    final initial =
        state.signUpModel?.dob ?? DateTime(now.year - 18, now.month, now.day);
    final first = DateTime(1900);

    final bloc = context.read<SignUpBloc>();

    if (Platform.isIOS) {
      // Picker iOS nativo (ruota). Modal popup ancorato al fondo, sfondo
      // sistema (rispetta light/dark del device).
      DateTime temp = initial;
      await showCupertinoModalPopup<void>(
        context: context,
        builder: (ctx) {
          return Container(
            height: 300,
            color: CupertinoColors.systemBackground.resolveFrom(ctx),
            child: SafeArea(
              top: false,
              child: Column(
                children: [
                  // Toolbar con Annulla / Fatto, in stile iOS.
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: CupertinoColors.separator.resolveFrom(ctx),
                          width: 0.5,
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        CupertinoButton(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: const Text('Annulla'),
                        ),
                        CupertinoButton(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          onPressed: () {
                            bloc.add(DobChangedEvent(dob: temp));
                            Navigator.of(ctx).pop();
                          },
                          child: const Text(
                            'Fatto',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: CupertinoDatePicker(
                      mode: CupertinoDatePickerMode.date,
                      initialDateTime: initial,
                      minimumDate: first,
                      maximumDate: now,
                      onDateTimeChanged: (d) => temp = d,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
      return;
    }

    // Android (e altri): picker Material nativo, senza override custom — usa
    // il tema di sistema (in dark mode è già scuro).
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: now,
    );
    if (picked != null && context.mounted) {
      bloc.add(DobChangedEvent(dob: picked));
    }
  }

  /// Email già registrata: offre di andare al login invece di registrarsi.
  void _showEmailTakenDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Email già registrata'),
        content: const Text(SignUpBloc.emailTakenMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              // La schermata di registrazione è stata aperta dal login: torniamo lì.
              NavigatorService.goBack();
            },
            child: const Text('Accedi'),
          ),
        ],
      ),
    );
  }
}

/// Spunta obbligatoria alla registrazione: consenso a Privacy Policy e Termini.
///
/// Il click sui link "Privacy Policy" e "Termini" apre le pagine
/// corrispondenti sul sito (URL in [kPrivacyUrl] / [kTermsUrl]) nel browser
/// esterno, così l'utente può leggerle senza uscire dallo stack di navigazione.
class _LegalConsentCheckbox extends StatelessWidget {
  const _LegalConsentCheckbox({
    required this.checked,
    required this.onChanged,
  });

  final bool checked;
  final ValueChanged<bool> onChanged;

  Future<void> _openLegal(String url) async {
    final uri = Uri.parse(url);
    // externalApplication: apre il browser di sistema, non un webview interno.
    // Se il sito non è raggiungibile (offline) fallisce silenziosamente:
    // l'utente non è bloccato dalla registrazione.
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Checkbox custom con bordo bianco, per rimanere coerente col design
        // scuro/underline della schermata. Tap sul quadrato o sull'etichetta.
        GestureDetector(
          onTap: () => onChanged(!checked),
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: 22,
            height: 22,
            margin: const EdgeInsets.only(top: 2, right: 12),
            decoration: BoxDecoration(
              color: checked ? OnlistColors.white : Colors.transparent,
              border: Border.all(color: OnlistColors.white, width: 1.6),
              borderRadius: BorderRadius.circular(4),
            ),
            alignment: Alignment.center,
            child: checked
                ? const Icon(Icons.check, size: 16, color: OnlistColors.black)
                : null,
          ),
        ),
        Expanded(
          child: GestureDetector(
            onTap: () => onChanged(!checked),
            behavior: HitTestBehavior.opaque,
            child: Text.rich(
              TextSpan(
                style: const TextStyle(
                  fontFamily: 'OnlistHN',
                  fontSize: 13,
                  height: 1.4,
                  color: Colors.white,
                ),
                children: [
                  const TextSpan(text: 'Ho letto e accetto la '),
                  TextSpan(
                    text: 'Privacy Policy',
                    style: const TextStyle(
                      decoration: TextDecoration.underline,
                      fontWeight: FontWeight.w600,
                    ),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () => _openLegal(kPrivacyUrl),
                  ),
                  const TextSpan(text: ' e i '),
                  TextSpan(
                    text: 'Termini e condizioni',
                    style: const TextStyle(
                      decoration: TextDecoration.underline,
                      fontWeight: FontWeight.w600,
                    ),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () => _openLegal(kTermsUrl),
                  ),
                  const TextSpan(
                      text:
                          ' di OnListClub. Confermo di avere almeno 14 anni.'),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
