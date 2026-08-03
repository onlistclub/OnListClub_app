import 'package:flutter/material.dart';

/// Prezzo grande ("25€") con il simbolo di valuta staccato dal numero.
///
/// Gli stili prezzo del design (`price96`/`price192`) usano la crenatura
/// negativa del Figma (-0.08em). Flutter la applica dopo ogni glifo, quindi
/// anche tra l'ultima cifra e il "€": a 192px sono ~15px che tirano il
/// simbolo sopra la cifra. Qui il numero conserva la crenatura del design,
/// mentre la giunzione numero→simbolo viene neutralizzata e distanziata di
/// un soffio, restando compatta come nel Figma.
///
/// Il simbolo è anche più PICCOLO delle cifre e appoggia sulla loro stessa
/// linea di base — vedi [_symbolScale].
///
/// Tutte le misure derivano dal `fontSize` dello stile: nessun pixel fisso.
class OnlistPriceText extends StatelessWidget {
  const OnlistPriceText(
    this.price, {
    super.key,
    required this.style,
    this.textAlign,
  });

  /// Prezzo già formattato, es. "25€" o "12.50€".
  final String price;
  final TextStyle style;
  final TextAlign? textAlign;

  /// Respiro reale tra cifra e simbolo, in em.
  static const double _gapEm = 0.02;

  /// Il simbolo di valuta è più piccolo delle cifre.
  ///
  /// Misurato sul PNG ufficiale (`Carrello - Ticket.png`, prezzo a 96px): le
  /// cifre sono alte 69 px design e il "€" 47, cioè il **68%**, con lo stesso
  /// bordo inferiore — nell'app usciva invece alto 71, più GRANDE delle cifre e
  /// pure più in alto.
  ///
  /// Basta rimpicciolire lo span: dentro una riga di testo gli span condividono
  /// la linea di base, quindi il simbolo scende da solo senza offset manuali.
  static const double _symbolScale = 0.68;

  /// Numero (cifre, punto, virgola) seguito dal simbolo di valuta finale.
  static final RegExp _priceRe = RegExp(r'^([\d.,]+)(\D)$');

  @override
  Widget build(BuildContext context) {
    final match = _priceRe.firstMatch(price.trim());
    // Stringhe non riconosciute (es. il placeholder "—") restano com'erano.
    if (match == null) {
      return Text(price, style: style, textAlign: textAlign);
    }

    final digits = match.group(1)!;
    final symbol = match.group(2)!;
    final head = digits.substring(0, digits.length - 1);
    final lastDigit = digits.substring(digits.length - 1);
    final gap = (style.fontSize ?? 0) * _gapEm;

    return Text.rich(
      TextSpan(
        style: style,
        children: [
          if (head.isNotEmpty) TextSpan(text: head),
          // La crenatura dell'ultima cifra è l'unica che tocca il simbolo:
          // da negativa diventa il gap minimo voluto dal design.
          TextSpan(text: lastDigit, style: TextStyle(letterSpacing: gap)),
          // Azzerata sul simbolo: è in coda, altrimenti stringerebbe il box.
          TextSpan(
            text: symbol,
            style: TextStyle(
              letterSpacing: 0,
              fontSize: (style.fontSize ?? 0) * _symbolScale,
            ),
          ),
        ],
      ),
      textAlign: textAlign,
    );
  }
}
