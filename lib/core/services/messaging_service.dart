import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Invio di email e SMS transazionali tramite Brevo.
///
/// Le chiamate passano dalle Edge Functions Supabase `send-email` e `send-sms`,
/// dove vive la `BREVO_API_KEY` (mai esposta al client — vedi CLAUDE.md §3).
/// `functions.invoke` allega automaticamente il JWT dell'utente loggato, quindi
/// le function (protette da verify_jwt) accettano solo chiamate autenticate.
///
/// IMPORTANTE: le email di verifica account / reset password NON passano da qui:
/// le gestisce Supabase Auth, che usa Brevo come server SMTP (configurato in
/// dashboard). Questo servizio è solo per le email/SMS transazionali dell'app
/// (conferma ordine, QR, annullamento, promemoria).
///
/// DEEP LINK: I link nelle email usano lo schema `onlistclub://` (custom scheme
/// registrato in AndroidManifest.xml + iOS Info.plist) per aprire direttamente
/// la schermata corretta dell'app. Mai link al sito web.
///   onlistclub://home     → Home
///   onlistclub://orders   → Sezione Ordini
class MessagingService {
  static SupabaseClient get _client => Supabase.instance.client;

  // ─────────────────────────────────────────────────────────────────────────
  // PRIMITIVE GENERICHE
  // ─────────────────────────────────────────────────────────────────────────

  /// Invia un'email. Ritorna `true` se Brevo ha accettato l'invio.
  ///
  /// In caso di errore NON lancia: logga e ritorna `false`, così l'invio email
  /// non può mai far fallire un flusso critico (es. completamento ordine).
  static Future<bool> sendEmail({
    required String to,
    String? toName,
    required String subject,
    required String htmlContent,
    String? textContent,
    String? replyTo,
  }) async {
    try {
      final res = await _client.functions.invoke(
        'send-email',
        body: {
          'to': to,
          if (toName != null) 'toName': toName,
          'subject': subject,
          'htmlContent': htmlContent,
          if (textContent != null) 'textContent': textContent,
          if (replyTo != null) 'replyTo': replyTo,
        },
      );
      final ok = res.status == 200 && (res.data?['ok'] == true);
      if (!ok) {
        debugPrint('[MessagingService] send-email non ok: '
            'status=${res.status} data=${res.data}');
      }
      return ok;
    } on FunctionException catch (e) {
      debugPrint('[MessagingService] send-email FunctionException: '
          '${e.status} ${e.details}');
      return false;
    } catch (e) {
      debugPrint('[MessagingService] send-email error: $e');
      return false;
    }
  }

