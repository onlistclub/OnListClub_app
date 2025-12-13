import 'package:flutter/material.dart';

import '../../core/app_export.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_edit_text.dart';
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
        child: BlocConsumer<AuthenticationBloc, AuthenticationState>(
          listener: (context, state) {
            if (state.isLoginSuccess) {
              NavigatorService.pushNamedAndRemoveUntil(
                AppRoutes.eventDetailScreen,
              );
            }
            if (state.errorMessage != null && state.errorMessage!.isNotEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Errore di autenticazione')),
              );
            }
          },
          builder: (context, state) {
            return Container(
              width: double.infinity,
              height: double.infinity,
              padding: EdgeInsets.only(
                top: 92.h,
                right: 28.h,
                left: 28.h,
              ),
              child: Form(
                key: state.formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: EdgeInsets.only(left: 20.h),
                      child: Text(
                        'Accedi',
                        style: TextStyleHelper
                            .instance.headline32ExtraBoldSFCompact
                            .copyWith(height: 1.22),
                      ),
                    ),
                    Container(
                      margin: EdgeInsets.only(
                        top: 36.h,
                        left: 20.h,
                      ),
                      child: CustomEditText(
                        controller: state.emailController,
                        placeholder: 'Email',
                        inputType: 'EMAIL',
                        textStyle:
                            TextStyleHelper.instance.title16ExtraBoldSFCompact,
                        contentPadding: EdgeInsets.only(
                          top: 12.h,
                          right: 12.h,
                          bottom: 8.h,
                          left: 12.h,
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your email';
                          }
                          if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                              .hasMatch(value)) {
                            return 'Please enter a valid email';
                          }
                          return null;
                        },
                        onChanged: (value) {
                          context.read<AuthenticationBloc>().add(
                                EmailChangedEvent(email: value),
                              );
                        },
                      ),
                    ),
                    Container(
                      margin: EdgeInsets.only(
                        top: 52.h,
                        left: 20.h,
                      ),
                      child: CustomEditText(
                        controller: state.passwordController,
                        placeholder: 'Password',
                        inputType: 'Password',
                        passwordField: true,
                        textStyle:
                            TextStyleHelper.instance.title16ExtraBoldSFCompact,
                        contentPadding: EdgeInsets.all(12.h),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your password';
                          }
                          if (value.length < 6) {
                            return 'Password must be at least 6 characters';
                          }
                          return null;
                        },
                        onChanged: (value) {
                          context.read<AuthenticationBloc>().add(
                                PasswordChangedEvent(password: value),
                              );
                        },
                      ),
                    ),
                    Container(
                      margin: EdgeInsets.only(top: 24.h),
                      alignment: Alignment.center,
                      child: CustomButton(
                        text: 'Accedi',
                        onPressed: () {
                          _onTapAccedi(context);
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
                    Container(
                      margin: EdgeInsets.only(top: 10.h),
                      alignment: Alignment.center,
                      child: CustomButton(
                        text: 'Registratt',
                        onPressed: () {
                          _onTapRegistrati(context);
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
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _onTapAccedi(BuildContext context) {
    final bloc = context.read<AuthenticationBloc>();
    final state = bloc.state;

    if (state.formKey?.currentState?.validate() ?? false) {
      bloc.add(LoginButtonPressedEvent());
    }
  }

  void _onTapRegistrati(BuildContext context) {
    final bloc = context.read<AuthenticationBloc>();
    bloc.add(RegisterButtonPressedEvent());
  }
}
