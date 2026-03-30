part of 'authentication_bloc.dart';

class AuthenticationState extends Equatable {
  final TextEditingController? emailController;
  final TextEditingController? passwordController;
  final GlobalKey<FormState>? formKey;
  final bool isLoading;
  final bool isLoginSuccess;
  final bool isRegisterSuccess;
  final bool needsProfileCompletion;
  final String? oauthNome;
  final String? oauthCognome;
  final String? errorMessage;
  final AuthenticationModel? authenticationModel;

  const AuthenticationState({
    this.emailController,
    this.passwordController,
    this.formKey,
    this.isLoading = false,
    this.isLoginSuccess = false,
    this.isRegisterSuccess = false,
    this.needsProfileCompletion = false,
    this.oauthNome,
    this.oauthCognome,
    this.errorMessage,
    this.authenticationModel,
  });

  @override
  List<Object?> get props => [
        emailController,
        passwordController,
        formKey,
        isLoading,
        isLoginSuccess,
        isRegisterSuccess,
        needsProfileCompletion,
        oauthNome,
        oauthCognome,
        errorMessage,
        authenticationModel,
      ];

  AuthenticationState copyWith({
    TextEditingController? emailController,
    TextEditingController? passwordController,
    GlobalKey<FormState>? formKey,
    bool? isLoading,
    bool? isLoginSuccess,
    bool? isRegisterSuccess,
    bool? needsProfileCompletion,
    String? oauthNome,
    String? oauthCognome,
    String? errorMessage,
    AuthenticationModel? authenticationModel,
  }) {
    return AuthenticationState(
      emailController: emailController ?? this.emailController,
      passwordController: passwordController ?? this.passwordController,
      formKey: formKey ?? this.formKey,
      isLoading: isLoading ?? this.isLoading,
      isLoginSuccess: isLoginSuccess ?? this.isLoginSuccess,
      isRegisterSuccess: isRegisterSuccess ?? this.isRegisterSuccess,
      needsProfileCompletion: needsProfileCompletion ?? this.needsProfileCompletion,
      oauthNome: oauthNome ?? this.oauthNome,
      oauthCognome: oauthCognome ?? this.oauthCognome,
      errorMessage: errorMessage ?? this.errorMessage,
      authenticationModel: authenticationModel ?? this.authenticationModel,
    );
  }
}
