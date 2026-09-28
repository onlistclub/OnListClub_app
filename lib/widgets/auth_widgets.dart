import 'package:flutter/material.dart';

import '../core/utils/responsive.dart';
import '../theme/onlist_colors.dart';
import '../theme/onlist_text_styles.dart';
import 'glow_card.dart';

/// Pezzi condivisi delle schermate di accesso e registrazione, dal Figma
/// nuovo (`docs/figma_screen/off/NUOVO/login.css` e `registrazione.css`).
///
/// Le due schermate disegnano lo stesso pannello blu con gli stessi campi a
/// pillola: tenerli qui evita che fra un mese siano due copie leggermente
/// diverse.
///
/// **Attenzione alle coordinate del Figma.** `login.css` esporta posizioni
/// ASSOLUTE sul frame 393×852; `registrazione.css` le esporta RELATIVE al
/// contenitore "Frame 462", che sta a (37, 326). Verificato sui PNG ufficiali,
/// che sono 393×852 esatti: i campi della registrazione cadono a y 327, 413,
/// 499, 585, 671, cioè 326 + 0/86/172/258/344. Chi legge quei CSS deve
/// sommare l'origine, altrimenti la schermata esce 326 px più in alto.

/// Misure di riferimento del frame Figma.
class AuthMetrics {
  AuthMetrics._();

  /// Altezza del frame di design. Le proporzioni verticali delle schermate
  /// sono espresse come frazioni di questo valore.
  static const double frameH = 852;

  /// Campi: 315×48, bordo bianco 2px, raggio 32.
  static const double fieldW = 315;
  static const double fieldH = 48;
  static const double fieldRadius = 32;
  static const double fieldBorder = 2;

  /// Rientro del testo dentro il campo (CSS: label a x 11).
  static const double fieldPadX = 11;

  /// Margine laterale dei campi sul frame: (393 - 315) / 2.
  static const double sideMargin = 39;

  /// Bottone grande chiaro ("Accedi", "Registrati" in fondo al form).
  static const double buttonW = 215.87;
  static const double buttonH = 40;
  static const double buttonRadius = 28;

  /// Raggio degli angoli alti del pannello blu.
  static const double panelRadius = 32;
}

/// Il pannello blu che occupa la parte bassa della schermata.
///
/// Angoli arrotondati solo in alto: nel mockup gli angoli bassi seguono la
/// cornice tonda del telefono, su un device vero resterebbero due spicchi di
/// sfondo scuro in fondo allo schermo.
class AuthPanel extends StatelessWidget {
  const AuthPanel({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GlowCard(
      gradient: OnlistColors.authPanel,
      radius: R.sp(AuthMetrics.panelRadius),
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(R.sp(AuthMetrics.panelRadius)),
      ),
      glowColor: OnlistColors.authPanelGlow,
      // CSS `inset 0px 2px 100px`: in Flutter il sigma è metà del blur.
      glowSigma: R.sp(50),
      glowOffset: Offset(0, R.sp(2)),
      child: child,
    );
  }
}

/// Trattino bianco sotto il bordo alto del pannello (CSS "Line 27": 38×0 con
/// bordo 3px, cioè una barretta 38×3).
class AuthDash extends StatelessWidget {
  const AuthDash({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: R.sp(38),
      height: R.sp(3),
      decoration: BoxDecoration(
        color: OnlistColors.white,
        borderRadius: BorderRadius.circular(R.sp(2)),
      ),
    );
  }
}

/// Stile del testo digitato dentro i campi a pillola.
TextStyle authFieldInputStyle() => OnlistTextStyles.hn(
      fontSize: R.sp(22),
      fontWeight: FontWeight.w400,
      height: 1.0,
      color: OnlistColors.white,
    );

/// Stile del segnaposto ("Email", "Password", …): stesso corpo, bianco al 50%.
TextStyle authFieldHintStyle() => OnlistTextStyles.hn(
      fontSize: R.sp(22),
      fontWeight: FontWeight.w400,
      height: 1.0,
      color: OnlistColors.authFieldHint,
    );

