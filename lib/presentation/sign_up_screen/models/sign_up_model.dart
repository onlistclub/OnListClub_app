import 'package:equatable/equatable.dart';

/// This class is used in the [sign_up_screen] screen.
class SignUpModel extends Equatable {
  SignUpModel({
    this.firstName = "",
    this.lastName = "",
    this.email = "",
    this.password = "",
    this.confirmPassword = "",
    this.dob,
    this.phone = "",
    this.phoneCountryIso,
  });

  final String firstName;
  final String lastName;
  final String email;
  final String password;
  final String confirmPassword;
  final DateTime? dob;
  final String phone;
  final String? phoneCountryIso;

  SignUpModel copyWith({
    String? firstName,
    String? lastName,
    String? email,
    String? password,
    String? confirmPassword,
    DateTime? dob,
    String? phone,
    String? phoneCountryIso,
  }) {
    return SignUpModel(
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      password: password ?? this.password,
      confirmPassword: confirmPassword ?? this.confirmPassword,
      dob: dob ?? this.dob,
      phone: phone ?? this.phone,
      phoneCountryIso: phoneCountryIso ?? this.phoneCountryIso,
    );
  }

  @override
  List<Object?> get props => [
        firstName,
        lastName,
        email,
        password,
        confirmPassword,
        dob,
        phone,
        phoneCountryIso,
      ];
}
