import 'package:flutter/material.dart';

/// Spinner standard dell'app: `CircularProgressIndicator` con il colore brand
/// (`#1D00FF`). Da usare ovunque serva un loading, per consistenza visiva.
class AppLoadingIndicator extends StatelessWidget {
  const AppLoadingIndicator({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(color: Color(0xFF1D00FF)),
    );
  }
}