/// Decorazione del campo a pillola: bordo bianco 2px, raggio 32, nessun
/// riempimento.
///
/// Il testo dell'eventuale errore di validazione resta sotto il campo e fa
/// crescere la colonna: le schermate distribuiscono lo spazio con `Spacer`,
/// che si stringono per assorbirlo senza mandare il layout in overflow.
InputDecoration authFieldDecoration({
  required String hint,
  Widget? suffixIcon,
}) {
  OutlineInputBorder bordo(Color colore, double spessore) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(R.sp(AuthMetrics.fieldRadius)),
        borderSide: BorderSide(color: colore, width: spessore),
      );

  return InputDecoration(
    isDense: true,
    filled: false,
    hintText: hint,
    hintStyle: authFieldHintStyle(),
    // 13 sopra e sotto + 22 di riga = i 48 px del CSS.
    contentPadding: EdgeInsets.symmetric(
      horizontal: R.sp(AuthMetrics.fieldPadX),
      vertical: R.sp(13),
    ),
    enabledBorder: bordo(OnlistColors.white, AuthMetrics.fieldBorder),
    focusedBorder: bordo(OnlistColors.white, AuthMetrics.fieldBorder),
    errorBorder: bordo(OnlistColors.destructive, AuthMetrics.fieldBorder),
    focusedErrorBorder:
        bordo(OnlistColors.destructive, AuthMetrics.fieldBorder),
    errorStyle: OnlistTextStyles.hn(
      fontSize: R.sp(12),
      color: OnlistColors.white,
    ),
    suffixIcon: suffixIcon,
    suffixIconConstraints: BoxConstraints(
      minWidth: R.sp(44),
      minHeight: R.sp(AuthMetrics.fieldH),
    ),
  );
}

/// Campo a pillola del nuovo design.
class AuthPillField extends StatelessWidget {
  const AuthPillField({
    super.key,
    required this.hint,
    this.controller,
    this.keyboardType,
    this.textInputAction,
    this.validator,
    this.onChanged,
    this.readOnly = false,
    this.suffixIcon,
  });

  final String hint;
  final TextEditingController? controller;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;
  final bool readOnly;
  final Widget? suffixIcon;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      readOnly: readOnly,
      style: authFieldInputStyle(),
      cursorColor: OnlistColors.white,
      decoration: authFieldDecoration(hint: hint, suffixIcon: suffixIcon),
      validator: validator,
      onChanged: onChanged,
    );
  }
}

/// Campo password a pillola, con l'occhio per mostrare/nascondere.
///
/// L'occhio non è nel Figma, ma c'era già nella versione precedente della
/// schermata: toglierlo sarebbe una perdita secca per chi digita una password
/// lunga su tastiera del telefono.
class AuthPasswordField extends StatefulWidget {
  const AuthPasswordField({
    super.key,
    this.controller,
    this.hint = 'Password',
    this.validator,
    this.onChanged,
    this.textInputAction,
  });

  final TextEditingController? controller;
  final String hint;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;
  final TextInputAction? textInputAction;

  @override
  State<AuthPasswordField> createState() => _AuthPasswordFieldState();
}

class _AuthPasswordFieldState extends State<AuthPasswordField> {
  bool _nascosta = true;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      obscureText: _nascosta,
      textInputAction: widget.textInputAction,
      style: authFieldInputStyle(),
      cursorColor: OnlistColors.white,
      decoration: authFieldDecoration(
        hint: widget.hint,
        suffixIcon: IconButton(
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
          icon: Icon(
            _nascosta ? Icons.visibility_off : Icons.visibility,
            color: OnlistColors.authFieldHint,
            size: R.sp(20),
          ),
          onPressed: () => setState(() => _nascosta = !_nascosta),
        ),
      ),
      validator: widget.validator,
      onChanged: widget.onChanged,
    );
  }
}

/// Bottone grande del form: 215.87×40, sfondo bianco al 50%, raggio 28.
class AuthPrimaryButton extends StatelessWidget {
  const AuthPrimaryButton({
    super.key,
    required this.label,
    required this.onTap,
    this.enabled = true,
  });

  final String label;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: SizedBox(
        width: R.sp(AuthMetrics.buttonW),
        height: R.sp(AuthMetrics.buttonH),
        child: ElevatedButton(
          onPressed: enabled ? onTap : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: OnlistColors.authButtonLight,
            disabledBackgroundColor: OnlistColors.authButtonLight,
            foregroundColor: OnlistColors.white,
            elevation: 0,
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius:
                  BorderRadius.circular(R.sp(AuthMetrics.buttonRadius)),
            ),
          ),
          child: Text(
            label,
            style: OnlistTextStyles.hn(
              fontSize: R.sp(22),
              fontWeight: FontWeight.w400,
              height: 1.0,
              color: OnlistColors.white,
            ),
          ),
        ),
      ),
    );
  }
}

/// Pillola nera piccola: 97×33, testo 12. È il "Registrati" della schermata
/// di accesso.
class AuthSmallButton extends StatelessWidget {
  const AuthSmallButton({
    super.key,
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: R.sp(97),
      height: R.sp(33),
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: OnlistColors.black,
          foregroundColor: OnlistColors.white,
          elevation: 0,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(R.sp(28)),
          ),
        ),
        child: Text(
          label,
          style: OnlistTextStyles.hn(
            fontSize: R.sp(12),
            fontWeight: FontWeight.w400,
            height: 1.0,
            color: OnlistColors.white,
          ),
        ),
      ),
    );
  }
}
