part of 'verification_bloc.dart';

class verificationState extends Equatable {
  final bool isLoading;
  final bool isVerified;
  final String? errorMessage;
  final String? emailResentMessage;
  final DateTime? registrationTime;
  final String? email;
  final String? password;

  const verificationState({
    this.isLoading = false,
    this.isVerified = false,
    this.errorMessage,
    this.emailResentMessage,
    this.registrationTime,
    this.email,
    this.password,
  });

  @override
  List<Object?> get props => [
        isLoading,
        isVerified,
        errorMessage,
        emailResentMessage,
        registrationTime,
        email,
        password,
      ];

  verificationState copyWith({
    bool? isLoading,
    bool? isVerified,
    String? errorMessage,
    String? emailResentMessage,
    DateTime? registrationTime,
    String? email,
    String? password,
  }) {
    return verificationState(
      isLoading: isLoading ?? this.isLoading,
      isVerified: isVerified ?? this.isVerified,
      errorMessage: errorMessage,
      emailResentMessage: emailResentMessage,
      registrationTime: registrationTime ?? this.registrationTime,
      email: email ?? this.email,
      password: password ?? this.password,
    );
  }
}
