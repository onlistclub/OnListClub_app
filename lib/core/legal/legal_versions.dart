/// Versioni correnti dei documenti legali (privacy policy e termini) mostrati
/// all'utente in registrazione e alla riapertura dell'app.
///
/// ── COME FUNZIONA ────────────────────────────────────────────────────────────
/// La versione accettata dall'utente viene scritta nella tabella
/// `user_consents` su Supabase (vedi migration 017_user_consents.sql). Al
/// login, lo splash confronta le versioni qui sotto con l'ultima accettazione
/// dell'utente: se una delle due è più recente, [LegalConsentService.needsReacceptance]
/// restituisce true e la UI mostra la schermata di ri-accettazione.
///
/// ── COME AGGIORNARE ──────────────────────────────────────────────────────────
/// Quando cambia il testo di privacy o termini sul sito (Sito_Web_OnListClub_MVP/
/// src/routes/privacy.tsx o termini.tsx):
///   1. Aggiorna anche il "Ultimo aggiornamento" e il "Documento legale ·
///      Versione X.Y" sul sito.
///   2. Incrementa il valore di [kPrivacyVersion] o [kTermsVersion] qui.
///   3. Aggiorna la data corrispondente [kPrivacyUpdatedAt] o [kTermsUpdatedAt].
///   4. Aggiorna la stessa costante nel sito (`src/lib/legal-versions.ts`) per
///      tenere le due sorgenti in sync.
///
/// Al prossimo avvio dell'app tutti gli utenti loggati vedranno la schermata
/// di ri-accettazione.
library;

/// Versione corrente della Privacy Policy. Incrementare quando cambia il
/// testo sul sito, così l'app forza la ri-accettazione.
const String kPrivacyVersion = '2.0';

/// Versione corrente dei Termini e condizioni. Incrementare quando cambia
/// il testo sul sito, così l'app forza la ri-accettazione.
const String kTermsVersion = '2.0';

/// Data leggibile del testo attualmente pubblicato, mostrata sotto ai link
/// nella schermata di registrazione e nella schermata di ri-accettazione.
const String kPrivacyUpdatedAt = '21 settembre 2026';
const String kTermsUpdatedAt = '21 settembre 2026';

/// URL pubblici delle pagine legali sul sito. L'app non ospita i testi:
/// vengono aperti nel browser tramite `url_launcher` con [Uri.parse].
const String kPrivacyUrl = 'https://www.onlistclub.com/privacy';
const String kTermsUrl = 'https://www.onlistclub.com/termini';
const String kCookiePolicyUrl = 'https://www.onlistclub.com/cookie-policy';
