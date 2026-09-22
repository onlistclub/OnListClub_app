import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/legal/legal_versions.dart';
import '../../core/services/legal_consent_service.dart';
import '../../core/services/navigator_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/utils/analytics_mixin.dart';
import '../../routes/app_routes.dart';
import '../../theme/onlist_colors.dart';
import '../../theme/onlist_text_styles.dart';

/// Schermata bloccante di ri-accettazione delle informative legali.
///
/// L'app naviga qui, invece che direttamente alla home, quando lo splash
/// rileva che l'utente ha una sessione valida ma le versioni accettate di
/// privacy o termini sono più vecchie delle correnti definite in
/// [kPrivacyVersion] / [kTermsVersion].
///
/// Due sole vie d'uscita:
///  - "Accetto" → registra il consenso alla versione corrente e va alla home;
///  - "Esci" → logout e ritorno alla schermata di autenticazione.
///
/// La schermata NON ha un pulsante "indietro" perché il primo login dopo
/// l'aggiornamento della privacy deve OBBLIGARE la scelta: se ha già una
/// sessione ma non ha accettato la versione corrente, il servizio non può
/// essere usato.
class LegalReacceptScreen extends StatefulWidget {
  const LegalReacceptScreen({Key? key, required this.status}) : super(key: key);

  final LegalReacceptanceStatus status;

  static Widget builder(BuildContext context) {
    // Lo status vero arriva dallo splash come argomento. Se manca (avvio
    // diretto per test, deep link inatteso) forziamo un check pessimistico.
    final args = ModalRoute.of(context)?.settings.arguments as Map?;
    final status = args?['status'] as LegalReacceptanceStatus? ??
        const LegalReacceptanceStatus(
          needsReacceptance: true,
          firstTime: true,
          needsPrivacy: true,
          needsTerms: true,
        );
    return LegalReacceptScreen(status: status);
  }

  @override
  State<LegalReacceptScreen> createState() => _LegalReacceptScreenState();
}

