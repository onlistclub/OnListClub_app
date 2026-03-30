part of 'complete_profile_bloc.dart';

class CompleteProfileState extends Equatable {
  final TextEditingController? firstNameController;
  final TextEditingController? lastNameController;
  final TextEditingController? dobController;
  final TextEditingController? phoneController;
  final GlobalKey<FormState>? formKey;
  final bool isLoading;
  final bool isSuccess;
  final String? errorMessage;
  final CompleteProfileModel? model;

  const CompleteProfileState({
    this.firstNameController,
    this.lastNameController,
    this.dobController,
    this.phoneController,
    this.formKey,
    this.isLoading = false,
    this.isSuccess = false,
    this.errorMessage,
    this.model,
  });

  @override
  List<Object?> get props => [
        firstNameController,
        lastNameController,
        dobController,
        phoneController,
        formKey,
        isLoading,
        isSuccess,
        errorMessage,
        model,
      ];

  CompleteProfileState copyWith({
    TextEditingController? firstNameController,
    TextEditingController? lastNameController,
    TextEditingController? dobController,
    TextEditingController? phoneController,
    GlobalKey<FormState>? formKey,
    bool? isLoading,
    bool? isSuccess,
    String? errorMessage,
    CompleteProfileModel? model,
  }) {
    return CompleteProfileState(
      firstNameController: firstNameController ?? this.firstNameController,
      lastNameController: lastNameController ?? this.lastNameController,
      dobController: dobController ?? this.dobController,
      phoneController: phoneController ?? this.phoneController,
      formKey: formKey ?? this.formKey,
      isLoading: isLoading ?? this.isLoading,
      isSuccess: isSuccess ?? this.isSuccess,
      errorMessage: errorMessage ?? this.errorMessage,
      model: model ?? this.model,
    );
  }
}
