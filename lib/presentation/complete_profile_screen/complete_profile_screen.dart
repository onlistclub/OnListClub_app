import 'package:flutter/material.dart';
import '../../core/app_export.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_edit_text.dart';
import './bloc/complete_profile_bloc.dart';
import '../../core/utils/age_calculator.dart';
import 'package:intl_phone_number_input/intl_phone_number_input.dart';

class CompleteProfileScreen extends StatelessWidget {
  const CompleteProfileScreen({Key? key}) : super(key: key);

  static Widget builder(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final nome = args?['nome'] as String?;
    final cognome = args?['cognome'] as String?;
    final email = args?['email'] as String?;
    return BlocProvider<CompleteProfileBloc>(
      create: (context) => CompleteProfileBloc(const CompleteProfileState())
        ..add(CompleteProfileInitialEvent(
          prefillNome: nome,
          prefillCognome: cognome,
          prefillEmail: email,
        )),
      child: const CompleteProfileScreen(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1600BC),
              appTheme.indigo_900,
              appTheme.black_900_01,
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: BlocConsumer<CompleteProfileBloc, CompleteProfileState>(
          listener: (context, state) {
            if (state.isSuccess) {
              NavigatorService.pushNamedAndRemoveUntil(
                AppRoutes.eventDetailScreen,
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
              child: Container(
                width: double.infinity,
                height: double.infinity,
                padding: EdgeInsets.symmetric(horizontal: 28.h),
                child: SingleChildScrollView(
                  child: Form(
                    key: state.formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: 40.h),
                        Container(
                          margin: EdgeInsets.only(left: 20.h),
                          child: Text(
                            'Completa il profilo',
                            style: TextStyleHelper
                                .instance.headline32ExtraBoldSFCompact
                                .copyWith(height: 1.22),
                          ),
                        ),
                        SizedBox(height: 8.h),
                        Container(
                          margin: EdgeInsets.only(left: 20.h),
                          child: Text(
                            'Inserisci i dati mancanti per completare la registrazione.',
                            style: TextStyleHelper.instance.title16ExtraBoldSFCompact
                                .copyWith(color: appTheme.white_A700.withValues(alpha: 0.7)),
                          ),
                        ),
                        SizedBox(height: 32.h),
                        // Email (read-only — pre-compilata da Google OAuth)
                        if (state.emailController != null &&
                            state.emailController!.text.isNotEmpty) ...[
                          _buildLabel('Email'),
                          CustomEditText(
                            controller: state.emailController,
                            placeholder: 'Email',
                            inputType: 'EMAIL',
                            enabled: false,
                            textStyle: TextStyleHelper.instance.title16ExtraBoldSFCompact
                                .copyWith(color: appTheme.white_A700.withValues(alpha: 0.5)),
                            fillColor: Colors.white.withValues(alpha: 0.05),
                            contentPadding: EdgeInsets.all(12.h),
                          ),
                          SizedBox(height: 4.h),
                          Container(
                            margin: EdgeInsets.only(left: 12.h, bottom: 12.h),
                            child: Text(
                              'Email proveniente dal tuo account Google',
                              style: TextStyleHelper.instance.title16ExtraBoldSFCompact.copyWith(
                                color: appTheme.white_A700.withValues(alpha: 0.4),
                                fontSize: 11.fSize,
                              ),
                            ),
                          ),
                        ],
                        _buildLabel('Nome'),
                        CustomEditText(
                          controller: state.firstNameController,
                          placeholder: 'Nome',
                          inputType: 'TEXT',
                          textStyle: TextStyleHelper.instance.title16ExtraBoldSFCompact,
                          contentPadding: EdgeInsets.all(12.h),
                          validator: (value) {
                            if (value == null || value.length < 2) {
                              return 'Il nome deve avere almeno 2 caratteri';
                            }
                            return null;
                          },
                          onChanged: (value) {
                            context.read<CompleteProfileBloc>().add(
                                  CompleteProfileFirstNameChangedEvent(firstName: value),
                                );
                          },
                        ),
                        SizedBox(height: 16.h),
                        _buildLabel('Cognome'),
                        CustomEditText(
                          controller: state.lastNameController,
                          placeholder: 'Cognome',
                          inputType: 'TEXT',
                          textStyle: TextStyleHelper.instance.title16ExtraBoldSFCompact,
                          contentPadding: EdgeInsets.all(12.h),
                          validator: (value) {
                            if (value == null || value.length < 2) {
                              return 'Il cognome deve avere almeno 2 caratteri';
                            }
                            return null;
                          },
                          onChanged: (value) {
                            context.read<CompleteProfileBloc>().add(
                                  CompleteProfileLastNameChangedEvent(lastName: value),
                                );
                          },
                        ),
                        SizedBox(height: 16.h),
                        _buildLabel('Telefono'),
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
                            leadingPadding: 12,
                            trailingSpace: true,
                          ),
                          ignoreBlank: false,
                          autoValidateMode: AutovalidateMode.disabled,
                          selectorTextStyle: TextStyleHelper
                              .instance.title16ExtraBoldSFCompact
                              .copyWith(color: Colors.white),
                          formatInput: false,
                          keyboardType: TextInputType.phone,
                          inputDecoration: InputDecoration(
                            hintText: 'Telefono',
                            hintStyle: TextStyleHelper.instance.title16ExtraBoldSFCompact
                                .copyWith(color: Colors.white54),
                            fillColor: Colors.white.withValues(alpha: 0.1),
                            filled: true,
                            contentPadding: EdgeInsets.all(12.h),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10.h),
                              borderSide: const BorderSide(),
                            ),
                            errorStyle: const TextStyle(color: Colors.redAccent),
                          ),
                          onInputChanged: (phone) {
                            final iso = phone.isoCode;
                            final dial = phone.dialCode ?? '';
                            final full = (phone.phoneNumber ?? '').replaceAll(' ', '');
                            final cleaned = full.replaceAll(RegExp(r'\D'), '');
                            final dialClean = dial.replaceAll('+', '');
                            final nn = cleaned.startsWith(dialClean)
                                ? cleaned.substring(dialClean.length)
                                : cleaned;
                            context.read<CompleteProfileBloc>().add(
                                  CompleteProfilePhoneChangedEvent(
                                    phone: full,
                                    countryIso: iso,
                                    nationalNumber: nn,
                                  ),
                                );
                          },
                        ),
                        SizedBox(height: 16.h),
                        _buildLabel('Data di nascita'),
                        GestureDetector(
                          onTap: () => _selectDate(context),
                          child: AbsorbPointer(
                            child: CustomEditText(
                              controller: state.dobController,
                              placeholder: 'GG/MM/AAAA',
                              inputType: 'TEXT',
                              textStyle: TextStyleHelper.instance.title16ExtraBoldSFCompact,
                              contentPadding: EdgeInsets.all(12.h),
                              validator: (value) {
                                if (state.model?.dob == null) {
                                  return 'Inserisci la data di nascita';
                                }
                                final age = DateTime.now().year - state.model!.dob!.year;
                                if (age < 14) {
                                  return 'Devi avere almeno 14 anni';
                                }
                                return null;
                              },
                            ),
                          ),
                        ),
                        if (state.model?.dob != null) ...[
                          SizedBox(height: 8.h),
                          Builder(builder: (context) {
                            final isAdult = AgeCalculator.isAdult(state.model!.dob!);
                            return Text(
                              isAdult ? 'Utente maggiorenne' : 'Utente minorenne',
                              style: TextStyleHelper.instance.title16ExtraBoldSFCompact
                                  .copyWith(
                                color: isAdult ? Colors.green : Colors.orange,
                                fontSize: 14.fSize,
                              ),
                            );
                          }),
                        ],
                        SizedBox(height: 32.h),
                        state.isLoading
                            ? Center(
                                child: CircularProgressIndicator(
                                    color: appTheme.white_A700))
                            : Container(
                                alignment: Alignment.center,
                                child: CustomButton(
                                  text: 'Continua',
                                  onPressed: () {
                                    context
                                        .read<CompleteProfileBloc>()
                                        .add(CompleteProfileSubmitEvent());
                                  },
                                  backgroundColor: appTheme.white_A700,
                                  textColor: appTheme.black_900,
                                  borderRadius: 10.h,
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 30.h, vertical: 2.h),
                                  fontSize: 16.fSize,
                                  fontFamily: 'SF Compact',
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                        SizedBox(height: 40.h),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Container(
      margin: EdgeInsets.only(left: 20.h, bottom: 8.h),
      child: Text(
        text,
        style: TextStyleHelper.instance.title16ExtraBoldSFCompact.copyWith(
          color: appTheme.white_A700,
          fontSize: 14.fSize,
        ),
      ),
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 14)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            primaryColor: appTheme.indigo_900,
            colorScheme: ColorScheme.light(primary: appTheme.indigo_900),
            buttonTheme:
                const ButtonThemeData(textTheme: ButtonTextTheme.primary),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && context.mounted) {
      context
          .read<CompleteProfileBloc>()
          .add(CompleteProfileDobChangedEvent(dob: picked));
    }
  }
}
