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
/// LAYOUT EMAIL: shell "light-first" ufficiale usato da tutti i template
/// OnListClub (docs/email_templates/*.html). Sfondo email #F5F6F8, card bianca
/// con border grigio chiaro, testi scuri, accent viola/indigo per badge e CTA.
/// Meta color-scheme:light dice ai client email "questa e' progettata per
/// light mode": iOS Mail in dark auto-inverte con contrasto, tutti gli altri
/// la mostrano light pulita. Nessuna inversione problematica come col design
/// dark-forzato, che iOS Mail sminchava a modo suo.
///
/// DEEP LINK: I link nelle email usano lo schema `onlistclub://`.
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
  // BUILDERS HTML — shell light-first ufficiale
  //
  // Palette:
  // - bg email  #F5F6F8   card bg #FFFFFF   border #E4E7EB
  // - text      #0F172A (primary) / #334155 (body) / #64748B (muted)
  // - accent    viola     badge bg #EDE9FE / text #5B21B6 / border #DDD6FE
  //             CTA gradient linear-gradient(135deg,#4F46E5,#7C3AED)
  // - verde OK  badge bg #DCFCE7 / text #166534 / border #BBF7D0
  //             details bg #F0FDF4 / border #BBF7D0
  // - arancio W badge bg #FFEDD5 / text #9A3412 / border #FED7AA
  //             details bg #FFF7ED / border #FED7AA
  //
  // Il logo mail.png ha alone viola, wordmark scuro: perfetto su card bianca.
  // ─────────────────────────────────────────────────────────────────────────

  static const _logoUrl = 'https://www.onlistclub.com/mail.png';

  static const String _shellCss = '''
    html,body{margin:0!important;padding:0!important;width:100%!important;min-width:100%!important;height:100%!important;-webkit-text-size-adjust:100%;-ms-text-size-adjust:100%;}
    body{background-color:#F5F6F8;color:#0F172A;}
    table,td{mso-table-lspace:0pt!important;mso-table-rspace:0pt!important;}
    img{border:0;height:auto;line-height:100%;outline:none;text-decoration:none;-ms-interpolation-mode:bicubic;}
    a{text-decoration:none;}
    .email-container{box-sizing:border-box!important;width:100%!important;max-width:600px!important;padding:36px 32px!important;background-color:#FFFFFF!important;border:1px solid #E4E7EB!important;border-radius:22px!important;box-shadow:0 1px 2px rgba(15,23,42,.04),0 12px 32px rgba(15,23,42,.06)!important;}
    .logo-mark{display:block!important;width:200px!important;max-width:70%!important;height:auto!important;margin:0 auto!important;}
    .heading-status-row{width:100%!important;table-layout:fixed!important;}
    .heading-cell{width:56%!important;text-align:left!important;vertical-align:middle!important;}
    .status-cell{width:44%!important;text-align:right!important;vertical-align:middle!important;}
    .text-title{font-size:25px!important;color:#0F172A!important;}
    .text-body{color:#334155!important;}
    .text-bold-name{color:#0F172A!important;}
    .badge-bg{box-sizing:border-box!important;width:auto!important;padding:6px 12px!important;border:1px solid #DDD6FE!important;border-radius:26px!important;background-color:#EDE9FE!important;text-align:center!important;vertical-align:middle!important;}
    .badge-text{color:#5B21B6!important;font-size:13px!important;line-height:1.25!important;font-weight:700!important;letter-spacing:.02em!important;}
    .badge-bg-ok{box-sizing:border-box!important;width:auto!important;padding:6px 12px!important;border:1px solid #BBF7D0!important;border-radius:26px!important;background-color:#DCFCE7!important;text-align:center!important;vertical-align:middle!important;}
    .badge-text-ok{color:#166534!important;font-size:13px!important;line-height:1.25!important;font-weight:700!important;letter-spacing:.02em!important;}
    .badge-bg-warn{box-sizing:border-box!important;width:auto!important;padding:6px 12px!important;border:1px solid #FED7AA!important;border-radius:26px!important;background-color:#FFEDD5!important;text-align:center!important;vertical-align:middle!important;}
    .badge-text-warn{color:#9A3412!important;font-size:13px!important;line-height:1.25!important;font-weight:700!important;letter-spacing:.02em!important;}
    .details-box{background-color:#F8FAFC!important;border:1px solid #E4E7EB!important;border-radius:16px!important;}
    .details-label{color:#64748B!important;}
    .details-value{color:#0F172A!important;}
    .detail-cell:first-child{padding-right:16px!important;}
    .detail-cell:nth-child(2){padding-left:16px!important;}
    .note-box{background-color:#F5F3FF!important;border:1px solid #DDD6FE!important;border-radius:14px!important;}
    .note-text{color:#4B5563!important;}
    .note-bold{color:#0F172A!important;}
    .cta-cell{background:#4F46E5!important;background-image:linear-gradient(135deg,#4F46E5 0%,#7C3AED 100%)!important;border-radius:999px!important;box-shadow:0 6px 16px rgba(79,70,229,.28)!important;}
    .cta-link{display:block!important;min-height:48px!important;box-sizing:border-box!important;padding:14px 20px!important;font-size:15px!important;line-height:1.4!important;font-weight:600!important;letter-spacing:.2px!important;color:#FFFFFF!important;}
    .footer-divider{border-top:1px solid #E4E7EB!important;}
    .footer-text{color:#64748B!important;}
    .footer-link{color:#4F46E5!important;}
    @media only screen and (max-width:600px){
      .outer-wrapper-cell{padding:16px 10px!important;}
      .email-container{padding:22px 18px!important;border-radius:18px!important;}
      .logo-mark{width:170px!important;}
      .heading-cell,.status-cell{display:table-cell!important;vertical-align:middle!important;}
      .heading-cell{width:60%!important;}
      .status-cell{width:40%!important;text-align:center!important;}
      .text-title{font-size:22px!important;line-height:1.2!important;}
      .badge-bg,.badge-bg-ok,.badge-bg-warn{padding:4px 8px!important;}
      .badge-text,.badge-text-ok,.badge-text-warn{font-size:11px!important;letter-spacing:0!important;line-height:1.1!important;white-space:nowrap!important;}
      .text-body{font-size:14px!important;line-height:1.5!important;}
      .details-box{padding:12px!important;}
      .detail-cell:first-child{padding-right:6px!important;}
      .detail-cell:nth-child(2){padding-left:6px!important;}
      .details-value{font-size:14px!important;}
      .cta-link{min-height:42px!important;padding:12px 16px!important;}
      .note-text{font-size:12px!important;line-height:1.4!important;}
      .footer-text{font-size:11px!important;line-height:1.3!important;}
    }
    @media only screen and (max-width:360px){
      .heading-cell,.status-cell{display:block!important;width:100%!important;text-align:center!important;}
      .status-cell{padding-top:10px!important;}
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
  <meta name="color-scheme" content="light">
  <meta name="supported-color-schemes" content="light">
  <meta name="x-apple-disable-message-reformatting">
  <title>$title</title>
  <!--[if mso]><noscript><xml><o:OfficeDocumentSettings><o:PixelsPerInch>96</o:PixelsPerInch></o:OfficeDocumentSettings></xml></noscript><![endif]-->
  <style>$_shellCss</style>
</head>
<body style="margin:0;padding:0;width:100%;min-width:100%;background-color:#F5F6F8;font-family:'Helvetica Neue',Helvetica,Arial,sans-serif;color:#0F172A;">
  <span style="display:none;font-size:1px;color:transparent;line-height:1px;max-height:0px;max-width:0px;opacity:0;overflow:hidden;">$preheader</span>
  <table role="presentation" width="100%" height="100%" cellpadding="0" cellspacing="0" border="0" bgcolor="#F5F6F8" style="width:100%;min-width:100%;height:100%;background-color:#F5F6F8;">
    <tr>
      <td align="center" valign="top" class="outer-wrapper-cell" style="padding:32px 16px;">
        <table bgcolor="#FFFFFF" class="email-container" width="100%" cellpadding="0" cellspacing="0" border="0" style="box-sizing:border-box;width:100%;max-width:560px;background-color:#FFFFFF;border:1px solid #E4E7EB;border-radius:22px;padding:36px 32px;box-shadow:0 1px 2px rgba(15,23,42,.04),0 12px 32px rgba(15,23,42,.06);">
          <tr>
            <td align="center" style="padding-bottom:28px;">
              <img class="logo-mark" src="$_logoUrl" alt="OnListClub" width="200" style="display:block;width:200px;max-width:70%;height:auto;border:0;margin:0 auto;">
            </td>
          </tr>
          $cardContent
          <tr>
            <td class="footer-divider" style="border-top:1px solid #E4E7EB;padding-top:22px;" align="center">
              <p class="footer-text" style="margin:0 0 6px;font-family:'Helvetica Neue',Helvetica,Arial,sans-serif;font-size:12px;text-align:center;color:#64748B;">
                OnListClub. Prenota tavoli, prevendite e drink nei migliori locali.
              </p>
              <p class="footer-text" style="margin:0;font-family:'Helvetica Neue',Helvetica,Arial,sans-serif;font-size:12px;text-align:center;color:#64748B;">
                Hai domande? Scrivici a <a href="mailto:info@onlistclub.com" class="footer-link" style="color:#4F46E5;text-decoration:none;" target="_blank">info@onlistclub.com</a>
              </p>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>''';

  /// Row heading (sx) + badge (dx). [badgeVariant] "default"|"ok"|"warn"
  /// controlla i colori del badge.
  static String _headingWithBadge({
    required String title,
    required String badgeLabel,
    String badgeVariant = 'default',
  }) {
    late String badgeClass;
    late String badgeTextClass;
    late String badgeBg;
    late String badgeBorder;
    late String badgeTextColor;
    switch (badgeVariant) {
      case 'ok':
        badgeClass = 'badge-bg-ok';
        badgeTextClass = 'badge-text-ok';
        badgeBg = '#DCFCE7';
        badgeBorder = '#BBF7D0';
        badgeTextColor = '#166534';
        break;
      case 'warn':
        badgeClass = 'badge-bg-warn';
        badgeTextClass = 'badge-text-warn';
        badgeBg = '#FFEDD5';
        badgeBorder = '#FED7AA';
        badgeTextColor = '#9A3412';
        break;
      default:
        badgeClass = 'badge-bg';
        badgeTextClass = 'badge-text';
        badgeBg = '#EDE9FE';
        badgeBorder = '#DDD6FE';
        badgeTextColor = '#5B21B6';
    }
    return '''
          <tr>
            <td style="padding-bottom:16px;">
              <table class="heading-status-row" width="100%" cellpadding="0" cellspacing="0" border="0" role="presentation" style="width:100%;table-layout:fixed;">
                <tr>
                  <td class="heading-cell" align="left" valign="middle" style="width:56%;text-align:left;vertical-align:middle;">
                    <h1 class="text-title" style="margin:0;font-family:'Helvetica Neue',Helvetica,Arial,sans-serif;font-size:26px;line-height:1.25;font-weight:700;color:#0F172A;">$title</h1>
                  </td>
                  <td class="status-cell" align="right" valign="middle" style="width:44%;text-align:right;vertical-align:middle;">
                    <table align="right" cellpadding="0" cellspacing="0" border="0" role="presentation" style="width:auto;margin:0 0 0 auto;">
                      <tr>
                        <td class="$badgeClass" valign="middle" bgcolor="$badgeBg" style="border:1px solid $badgeBorder;border-radius:26px;padding:6px 12px;background-color:$badgeBg;text-align:center;vertical-align:middle;">
                          <span class="$badgeTextClass" style="font-family:'Helvetica Neue',Helvetica,Arial,sans-serif;font-size:13px;font-weight:700;line-height:1.25;color:$badgeTextColor;letter-spacing:.02em;">$badgeLabel</span>
                        </td>
                      </tr>
                    </table>
                  </td>
                </tr>
              </table>
            </td>
          </tr>
''';
  }

  static String _body(String innerHtml, {int paddingBottom = 24, int fontSize = 15}) => '''
          <tr>
            <td align="left" style="padding-bottom:${paddingBottom}px;">
              <p class="text-body" style="margin:0;font-family:'Helvetica Neue',Helvetica,Arial,sans-serif;font-size:${fontSize}px;line-height:1.6;color:#334155;">$innerHtml</p>
            </td>
          </tr>
''';

  static String _ctaButton(String label, String href, {int paddingBottom = 28}) => '''
          <tr>
            <td style="padding-bottom:${paddingBottom}px;">
              <table width="100%" cellpadding="0" cellspacing="0" border="0"><tr>
                <td align="center" class="cta-cell" bgcolor="#4F46E5" style="background:#4F46E5;background-color:#4F46E5;background-image:linear-gradient(135deg,#4F46E5 0%,#7C3AED 100%);border-radius:999px;box-shadow:0 6px 16px rgba(79,70,229,.28);">
                  <a href="$href" class="cta-link" style="display:block;min-height:48px;box-sizing:border-box;padding:14px 20px;font-family:'Helvetica Neue',Helvetica,Arial,sans-serif;font-size:15px;line-height:1.4;font-weight:600;letter-spacing:.2px;text-decoration:none;color:#FFFFFF;text-align:center;" target="_blank">${_escHtml(label)}</a>
                </td>
              </tr></table>
            </td>
          </tr>
''';

  static String _detailCell(String label, String value, {bool bottomPadded = true, String labelColor = '#64748B'}) {
    final pb = bottomPadded ? 'padding-bottom:18px;' : '';
    return '<td class="detail-cell" width="50%" style="${pb}vertical-align:top;">'
        '<p class="details-label" style="margin:0 0 4px;font-family:\'Helvetica Neue\',Helvetica,Arial,sans-serif;font-size:11px;font-weight:400;text-transform:uppercase;letter-spacing:0.08em;color:$labelColor;">${_escHtml(label)}</p>'
        '<p class="details-value" style="margin:0;font-family:\'Helvetica Neue\',Helvetica,Arial,sans-serif;font-size:16px;font-weight:700;color:#0F172A;">$value</p>'
        '</td>';
  }

  static String _emptyCell() =>
      '<td class="detail-cell" width="50%" style="vertical-align:top;"></td>';

  /// details-box con [variant] "default"|"ok"|"warn" per i colori
  static String _detailsBox(List<List<String>> rows, {String variant = 'default'}) {
    late String bg;
    late String border;
    switch (variant) {
      case 'ok':
        bg = '#F0FDF4';
        border = '#BBF7D0';
        break;
      case 'warn':
        bg = '#FFF7ED';
        border = '#FED7AA';
        break;
      default:
        bg = '#F8FAFC';
        border = '#E4E7EB';
    }
    final rowsHtml = rows.map((cells) {
      final left = cells.isNotEmpty ? cells[0] : _emptyCell();
      final right = cells.length > 1 ? cells[1] : _emptyCell();
      return '<tr>$left$right</tr>';
    }).join();
    return '''
          <tr>
            <td style="padding-bottom:24px;">
              <table bgcolor="$bg" class="details-box" width="100%" cellpadding="0" cellspacing="0" border="0" style="background-color:$bg;border:1px solid $border;border-radius:16px;padding:20px;">
                $rowsHtml
              </table>
            </td>
          </tr>
''';
  }

  static String _noteBox(String innerHtml) => '''
          <tr>
            <td style="padding-bottom:28px;">
              <table bgcolor="#F5F3FF" class="note-box" width="100%" cellpadding="0" cellspacing="0" border="0" style="background-color:#F5F3FF;border:1px solid #DDD6FE;border-radius:14px;padding:14px 16px;">
                <tr>
                  <td align="center" style="text-align:center;">
                    <p class="note-text" style="margin:0;font-family:'Helvetica Neue',Helvetica,Arial,sans-serif;font-size:13px;line-height:1.5;text-align:center;color:#4B5563;">$innerHtml</p>
                  </td>
                </tr>
              </table>
            </td>
          </tr>
''';

  // ── Welcome ────────────────────────────────────────────────────────────────
  static String _buildWelcomeHtml(String nome) {
    final card =
        _headingWithBadge(title: 'Sei dentro, ${_escHtml(nome)}.', badgeLabel: 'Benvenuto') +
        _body(
          "Il tuo account OnListClub e' attivo. Puoi prenotare tavoli, acquistare prevendite e ordinare drink nei migliori club della tua citta', direttamente dall'app.",
          paddingBottom: 16,
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
        _headingWithBadge(title: _escHtml(saluto), badgeLabel: 'Prevendita confermata') +
        _body(
          '<strong class="text-bold-name" style="color:#0F172A;font-weight:700;">${_escHtml(nome)}</strong>, la tua prevendita e\' confermata.<br>Ecco il riepilogo:',
        ) +
        _detailsBox(rows) +
        _ctaButton("Vedi il tuo biglietto nell'app", orderLink, paddingBottom: 24) +
        _noteBox(
          'Mostra il QR code all\'ingresso.<br>Aprilo dalla sezione <strong class="note-bold" style="color:#0F172A;font-weight:700;">Ordini</strong> nell\'app OnListClub.',
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
      [_detailCell('Locale', _escHtml(localeNome), labelColor: '#166534'), _detailCell('Serata', _escHtml(eventoNome), labelColor: '#166534')],
      [_detailCell('Check-in', _escHtml(checkinTime), bottomPadded: false, labelColor: '#166534'), _emptyCell()],
    ];

    final card =
        _headingWithBadge(
          title: 'Sei entrato.',
          badgeLabel: 'Ingresso confermato',
          badgeVariant: 'ok',
        ) +
        _body(
          '<strong class="text-bold-name" style="color:#0F172A;font-weight:700;">${_escHtml(nome)}</strong>, il tuo biglietto e\' stato scannerizzato all\'ingresso.',
        ) +
        _detailsBox(rows, variant: 'ok');

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
      [_detailCell('Locale', _escHtml(localeNome), labelColor: '#9A3412'), _detailCell('Serata', _escHtml(eventoNome), labelColor: '#9A3412')],
      [_detailCell('Prima scansione', _escHtml(firstScanTime), bottomPadded: false, labelColor: '#9A3412'), _emptyCell()],
    ];

    final card =
        _headingWithBadge(
          title: 'Scansione non accettata.',
          badgeLabel: "Biglietto gia' usato",
          badgeVariant: 'warn',
        ) +
        _body(
          '<strong class="text-bold-name" style="color:#0F172A;font-weight:700;">${_escHtml(nome)}</strong>, il tuo biglietto e\' stato rifiutato all\'ingresso perche\' e\' gia\' stato utilizzato.',
        ) +
        _detailsBox(rows, variant: 'warn') +
        _body(
          '<strong class="text-bold-name" style="color:#0F172A;font-weight:700;">Non sei stato tu?</strong><br>Se non riconosci questo accesso, il tuo QR potrebbe essere stato condiviso. Contattaci subito.',
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
