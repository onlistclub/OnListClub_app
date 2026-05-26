import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/utils/navigator_service.dart';
import '../../routes/app_routes.dart';
import '../../widgets/shared_footer.dart';

class PaymentSuccessScreen extends StatelessWidget {
  const PaymentSuccessScreen({Key? key}) : super(key: key);

  static Widget builder(BuildContext context) => const PaymentSuccessScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            const Spacer(),
            Center(
              child: Text(
                "Ordine effettuato",
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 30),
            // Bottone per andare agli ordini
            GestureDetector(
              onTap: () => NavigatorService.pushNamed(AppRoutes.ordersScreen),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 40),
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1D00FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Vedi i tuoi ordini',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const Spacer(),
          ],
        ),
      ),
      bottomNavigationBar: const SharedFooter(currentIndex: 1),
    );
  }


  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: GestureDetector(
        onTap: () => NavigatorService.goBack(),
        child: Row(
          children: [
            const Icon(Icons.arrow_back, color: Colors.white, size: 20),
            const SizedBox(width: 6),
            Text(
              'Torna indietro',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackButton() {
    return Padding(
      padding: const EdgeInsets.only(left: 10, top: 10),
      child: GestureDetector(
        onTap: () => NavigatorService.goBack(),
        child: Row(
          children: [
            const Icon(Icons.arrow_back, color: Colors.white, size: 28),
            const SizedBox(width: 10),
            Text(
              'Torna indietro',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNav() => const SharedFooter(currentIndex: 1);
}
