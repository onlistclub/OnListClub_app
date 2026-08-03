import 'dart:io' show Platform;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../core/app_export.dart';
import '../../core/services/location_service.dart';
import '../../core/utils/age_calculator.dart';
import '../../core/services/analytics_service.dart';
import '../../core/utils/analytics_mixin.dart';
import '../../theme/onlist_colors.dart';
import '../../theme/onlist_text_styles.dart';
import '../../widgets/phone_field/onlist_phone_field.dart';
import './bloc/sign_up_bloc.dart';
import './models/sign_up_model.dart';

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
      decoration: const BoxDecoration(gradient: OnlistColors.onboardingBackground),
      child: Scaffold(
      backgroundColor: Colors.transparent,
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
            if (state.errorMessage != null && state.errorMessage!.isNotEmpty) {
              AnalyticsService.log(event: 'registration_error', metadata: {'error': state.errorMessage});
              if (state.errorMessage == SignUpBloc.emailTakenMessage) {
                _showEmailTakenDialog(context);
              } else {
                showAppErrorDialog(context, state.errorMessage!);
              }
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
                      const SizedBox(height: 40),
                      Text('Registrati', style: OnlistTextStyles.display40Regular),
                      const SizedBox(height: 36),
                      _UnderlineField(
                        label: 'Nome',
                        controller: state.firstNameController,
                        validator: (v) {
                          if (v == null || v.length < 2) {
                            return 'Il nome deve avere almeno 2 caratteri';
                          }
                          return null;
                        },
                        onChanged: (v) => context
                            .read<SignUpBloc>()
                            .add(FirstNameChangedEvent(firstName: v)),
                      ),
                      const SizedBox(height: 24),
                      _UnderlineField(
                        label: 'Cognome',
                        controller: state.lastNameController,
                        validator: (v) {
                          if (v == null || v.length < 2) {
                            return 'Il cognome deve avere almeno 2 caratteri';
                          }
                          return null;
                        },
                        onChanged: (v) => context
                            .read<SignUpBloc>()
                            .add(LastNameChangedEvent(lastName: v)),
                      ),
                      const SizedBox(height: 24),
                      GestureDetector(
                        onTap: () => _selectDate(context, state),
                        child: AbsorbPointer(
                          child: _UnderlineField(
                            label: 'Data di nascita',
                            controller: state.dobController,
                            validator: (_) {
                              if (state.signUpModel?.dob == null) {
                                return 'Inserisci la data di nascita';
                              }
                              final age = DateTime.now().year -
                                  state.signUpModel!.dob!.year;
                              if (age < 14) return 'Devi avere almeno 14 anni';
                              return null;
                            },
                            onChanged: (_) {},
                          ),
                        ),
                      ),
                      if (state.signUpModel?.dob != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          AgeCalculator.isAdult(state.signUpModel!.dob!)
                              ? 'Utente maggiorenne'
                              : 'Utente minorenne',
                          style: TextStyle(
                            fontFamily: 'OnlistHN',
                            fontSize: 13,
                            color: AgeCalculator.isAdult(state.signUpModel!.dob!)
                                ? Colors.greenAccent
                                : Colors.orangeAccent,
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      _UnderlineField(
                        label: 'Email',
                        controller: state.emailController,
                        keyboardType: TextInputType.emailAddress,
                        // Con OAuth l'email è quella verificata dal provider e
                        // identifica l'account: modificarla qui creerebbe un
                        // disallineamento con l'identità Google/Apple.
                        readOnly: state.oauthVerified,
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Inserisci la tua email';
                          if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                              .hasMatch(v)) {
                            return 'Email non valida';
                          }
                          return null;
                        },
                        onChanged: (v) => context
                            .read<SignUpBloc>()
                            .add(EmailChangedEvent(email: v)),
                      ),
                      // Con OAuth (Google/Apple) l'autenticazione è già fatta
                      // dal provider: la password non serve e il campo è nascosto.
                      if (!state.oauthVerified) ...[
                        const SizedBox(height: 24),
                        _UnderlinePasswordField(
                          controller: state.passwordController,
                          onChanged: (v) => context
                              .read<SignUpBloc>()
                              .add(PasswordChangedEvent(password: v)),
                        ),
                      ],
                      const SizedBox(height: 24),
                      Text('Telefono', style: OnlistTextStyles.formLabel22),
                      const SizedBox(height: 4),
                      OnlistPhoneField(
                        controller: state.phoneController,
                        initialIso: 'IT',
                        onChanged: (iso, _, nn, e164) {
                          context.read<SignUpBloc>().add(PhoneChangedEvent(
                              phone: e164,
                              countryIso: iso,
                              nationalNumber: nn));
                        },
                      ),
                      const SizedBox(height: 48),
                      Center(
                        child: state.isLoading
                            ? const CircularProgressIndicator(color: OnlistColors.white)
                            : _WhiteButton(
                                label: 'Registrati',
                                onTap: () {
                                  AnalyticsService.log(event: 'registration_attempt');
                                  context
                                      .read<SignUpBloc>()
                                      .add(SubmitSignUpEvent());
                                },
                              ),
                      ),
                      const SizedBox(height: 20),
                      Center(
                        child: GestureDetector(
                          onTap: () => NavigatorService.goBack(),
                          child: Text(
                            'Hai già un account? Accedi',
                            style: const TextStyle(
                              fontFamily: 'OnlistHN',
                              fontSize: 14,
                              color: Colors.white70,
                              decoration: TextDecoration.underline,
                              decorationColor: Colors.white70,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
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
    final initial = state.signUpModel?.dob ??
        DateTime(now.year - 18, now.month, now.day);
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

// ── Underline fields ──────────────────────────────────────────────────────────

const TextStyle _kInputStyle = TextStyle(
  fontFamily: 'OnlistHN',
  fontSize: 16,
  fontWeight: FontWeight.w400,
  color: OnlistColors.white,
);

InputDecoration _underlineDecoration({Widget? suffixIcon, String? hintText}) {
  return InputDecoration(
    isDense: true,
    filled: false,
    hintText: hintText,
    hintStyle: const TextStyle(
      fontFamily: 'OnlistHN',
      fontSize: 16,
      fontWeight: FontWeight.w400,
      color: Colors.white54,
    ),
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
    this.readOnly = false,
  });

  final String label;
  final TextEditingController? controller;
  final TextInputType? keyboardType;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: OnlistTextStyles.formLabel22),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          readOnly: readOnly,
          // Grigio "disabilitato" del design system: rende evidente che il
          // campo non è editabile, senza toglierlo dal form.
          style: readOnly
              ? _kInputStyle.copyWith(color: OnlistColors.textSecondary)
              : _kInputStyle,
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
            if (v == null || v.length < 8) {
              return 'La password deve avere almeno 8 caratteri';
            }
            return null;
          },
          onChanged: widget.onChanged,
        ),
      ],
    );
  }
}

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
