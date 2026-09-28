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
/// Aspetto del campo telefono.
enum OnlistPhoneFieldStyle {
  /// Sottolineatura bianca, come i vecchi campi del profilo.
  underline,

  /// Pillola con bordo bianco 2px e raggio 32, come i campi del Figma nuovo
  /// di login e registrazione.
  pill,
}

class OnlistPhoneField extends StatefulWidget {
  const OnlistPhoneField({
    super.key,
    required this.controller,
    required this.onChanged,
    this.initialIso = 'IT',
    this.hintText = 'Numero di telefono',
    this.stile = OnlistPhoneFieldStyle.underline,
  });

  /// Come disegnare il campo. Il default resta la sottolineatura: il profilo
  /// e gli altri usi esistenti non devono cambiare aspetto.
  final OnlistPhoneFieldStyle stile;

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
    return widget.stile == OnlistPhoneFieldStyle.pill
        ? _pill()
        : _sottolineato();
  }

  /// Bandiera + prefisso: il pezzo che apre il selettore paese. Uguale nei
  /// due stili, cambia solo la spaziatura attorno.
  Widget _selettorePaese({
    required double corpoBandiera,
    required double corpoPrefisso,
    required EdgeInsets padding,
  }) {
    return InkWell(
      onTap: _openPicker,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: padding,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_country.flagEmoji, style: TextStyle(fontSize: corpoBandiera)),
            const SizedBox(width: 6),
            Text(
              _country.dial,
              style: TextStyle(
                fontFamily: 'OnlistHN',
                fontSize: corpoPrefisso,
                fontWeight: FontWeight.w400,
                color: OnlistColors.white,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down, color: Colors.white70, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _numero({
    required double corpo,
    required InputBorder bordo,
    required EdgeInsets contentPadding,
    InputBorder? bordoErrore,
    Color hintColor = Colors.white54,
  }) {
    return TextField(
      controller: _controller,
      keyboardType: TextInputType.phone,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      style: TextStyle(
        fontFamily: 'OnlistHN',
        fontSize: corpo,
        fontWeight: FontWeight.w400,
        color: OnlistColors.white,
      ),
      cursorColor: OnlistColors.white,
      decoration: InputDecoration(
        isDense: true,
        filled: false,
        hintText: widget.hintText,
        hintStyle: TextStyle(
          fontFamily: 'OnlistHN',
          fontSize: corpo,
          fontWeight: FontWeight.w400,
          color: hintColor,
        ),
        contentPadding: contentPadding,
        border: bordo,
        enabledBorder: bordo,
        focusedBorder: bordo,
        errorBorder: bordoErrore ?? bordo,
        focusedErrorBorder: bordoErrore ?? bordo,
      ),
      onChanged: (_) => _emit(),
    );
  }

  Widget _sottolineato() {
    const bordo = UnderlineInputBorder(
        borderSide: BorderSide(color: OnlistColors.white, width: 2));
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _selettorePaese(
            corpoBandiera: 22,
            corpoPrefisso: 16,
            padding: const EdgeInsets.fromLTRB(0, 8, 8, 8)),
        const SizedBox(width: 6),
        Expanded(
          child: _numero(
            corpo: 16,
            bordo: bordo,
            bordoErrore: const UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.redAccent, width: 2)),
            contentPadding: const EdgeInsets.only(top: 8, bottom: 6),
          ),
        ),
      ],
    );
  }

  /// Stile del Figma nuovo: bordo e raggio stanno sul contenitore, il campo
  /// dentro non ha nessun bordo proprio — altrimenti si vedrebbero due
  /// cornici, una dentro l'altra.
  Widget _pill() {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 11),
      decoration: BoxDecoration(
        border: Border.all(color: OnlistColors.white, width: 2),
        borderRadius: BorderRadius.circular(32),
      ),
      child: Row(
        children: [
          _selettorePaese(
              corpoBandiera: 20,
              corpoPrefisso: 18,
              padding: const EdgeInsets.symmetric(vertical: 4)),
          const SizedBox(width: 4),
          Expanded(
            child: _numero(
              corpo: 18,
              bordo: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              hintColor: OnlistColors.authFieldHint,
            ),
          ),
        ],
      ),
    );
  }
}
