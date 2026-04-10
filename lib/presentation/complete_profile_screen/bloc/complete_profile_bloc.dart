import 'package:flutter/material.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/complete_profile_model.dart';
import '../../../core/utils/phone_utils.dart';
import '../../../core/services/register_service.dart';

part 'complete_profile_event.dart';
part 'complete_profile_state.dart';

class CompleteProfileBloc
    extends Bloc<CompleteProfileEvent, CompleteProfileState> {
  CompleteProfileBloc(CompleteProfileState initialState) : super(initialState) {
    on<CompleteProfileInitialEvent>(_onInitialize);
    on<CompleteProfileFirstNameChangedEvent>(_onFirstNameChanged);
    on<CompleteProfileLastNameChangedEvent>(_onLastNameChanged);
    on<CompleteProfileDobChangedEvent>(_onDobChanged);
    on<CompleteProfilePhoneChangedEvent>(_onPhoneChanged);
    on<CompleteProfileSubmitEvent>(_onSubmit);
  }

  _onInitialize(
    CompleteProfileInitialEvent event,
    Emitter<CompleteProfileState> emit,
  ) {
    final firstNameCtrl = TextEditingController(text: event.prefillNome ?? '');
    final lastNameCtrl = TextEditingController(text: event.prefillCognome ?? '');
    final emailCtrl = TextEditingController(text: event.prefillEmail ?? '');
    emit(state.copyWith(
      firstNameController: firstNameCtrl,
      lastNameController: lastNameCtrl,
      emailController: emailCtrl,
      dobController: TextEditingController(),
      phoneController: TextEditingController(),
      formKey: GlobalKey<FormState>(),
      isLoading: false,
      isSuccess: false,
      model: CompleteProfileModel(
        firstName: event.prefillNome ?? '',
        lastName: event.prefillCognome ?? '',
        phoneCountryIso: 'IT',
      ),
    ));
  }

  _onFirstNameChanged(
    CompleteProfileFirstNameChangedEvent event,
    Emitter<CompleteProfileState> emit,
  ) {
    emit(state.copyWith(
      model: state.model?.copyWith(firstName: event.firstName),
    ));
  }

  _onLastNameChanged(
    CompleteProfileLastNameChangedEvent event,
    Emitter<CompleteProfileState> emit,
  ) {
    emit(state.copyWith(
      model: state.model?.copyWith(lastName: event.lastName),
    ));
  }

  _onDobChanged(
    CompleteProfileDobChangedEvent event,
    Emitter<CompleteProfileState> emit,
  ) {
    final formatted = DateFormat('dd/MM/yyyy').format(event.dob);
    state.dobController?.text = formatted;
    emit(state.copyWith(
      model: state.model?.copyWith(dob: event.dob),
    ));
  }

  _onPhoneChanged(
    CompleteProfilePhoneChangedEvent event,
    Emitter<CompleteProfileState> emit,
  ) {
    final normalized = PhoneUtils.normalize(
      countryIso: event.countryIso,
      nationalNumber: event.nationalNumber,
      completeNumber: event.phone,
    );
    final nnDigits = (event.nationalNumber ?? '').replaceAll(RegExp(r'\D'), '');
    emit(state.copyWith(
      model: state.model?.copyWith(
        phone: normalized,
        phoneCountryIso: event.countryIso ?? state.model?.phoneCountryIso,
        nationalNumber: nnDigits,
      ),
    ));
  }

  _onSubmit(
    CompleteProfileSubmitEvent event,
    Emitter<CompleteProfileState> emit,
  ) async {
    if (state.formKey?.currentState?.validate() != true) return;
    emit(state.copyWith(isLoading: true, errorMessage: null));

    try {
      final model = state.model;
      if (model == null) return;

      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        emit(state.copyWith(isLoading: false, errorMessage: 'Sessione scaduta'));
        return;
      }

      final iso = model.phoneCountryIso ?? 'IT';
      final nn = model.nationalNumber;
      final dob = model.dob;

      if (nn.isEmpty || dob == null) {
        emit(state.copyWith(
          isLoading: false,
          errorMessage: 'Completa tutti i campi',
        ));
        return;
      }

      final cleaned = nn.replaceAll(RegExp(r'\D'), '');
      final countryId = await RegisterService().resolveCountryIdFromIso(iso);

      await Supabase.instance.client.from('utenti').upsert({
        'id': user.id,
        'nome': model.firstName,
        'cognome': model.lastName,
        'email': user.email,
        'data_nascita': dob.toIso8601String(),
        'maggiorenne': DateTime.now().difference(dob).inDays >= 365 * 18,
      });

      await Supabase.instance.client.from('utenti_numeri_telefono').upsert({
        'user_id': user.id,
        'country_id': countryId,
        'telefono': cleaned,
        'is_primary': true,
        'is_verified': false,
      }, onConflict: 'user_id,telefono');

      emit(state.copyWith(isLoading: false, isSuccess: true));
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        errorMessage: 'Errore salvataggio: $e',
      ));
    }
  }
}
