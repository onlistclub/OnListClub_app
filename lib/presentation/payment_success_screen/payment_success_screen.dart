import 'package:flutter/material.dart';
import '../../core/services/navigator_service.dart';
import '../../routes/app_routes.dart';
import '../../theme/onlist_colors.dart';
import '../../theme/onlist_text_styles.dart';
import '../../widgets/custom_top_bar.dart';
import '../../widgets/shared_footer.dart';
import '../../widgets/onlist_primary_button.dart';

class PaymentSuccessScreen extends StatelessWidget {
  const PaymentSuccessScreen({Key? key}) : super(key: key);

  static Widget builder(BuildContext context) => const PaymentSuccessScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: OnlistColors.screenBackground),
        child: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const CustomTopBar(),
              const Spacer(flex: 3),
              // Titolo "a cascata" sfasato a destra (Figma). Il blocco intero è
              // scalato per non sforare sui telefoni stretti, mantenendo le
              // proporzioni esatte fra testo e indentazioni.
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(left: 40),
                      child: Text('ORDINE', style: OnlistTextStyles.display64Light),
                    ),
                    const Padding(
                      padding: EdgeInsets.only(left: 163),
                      child: Text('EFFETTUATO', style: OnlistTextStyles.title36Light),
                    ),
                    const SizedBox(height: 8),
                    const Padding(
                      padding: EdgeInsets.only(left: 163),
                      child: Text('Buon divertimento!', style: OnlistTextStyles.body20Light),
                    ),
                  ],
                ),
              ),
              const Spacer(flex: 4),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                child: OnlistPrimaryButton(
                  label: 'TORNA NELLA HOME',
                  onPressed: () => NavigatorService.pushNamedAndRemoveUntil(
                      AppRoutes.homeScreen),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const SharedFooter(currentIndex: 2),
    );
  }
}