  /// Invia un SMS. [toE164] è il numero in formato E.164 (con o senza `+`).
  /// Ritorna `true` se Brevo ha accettato l'invio.
  static Future<bool> sendSms({
    required String toE164,
    required String content,
  }) async {
    try {
      final res = await _client.functions.invoke(
        'send-sms',
        body: {
          'recipient': toE164,
          'content': content,
        },
      );
      final ok = res.status == 200 && (res.data?['ok'] == true);
      if (!ok) {
        debugPrint('[MessagingService] send-sms non ok: '
            'status=${res.status} data=${res.data}');
      }
      return ok;
    } on FunctionException catch (e) {
      debugPrint('[MessagingService] send-sms FunctionException: '
          '${e.status} ${e.details}');
      return false;
    } catch (e) {
      debugPrint('[MessagingService] send-sms error: $e');
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HELPER DI DOMINIO
  // ─────────────────────────────────────────────────────────────────────────

  /// Email di benvenuto dopo la verifica dell'email o il primo login Google.
  /// Da chiamare da `UserProfileManager.ensureProfileExists()` solo quando il
  /// profilo viene creato per la PRIMA volta (non ad ogni login).
  static Future<bool> sendWelcomeEmail({
    required String to,
    required String nome,
  }) {
    final nomeDisplay = nome.isNotEmpty ? nome : 'amico';
    final html = _buildWelcomeHtml(nomeDisplay);
    return sendEmail(
      to: to,
      toName: nome,
      subject: 'Benvenuto su OnListClub, $nomeDisplay! 🎶',
      htmlContent: html,
    );
  }

  /// Email di conferma prevendita/ordine con link diretto all'app (onlistclub://orders).
  /// Da chiamare dopo il completamento ordine in `BookingService.createReservation`.
  static Future<bool> sendOrderConfirmationEmail({
    required String to,
    required String nome,
    required String localeNome,
    required String eventoNome,
    required String dataEvento,
    DateTime? dataEventoDt,
    String? tipoTicket,
  }) {
    final nomeDisplay = nome.isNotEmpty ? nome : 'amico';
    final html = _buildOrderConfirmationHtml(
      nome: nomeDisplay,
      localeNome: localeNome,
      eventoNome: eventoNome,
      dataEvento: dataEvento,
      dataEventoDt: dataEventoDt,
      tipoTicket: tipoTicket,
    );
    return sendEmail(
      to: to,
      toName: nome,
      subject: 'Prevendita confermata — $localeNome',
      htmlContent: html,
    );
  }

  /// Email di notifica ingresso valido (QR scannerizzato con successo).
  /// Chiamata dalla Edge Function `on-scan-log` lato server (non dal client).
  /// Esposta qui come documentazione: la chiamata vera avviene server-side.
  static Future<bool> sendQrValidEmail({
    required String to,
    required String nome,
    required String localeNome,
    required String eventoNome,
    required DateTime checkinAt,
  }) {
    final timeStr = DateFormat('dd/MM/yyyy HH:mm', 'it_IT').format(checkinAt.toLocal());
    final html = _buildQrValidHtml(
      nome: nome.isNotEmpty ? nome : 'amico',
      localeNome: localeNome,
      eventoNome: eventoNome,
      checkinTime: timeStr,
    );
    return sendEmail(
      to: to,
      toName: nome,
      subject: '✅ Ingresso confermato — $localeNome',
      htmlContent: html,
    );
  }

  /// Email di avviso biglietto già usato (QR rifiutato all'ingresso).
  /// Chiamata dalla Edge Function `on-scan-log` lato server.
  static Future<bool> sendQrAlreadyUsedEmail({
    required String to,
    required String nome,
    required String localeNome,
    required String eventoNome,
    required DateTime firstScanAt,
  }) {
    final timeStr = DateFormat('dd/MM/yyyy HH:mm', 'it_IT').format(firstScanAt.toLocal());
    final html = _buildQrAlreadyUsedHtml(
      nome: nome.isNotEmpty ? nome : 'amico',
      localeNome: localeNome,
      eventoNome: eventoNome,
      firstScanTime: timeStr,
    );
    return sendEmail(
      to: to,
      toName: nome,
      subject: '⚠️ Biglietto già utilizzato — $localeNome',
      htmlContent: html,
    );
  }

  /// SMS promemoria serata (informativo, non OTP).
  static Future<bool> sendEventReminderSms({
    required String toE164,
    required String localeNome,
    required String dataEvento,
  }) {
    return sendSms(
      toE164: toE164,
      content:
          'Onlist Club: ti aspettiamo da $localeNome il $dataEvento! Mostra il QR in app all\'ingresso.',
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILDERS HTML (inline — allineati al design system di docs/email_templates/)
  // Stessa struttura e palette dei template .html in docs/email_templates/.
  // ─────────────────────────────────────────────────────────────────────────

  static String _htmlShell({
    required String preheader,
    required String title,
    required String cardContent,
  }) => '''<!DOCTYPE html>
<html lang="it">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <meta name="color-scheme" content="light dark" />
    <meta name="supported-color-schemes" content="light dark" />
    <title>$title</title>
    <style>
      body, .bg-outer { background-color: #eef1f8; }
      .card { background-color: #ffffff; border-color: #e1e5f0 !important; }
      .text-heading { color: #12131c !important; }
      .text-body { color: #525b70 !important; }
      .footer-link { color: #1b3fd6 !important; }
      .logo-plate { background-color: #8f95aa !important; border-color: #747a90 !important; }
      @media (prefers-color-scheme: dark) {
        body, .bg-outer { background-color: #05050f !important; }
        .card { background-color: #0d0f24 !important; border-color: #24304d !important; }
        .text-heading { color: #f4f6fb !important; }
        .text-body { color: #a9b3c6 !important; }
        .footer-link { color: #8fb4ff !important; }
        .logo-plate { background-color: transparent !important; border-color: transparent !important; }
      }
    </style>
  </head>
  <body class="bg-outer" style="margin:0;padding:0;background-color:#eef1f8;">
    <span style="display:none;max-height:0;overflow:hidden;opacity:0;">$preheader</span>
    <table role="presentation" width="100%" cellpadding="0" cellspacing="0" class="bg-outer" bgcolor="#eef1f8" style="background-color:#eef1f8;padding:36px 16px;">
      <tr><td align="center">
        <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:560px;">
          <tr>
            <td align="center" style="padding-bottom:28px;">
              <table role="presentation" cellpadding="0" cellspacing="0" style="margin:0 auto;">
                <tr>
                  <td align="center" class="logo-plate" bgcolor="#8f95aa" style="background-color:#8f95aa;border:1px solid #747a90;border-radius:20px;padding:20px 32px;">
                    <img src="https://www.onlistclub.com/email-logo.png" alt="OnListClub" width="140" style="display:block;width:140px;height:auto;border:0;margin:0 auto;" />
                  </td>
                </tr>
              </table>
            </td>
          </tr>
          <tr>
            <td class="card" bgcolor="#ffffff" style="background-color:#ffffff;border:1px solid #e1e5f0;border-radius:24px;padding:36px 32px;">
              $cardContent
            </td>
          </tr>
          <tr>
            <td align="center" style="padding-top:28px;">
              <p class="text-body" style="margin:0 0 6px;font-family:'Inter',Helvetica,Arial,sans-serif;font-size:12px;color:#525b70;">
                OnListClub — Prenota tavoli, prevendite e drink nei migliori locali.
              </p>
              <p class="text-body" style="margin:0;font-family:'Inter',Helvetica,Arial,sans-serif;font-size:12px;color:#525b70;">
                Hai domande? Scrivici a <a href="mailto:info@onlistclub.com" class="footer-link" style="color:#1b3fd6;text-decoration:none;">info@onlistclub.com</a>
              </p>
            </td>
          </tr>
        </table>
      </td></tr>
    </table>
  </body>
</html>''';

  static String _badge(String label, {String bgLight = 'rgba(19,62,255,0.08)', String borderLight = 'rgba(19,62,255,0.28)', String textLight = '#1b3fd6'}) =>
    '<table role="presentation" cellpadding="0" cellspacing="0" style="margin-bottom:20px;"><tr>'
    '<td style="border-radius:999px;background-color:$bgLight;border:1px solid $borderLight;padding:6px 14px;font-family:\'Inter\',Helvetica,Arial,sans-serif;font-size:11px;letter-spacing:.08em;text-transform:uppercase;color:$textLight;">'
    '$label</td></tr></table>';

  static String _ctaButton(String label, String href) =>
    '<table role="presentation" cellpadding="0" cellspacing="0" style="margin-top:24px;"><tr>'
    '<td bgcolor="#0098ff" style="border-radius:999px;background-color:#0098ff;background-image:linear-gradient(135deg,#133eff,#0098ff);">'
    '<a href="$href" style="display:inline-block;padding:13px 32px;font-family:\'Inter\',Helvetica,Arial,sans-serif;font-size:14px;font-weight:600;color:#ffffff;text-decoration:none;">$label</a>'
    '</td></tr></table>';

  static String _infoRow(String label, String value) =>
    '<tr><td style="padding-bottom:10px;">'
    '<p style="margin:0;font-family:\'Inter\',Helvetica,Arial,sans-serif;font-size:12px;letter-spacing:.06em;text-transform:uppercase;color:#8b93a7;">$label</p>'
    '<p style="margin:4px 0 0;font-family:\'Space Grotesk\',Helvetica,Arial,sans-serif;font-size:16px;font-weight:600;color:#12131c;" class="text-heading">$value</p>'
    '</td></tr>';

  static String _infoBox(List<String> rows, {String bg = '#f4f6fb', String border = '#e1e5f0'}) =>
    '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="margin-bottom:24px;"><tr>'
    '<td style="background-color:$bg;border:1px solid $border;border-radius:14px;padding:18px 20px;">'
    '<table role="presentation" width="100%" cellpadding="0" cellspacing="0">${rows.join()}</table>'
    '</td></tr></table>';

  // ── Welcome ────────────────────────────────────────────────────────────────
  static String _buildWelcomeHtml(String nome) {
    final card =
        _badge('Benvenuto') +
        '<h1 class="text-heading" style="margin:0 0 14px;font-family:\'Space Grotesk\',Helvetica,Arial,sans-serif;font-size:24px;line-height:1.25;color:#12131c;letter-spacing:-0.02em;">'
        'Sei dentro, $nome! 🎶</h1>'
        '<p class="text-body" style="margin:0 0 20px;font-family:\'Inter\',Helvetica,Arial,sans-serif;font-size:15px;line-height:1.6;color:#525b70;">'
        'Il tuo account OnListClub è attivo. Da adesso puoi prenotare tavoli, acquistare prevendite e ordinare drink nei migliori club della tua città — tutto dall\'app, senza code all\'ingresso.</p>'
        '<p class="text-body" style="margin:0 0 8px;font-family:\'Inter\',Helvetica,Arial,sans-serif;font-size:15px;line-height:1.6;color:#525b70;">'
        'Apri l\'app, scegli il tuo locale preferito e inizia a vivere la notte.</p>'
        + _ctaButton('Apri OnListClub →', 'onlistclub://home');
    return _htmlShell(
      preheader: 'Benvenuto su OnListClub! Il tuo account è attivo. Apri l\'app e inizia a prenotare.',
      title: 'Benvenuto su OnListClub!',
      cardContent: card,
    );
  }

  /// Saluto in testa all'email di conferma, in base a quanto manca alla
  /// serata: stasera/stanotte, domani sera, oppure il giorno della settimana
  /// (da 2 giorni di distanza in su, "2" incluso).
  static String _salutoPrevendita(DateTime? dataEventoDt) {
    if (dataEventoDt == null) return 'Ci vediamo stanotte! 🎉';
    final ora = DateTime.now();
    final oggi = DateTime(ora.year, ora.month, ora.day);
    final giornoEvento =
        DateTime(dataEventoDt.year, dataEventoDt.month, dataEventoDt.day);
    final giorni = giornoEvento.difference(oggi).inDays;
    if (giorni <= 0) return 'Ci vediamo stanotte! 🎉';
    if (giorni == 1) return 'Ci vediamo domani sera! 🎉';
    final giornoSettimana =
        DateFormat('EEEE', 'it_IT').format(dataEventoDt);
    return 'Ci vediamo $giornoSettimana! 🎉';
  }

  // ── Order Confirmation ─────────────────────────────────────────────────────
  static String _buildOrderConfirmationHtml({
    required String nome,
    required String localeNome,
    required String eventoNome,
    required String dataEvento,
    DateTime? dataEventoDt,
    String? tipoTicket,
  }) {
    final rows = [
      _infoRow('Locale', _escHtml(localeNome)),
      _infoRow('Serata', _escHtml(eventoNome)),
      _infoRow('Data', _escHtml(dataEvento)),
      if (tipoTicket != null && tipoTicket.isNotEmpty)
        _infoRow('Tipo biglietto', _escHtml(tipoTicket)),
    ];
    final card =
        _badge('Prevendita confermata') +
        '<h1 class="text-heading" style="margin:0 0 14px;font-family:\'Space Grotesk\',Helvetica,Arial,sans-serif;font-size:24px;line-height:1.25;color:#12131c;letter-spacing:-0.02em;">'
        '${_salutoPrevendita(dataEventoDt)}</h1>'
        '<p class="text-body" style="margin:0 0 24px;font-family:\'Inter\',Helvetica,Arial,sans-serif;font-size:15px;line-height:1.6;color:#525b70;">'
        'Ciao <strong style="color:#12131c;">$nome</strong>, la tua prevendita è confermata. Ecco il riepilogo:</p>'
        + _infoBox(rows)
        + _ctaButton('Vedi il tuo biglietto nell\'app →', 'onlistclub://orders')
        + '<p class="text-body" style="margin:16px 0 0;font-family:\'Inter\',Helvetica,Arial,sans-serif;font-size:13px;line-height:1.6;color:#525b70;">'
        'Mostra il QR code all\'ingresso. Aprilo dalla sezione <strong>Ordini</strong> nell\'app OnListClub.</p>';
    return _htmlShell(
      preheader: 'La tua prevendita per $eventoNome è confermata. Apri l\'app per vedere il QR di ingresso.',
      title: 'Prevendita confermata — OnListClub',
      cardContent: card,
    );
  }

  // ── QR Valid ───────────────────────────────────────────────────────────────
  static String _buildQrValidHtml({
    required String nome,
    required String localeNome,
    required String eventoNome,
    required String checkinTime,
  }) {
    final rows = [
      _infoRow('Locale', _escHtml(localeNome)),
      _infoRow('Serata', _escHtml(eventoNome)),
      _infoRow('Check-in', _escHtml(checkinTime)),
    ];
    final card =
        _badge('Ingresso confermato', bgLight: 'rgba(22,163,74,0.08)', borderLight: 'rgba(22,163,74,0.28)', textLight: '#15803d') +
        '<h1 class="text-heading" style="margin:0 0 14px;font-family:\'Space Grotesk\',Helvetica,Arial,sans-serif;font-size:24px;line-height:1.25;color:#12131c;letter-spacing:-0.02em;">'
        'Sei entrato! Divertiti 🎟️</h1>'
        '<p class="text-body" style="margin:0 0 24px;font-family:\'Inter\',Helvetica,Arial,sans-serif;font-size:15px;line-height:1.6;color:#525b70;">'
        'Ciao <strong style="color:#12131c;">$nome</strong>, il tuo biglietto è stato scannerizzato con successo all\'ingresso.</p>'
        + _infoBox(rows, bg: '#f0fdf4', border: 'rgba(22,163,74,0.25)');
    return _htmlShell(
      preheader: 'Il tuo biglietto per $eventoNome è stato scannerizzato: ingresso confermato! Divertiti.',
      title: 'Ingresso confermato — OnListClub',
      cardContent: card,
    );
  }

  // ── QR Already Used ────────────────────────────────────────────────────────
  static String _buildQrAlreadyUsedHtml({
    required String nome,
    required String localeNome,
    required String eventoNome,
    required String firstScanTime,
  }) {
    final rows = [
      _infoRow('Locale', _escHtml(localeNome)),
      _infoRow('Serata', _escHtml(eventoNome)),
      _infoRow('Prima scansione', _escHtml(firstScanTime)),
    ];
    final card =
        _badge('Biglietto già usato', bgLight: 'rgba(234,88,12,0.08)', borderLight: 'rgba(234,88,12,0.28)', textLight: '#c2410c') +
        '<h1 class="text-heading" style="margin:0 0 14px;font-family:\'Space Grotesk\',Helvetica,Arial,sans-serif;font-size:24px;line-height:1.25;color:#12131c;letter-spacing:-0.02em;">'
        'Scansione non accettata ⚠️</h1>'
        '<p class="text-body" style="margin:0 0 24px;font-family:\'Inter\',Helvetica,Arial,sans-serif;font-size:15px;line-height:1.6;color:#525b70;">'
        'Ciao <strong style="color:#12131c;">$nome</strong>, il tuo biglietto è stato rifiutato all\'ingresso perché è già stato utilizzato in precedenza.</p>'
        + _infoBox(rows, bg: '#fff7ed', border: 'rgba(234,88,12,0.22)')
        + '<p class="text-body" style="margin:0 0 8px;font-family:\'Inter\',Helvetica,Arial,sans-serif;font-size:14px;line-height:1.6;color:#525b70;">'
        '<strong style="color:#12131c;">Non sei stato tu?</strong><br />'
        'Se non riconosci questo accesso, il tuo QR potrebbe essere stato condiviso. Contattaci subito.</p>'
        + _ctaButton('Vedi i tuoi ordini nell\'app →', 'onlistclub://orders');
    return _htmlShell(
      preheader: 'Attenzione: il tuo biglietto per $eventoNome è già stato utilizzato in precedenza.',
      title: 'Biglietto già utilizzato — OnListClub',
      cardContent: card,
    );
  }

  /// Escaping minimo per testo variabile inserito nell'HTML.
  static String _escHtml(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
}