class _LegalReacceptScreenState extends State<LegalReacceptScreen>
    with ScreenAnalytics {
  @override
  String get screenName => 'legal_reaccept';

  bool _accepted = false;
  bool _isSaving = false;

  Future<void> _onAccept() async {
    if (!_accepted || _isSaving) return;
    setState(() => _isSaving = true);
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      // Sessione persa mentre l'utente decideva: torniamo al login.
      NavigatorService.pushNamedAndRemoveUntil(AppRoutes.authenticationScreen);
      return;
    }
    await LegalConsentService.recordConsent(
      userId: userId,
      source: 'app_reprompt',
      extraMetadata: {
        'needs_privacy': widget.status.needsPrivacy,
        'needs_terms': widget.status.needsTerms,
        'first_time': widget.status.firstTime,
      },
    );
    if (!mounted) return;
    NavigatorService.pushNamedAndRemoveUntil(AppRoutes.homeScreen);
  }

  Future<void> _onDecline() async {
    // Non accetta: unica via è il logout. Registrare il consenso a un
    // documento non accettato sarebbe una bugia legale.
    try {
      await AuthService.instance.signOut();
    } catch (_) {
      // Se il logout fallisce (rete assente), navighiamo comunque al login:
      // la sessione locale sarà pulita al prossimo avvio riuscito.
    }
    if (!mounted) return;
    NavigatorService.pushNamedAndRemoveUntil(AppRoutes.authenticationScreen);
  }

  Future<void> _openLegal(String url) async {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    // Copy adatta al contesto: prima volta ("mancano tutti e due") vs
    // aggiornamento di un solo documento.
    final title = widget.status.firstTime
        ? 'Prima di continuare'
        : 'Abbiamo aggiornato le nostre policy';
    final subtitle = widget.status.firstTime
        ? 'Per usare OnListClub devi accettare la Privacy Policy e i Termini e condizioni. Ti chiediamo di prenderne visione ora — è un passaggio richiesto una volta sola.'
        : _buildUpdateSubtitle();

    return DecoratedBox(
      decoration:
          const BoxDecoration(gradient: OnlistColors.onboardingBackground),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 40),
                Text(title, style: OnlistTextStyles.display40Regular),
                const SizedBox(height: 24),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontFamily: 'OnlistHN',
                    fontSize: 15,
                    height: 1.5,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Documenti aggiornati al $kPrivacyUpdatedAt (Privacy) e $kTermsUpdatedAt (Termini).',
                  style: const TextStyle(
                    fontFamily: 'OnlistHN',
                    fontSize: 12,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 32),
                _CheckboxRow(
                  checked: _accepted,
                  onChanged: (v) => setState(() => _accepted = v),
                  onTapPrivacy: () => _openLegal(kPrivacyUrl),
                  onTapTerms: () => _openLegal(kTermsUrl),
                ),
                const SizedBox(height: 40),
                Center(
                  child: _isSaving
                      ? const CircularProgressIndicator(color: OnlistColors.white)
                      : SizedBox(
                          width: 200,
                          height: 44,
                          child: ElevatedButton(
                            onPressed: _accepted ? _onAccept : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: OnlistColors.white,
                              foregroundColor: OnlistColors.black,
                              disabledBackgroundColor:
                                  OnlistColors.white.withValues(alpha: 0.4),
                              disabledForegroundColor:
                                  OnlistColors.black.withValues(alpha: 0.6),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                            child: Text('Accetto e continuo',
                                style: OnlistTextStyles.button16Bold),
                          ),
                        ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: TextButton(
                    onPressed: _isSaving ? null : _onDecline,
                    child: const Text(
                      'Non accetto — esci',
                      style: TextStyle(
                        fontFamily: 'OnlistHN',
                        fontSize: 14,
                        color: Colors.white70,
                        decoration: TextDecoration.underline,
                        decorationColor: Colors.white70,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _buildUpdateSubtitle() {
    if (widget.status.needsPrivacy && widget.status.needsTerms) {
      return 'Abbiamo pubblicato una nuova versione della Privacy Policy e dei Termini e condizioni. Per continuare a usare OnListClub ti chiediamo di prenderne visione e di accettarle.';
    }
    if (widget.status.needsPrivacy) {
      return 'Abbiamo pubblicato una nuova versione della Privacy Policy. Per continuare a usare OnListClub ti chiediamo di prenderne visione e di accettarla.';
    }
    return 'Abbiamo aggiornato i Termini e condizioni. Per continuare a usare OnListClub ti chiediamo di prenderne visione e di accettarli.';
  }
}

class _CheckboxRow extends StatelessWidget {
  const _CheckboxRow({
    required this.checked,
    required this.onChanged,
    required this.onTapPrivacy,
    required this.onTapTerms,
  });

  final bool checked;
  final ValueChanged<bool> onChanged;
  final VoidCallback onTapPrivacy;
  final VoidCallback onTapTerms;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => onChanged(!checked),
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: 22,
            height: 22,
            margin: const EdgeInsets.only(top: 2, right: 12),
            decoration: BoxDecoration(
              color: checked ? OnlistColors.white : Colors.transparent,
              border: Border.all(color: OnlistColors.white, width: 1.6),
              borderRadius: BorderRadius.circular(4),
            ),
            alignment: Alignment.center,
            child: checked
                ? const Icon(Icons.check, size: 16, color: OnlistColors.black)
                : null,
          ),
        ),
        Expanded(
          child: GestureDetector(
            onTap: () => onChanged(!checked),
            behavior: HitTestBehavior.opaque,
            child: Text.rich(
              TextSpan(
                style: const TextStyle(
                  fontFamily: 'OnlistHN',
                  fontSize: 14,
                  height: 1.4,
                  color: Colors.white,
                ),
                children: [
                  const TextSpan(text: 'Ho letto e accetto la '),
                  TextSpan(
                    text: 'Privacy Policy',
                    style: const TextStyle(
                      decoration: TextDecoration.underline,
                      fontWeight: FontWeight.w600,
                    ),
                    recognizer: TapGestureRecognizer()..onTap = onTapPrivacy,
                  ),
                  const TextSpan(text: ' e i '),
                  TextSpan(
                    text: 'Termini e condizioni',
                    style: const TextStyle(
                      decoration: TextDecoration.underline,
                      fontWeight: FontWeight.w600,
                    ),
                    recognizer: TapGestureRecognizer()..onTap = onTapTerms,
                  ),
                  const TextSpan(text: ' aggiornati di OnListClub.'),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
