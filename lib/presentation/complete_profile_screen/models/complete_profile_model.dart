import 'package:equatable/equatable.dart';

class CompleteProfileModel extends Equatable {
  CompleteProfileModel({
    this.firstName = '',
    this.lastName = '',
    this.dob,
    this.phone = '',
    this.phoneCountryIso = 'IT',
    this.nationalNumber = '',
  });

  final String firstName;
  final String lastName;
  final DateTime? dob;
  final String phone;
  final String? phoneCountryIso;
  final String nationalNumber;

  CompleteProfileModel copyWith({
    String? firstName,
    String? lastName,
    DateTime? dob,
    String? phone,
    String? phoneCountryIso,
    String? nationalNumber,
  }) {
    return CompleteProfileModel(
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      dob: dob ?? this.dob,
      phone: phone ?? this.phone,
      phoneCountryIso: phoneCountryIso ?? this.phoneCountryIso,
      nationalNumber: nationalNumber ?? this.nationalNumber,
    );
  }

  @override
  List<Object?> get props => [
        firstName,
        lastName,
        dob,
        phone,
        phoneCountryIso,
        nationalNumber,
      ];
}
