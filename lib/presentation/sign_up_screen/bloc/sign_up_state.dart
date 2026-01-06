part of 'sign_up_bloc.dart';

class SignUpState extends Equatable {
  final TextEditingController? firstNameController;
  final TextEditingController? lastNameController;
  final TextEditingController? emailController;
  final TextEditingController? passwordController;
  final TextEditingController? confirmPasswordController;
  final TextEditingController? dobController;
  final TextEditingController? phoneController;
  final GlobalKey<FormState>? formKey;
  final bool isLoading;
  final bool isSuccess;
  final String? errorMessage;
  final SignUpModel? signUpModel;
  // No custom country list: we use IntlPhoneField's internal list

  const SignUpState({
    this.firstNameController,
    this.lastNameController,
    this.emailController,
    this.passwordController,
    this.confirmPasswordController,
    this.dobController,
    this.phoneController,
    this.formKey,
    this.isLoading = false,
    this.isSuccess = false,
    this.errorMessage,
    this.signUpModel,
    // No custom countries state
  });

  @override
  List<Object?> get props => [
        firstNameController,
        lastNameController,
        emailController,
        passwordController,
        confirmPasswordController,
        dobController,
        phoneController,
        formKey,
        isLoading,
        isSuccess,
        errorMessage,
        signUpModel,
        // no custom countries state
      ];

  SignUpState copyWith({
    TextEditingController? firstNameController,
    TextEditingController? lastNameController,
    TextEditingController? emailController,
    TextEditingController? passwordController,
    TextEditingController? confirmPasswordController,
    TextEditingController? dobController,
    TextEditingController? phoneController,
    GlobalKey<FormState>? formKey,
    bool? isLoading,
    bool? isSuccess,
    String? errorMessage,
    SignUpModel? signUpModel,
    // no custom countries state
  }) {
    return SignUpState(
      firstNameController: firstNameController ?? this.firstNameController,
      lastNameController: lastNameController ?? this.lastNameController,
      emailController: emailController ?? this.emailController,
      passwordController: passwordController ?? this.passwordController,
      confirmPasswordController:
          confirmPasswordController ?? this.confirmPasswordController,
      dobController: dobController ?? this.dobController,
      phoneController: phoneController ?? this.phoneController,
      formKey: formKey ?? this.formKey,
      isLoading: isLoading ?? this.isLoading,
      isSuccess: isSuccess ?? this.isSuccess,
      errorMessage: errorMessage ?? this.errorMessage,
      signUpModel: signUpModel ?? this.signUpModel,
      // no custom countries state
    );
  }
}
