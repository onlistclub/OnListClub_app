part of 'verification_bloc.dart';

class verificationState extends Equatable {
  final Duration remainingTime;
  final bool isLoading;
  final bool isVerified;
  final bool isExpired;
  final String? errorMessage;
  final String? emailResentMessage;
  final DateTime? registrationTime;
  final String? email;
  final String? password;

  const verificationState({
    this.remainingTime = const Duration(hours: 4),
    this.isLoading = false,
    this.isVerified = false,
    this.isExpired = false,
    this.errorMessage,
    this.emailResentMessage,
    this.registrationTime,
    this.email,
    this.password,
  });

  @override
  List<Object?> get props => [
        remainingTime,
        isLoading,
        isVerified,
        isExpired,
        errorMessage,
        emailResentMessage,
        registrationTime,
        email,
        password,
      ];

  verificationState copyWith({
    Duration? remainingTime,
    bool? isLoading,
    bool? isVerified,
    bool? isExpired,
    String? errorMessage,
    String? emailResentMessage,
    DateTime? registrationTime,
    String? email,
    String? password,
  }) {
    return verificationState(
      remainingTime: remainingTime ?? this.remainingTime,
      isLoading: isLoading ?? this.isLoading,
      isVerified: isVerified ?? this.isVerified,
      isExpired: isExpired ?? this.isExpired,
      errorMessage: errorMessage, 
      emailResentMessage: emailResentMessage,
      registrationTime: registrationTime ?? this.registrationTime,
      email: email ?? this.email,
      password: password ?? this.password,
    );
  }
}
