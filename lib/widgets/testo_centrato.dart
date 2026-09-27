import 'package:flutter/material.dart';

/// Testo centrato DAVVERO, anche con la crenatura negativa del design.
///
/// Flutter toglie lo spazio della crenatura anche **dopo l'ultima lettera**:
/// con `letterSpacing: -0.1em` il paragrafo misura un decimo di corpo meno
/// dell'inchiostro che disegna. Chi lo centra — un `Center`, un
/// `alignment: Alignment.center`, un `textAlign: TextAlign.center` — centra
/// quella misura, non le lettere, e la scritta finisce mezza crenatura più a
/// destra del centro vero: su un titolo a corpo 64 sono più di 3 px, che si
/// vedono (punto 7.1 del documento "Specifiche Modifiche App").
///
/// Qui lo spazio mancante viene restituito a destra, così il riquadro torna
/// largo quanto l'inchiostro e centrarlo centra le lettere. È lo stesso
/// rimedio che [FitOneLineText] applica già al suo interno: questo widget
/// serve dove il testo NON deve rimpicciolirsi per starci.
class TestoCentrato extends StatelessWidget {
  const TestoCentrato(
    this.text, {
    super.key,
    required this.style,
    this.maxLines,
    this.overflow,
  });

  final String text;
  final TextStyle style;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) {
    final double crenatura = style.letterSpacing ?? 0;
    return Padding(
      padding: EdgeInsets.only(right: crenatura < 0 ? -crenatura : 0),
      child: Text(
        text,
        textAlign: TextAlign.center,
        maxLines: maxLines,
        overflow: overflow,
        style: style,
      ),
    );
  }
}
