import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/onlist_colors.dart';
import 'country_picker_sheet.dart';
import 'phone_country.dart';

/// Campo telefono brandizzato Onlist:
///   [bottone bandiera + prefisso] [TextField numero nazionale]
///
/// Il selettore paese apre un modal **nativo** alla piattaforma (vedi
/// `showCountryPicker`), evitando i bug touch del DIALOG di
/// `intl_phone_number_input ^0.7.4`.
///
/// API simile al precedente `InternationalPhoneNumberInput`:
///   - [controller] contiene SOLO le cifre nazionali (no prefisso).
///   - [onChanged] notifica `(iso, dialCode, nationalNumber, e164)` ad ogni
///     cambio (sia di bandiera che di numero), così il BLoC può ricostruire
///     l'E.164 esattamente come prima.
class OnlistPhoneField extends StatefulWidget {
  const OnlistPhoneField({
    super.key,
    required this.controller,
    required this.onChanged,
    this.initialIso = 'IT',
    this.hintText = 'Numero di telefono',
  });

  // Nullable perché nella schermata di registrazione il controller arriva da
  // un BLoC che lo crea in modo asincrono: nel primissimo build (prima che il
  // BLoC emetta il suo stato iniziale) può ancora valere null.
  final TextEditingController? controller;
  final void Function(
    String iso,
    String dialCode,
    String nationalNumber,
    String e164,
  ) onChanged;
  final String initialIso;
  final String hintText;

  @override
  State<OnlistPhoneField> createState() => _OnlistPhoneFieldState();
}

class _OnlistPhoneFieldState extends State<OnlistPhoneField> {
  late PhoneCountry _country;
  // Fallback usato solo finché widget.controller è null (vedi commento sul
  // campo `controller`); viene scartato non appena il vero controller arriva.
  TextEditingController? _fallbackController;

  TextEditingController get _controller =>
      widget.controller ?? (_fallbackController ??= TextEditingController());

  @override
  void initState() {
    super.initState();
    _country = PhoneCountry.byIso(widget.initialIso) ??
        PhoneCountry.byIso('IT') ??
        PhoneCountry.all().first;
    // Emit dello stato iniziale: replica il comportamento del widget
    // sostituito, che notificava subito l'E.164 di default.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _emit();
    });
  }

  @override
  void dispose() {
    _fallbackController?.dispose();
    super.dispose();
  }

  void _emit() {
    final national = _digitsOnly(_controller.text);
    final dialClean = _country.dial.replaceAll(RegExp(r'\D'), '');
    final e164 = '+$dialClean$national';
    widget.onChanged(_country.iso, _country.dial, national, e164);
  }

  String _digitsOnly(String s) => s.replaceAll(RegExp(r'\D'), '');

  Future<void> _openPicker() async {
    final picked = await showCountryPicker(context);
    if (picked == null) return;
    setState(() => _country = picked);
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Bottone bandiera + prefisso
        InkWell(
          onTap: _openPicker,
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(0, 8, 8, 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _country.flagEmoji,
                  style: const TextStyle(fontSize: 22),
                ),
                const SizedBox(width: 6),
                Text(
                  _country.dial,
                  style: const TextStyle(
                    fontFamily: 'OnlistHN',
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    color: OnlistColors.white,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.arrow_drop_down,
                    color: Colors.white70, size: 20),
              ],
            ),
          ),
        ),
        const SizedBox(width: 6),
        // Campo numero nazionale (sotto-linea bianca, come gli altri input)
        Expanded(
          child: TextField(
            controller: _controller,
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
            ],
            style: const TextStyle(
              fontFamily: 'OnlistHN',
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: OnlistColors.white,
            ),
            decoration: InputDecoration(
              isDense: true,
              filled: false,
              hintText: widget.hintText,
              hintStyle: const TextStyle(
                fontFamily: 'OnlistHN',
                fontSize: 16,
                fontWeight: FontWeight.w400,
                color: Colors.white54,
              ),
              contentPadding: const EdgeInsets.only(top: 8, bottom: 6),
              enabledBorder: const UnderlineInputBorder(
                  borderSide:
                      BorderSide(color: OnlistColors.white, width: 2)),
              focusedBorder: const UnderlineInputBorder(
                  borderSide:
                      BorderSide(color: OnlistColors.white, width: 2)),
              errorBorder: const UnderlineInputBorder(
                  borderSide:
                      BorderSide(color: Colors.redAccent, width: 2)),
              focusedErrorBorder: const UnderlineInputBorder(
                  borderSide:
                      BorderSide(color: Colors.redAccent, width: 2)),
            ),
            onChanged: (_) => _emit(),
          ),
        ),
      ],
    );
  }
}
