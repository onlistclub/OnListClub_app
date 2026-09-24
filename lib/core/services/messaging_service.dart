import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Invio di email e SMS transazionali tramite Brevo.
///
/// Le chiamate passano dalle Edge Functions Supabase `send-email` e `send-sms`,
/// dove vive la `BREVO_API_KEY` (mai esposta al client, vedi CLAUDE.md §3).
/// `functions.invoke` allega automaticamente il JWT dell'utente loggato, quindi
/// le function (protette da verify_jwt) accettano solo chiamate autenticate.
///
/// IMPORTANTE: le email di verifica account / reset password NON passano da qui:
/// le gestisce Supabase Auth, che usa Brevo come server SMTP (configurato in
/// dashboard). Questo servizio è solo per le email/SMS transazionali dell'app
/// (conferma ordine, QR, annullamento, promemoria).
///
/// LAYOUT EMAIL: shell "ZUCC" ufficiale usato anche dai template statici in
/// `docs/email_templates/`. Card trasparente con border a colore d'accento
/// (viola per informativi, verde per conferme d'ingresso, arancio per warning),
/// logo wordmark che si swappa via CSS tra light e dark mode. Gli asset PNG
/// vivono sul sito (`https://www.onlistclub.com/email-logo-onlist-{light,dark}.png`)
/// e nelle icone (`email-icon-check.png`, `email-icon-moon.png`,
/// `email-icon-phone.png`), tutti caricati esternamente e non inline base64 per
/// stare sotto il limite Gmail di 102KB per messaggio.
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

  /// Email di benvenuto dopo la verifica dell'email o il primo login OAuth.
  /// Da chiamare da `UserProfileManager.ensureProfileExists()` (utenti email+pw)
  /// o da `CompleteProfileBloc._onSubmit` (utenti Google/Apple) solo quando il
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
      subject: 'Benvenuto su OnListClub, $nomeDisplay',
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
    String? reservationId,
  }) {
    final nomeDisplay = nome.isNotEmpty ? nome : 'amico';
    final html = _buildOrderConfirmationHtml(
      nome: nomeDisplay,
      localeNome: localeNome,
      eventoNome: eventoNome,
      dataEvento: dataEvento,
      dataEventoDt: dataEventoDt,
      tipoTicket: tipoTicket,
      reservationId: reservationId,
    );
    return sendEmail(
      to: to,
      toName: nome,
      subject: 'Prevendita confermata: $localeNome',
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
      subject: 'Ingresso confermato: $localeNome',
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
      subject: 'Biglietto già utilizzato: $localeNome',
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
          'Onlist Club: ti aspettiamo da $localeNome il $dataEvento. Mostra il QR in app all\'ingresso.',
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILDERS HTML — shell ZUCC condiviso con docs/email_templates/
  //
  // Convenzione colori: ogni email ha un "accento" che tinge border card,
  // border details-box e badge. Tre varianti:
  //   purple → informativi (welcome, ordine)
  //   green  → conferme d'ingresso (qr_valid)
  //   orange → warning (qr_already_used)
  // ─────────────────────────────────────────────────────────────────────────

  static const _logoLightUrl = 'https://www.onlistclub.com/email-logo-onlist-light.png';
  static const _logoDarkUrl = 'https://www.onlistclub.com/email-logo-onlist-dark.png';
  static const _iconCheckUrl = 'https://www.onlistclub.com/email-icon-check.png';
  static const _iconMoonUrl = 'https://www.onlistclub.com/email-icon-moon.png';
  static const _iconPhoneUrl = 'https://www.onlistclub.com/email-icon-phone.png';

  // Accento viola (default).
  static const _accentPurpleBorder = '#A78BFA';
  static const _accentPurpleGlow = 'rgba(139,92,246,.26)';
  static const _accentPurpleShadow = 'rgba(47,34,77,.12)';
  static const _accentPurpleBadgeBorder = 'rgba(124,58,237,0.35)';
  static const _accentPurpleBadgeText = '#7C3AED';
  static const _accentPurpleDetailsBorder = '#C4B5FD';

  // Accento verde (ingresso confermato).
  static const _accentGreenBorder = '#86EFAC';
  static const _accentGreenGlow = 'rgba(22,163,74,.26)';
  static const _accentGreenShadow = 'rgba(6,78,59,.12)';
  static const _accentGreenBadgeBorder = 'rgba(22,163,74,0.40)';
  static const _accentGreenBadgeText = '#15803D';

  // Accento arancio (warning).
  static const _accentOrangeBorder = '#FDBA74';
  static const _accentOrangeGlow = 'rgba(234,88,12,.26)';
  static const _accentOrangeShadow = 'rgba(124,45,18,.12)';
  static const _accentOrangeBadgeBorder = 'rgba(234,88,12,0.40)';
  static const _accentOrangeBadgeText = '#C2410C';

  static String _htmlShell({
    required String preheader,
    required String title,
    required String cardContent,
    String cardBorder = _accentPurpleBorder,
    String cardGlow = _accentPurpleGlow,
    String cardShadow = _accentPurpleShadow,
    String detailsBorder = _accentPurpleDetailsBorder,
  }) => '''<!DOCTYPE html>
<html lang="it" xmlns="http://www.w3.org/1999/xhtml" xmlns:v="urn:schemas-microsoft-com:vml" xmlns:o="urn:schemas-microsoft-com:office:office">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <meta name="color-scheme" content="light dark">
  <meta name="supported-color-schemes" content="light dark">
  <meta name="x-apple-disable-message-reformatting">
  <title>$title</title>
  <!--[if mso]>
  <noscript><xml><o:OfficeDocumentSettings><o:PixelsPerInch>96</o:PixelsPerInch></o:OfficeDocumentSettings></xml></noscript>
  <![endif]-->
  <style>
    html,body{margin:0!important;padding:0!important;width:100%!important;min-width:100%!important;height:100%!important;-webkit-text-size-adjust:100%;-ms-text-size-adjust:100%;}
    body{background-color:transparent!important;color:inherit;}
    table,td{mso-table-lspace:0pt!important;mso-table-rspace:0pt!important;}
    img{border:0;height:auto;line-height:100%;outline:none;text-decoration:none;-ms-interpolation-mode:bicubic;}
    a{text-decoration:none;}
    .email-container{box-sizing:border-box!important;width:100%!important;max-width:560px!important;background-color:transparent!important;border:2px solid $cardBorder!important;border-radius:22px!important;padding:36px 32px!important;box-shadow:0 0 0 1px $cardGlow,0 0 22px $cardGlow,0 18px 42px $cardShadow!important;}
    .logo-light,.logo-dark{display:block!important;width:200px!important;max-width:78%!important;height:auto!important;margin:0 auto!important;}
    .logo-dark{display:none!important;}
    .text-title,.text-body,.text-bold-name,.details-value,.details-label,.note-bold,.note-text,.footer-text{color:inherit!important;}
    .details-box{background-color:transparent!important;border:1.5px solid $detailsBorder!important;border-radius:16px!important;}
    .detail-cell:first-child{padding-right:16px!important;}
    .detail-cell:nth-child(2){padding-left:16px!important;}
    .note-box{background-color:transparent!important;border:1.5px solid $detailsBorder!important;border-radius:14px!important;}
    .footer-divider{border-top-color:rgba(127,111,150,.35)!important;}
    .footer-link{color:$_accentPurpleBadgeText!important;}
    .cta-cell{background:$_accentPurpleBadgeText!important;background-image:linear-gradient(135deg,$_accentPurpleBadgeText 0%,#6366F1 52%,#4F46E5 100%)!important;border-radius:999px!important;box-shadow:0 8px 22px rgba(124,58,237,.22)!important;}
    .cta-link{display:block!important;min-height:48px!important;box-sizing:border-box!important;padding:14px 20px!important;color:#FFFFFF!important;}
    @media only screen and (max-width:600px){
      .outer-wrapper-cell{padding:20px 10px 36px 10px!important;}
      .email-container{max-width:100%!important;padding:26px 20px!important;border-radius:18px!important;}
      .logo-light,.logo-dark{width:170px!important;max-width:72%!important;}
      .header-logo-cell{padding-bottom:24px!important;}
      .text-title{font-size:24px!important;}
      .detail-cell{display:block!important;width:100%!important;padding-left:0!important;padding-right:0!important;padding-bottom:14px!important;}
    }
    [data-ogsc] .logo-light{display:none!important;}
    [data-ogsc] .logo-dark{display:block!important;}
    @media (prefers-color-scheme: dark){
      .logo-light{display:none!important;}
      .logo-dark{display:block!important;}
      .email-container{border-color:$cardBorder!important;box-shadow:0 0 0 1px $cardGlow,0 0 24px $cardGlow,0 18px 44px rgba(0,0,0,.16)!important;}
    }
  </style>
</head>
<body style="background:transparent;margin:0;padding:0;width:100%;min-width:100%;font-family:'Helvetica Neue',Helvetica,Arial,sans-serif;">
  <span style="display:none;font-size:1px;color:transparent;line-height:1px;max-height:0px;max-width:0px;opacity:0;overflow:hidden;">$preheader</span>
  <table class="outer-wrapper" width="100%" height="100%" cellpadding="0" cellspacing="0" border="0" style="width:100%;min-width:100%;height:100%;table-layout:fixed;">
    <tr>
      <td align="center" valign="top" class="outer-wrapper-cell" style="padding:28px 16px 48px 16px;">
        <!--[if mso]><table align="center" width="560" style="width:560px;"><tr><td><![endif]-->
        <table class="email-container" width="100%" cellpadding="0" cellspacing="0" border="0" style="box-sizing:border-box;width:100%;max-width:560px;background-color:transparent;border:2px solid $cardBorder;border-radius:22px;padding:36px 32px;box-shadow:0 0 0 1px $cardGlow,0 0 22px $cardGlow,0 18px 42px $cardShadow;">
          <tr>
            <td class="header-logo-cell" align="center" style="padding-bottom:28px;">
              <img class="logo-light" src="$_logoLightUrl" alt="OnListClub" width="200" style="display:block;width:200px;max-width:78%;height:auto;border:0;margin:0 auto;">
              <img class="logo-dark"  src="$_logoDarkUrl"  alt="OnListClub" width="200" style="display:none; width:200px;max-width:78%;height:auto;border:0;margin:0 auto;">
            </td>
          </tr>
          $cardContent
          <tr>
            <td class="footer-divider" style="border-top:1.5px solid #E8E3EF;padding-top:22px;" align="center">
              <p class="footer-text" style="margin:0 0 6px;font-family:'Helvetica Neue',Helvetica,Arial,sans-serif;font-size:12px;text-align:center;">
                OnListClub. Prenota tavoli, prevendite e drink nei migliori locali.
              </p>
              <p class="footer-text" style="margin:0;font-family:'Helvetica Neue',Helvetica,Arial,sans-serif;font-size:12px;text-align:center;">
                Hai domande? Scrivici a <a href="mailto:info@onlistclub.com" class="footer-link" style="text-decoration:none;color:$_accentPurpleBadgeText;" target="_blank">info@onlistclub.com</a>
              </p>
            </td>
          </tr>
        </table>
        <!--[if mso]></td></tr></table><![endif]-->
      </td>
    </tr>
  </table>
</body>
</html>''';

  /// Badge pill in cima al contenuto (sotto il logo).
  static String _badge(
    String label, {
    String borderColor = _accentPurpleBadgeBorder,
    String textColor = _accentPurpleBadgeText,
    String? iconUrl,
  }) {
    final iconTag = iconUrl != null
        ? '<img src="$iconUrl" alt="" width="14" height="14" style="display:inline-block;vertical-align:-2px;width:14px;height:14px;border:0;margin-right:6px;">'
        : '';
    return '<tr><td align="left" style="padding-bottom:18px;">'
        '<table cellpadding="0" cellspacing="0" border="0"><tr>'
        '<td style="border:1.5px solid $borderColor;border-radius:9999px;padding:6px 14px;">'
        '<span style="font-family:\'Helvetica Neue\',Helvetica,Arial,sans-serif;font-size:11px;font-weight:700;letter-spacing:0.08em;text-transform:uppercase;color:$textColor;">$iconTag$label</span>'
        '</td></tr></table>'
        '</td></tr>';
  }

  /// H1 principale della card.
  static String _heading(String innerHtml) =>
      '<tr><td align="left" style="padding-bottom:14px;">'
      '<h1 class="text-title" style="margin:0;font-family:\'Helvetica Neue\',Helvetica,Arial,sans-serif;font-size:26px;line-height:1.25;font-weight:700;">$innerHtml</h1>'
      '</td></tr>';

  /// Paragrafo standard del corpo.
  static String _body(String innerHtml, {int paddingBottom = 24, int fontSize = 15}) =>
      '<tr><td align="left" style="padding-bottom:${paddingBottom}px;">'
      '<p class="text-body" style="margin:0;font-family:\'Helvetica Neue\',Helvetica,Arial,sans-serif;font-size:${fontSize}px;line-height:1.6;">$innerHtml</p>'
      '</td></tr>';

  /// Cella singola della details-box (label uppercase + valore bold).
  static String _detailCell(String label, String value, {bool bottomPadded = true}) {
    final padBottom = bottomPadded ? 'padding-bottom:18px;' : '';
    return '<td class="detail-cell" width="50%" style="${padBottom}vertical-align:top;">'
        '<p class="details-label" style="margin:0 0 4px;font-family:\'Helvetica Neue\',Helvetica,Arial,sans-serif;font-size:11px;font-weight:400;text-transform:uppercase;letter-spacing:0.08em;">${_escHtml(label)}</p>'
        '<p class="details-value" style="margin:0;font-family:\'Helvetica Neue\',Helvetica,Arial,sans-serif;font-size:16px;font-weight:700;">$value</p>'
        '</td>';
  }

  static String _emptyCell({bool bottomPadded = false}) {
    final padBottom = bottomPadded ? 'padding-bottom:18px;' : '';
    return '<td class="detail-cell" width="50%" style="${padBottom}vertical-align:top;"></td>';
  }

  /// details-box con celle a griglia 2 colonne × N righe.
  /// [rows] è una lista di righe, ogni riga è una lista di 2 celle HTML già
  /// prodotte (via `_detailCell` o `_emptyCell`).
  static String _detailsBox(List<List<String>> rows, {String border = _accentPurpleDetailsBorder}) {
    final rowsHtml = rows.map((cells) {
      // Se manca una cella, riempiamo con vuoto per non rompere il layout.
      final left = cells.isNotEmpty ? cells[0] : _emptyCell();
      final right = cells.length > 1 ? cells[1] : _emptyCell();
      return '<tr>$left$right</tr>';
    }).join();
    return '<tr><td style="padding-bottom:24px;">'
        '<table class="details-box" width="100%" cellpadding="0" cellspacing="0" border="0" style="background-color:transparent;border:1.5px solid $border;border-radius:16px;padding:20px 20px;">$rowsHtml</table>'
        '</td></tr>';
  }

  /// Note-box centrata (usata per "Mostra il QR all'ingresso").
  static String _noteBox(String innerHtml, {String border = _accentPurpleDetailsBorder}) =>
      '<tr><td style="padding-bottom:28px;">'
      '<table class="note-box" width="100%" cellpadding="0" cellspacing="0" border="0" style="background-color:transparent;border:1.5px solid $border;border-radius:14px;padding:13px 16px;">'
      '<tr><td align="center" style="text-align:center;">'
      '<p class="note-text" style="margin:0;font-family:\'Helvetica Neue\',Helvetica,Arial,sans-serif;font-size:13px;line-height:1.5;text-align:center;">$innerHtml</p>'
      '</td></tr></table>'
      '</td></tr>';

  /// CTA gradient viola centrata.
  static String _ctaButton(String label, String href) =>
      '<tr><td style="padding-bottom:28px;">'
      '<table width="100%" cellpadding="0" cellspacing="0" border="0"><tr>'
      '<td align="center" class="cta-cell" style="background:$_accentPurpleBadgeText;background-color:$_accentPurpleBadgeText;background-image:linear-gradient(135deg,$_accentPurpleBadgeText 0%,#6366F1 52%,#4F46E5 100%);border-radius:999px;box-shadow:0 8px 22px rgba(124,58,237,.28);">'
      '<a href="$href" class="cta-link" style="display:block;min-height:48px;box-sizing:border-box;padding:14px 20px;font-family:\'Helvetica Neue\',Helvetica,Arial,sans-serif;font-size:15px;font-weight:600;text-decoration:none;color:#FFFFFF;text-align:center;" target="_blank">${_escHtml(label)}</a>'
      '</td></tr></table>'
      '</td></tr>';

  // ── Welcome ────────────────────────────────────────────────────────────────
  static String _buildWelcomeHtml(String nome) {
    final card =
        _badge('Benvenuto') +
        _heading('Sei dentro, ${_escHtml(nome)}.') +
        _body(
          'Il tuo account OnListClub è attivo. Puoi prenotare tavoli, acquistare prevendite e ordinare drink nei migliori club della tua città, direttamente dall\'app.',
          paddingBottom: 16,
        ) +
        _body("Apri l'app e scegli il tuo locale.", paddingBottom: 28) +
        _ctaButton('Apri OnListClub', 'onlistclub://home');
    return _htmlShell(
      preheader: "Il tuo account OnListClub è attivo. Apri l'app e inizia a prenotare.",
      title: 'Benvenuto su OnListClub',
      cardContent: card,
    );
  }

  /// Saluto in testa all'email di conferma, in base a quanto manca alla
  /// serata: stasera/stanotte, domani sera, oppure il giorno della settimana
  /// (da 2 giorni di distanza in su, "2" incluso).
  static String _salutoPrevendita(DateTime? dataEventoDt) {
    if (dataEventoDt == null) return 'Ci vediamo stanotte.';
    final ora = DateTime.now();
    final oggi = DateTime(ora.year, ora.month, ora.day);
    final giornoEvento =
        DateTime(dataEventoDt.year, dataEventoDt.month, dataEventoDt.day);
    final giorni = giornoEvento.difference(oggi).inDays;
    if (giorni <= 0) return 'Ci vediamo stanotte.';
    if (giorni == 1) return 'Ci vediamo domani sera.';
    final giornoSettimana =
        DateFormat('EEEE', 'it_IT').format(dataEventoDt);
    return 'Ci vediamo $giornoSettimana.';
  }

  // ── Order Confirmation ─────────────────────────────────────────────────────
  static String _buildOrderConfirmationHtml({
    required String nome,
    required String localeNome,
    required String eventoNome,
    required String dataEvento,
    DateTime? dataEventoDt,
    String? tipoTicket,
    String? reservationId,
  }) {
    // Griglia 2×N: (Locale|Serata) → (Data|TipoBiglietto?).
    final hasTicket = tipoTicket != null && tipoTicket.isNotEmpty;
    final rows = <List<String>>[
      [_detailCell('Locale', _escHtml(localeNome)), _detailCell('Serata', _escHtml(eventoNome))],
      [
        _detailCell('Data', _escHtml(dataEvento), bottomPadded: false),
        hasTicket
            ? _detailCell('Tipo biglietto', _escHtml(tipoTicket), bottomPadded: false)
            : _emptyCell(),
      ],
    ];
    final orderLink = (reservationId != null && reservationId.isNotEmpty)
        ? 'onlistclub://orders?id=$reservationId'
        : 'onlistclub://orders';
    final saluto = _salutoPrevendita(dataEventoDt);
    final moonIcon =
        '<img src="$_iconMoonUrl" alt="" width="28" height="28" style="display:inline-block;vertical-align:-5px;width:28px;height:28px;border:0;margin-left:4px;">';
    final phoneIcon =
        '<img src="$_iconPhoneUrl" alt="" width="18" height="18" style="display:inline-block;vertical-align:-4px;width:18px;height:18px;border:0;margin-right:6px;">';

    final card =
        _badge('Prevendita confermata', iconUrl: _iconCheckUrl) +
        _heading('${_escHtml(saluto)} $moonIcon') +
        _body(
          '<strong class="text-bold-name" style="font-weight:700;">${_escHtml(nome)}</strong>, la tua prevendita è confermata.<br>Ecco il riepilogo:',
        ) +
        _detailsBox(rows) +
        _ctaButton("Vedi il tuo biglietto nell'app", orderLink) +
        _noteBox(
          '${phoneIcon}Mostra il QR code all\'ingresso.<br>Aprilo dalla sezione <strong class="note-bold" style="font-weight:700;">Ordini</strong> nell\'app OnListClub.',
        );

    return _htmlShell(
      preheader:
          "La tua prevendita per ${_escHtml(eventoNome)} è confermata. Apri l'app per vedere il QR di ingresso.",
      title: 'Prevendita confermata',
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
    final rows = <List<String>>[
      [_detailCell('Locale', _escHtml(localeNome)), _detailCell('Serata', _escHtml(eventoNome))],
      [_detailCell('Check-in', _escHtml(checkinTime), bottomPadded: false), _emptyCell()],
    ];

    final card =
        _badge(
          'Ingresso confermato',
          borderColor: _accentGreenBadgeBorder,
          textColor: _accentGreenBadgeText,
          iconUrl: _iconCheckUrl,
        ) +
        _heading('Sei entrato.') +
        _body(
          '<strong class="text-bold-name" style="font-weight:700;">${_escHtml(nome)}</strong>, il tuo biglietto è stato scannerizzato all\'ingresso.',
        ) +
        _detailsBox(rows, border: _accentGreenBorder);

    return _htmlShell(
      preheader:
          "Il tuo biglietto per ${_escHtml(eventoNome)} è stato scannerizzato. Ingresso confermato.",
      title: 'Ingresso confermato',
      cardContent: card,
      cardBorder: _accentGreenBorder,
      cardGlow: _accentGreenGlow,
      cardShadow: _accentGreenShadow,
      detailsBorder: _accentGreenBorder,
    );
  }

  // ── QR Already Used ────────────────────────────────────────────────────────
  static String _buildQrAlreadyUsedHtml({
    required String nome,
    required String localeNome,
    required String eventoNome,
    required String firstScanTime,
  }) {
    final rows = <List<String>>[
      [_detailCell('Locale', _escHtml(localeNome)), _detailCell('Serata', _escHtml(eventoNome))],
      [_detailCell('Prima scansione', _escHtml(firstScanTime), bottomPadded: false), _emptyCell()],
    ];

    final card =
        _badge(
          'Biglietto già usato',
          borderColor: _accentOrangeBadgeBorder,
          textColor: _accentOrangeBadgeText,
        ) +
        _heading('Scansione non accettata.') +
        _body(
          '<strong class="text-bold-name" style="font-weight:700;">${_escHtml(nome)}</strong>, il tuo biglietto è stato rifiutato all\'ingresso perché è già stato utilizzato.',
        ) +
        _detailsBox(rows, border: _accentOrangeBorder) +
        _body(
          '<strong class="text-bold-name" style="font-weight:700;">Non sei stato tu?</strong><br>Se non riconosci questo accesso, il tuo QR potrebbe essere stato condiviso. Contattaci subito.',
          fontSize: 14,
        ) +
        _ctaButton("Vedi i tuoi ordini nell'app", 'onlistclub://orders');

    return _htmlShell(
      preheader:
          "Il tuo biglietto per ${_escHtml(eventoNome)} è già stato utilizzato.",
      title: 'Biglietto già utilizzato',
      cardContent: card,
      cardBorder: _accentOrangeBorder,
      cardGlow: _accentOrangeGlow,
      cardShadow: _accentOrangeShadow,
      detailsBorder: _accentOrangeBorder,
    );
  }

  /// Escaping minimo per testo variabile inserito nell'HTML.
  static String _escHtml(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
}
