import 'package:flutter/material.dart';
import 'package:intl_phone_number_input/intl_phone_number_input.dart';

import '../../core/app_export.dart';
import '../../core/utils/age_calculator.dart';
import '../../core/services/analytics_service.dart';
import '../../core/utils/analytics_mixin.dart';
import '../../theme/onlist_colors.dart';
import '../../theme/onlist_text_styles.dart';
import './bloc/sign_up_bloc.dart';
import './models/sign_up_model.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({Key? key}) : super(key: key);

  static Widget builder(BuildContext context) {
    return BlocProvider<SignUpBloc>(
      create: (context) => SignUpBloc(SignUpState(
        signUpModel: SignUpModel(),
      ))
        ..add(SignUpInitialEvent()),
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
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: OnlistColors.onboardingBackground),
        child: BlocConsumer<SignUpBloc, SignUpState>(
          listener: (context, state) {
            if (state.isSuccess) {
              AnalyticsService.log(event: 'registration_email_success');
              NavigatorService.pushNamedAndRemoveUntil(
                AppRoutes.verificationScreen,
                arguments: {
                  'registrationTime': DateTime.now(),
                  'email': state.signUpModel?.email,
                  'password': state.signUpModel?.password,
                },
              );
            }
            if (state.errorMessage != null && state.errorMessage!.isNotEmpty) {
              AnalyticsService.log(event: 'registration_error', metadata: {'error': state.errorMessage});
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
                            fontFamily: 'HelveticaNeue',
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
                      const SizedBox(height: 24),
                      _UnderlinePasswordField(
                        controller: state.passwordController,
                        onChanged: (v) => context
                            .read<SignUpBloc>()
                            .add(PasswordChangedEvent(password: v)),
                      ),
                      const SizedBox(height: 24),
                      Text('Telefono', style: OnlistTextStyles.formLabel22),
                      const SizedBox(height: 4),
                      InternationalPhoneNumberInput(
                        textFieldController: state.phoneController,
                        initialValue: PhoneNumber(isoCode: 'IT'),
                        countries: const ['IT', 'CH', 'FR', 'DE', 'ES'],
                        locale: 'it_IT',
                        selectorConfig: const SelectorConfig(
                          selectorType: PhoneInputSelectorType.DIALOG,
                          showFlags: true,
                          useEmoji: false,
                          setSelectorButtonAsPrefixIcon: false,
                          leadingPadding: 0,
                          trailingSpace: true,
                        ),
                        ignoreBlank: false,
                        autoValidateMode: AutovalidateMode.disabled,
                        selectorTextStyle: _kInputStyle,
                        textStyle: _kInputStyle,
                        formatInput: false,
                        keyboardType: TextInputType.phone,
                        inputDecoration: _underlineDecoration(
                          hintText: 'Numero di telefono',
                        ),
                        onInputChanged: (phone) {
                          final iso = phone.isoCode;
                          final dial = phone.dialCode ?? '';
                          final full =
                              (phone.phoneNumber ?? '').replaceAll(' ', '');
                          final cleaned = full.replaceAll(RegExp(r'\D'), '');
                          final dialClean = dial.replaceAll('+', '');
                          final nn = cleaned.startsWith(dialClean)
                              ? cleaned.substring(dialClean.length)
                              : cleaned;
                          context.read<SignUpBloc>().add(PhoneChangedEvent(
                              phone: full,
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
                              fontFamily: 'HelveticaNeue',
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
    );
  }

  Future<void> _selectDate(BuildContext context, SignUpState state) async {
    final picked = await showDatePicker(
      context: context,
      initialDate:
          DateTime.now().subtract(const Duration(days: 365 * 18)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Colors.white,
            onPrimary: Color(0xFF0000FF),
            surface: Color(0xFF0A0066),
            onSurface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null && context.mounted) {
      context.read<SignUpBloc>().add(DobChangedEvent(dob: picked));
    }
  }
}

// ── Underline fields ──────────────────────────────────────────────────────────

const TextStyle _kInputStyle = TextStyle(
  fontFamily: 'HelveticaNeue',
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
      fontFamily: 'HelveticaNeue',
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
