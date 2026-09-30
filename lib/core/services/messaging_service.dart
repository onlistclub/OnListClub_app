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
/// dashboard). Questo servizio e' solo per le email/SMS transazionali dell'app
/// (conferma ordine, QR, annullamento, promemoria).
///
/// LAYOUT EMAIL: shell "mobile" ufficiale (docs/email_templates/mobile.html),
/// forzato dark via `meta color-scheme:dark` cosi' che sia iOS Mail, Gmail,
/// Outlook e webmail lo presentino identico a prescindere dal tema del client.
/// Card blu notte `#071421` con gradient e border blu chiaro `#42A5FF`,
/// wordmark `mail-dark.png` esterno (272KB su onlistclub.com), CTA gradient
/// blu scuro. Nessun adattamento light/dark, nessun swap CSS, nessuna
/// inversione da parte di iOS Mail perche' il colore chiave e' nella
/// background-image gradient che iOS non tocca.
///
/// DEEP LINK: I link nelle email usano lo schema `onlistclub://` (custom scheme
/// registrato in AndroidManifest.xml + iOS Info.plist).
///   onlistclub://home              → Home
///   onlistclub://orders            → Sezione Ordini
///   onlistclub://orders?id=<uuid>  → Dettaglio prevendita (vedi DeepLinkService).
class MessagingService {
  static SupabaseClient get _client => Supabase.instance.client;

  // ─────────────────────────────────────────────────────────────────────────
  // PRIMITIVE GENERICHE
  // ─────────────────────────────────────────────────────────────────────────

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
  // API PUBBLICHE
  // ─────────────────────────────────────────────────────────────────────────

