import 'package:equatable/equatable.dart';
import '../../../core/app_export.dart';

/// This class is used in the [authentication_screen] screen.

// ignore_for_file: must_be_immutable
class AuthenticationModel extends Equatable {
  AuthenticationModel({
    this.email,
    this.password,
    this.id,
  }) {
    email = email ?? "";
    password = password ?? "";
    id = id ?? "";
  }

  String? email;
  String? password;
  String? id;

  AuthenticationModel copyWith({
    String? email,
    String? password,
    String? id,
  }) {
    return AuthenticationModel(
      email: email ?? this.email,
      password: password ?? this.password,
      id: id ?? this.id,
    );
  }

  @override
  List<Object?> get props => [email, password, id];
}
