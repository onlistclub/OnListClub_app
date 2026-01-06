import 'package:flutter/material.dart';
import '../../core/app_export.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_edit_text.dart';
import './bloc/sign_up_bloc.dart';
import './models/sign_up_model.dart';
// No custom country model
import '../../core/utils/age_calculator.dart';
import 'package:intl_phone_field/intl_phone_field.dart';

class SignUpScreen extends StatelessWidget {
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
        child: BlocConsumer<SignUpBloc, SignUpState>(
          listener: (context, state) {
            if (state.isSuccess) {
              // Pass credentials and time to Verification Screen
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
                            'Registrati',
                            style: TextStyleHelper
                                .instance.headline32ExtraBoldSFCompact
                                .copyWith(height: 1.22),
                          ),
                        ),
                        SizedBox(height: 36.h),
                        // Nome
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
                            context.read<SignUpBloc>().add(FirstNameChangedEvent(firstName: value));
                          },
                        ),
                        SizedBox(height: 16.h),
                        // Cognome
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
                            context.read<SignUpBloc>().add(LastNameChangedEvent(lastName: value));
                          },
                        ),
                        SizedBox(height: 16.h),
                        // Email
                        _buildLabel('Email'),
                        CustomEditText(
                          controller: state.emailController,
                          placeholder: 'Email',
                          inputType: 'EMAIL',
                          textStyle: TextStyleHelper.instance.title16ExtraBoldSFCompact,
                          contentPadding: EdgeInsets.all(12.h),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Inserisci la tua email';
                            }
                            if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                              return 'Inserisci un\'email valida';
                            }
                            return null;
                          },
                          onChanged: (value) {
                            context.read<SignUpBloc>().add(EmailChangedEvent(email: value));
                          },
                        ),
                        SizedBox(height: 16.h),
                        // Password
                        _buildLabel('Password'),
                        CustomEditText(
                          controller: state.passwordController,
                          placeholder: 'Password',
                          inputType: 'PASSWORD',
                          passwordField: true,
                          textStyle: TextStyleHelper.instance.title16ExtraBoldSFCompact,
                          contentPadding: EdgeInsets.all(12.h),
                          validator: (value) {
                            if (value == null || value.length < 8) {
                              return 'La password deve avere almeno 8 caratteri';
                            }
                            return null;
                          },
                          onChanged: (value) {
                            context.read<SignUpBloc>().add(PasswordChangedEvent(password: value));
                          },
                        ),
                        SizedBox(height: 16.h),
                        // Conferma Password
                        _buildLabel('Conferma Password'),
                        CustomEditText(
                          controller: state.confirmPasswordController,
                          placeholder: 'Conferma Password',
                          inputType: 'PASSWORD',
                          passwordField: true,
                          textStyle: TextStyleHelper.instance.title16ExtraBoldSFCompact,
                          contentPadding: EdgeInsets.all(12.h),
                          validator: (value) {
                            if (value != state.signUpModel?.password) {
                              return 'Le password non corrispondono';
                            }
                            return null;
                          },
                          onChanged: (value) {
                            context.read<SignUpBloc>().add(ConfirmPasswordChangedEvent(confirmPassword: value));
                          },
                        ),
                        SizedBox(height: 16.h),
                        // Numero di telefono
                        _buildLabel('Telefono'),
                        IntlPhoneField(
                          controller: state.phoneController, // Usiamo lo stesso controller del tuo BLoC
                          decoration: InputDecoration(
    hintText: 'Telefono',
    hintStyle: TextStyleHelper.instance.title16ExtraBoldSFCompact.copyWith(color: Colors.white54),
    fillColor: Colors.white.withValues(alpha: 0.1), // Sfondo leggermente visibile come i tuoi input
    filled: true,
    contentPadding: EdgeInsets.all(12.h),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10.h),
      borderSide: BorderSide(),
    ),
    errorStyle: TextStyle(color: Colors.redAccent),
  ),
  style: TextStyleHelper.instance.title16ExtraBoldSFCompact.copyWith(color: Colors.white),
  dropdownTextStyle: TextStyle(color: Colors.white, fontSize: 16.fSize), // Colore prefisso (+39)
  initialCountryCode: 'IT',
  languageCode: "it",
  cursorColor: Colors.white,
  dropdownIcon: Icon(Icons.arrow_drop_down, color: Colors.white),
  onChanged: (phone) {
    // Inviamo sia il numero completo che il codice ISO al BLoC
    // Nota: devi assicurarti che il tuo Event accetti questi parametri
    context.read<SignUpBloc>().add(PhoneChangedEvent(
      phone: phone.completeNumber, // Es: +393331234567
      countryIso: phone.countryISOCode, // Es: IT
      nationalNumber: phone.number,
    ));
  },
  invalidNumberMessage: 'Numero non valido',
),
                        SizedBox(height: 16.h),
                        // Data di nascita
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
                                if (state.signUpModel?.dob == null) {
                                  return 'Inserisci la data di nascita';
                                }
                                final age = DateTime.now().year - state.signUpModel!.dob!.year;
                                if (age < 13) {
                                  return 'Devi avere almeno 13 anni';
                                }
                                return null;
                              },
                            ),
                          ),
                        ),
                        if (state.signUpModel?.dob != null) ...[
                          SizedBox(height: 8.h),
                          Builder(
                            builder: (context) {
                              final isAdult = AgeCalculator.isAdult(state.signUpModel!.dob!);
                              return Text(
                                isAdult ? "Utente maggiorenne" : "Utente minorenne",
                                style: TextStyleHelper.instance.title16ExtraBoldSFCompact.copyWith(
                                  color: isAdult ? Colors.green : Colors.orange,
                                  fontSize: 14.fSize,
                                ),
                              );
                            }
                          ),
                        ],
                        SizedBox(height: 32.h),
                        // Pulsante Registrati
                        state.isLoading
                            ? Center(child: CircularProgressIndicator(color: appTheme.white_A700))
                            : Container(
                                alignment: Alignment.center,
                                child: CustomButton(
                                  text: 'Registrati',
                                  onPressed: () {
                                    context.read<SignUpBloc>().add(SubmitSignUpEvent());
                                  },
                                  backgroundColor: appTheme.white_A700,
                                  textColor: appTheme.black_900,
                                  borderRadius: 10.h,
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 30.h,
                                    vertical: 2.h,
                                  ),
                                  fontSize: 16.fSize,
                                  fontFamily: 'SF Compact',
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                         SizedBox(height: 20.h),
                         // Link per tornare al login
                         Container(
                          alignment: Alignment.center,
                          child: GestureDetector(
                            onTap: () {
                              NavigatorService.goBack();
                            },
                            child: Text(
                              "Hai già un account? Accedi",
                              style: TextStyle(
                                color: appTheme.white_A700,
                                decoration: TextDecoration.underline,
                              ),
                            ),
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
      initialDate: DateTime.now().subtract(Duration(days: 365 * 13)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            primaryColor: appTheme.indigo_900,
            colorScheme: ColorScheme.light(primary: appTheme.indigo_900),
            buttonTheme: ButtonThemeData(textTheme: ButtonTextTheme.primary),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      context.read<SignUpBloc>().add(DobChangedEvent(dob: picked));
    }
  }
}