  static Future<bool> sendWelcomeEmail({
    required String to,
    required String nome,
  }) {
    final nomeDisplay = nome.isNotEmpty ? nome : 'amico';
    return sendEmail(
      to: to,
      toName: nome,
      subject: 'Benvenuto su OnListClub, $nomeDisplay',
      htmlContent: _buildWelcomeHtml(nomeDisplay),
    );
  }

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
    return sendEmail(
      to: to,
      toName: nome,
      subject: 'Prevendita confermata: $localeNome',
      htmlContent: _buildOrderConfirmationHtml(
        nome: nomeDisplay,
        localeNome: localeNome,
        eventoNome: eventoNome,
        dataEvento: dataEvento,
        dataEventoDt: dataEventoDt,
        tipoTicket: tipoTicket,
        reservationId: reservationId,
      ),
    );
  }

  static Future<bool> sendQrValidEmail({
    required String to,
    required String nome,
    required String localeNome,
    required String eventoNome,
    required DateTime checkinAt,
  }) {
    final timeStr = DateFormat('dd/MM/yyyy HH:mm', 'it_IT').format(checkinAt.toLocal());
    return sendEmail(
      to: to,
      toName: nome,
      subject: 'Ingresso confermato: $localeNome',
      htmlContent: _buildQrValidHtml(
        nome: nome.isNotEmpty ? nome : 'amico',
        localeNome: localeNome,
        eventoNome: eventoNome,
        checkinTime: timeStr,
      ),
    );
  }

  static Future<bool> sendQrAlreadyUsedEmail({
    required String to,
    required String nome,
    required String localeNome,
    required String eventoNome,
    required DateTime firstScanAt,
  }) {
    final timeStr = DateFormat('dd/MM/yyyy HH:mm', 'it_IT').format(firstScanAt.toLocal());
    return sendEmail(
      to: to,
      toName: nome,
      subject: 'Biglietto gia\' utilizzato: $localeNome',
      htmlContent: _buildQrAlreadyUsedHtml(
        nome: nome.isNotEmpty ? nome : 'amico',
        localeNome: localeNome,
        eventoNome: eventoNome,
        firstScanTime: timeStr,
      ),
    );
  }

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
  // BUILDERS HTML — shell mobile ufficiale
  //
  // Il CSS shell e' identico in tutti i template (colori blu notte, gradient,
  // border, badge, cta). Cambia solo il contenuto card (heading+badge, body,
  // details, cta, note). Per non ripetere ~70 righe di CSS ogni volta, il
  // metodo `_htmlShell` assembla:
  //   <head><style>SHELL_CSS + PROVIDED_CSS</style></head>
  //   <body>OUTER_WRAPPER > EMAIL_CONTAINER > logo + [CARD_CONTENT] + footer
  // ─────────────────────────────────────────────────────────────────────────

  static const _logoUrl = 'https://www.onlistclub.com/mail-dark.png';

  /// CSS condiviso da tutti i template. Include gia' details-box e note-box
  /// perche' aggiungere quelle regole non usate ha costo praticamente nullo
  /// nel byte-count del messaggio.
  static const String _shellCss = '''
    :root{color-scheme:dark;}
    html,body{margin:0!important;padding:0!important;width:100%!important;min-width:100%!important;height:100%!important;-webkit-text-size-adjust:100%;-ms-text-size-adjust:100%;}
    body{background-color:transparent!important;color:#F2F7FC!important;}
    table,td{mso-table-lspace:0pt!important;mso-table-rspace:0pt!important;}
    img{border:0;height:auto;line-height:100%;outline:none;text-decoration:none;-ms-interpolation-mode:bicubic;}
    a{text-decoration:none;}
    .outer-wrapper{background-color:transparent!important;background-image:none!important;}
    .email-container,.details-box,.note-box{box-sizing:border-box!important;background-color:rgba(10,27,45,.94)!important;background-image:linear-gradient(155deg,rgba(0,119,255,.24) 0%,rgba(10,27,45,.90) 42%,rgba(10,27,45,.96) 100%)!important;border:1px solid #42A5FF!important;border-radius:22px!important;box-shadow:inset 0 1px 0 rgba(130,195,255,.48),0 18px 42px rgba(4,13,24,.42),0 0 22px rgba(0,119,255,.18)!important;}
    .email-container{width:100%!important;max-width:600px!important;padding:36px 32px!important;background-color:#071421!important;background-image:linear-gradient(155deg,rgba(0,119,255,.10) 0%,rgba(7,20,33,.97) 42%,rgba(5,14,24,.99) 100%)!important;box-shadow:inset 0 1px 0 rgba(130,195,255,.28),0 18px 42px rgba(3,12,22,.62),0 0 30px rgba(0,119,255,.24)!important;}
    .logo-light{display:block!important;width:240px!important;max-width:78%!important;height:auto!important;margin:0 auto!important;}
    .text-title,.text-body,.text-bold-name,.details-value,.note-bold,.note-text,.footer-text{color:#F2F7FC!important;}
    .details-label{color:#A9D6FF!important;}
    .detail-cell:first-child{padding-right:16px!important;}
    .detail-cell:nth-child(2){padding-left:16px!important;}
    .footer-divider{border-top-color:rgba(130,195,255,.42)!important;}
    .footer-link{color:#C7E6FF!important;text-decoration:underline!important;}
    .heading-status-row{width:100%!important;table-layout:fixed!important;}
    .heading-cell{width:48%!important;text-align:left!important;vertical-align:middle!important;}
    .status-cell{width:52%!important;text-align:right!important;vertical-align:middle!important;}
    .heading-cell .text-title{font-size:25px!important;}
    .badge-bg{box-sizing:border-box!important;width:auto!important;padding:6px 9px!important;border:1px solid rgba(130,195,255,.42)!important;border-radius:26px!important;background-color:#0B1B2D!important;background-image:linear-gradient(150deg,rgba(0,119,255,.14),rgba(10,27,45,.96))!important;box-shadow:inset 0 1px 0 rgba(130,195,255,.3)!important;text-align:center!important;vertical-align:middle!important;}
    .badge-text{color:#F2F7FC!important;font-size:16px!important;line-height:1.25!important;font-weight:700!important;}
    .badge-bg-ok{box-sizing:border-box!important;width:auto!important;padding:6px 9px!important;border:1px solid rgba(134,239,172,.55)!important;border-radius:26px!important;background-color:#0E2016!important;background-image:linear-gradient(150deg,rgba(22,163,74,.28),rgba(10,27,45,.96))!important;box-shadow:inset 0 1px 0 rgba(134,239,172,.35)!important;text-align:center!important;vertical-align:middle!important;}
    .badge-text-ok{color:#B7F5C7!important;font-size:16px!important;line-height:1.25!important;font-weight:700!important;}
    .badge-bg-warn{box-sizing:border-box!important;width:auto!important;padding:6px 9px!important;border:1px solid rgba(253,186,116,.55)!important;border-radius:26px!important;background-color:#241610!important;background-image:linear-gradient(150deg,rgba(234,88,12,.30),rgba(10,27,45,.96))!important;box-shadow:inset 0 1px 0 rgba(253,186,116,.35)!important;text-align:center!important;vertical-align:middle!important;}
    .badge-text-warn{color:#FDE1B2!important;font-size:16px!important;line-height:1.25!important;font-weight:700!important;}
    .note-box{width:84%!important;margin-left:auto!important;margin-right:auto!important;}
    .cta-cell{background:#0077FF!important;background-image:linear-gradient(135deg,#005CC8 0%,#0049A3 52%,#00377C 100%)!important;border-radius:999px!important;box-shadow:inset 0 1px 0 rgba(255,255,255,.22),0 0 8px rgba(255,255,255,.28),0 0 18px rgba(255,255,255,.16),0 8px 20px rgba(255,255,255,.10)!important;}
    .cta-link{display:block!important;min-height:48px!important;box-sizing:border-box!important;padding:14px 20px!important;font-size:15px!important;line-height:1.4!important;font-weight:600!important;letter-spacing:.3px!important;color:#FFFFFF!important;}
    @media only screen and (max-width:600px){
      .outer-wrapper-cell{vertical-align:middle!important;padding:12px 8px!important;}
      .email-container{padding:14px 12px!important;}
      .header-logo-cell{padding-bottom:12px!important;}
      .logo-light{width:190px!important;}
      .heading-cell,.status-cell{display:table-cell!important;vertical-align:middle!important;}
      .heading-cell{width:57%!important;text-align:left!important;}
      .status-cell{width:43%!important;text-align:center!important;}
      .heading-cell .text-title{font-size:24px!important;line-height:1.2!important;}
      .badge-bg,.badge-bg-ok,.badge-bg-warn{padding:4px 6px!important;}
      .badge-text,.badge-text-ok,.badge-text-warn{font-size:12px!important;letter-spacing:0!important;line-height:1.1!important;white-space:nowrap!important;}
      .text-body{font-size:14px!important;line-height:1.4!important;}
      .details-box{padding:12px!important;}
      .detail-cell:first-child{padding-right:6px!important;}
      .detail-cell:nth-child(2){padding-left:6px!important;}
      .details-value{font-size:14px!important;}
      .cta-link{min-height:42px!important;padding:10px 14px!important;}
      .note-box{width:100%!important;padding:12px 12px!important;}
      .note-text{font-size:12px!important;line-height:1.35!important;}
      .footer-divider{padding-top:14px!important;}
      .footer-text{font-size:11px!important;line-height:1.3!important;}
    }
    @media only screen and (max-width:360px){
      .heading-cell,.status-cell{display:block!important;width:100%!important;text-align:center!important;}
      .heading-cell .text-title{text-align:center!important;}
      .status-cell{padding-top:8px!important;}
    }
''';

  static String _htmlShell({
    required String preheader,
    required String title,
    required String cardContent,
  }) => '''<!DOCTYPE html>
<html lang="it" xmlns="http://www.w3.org/1999/xhtml" xmlns:v="urn:schemas-microsoft-com:vml" xmlns:o="urn:schemas-microsoft-com:office:office">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <meta name="color-scheme" content="dark">
  <meta name="supported-color-schemes" content="dark">
  <meta name="x-apple-disable-message-reformatting">
  <title>$title</title>
  <!--[if mso]><noscript><xml><o:OfficeDocumentSettings><o:PixelsPerInch>96</o:PixelsPerInch></o:OfficeDocumentSettings></xml></noscript><![endif]-->
  <style>$_shellCss</style>
</head>
<body style="background:transparent;background-color:transparent;margin:0;padding:0;width:100%;min-width:100%;font-family:'Helvetica Neue',Helvetica,Arial,sans-serif;">
  <span style="display:none;font-size:1px;color:transparent;line-height:1px;max-height:0px;max-width:0px;opacity:0;overflow:hidden;">$preheader</span>
  <table class="outer-wrapper" width="100%" height="100%" cellpadding="0" cellspacing="0" border="0" style="width:100%;min-width:100%;height:100%;table-layout:fixed;background-color:transparent;background-image:none;">
    <tr>
      <td align="center" valign="middle" class="outer-wrapper-cell" style="padding:28px 16px;vertical-align:middle;">
        <table bgcolor="#071421" class="email-container" width="100%" cellpadding="0" cellspacing="0" border="0" style="box-sizing:border-box;width:100%;max-width:560px;background-color:#071421;background-image:linear-gradient(155deg,rgba(0,119,255,.10) 0%,rgba(7,20,33,.97) 42%,rgba(5,14,24,.99) 100%);border:1px solid #42A5FF;border-radius:22px;padding:36px 32px;box-shadow:inset 0 1px 0 rgba(130,195,255,.28),0 18px 42px rgba(3,12,22,.62),0 0 30px rgba(0,119,255,.24);">
          <tr>
            <td class="header-logo-cell" align="center" style="padding-bottom:28px;">
              <img class="logo-light" src="$_logoUrl" alt="OnListClub" width="240" height="102" style="display:block;width:240px;max-width:78%;height:102px;border:0;margin:0 auto;">
            </td>
          </tr>
          $cardContent
          <tr>
            <td class="footer-divider" style="border-top:1px solid rgba(130,195,255,.42);padding-top:22px;" align="center">
              <p class="footer-text" style="margin:0 0 6px;font-family:'Helvetica Neue',Helvetica,Arial,sans-serif;font-size:12px;text-align:center;">
                OnListClub. Prenota tavoli, prevendite e drink nei migliori locali.
              </p>
              <p class="footer-text" style="margin:0;font-family:'Helvetica Neue',Helvetica,Arial,sans-serif;font-size:12px;text-align:center;">
                Hai domande? Scrivici a <a href="mailto:info@onlistclub.com" class="footer-link" style="text-decoration:underline;color:#C7E6FF;" target="_blank">info@onlistclub.com</a>
              </p>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>''';

  /// Row del titolo con badge affiancato a destra.
  /// [badgeClass] sceglie il colore: `badge-bg` (blu), `badge-bg-ok` (verde),
  /// `badge-bg-warn` (arancio). [badgeTextClass] segue lo stesso pattern.
  static String _headingWithBadge({
    required String title,
    required String badgeLabel,
    String badgeClass = 'badge-bg',
    String badgeTextClass = 'badge-text',
    String badgeInlineBg = '#0B1B2D',
    String badgeInlineBorder = 'rgba(130,195,255,.42)',
    String badgeInlineGrad = 'linear-gradient(150deg,rgba(0,119,255,.14),rgba(10,27,45,.96))',
    String badgeInlineShadow = 'inset 0 1px 0 rgba(130,195,255,.3)',
    String badgeInlineTextColor = '#F2F7FC',
  }) => '''
          <tr>
            <td style="padding-bottom:14px;">
              <table class="heading-status-row" width="100%" cellpadding="0" cellspacing="0" border="0" role="presentation" style="width:100%;table-layout:fixed;">
                <tr>
                  <td class="heading-cell" width="48%" align="left" valign="middle">
                    <h1 class="text-title" style="margin:0;font-family:'Helvetica Neue',Helvetica,Arial,sans-serif;font-size:26px;line-height:1.25;font-weight:700;">$title</h1>
                  </td>
                  <td class="status-cell" width="52%" align="right" valign="middle">
                    <table align="right" cellpadding="0" cellspacing="0" border="0" role="presentation" style="width:auto;margin:0 0 0 auto;">
                      <tr>
                        <td class="$badgeClass" valign="middle" style="border:1px solid $badgeInlineBorder;border-radius:26px;padding:6px 9px;background-color:$badgeInlineBg;background-image:$badgeInlineGrad;box-shadow:$badgeInlineShadow;text-align:center;vertical-align:middle;">
                          <span class="$badgeTextClass" style="font-family:'Helvetica Neue',Helvetica,Arial,sans-serif;font-size:16px;font-weight:700;line-height:1.25;color:$badgeInlineTextColor;">$badgeLabel</span>
                        </td>
                      </tr>
                    </table>
                  </td>
                </tr>
              </table>
            </td>
          </tr>
''';

  static String _body(String htmlInside, {int paddingBottom = 24, int fontSize = 15}) => '''
          <tr>
            <td align="left" style="padding-bottom:${paddingBottom}px;">
              <p class="text-body" style="margin:0;font-family:'Helvetica Neue',Helvetica,Arial,sans-serif;font-size:${fontSize}px;line-height:1.6;">$htmlInside</p>
            </td>
          </tr>
''';

  static String _ctaButton(String label, String href, {int paddingBottom = 28}) => '''
          <tr>
            <td style="padding-bottom:${paddingBottom}px;">
              <table width="100%" cellpadding="0" cellspacing="0" border="0"><tr>
                <td align="center" class="cta-cell" style="background:#0077FF;background-color:#0077FF;background-image:linear-gradient(135deg,#005CC8 0%,#0049A3 52%,#00377C 100%);border-radius:999px;box-shadow:inset 0 1px 0 rgba(255,255,255,.22),0 0 8px rgba(255,255,255,.28),0 0 18px rgba(255,255,255,.16),0 8px 20px rgba(255,255,255,.10);">
                  <a href="$href" class="cta-link" style="display:block;min-height:48px;box-sizing:border-box;padding:14px 20px;font-family:'Helvetica Neue',Helvetica,Arial,sans-serif;font-size:15px;line-height:1.4;font-weight:600;letter-spacing:.3px;text-decoration:none;color:#FFFFFF;text-align:center;" target="_blank">${_escHtml(label)}</a>
                </td>
              </tr></table>
            </td>
          </tr>
''';

  static String _detailCell(String label, String value, {bool bottomPadded = true}) {
    final pb = bottomPadded ? 'padding-bottom:18px;' : '';
    return '<td class="detail-cell" width="50%" style="${pb}vertical-align:top;">'
        '<p class="details-label" style="margin:0 0 4px;font-family:\'Helvetica Neue\',Helvetica,Arial,sans-serif;font-size:11px;font-weight:400;text-transform:uppercase;letter-spacing:0.08em;color:#A9D6FF;">${_escHtml(label)}</p>'
        '<p class="details-value" style="margin:0;font-family:\'Helvetica Neue\',Helvetica,Arial,sans-serif;font-size:16px;font-weight:700;color:#F2F7FC;">$value</p>'
        '</td>';
  }

  static String _emptyCell() =>
      '<td class="detail-cell" width="50%" style="vertical-align:top;"></td>';

  static String _detailsBox(List<List<String>> rows) {
    final rowsHtml = rows.map((cells) {
      final left = cells.isNotEmpty ? cells[0] : _emptyCell();
      final right = cells.length > 1 ? cells[1] : _emptyCell();
      return '<tr>$left$right</tr>';
    }).join();
    return '''
          <tr>
            <td style="padding-bottom:24px;">
              <table bgcolor="#0B1B2D" class="details-box" width="100%" cellpadding="0" cellspacing="0" border="0" style="background-color:rgba(10,27,45,.94);background-image:linear-gradient(155deg,rgba(0,119,255,.24) 0%,rgba(10,27,45,.90) 42%,rgba(10,27,45,.96) 100%);border:1px solid #42A5FF;border-radius:22px;padding:20px 20px;box-shadow:inset 0 1px 0 rgba(130,195,255,.48),0 18px 42px rgba(4,13,24,.42),0 0 22px rgba(0,119,255,.18);">
                $rowsHtml
              </table>
            </td>
          </tr>
''';
  }

  static String _noteBox(String htmlInside) => '''
          <tr>
            <td style="padding-bottom:28px;">
              <table align="center" bgcolor="#0B1B2D" class="note-box" width="100%" cellpadding="0" cellspacing="0" border="0" style="background-color:rgba(10,27,45,.94);background-image:linear-gradient(155deg,rgba(0,119,255,.24) 0%,rgba(10,27,45,.90) 42%,rgba(10,27,45,.96) 100%);border:1px solid #42A5FF;border-radius:22px;padding:13px 16px;box-shadow:inset 0 1px 0 rgba(130,195,255,.48),0 18px 42px rgba(4,13,24,.42),0 0 22px rgba(0,119,255,.18);">
                <tr>
                  <td align="center" style="text-align:center;">
                    <p class="note-text" style="margin:0;font-family:'Helvetica Neue',Helvetica,Arial,sans-serif;font-size:13px;line-height:1.5;text-align:center;color:#F2F7FC;">$htmlInside</p>
                  </td>
                </tr>
              </table>
            </td>
          </tr>
''';

  // ── Welcome ────────────────────────────────────────────────────────────────
  static String _buildWelcomeHtml(String nome) {
    final card =
        _headingWithBadge(
          title: 'Sei dentro, ${_escHtml(nome)}.',
          badgeLabel: 'Benvenuto',
        ) +
        _body(
          "Il tuo account OnListClub e' attivo. Puoi prenotare tavoli, acquistare prevendite e ordinare drink nei migliori club della tua citta', direttamente dall'app.",
          paddingBottom: 20,
        ) +
        _body("Apri l'app e scegli il tuo locale.", paddingBottom: 24) +
        _ctaButton('Apri OnListClub', 'onlistclub://home');
    return _htmlShell(
      preheader: "Il tuo account OnListClub e' attivo. Apri l'app e inizia a prenotare.",
      title: 'Benvenuto su OnListClub',
      cardContent: card,
    );
  }

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

    final card =
        _headingWithBadge(
          title: _escHtml(saluto),
          badgeLabel: 'Prevendita confermata',
        ) +
        _body(
          '<strong class="text-bold-name" style="color:#F2F7FC;font-weight:700;">${_escHtml(nome)}</strong>, la tua prevendita e\' confermata.<br>Ecco il riepilogo:',
        ) +
        _detailsBox(rows) +
        _ctaButton("Vedi il tuo biglietto nell'app", orderLink, paddingBottom: 24) +
        _noteBox(
          'Mostra il QR code all\'ingresso.<br>Aprilo dalla sezione <strong class="note-bold" style="color:#F2F7FC;font-weight:700;">Ordini</strong> nell\'app OnListClub.',
        );
    return _htmlShell(
      preheader:
          "La tua prevendita per ${_escHtml(eventoNome)} e' confermata. Apri l'app per vedere il QR di ingresso.",
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
        _headingWithBadge(
          title: 'Sei entrato.',
          badgeLabel: 'Ingresso confermato',
          badgeClass: 'badge-bg-ok',
          badgeTextClass: 'badge-text-ok',
          badgeInlineBg: '#0E2016',
          badgeInlineBorder: 'rgba(134,239,172,.55)',
          badgeInlineGrad: 'linear-gradient(150deg,rgba(22,163,74,.28),rgba(10,27,45,.96))',
          badgeInlineShadow: 'inset 0 1px 0 rgba(134,239,172,.35)',
          badgeInlineTextColor: '#B7F5C7',
        ) +
        _body(
          '<strong class="text-bold-name" style="color:#F2F7FC;font-weight:700;">${_escHtml(nome)}</strong>, il tuo biglietto e\' stato scannerizzato all\'ingresso.',
        ) +
        _detailsBox(rows);

    return _htmlShell(
      preheader:
          "Il tuo biglietto per ${_escHtml(eventoNome)} e' stato scannerizzato. Ingresso confermato.",
      title: 'Ingresso confermato',
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
    final rows = <List<String>>[
      [_detailCell('Locale', _escHtml(localeNome)), _detailCell('Serata', _escHtml(eventoNome))],
      [_detailCell('Prima scansione', _escHtml(firstScanTime), bottomPadded: false), _emptyCell()],
    ];

    final card =
        _headingWithBadge(
          title: 'Scansione non accettata.',
          badgeLabel: "Biglietto gia' usato",
          badgeClass: 'badge-bg-warn',
          badgeTextClass: 'badge-text-warn',
          badgeInlineBg: '#241610',
          badgeInlineBorder: 'rgba(253,186,116,.55)',
          badgeInlineGrad: 'linear-gradient(150deg,rgba(234,88,12,.30),rgba(10,27,45,.96))',
          badgeInlineShadow: 'inset 0 1px 0 rgba(253,186,116,.35)',
          badgeInlineTextColor: '#FDE1B2',
        ) +
        _body(
          '<strong class="text-bold-name" style="color:#F2F7FC;font-weight:700;">${_escHtml(nome)}</strong>, il tuo biglietto e\' stato rifiutato all\'ingresso perche\' e\' gia\' stato utilizzato.',
        ) +
        _detailsBox(rows) +
        _body(
          '<strong class="text-bold-name" style="color:#F2F7FC;font-weight:700;">Non sei stato tu?</strong><br>Se non riconosci questo accesso, il tuo QR potrebbe essere stato condiviso. Contattaci subito.',
          paddingBottom: 24,
          fontSize: 14,
        ) +
        _ctaButton("Vedi i tuoi ordini nell'app", 'onlistclub://orders');

    return _htmlShell(
      preheader:
          "Il tuo biglietto per ${_escHtml(eventoNome)} e' gia' stato utilizzato.",
      title: "Biglietto gia' utilizzato",
      cardContent: card,
    );
  }

  static String _escHtml(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
}
