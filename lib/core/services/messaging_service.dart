import 'package:flutter/foundation.dart';
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
  // HELPER DI DOMINIO (pronti da agganciare ai flussi)
  // ─────────────────────────────────────────────────────────────────────────

  /// Email di conferma prevendita/ordine, con template brandizzato (colori del
  /// design system §2: nero/blu brand). Da chiamare dopo il completamento ordine.
  static Future<bool> sendOrderConfirmationEmail({
    required String to,
    required String nome,
    required String localeNome,
    required String eventoNome,
    required String dataEvento,
    String? tipoTicket,
  }) {
    final subject = 'Conferma prevendita — $localeNome';
    final ticketRow = (tipoTicket == null || tipoTicket.isEmpty)
        ? ''
        : '<p style="margin:4px 0;color:#FFFFFF;">Ticket: <b>$tipoTicket</b></p>';
    final html = '''
<div style="background:#000000;padding:24px;font-family:Helvetica,Arial,sans-serif;">
  <div style="max-width:480px;margin:0 auto;background:linear-gradient(180deg,#1500B3 0%,#201064 100%);border-radius:32px;padding:28px;">
    <h1 style="color:#FFFFFF;font-size:24px;margin:0 0 16px;">Prevendita confermata 🎉</h1>
    <p style="color:#FFFFFF;font-size:16px;margin:0 0 16px;">Ciao $nome, la tua prevendita è stata registrata.</p>
    <div style="background:#060037;border-radius:10px;padding:16px;margin:0 0 16px;">
      <p style="margin:4px 0;color:#FFFFFF;">Locale: <b>$localeNome</b></p>
      <p style="margin:4px 0;color:#FFFFFF;">Serata: <b>$eventoNome</b></p>
      <p style="margin:4px 0;color:#FFFFFF;">Data: <b>$dataEvento</b></p>
      $ticketRow
    </div>
    <p style="color:#8E8E93;font-size:13px;margin:0;">Mostra il QR in app all'ingresso. A presto su Onlist Club.</p>
  </div>
</div>''';
    return sendEmail(
      to: to,
      toName: nome,
      subject: subject,
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
}
