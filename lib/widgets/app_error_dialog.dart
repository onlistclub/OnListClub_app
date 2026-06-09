import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Mostra un errore come popup nativo del sistema (adattivo):
/// stile Cupertino su iOS, stile Material su Android.
///
/// Sostituisce gli SnackBar grigi usati in precedenza per gli errori. Oltre
/// ad avere l'aspetto di un avviso "del telefono", essendo un dialog modale
/// non si accoda/ripete come facevano gli SnackBar emessi dai listener BLoC.
Future<void> showAppErrorDialog(
  BuildContext context,
  String message, {
  String title = 'Errore',
}) {
  return showAdaptiveDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog.adaptive(
      title: Text(title),
      content: Text(message),
      actions: [
        _adaptiveOkAction(dialogContext),
      ],
    ),
  );
}

/// Bottone "OK" che usa lo stile nativo della piattaforma:
/// `CupertinoDialogAction` su iOS/macOS, `TextButton` altrove.
Widget _adaptiveOkAction(BuildContext context) {
  void close() => Navigator.of(context).pop();
  switch (Theme.of(context).platform) {
    case TargetPlatform.iOS:
    case TargetPlatform.macOS:
      return CupertinoDialogAction(
        onPressed: close,
        child: const Text('OK'),
      );
    default:
      return TextButton(
        onPressed: close,
        child: const Text('OK'),
      );
  }
}
