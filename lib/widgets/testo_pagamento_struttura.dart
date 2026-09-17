import 'package:flutter/material.dart';

import '../core/app_export.dart';
import '../theme/onlist_text_styles.dart';

/// "Il pagamento dovrà essere effettuato in struttura", unico per la scelta
/// ticket e per i biglietti dopo l'ordine.
///
/// CSS NUOVO "Carrello - Ticket Normale" (16/09): 29/29 Light, -0.08em,
/// bianco al 78%, box largo 186 → va a capo su 4 righe. Il doc correzioni
/// chiedeva di ingrandirlo (era 20) in entrambi i punti. La larghezza la
/// decide il chiamante.
class TestoPagamentoInStruttura extends StatelessWidget {
  const TestoPagamentoInStruttura({super.key});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.78,
      child: Text(
        'Il pagamento dovrà essere effettuato in struttura',
        style: OnlistTextStyles.hn(
          color: Colors.white,
          fontSize: R.sp(29),
          fontWeight: FontWeight.w300,
          height: 1.0,
          letterSpacing: -0.08 * R.sp(29),
        ),
      ),
    );
  }
}
