// Edge Function: on-scan-log
//
// Riceve un webhook DATABASE dal trigger su public.scan_logs (INSERT) e,
// se la scansione è VALID o ALREADY_USED, manda all'utente l'email
// corrispondente tramite l'API Brevo.
//
// Sicurezza:
//   - Protetta da verify_jwt: false (viene chiamata dal DB con service_role).
//   - Legge SUPABASE_SERVICE_ROLE_KEY e BREVO_API_KEY dai secret.
//   - Non espone mai le chiavi al client.
//
// Il trigger DB chiama questa function via pg_net (extension disponibile su
// Supabase Pro/Team) oppure via Database Webhook (Supabase Dashboard).
// Vedi migration 010_scan_email_trigger.sql per i dettagli.
//
// Input JSON (Database Webhook payload):
//   {
//     "type": "INSERT",
//     "table": "scan_logs",
//     "record": {
//       "id": "...",
//       "ticket_id": "uuid",
//       "club_id": "uuid",
//       "status_result": "VALID" | "ALREADY_USED",
//       "scanned_at": "2026-07-23T21:00:00Z",
//       "qr_code": "..."
//     }
//   }

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders } from "../_shared/cors.ts";

const BREVO_API_URL = "https://api.brevo.com/v3/smtp/email";

// ── Design tokens email (shell ZUCC ufficiale) ───────────────────────────────
// Stesso layout dei template statici in `docs/email_templates/*.html` e del
// builder `messaging_service.dart`. Card trasparente su color:inherit del
// client, border 2px con accento (verde per VALID, arancio per ALREADY_USED),
// wordmark `mail.png` dentro plate `#0a0a0a` (non `#000000` puro per non
// farsi invertire da iOS Mail dark mode). Nessuna emoji, nessun em-dash.
const LOGO_URL = "https://www.onlistclub.com/mail.png";

// Accento verde (VALID) e arancio (ALREADY_USED). border+glow+shadow del card,
// border+text del badge.
const ACCENT_GREEN = {
  border: "#86EFAC",
  glow: "rgba(22,163,74,.26)",
  shadow: "rgba(6,78,59,.12)",
  badgeBorder: "rgba(22,163,74,0.40)",
  badgeText: "#15803D",
};
const ACCENT_ORANGE = {
  border: "#FDBA74",
  glow: "rgba(234,88,12,.26)",
  shadow: "rgba(124,45,18,.12)",
  badgeBorder: "rgba(234,88,12,0.40)",
  badgeText: "#C2410C",
};

function escHtml(s: string): string {
  return s
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

interface Accent {
  border: string;
  glow: string;
  shadow: string;
  badgeBorder: string;
  badgeText: string;
}

function htmlShell(preheader: string, title: string, cardContent: string, accent: Accent): string {
  return `<!DOCTYPE html>
<html lang="it" xmlns="http://www.w3.org/1999/xhtml" xmlns:v="urn:schemas-microsoft-com:vml" xmlns:o="urn:schemas-microsoft-com:office:office">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <meta name="color-scheme" content="light dark">
  <meta name="supported-color-schemes" content="light dark">
  <meta name="x-apple-disable-message-reformatting">
  <title>${title}</title>
  <!--[if mso]>
  <noscript><xml><o:OfficeDocumentSettings><o:PixelsPerInch>96</o:PixelsPerInch></o:OfficeDocumentSettings></xml></noscript>
  <![endif]-->
  <style>
    html,body{margin:0!important;padding:0!important;width:100%!important;min-width:100%!important;height:100%!important;-webkit-text-size-adjust:100%;-ms-text-size-adjust:100%;}
    body{background-color:transparent!important;color:inherit;}
    table,td{mso-table-lspace:0pt!important;mso-table-rspace:0pt!important;}
    img{border:0;height:auto;line-height:100%;outline:none;text-decoration:none;-ms-interpolation-mode:bicubic;}
    a{text-decoration:none;}
    .email-container{box-sizing:border-box!important;width:100%!important;max-width:560px!important;background-color:transparent!important;border:2px solid ${accent.border}!important;border-radius:22px!important;padding:36px 32px!important;box-shadow:0 0 0 1px ${accent.glow},0 0 22px ${accent.glow},0 18px 42px ${accent.shadow}!important;}
    .logo-plate{background-color:#0a0a0a!important;border-radius:20px!important;}
    .logo-mark{display:block!important;width:200px!important;max-width:78%!important;height:auto!important;margin:0 auto!important;}
    .text-title,.text-body,.text-bold-name,.details-value,.details-label,.footer-text{color:inherit!important;}
    .details-box{background-color:transparent!important;border:1.5px solid ${accent.border}!important;border-radius:16px!important;}
    .detail-cell:first-child{padding-right:16px!important;}
    .detail-cell:nth-child(2){padding-left:16px!important;}
    .footer-divider{border-top-color:rgba(127,111,150,.35)!important;}
    .footer-link{color:#7C3AED!important;}
    .cta-cell{background:#7C3AED!important;background-image:linear-gradient(135deg,#7C3AED 0%,#6366F1 52%,#4F46E5 100%)!important;border-radius:999px!important;box-shadow:0 8px 22px rgba(124,58,237,.22)!important;}
    .cta-link{display:block!important;min-height:48px!important;box-sizing:border-box!important;padding:14px 20px!important;color:#FFFFFF!important;}
    @media only screen and (max-width:600px){
      .outer-wrapper-cell{padding:20px 10px 36px 10px!important;}
      .email-container{max-width:100%!important;padding:26px 20px!important;border-radius:18px!important;}
      .logo-mark{width:170px!important;max-width:72%!important;}
      .text-title{font-size:24px!important;}
      .detail-cell{display:block!important;width:100%!important;padding-left:0!important;padding-right:0!important;padding-bottom:14px!important;}
    }
    @media (prefers-color-scheme: dark){
      .email-container{border-color:${accent.border}!important;box-shadow:0 0 0 1px ${accent.glow},0 0 24px ${accent.glow},0 18px 44px rgba(0,0,0,.16)!important;}
      .details-box{border-color:${accent.border}!important;}
    }
  </style>
</head>
<body style="background:transparent;margin:0;padding:0;width:100%;min-width:100%;font-family:'Helvetica Neue',Helvetica,Arial,sans-serif;">
  <span style="display:none;font-size:1px;color:transparent;line-height:1px;max-height:0px;max-width:0px;opacity:0;overflow:hidden;">${preheader}</span>
  <table class="outer-wrapper" width="100%" height="100%" cellpadding="0" cellspacing="0" border="0" style="width:100%;min-width:100%;height:100%;table-layout:fixed;">
    <tr>
      <td align="center" valign="top" class="outer-wrapper-cell" style="padding:28px 16px 48px 16px;">
        <!--[if mso]><table align="center" width="560" style="width:560px;"><tr><td><![endif]-->
        <table class="email-container" width="100%" cellpadding="0" cellspacing="0" border="0" style="box-sizing:border-box;width:100%;max-width:560px;background-color:transparent;border:2px solid ${accent.border};border-radius:22px;padding:36px 32px;box-shadow:0 0 0 1px ${accent.glow},0 0 22px ${accent.glow},0 18px 42px ${accent.shadow};">
          <tr>
            <td align="center" style="padding-bottom:28px;">
              <table role="presentation" cellpadding="0" cellspacing="0" border="0" style="margin:0 auto;"><tr>
                <td class="logo-plate" align="center" bgcolor="#0a0a0a" style="background-color:#0a0a0a;border-radius:20px;padding:22px 44px;">
                  <img class="logo-mark" src="${LOGO_URL}" alt="OnListClub" width="200" style="display:block;width:200px;max-width:78%;height:auto;border:0;margin:0 auto;">
                </td>
              </tr></table>
            </td>
          </tr>
          ${cardContent}
          <tr>
            <td class="footer-divider" style="border-top:1.5px solid #E8E3EF;padding-top:22px;" align="center">
              <p class="footer-text" style="margin:0 0 6px;font-family:'Helvetica Neue',Helvetica,Arial,sans-serif;font-size:12px;text-align:center;">
                OnListClub. Prenota tavoli, prevendite e drink nei migliori locali.
              </p>
              <p class="footer-text" style="margin:0;font-family:'Helvetica Neue',Helvetica,Arial,sans-serif;font-size:12px;text-align:center;">
                Hai domande? Scrivici a <a href="mailto:info@onlistclub.com" class="footer-link" style="text-decoration:none;color:#7C3AED;" target="_blank">info@onlistclub.com</a>
              </p>
            </td>
          </tr>
        </table>
        <!--[if mso]></td></tr></table><![endif]-->
      </td>
    </tr>
  </table>
</body>
</html>`;
}

function badge(label: string, borderColor: string, textColor: string): string {
  return `<tr><td align="left" style="padding-bottom:18px;">
    <table cellpadding="0" cellspacing="0" border="0"><tr>
      <td style="border:1.5px solid ${borderColor};border-radius:9999px;padding:6px 14px;">
        <span style="font-family:'Helvetica Neue',Helvetica,Arial,sans-serif;font-size:11px;font-weight:700;letter-spacing:0.08em;text-transform:uppercase;color:${textColor};">${label}</span>
      </td>
    </tr></table>
  </td></tr>`;
}

function heading(text: string): string {
  return `<tr><td align="left" style="padding-bottom:14px;">
    <h1 class="text-title" style="margin:0;font-family:'Helvetica Neue',Helvetica,Arial,sans-serif;font-size:26px;line-height:1.25;font-weight:700;">${text}</h1>
  </td></tr>`;
}

function body(htmlInside: string, paddingBottom = 24, fontSize = 15): string {
  return `<tr><td align="left" style="padding-bottom:${paddingBottom}px;">
    <p class="text-body" style="margin:0;font-family:'Helvetica Neue',Helvetica,Arial,sans-serif;font-size:${fontSize}px;line-height:1.6;">${htmlInside}</p>
  </td></tr>`;
}

function detailCell(label: string, value: string, bottomPadded = true): string {
  const pb = bottomPadded ? "padding-bottom:18px;" : "";
  return `<td class="detail-cell" width="50%" style="${pb}vertical-align:top;">
    <p class="details-label" style="margin:0 0 4px;font-family:'Helvetica Neue',Helvetica,Arial,sans-serif;font-size:11px;font-weight:400;text-transform:uppercase;letter-spacing:0.08em;">${label}</p>
    <p class="details-value" style="margin:0;font-family:'Helvetica Neue',Helvetica,Arial,sans-serif;font-size:16px;font-weight:700;">${value}</p>
  </td>`;
}

function emptyCell(): string {
  return `<td class="detail-cell" width="50%" style="vertical-align:top;"></td>`;
}

function detailsBox(border: string, rows: string[][]): string {
  const rowsHtml = rows
    .map((cells) => `<tr>${cells[0] ?? emptyCell()}${cells[1] ?? emptyCell()}</tr>`)
    .join("");
  return `<tr><td style="padding-bottom:24px;">
    <table class="details-box" width="100%" cellpadding="0" cellspacing="0" border="0" style="background-color:transparent;border:1.5px solid ${border};border-radius:16px;padding:20px 20px;">${rowsHtml}</table>
  </td></tr>`;
}

function ctaButton(label: string, href: string): string {
  return `<tr><td style="padding-bottom:28px;">
    <table width="100%" cellpadding="0" cellspacing="0" border="0"><tr>
      <td align="center" class="cta-cell" style="background:#7C3AED;background-color:#7C3AED;background-image:linear-gradient(135deg,#7C3AED 0%,#6366F1 52%,#4F46E5 100%);border-radius:999px;box-shadow:0 8px 22px rgba(124,58,237,.28);">
        <a href="${href}" class="cta-link" style="display:block;min-height:48px;box-sizing:border-box;padding:14px 20px;font-family:'Helvetica Neue',Helvetica,Arial,sans-serif;font-size:15px;font-weight:600;text-decoration:none;color:#FFFFFF;text-align:center;" target="_blank">${label}</a>
      </td>
    </tr></table>
  </td></tr>`;
}

// ─── Builder email VALID (accento verde) ─────────────────────────────────────
function buildValidHtml(nome: string, localeNome: string, eventoNome: string, checkinTime: string): string {
  const card =
    badge("Ingresso confermato", ACCENT_GREEN.badgeBorder, ACCENT_GREEN.badgeText) +
    heading("Sei entrato.") +
    body(`<strong class="text-bold-name" style="font-weight:700;">${escHtml(nome)}</strong>, il tuo biglietto e' stato scannerizzato all'ingresso.`) +
    detailsBox(ACCENT_GREEN.border, [
      [detailCell("Locale", escHtml(localeNome)), detailCell("Serata", escHtml(eventoNome))],
      [detailCell("Check-in", escHtml(checkinTime), false), emptyCell()],
    ]);
  return htmlShell(
    `Il tuo biglietto per ${escHtml(eventoNome)} e' stato scannerizzato. Ingresso confermato.`,
    "Ingresso confermato",
    card,
    ACCENT_GREEN,
  );
}

// ─── Builder email ALREADY_USED (accento arancio) ────────────────────────────
function buildAlreadyUsedHtml(nome: string, localeNome: string, eventoNome: string, firstScanTime: string): string {
  const card =
    badge("Biglietto gia' usato", ACCENT_ORANGE.badgeBorder, ACCENT_ORANGE.badgeText) +
    heading("Scansione non accettata.") +
    body(`<strong class="text-bold-name" style="font-weight:700;">${escHtml(nome)}</strong>, il tuo biglietto e' stato rifiutato all'ingresso perche' e' gia' stato utilizzato.`) +
    detailsBox(ACCENT_ORANGE.border, [
      [detailCell("Locale", escHtml(localeNome)), detailCell("Serata", escHtml(eventoNome))],
      [detailCell("Prima scansione", escHtml(firstScanTime), false), emptyCell()],
    ]) +
    body(`<strong class="text-bold-name" style="font-weight:700;">Non sei stato tu?</strong><br>Se non riconosci questo accesso, il tuo QR potrebbe essere stato condiviso. Contattaci subito.`, 24, 14) +
    ctaButton("Vedi i tuoi ordini nell'app", "onlistclub://orders");
  return htmlShell(
    `Il tuo biglietto per ${escHtml(eventoNome)} e' gia' stato utilizzato.`,
    "Biglietto gia' utilizzato",
    card,
    ACCENT_ORANGE,
  );
}

// ─── Formato ora leggibile ────────────────────────────────────────────────────
function formatDateTime(iso: string | null): string {
  if (!iso) return "N/D";
  try {
    const d = new Date(iso);
    return d.toLocaleString("it-IT", {
      day: "2-digit", month: "2-digit", year: "numeric",
      hour: "2-digit", minute: "2-digit",
      timeZone: "Europe/Rome",
    });
  } catch {
    return iso;
  }
}

// ─── Main handler ─────────────────────────────────────────────────────────────
serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const json = (body: unknown, status = 200) =>
    new Response(JSON.stringify(body), {
      status,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });

  try {
    // ── 1. Valida env ────────────────────────────────────────────────────────
    const apiKey = Deno.env.get("BREVO_API_KEY");
    if (!apiKey) return json({ ok: false, error: "missing_brevo_api_key" }, 500);

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const senderEmail = Deno.env.get("BREVO_SENDER_EMAIL") ?? "no-reply@onlist.club";
    const senderName = Deno.env.get("BREVO_SENDER_NAME") ?? "Onlist Club";
    // Mittente SMS: alias dedicato e approvato per l'invio SMS (allineato a
    // send-sms/index.ts). BREVO_SENDER_NAME è per le email e può contenere
    // uno spazio/testo non valido come sender ID SMS per l'Italia.
    const smsSenderName = Deno.env.get("BREVO_SMS_SENDER") ?? "OnList";

    // ── 2. Parse payload Database Webhook ────────────────────────────────────
    const payload = await req.json().catch(() => null);
    if (!payload) return json({ ok: false, error: "invalid_json" }, 400);

    const record = payload?.record;
    if (!record) return json({ ok: false, error: "missing_record" }, 400);

    const status: string = record.status_result ?? "";
    const ticketId: string | null = record.ticket_id ?? null;
    const scannedAt: string | null = record.scanned_at ?? null;

    // Solo VALID e ALREADY_USED generano un'email; ignoriamo gli altri.
    if (status !== "VALID" && status !== "ALREADY_USED") {
      return json({ ok: true, skipped: true, reason: `status ${status} not handled` });
    }
    if (!ticketId) return json({ ok: false, error: "missing_ticket_id" }, 400);

    // ── 3. Fetch dati del biglietto via service_role ──────────────────────────
    const admin = createClient(supabaseUrl, serviceKey);

    // Recupera prenotazioni_prevendite → prenotazioni → eventi → locali + utente
    const { data: ppRow, error: ppErr } = await admin
      .from("prenotazioni_prevendite")
      .select(`
        id, nome, cognome,
        id_prenotazione,
        id_utente,
        prenotazioni(
          id, id_evento,
          eventi( nome, inizio_evento, locali( nome ) )
        )
      `)
      .eq("id", ticketId)
      .maybeSingle();

    if (ppErr || !ppRow) {
      console.error("[on-scan-log] prenotazioni_prevendite fetch error:", ppErr);
      return json({ ok: false, error: "ticket_not_found" }, 404);
    }

    const pren = ppRow.prenotazioni as Record<string, unknown> | null;
    const evento = pren?.eventi as Record<string, unknown> | null;
    const locale = evento?.locali as Record<string, unknown> | null;

    const nomeUtente = [ppRow.nome ?? "", ppRow.cognome ?? ""]
      .filter(Boolean).join(" ") || "cliente";
    const eventoNome = (evento?.nome as string) ?? "";
    const localeNome = (locale?.nome as string) ?? "";

    // Recupera l'email dell'utente da auth.users
    const userId: string | null = ppRow.id_utente ?? null;
    if (!userId) return json({ ok: false, error: "missing_user_id" }, 400);

    const { data: authUser, error: authErr } = await admin.auth.admin.getUserById(userId);
    if (authErr || !authUser?.user?.email) {
      console.error("[on-scan-log] auth user fetch error:", authErr);
      return json({ ok: false, error: "user_email_not_found" }, 404);
    }
    const toEmail = authUser.user.email;

    // ── 4. Per ALREADY_USED recupera la prima scansione valida ───────────────
    let firstScanAt: string | null = null;
    if (status === "ALREADY_USED") {
      const { data: firstLog } = await admin
        .from("scan_logs")
        .select("scanned_at")
        .eq("ticket_id", ticketId)
        .eq("status_result", "VALID")
        .order("scanned_at", { ascending: true })
        .limit(1)
        .maybeSingle();
      firstScanAt = firstLog?.scanned_at ?? scannedAt;
    }

    // ── 5. Costruisci HTML email ──────────────────────────────────────────────
    let subject: string;
    let htmlContent: string;

    if (status === "VALID") {
      subject = `Ingresso confermato: ${localeNome}`;
      htmlContent = buildValidHtml(
        nomeUtente, localeNome, eventoNome,
        formatDateTime(scannedAt)
      );
    } else {
      subject = `Biglietto gia' utilizzato: ${localeNome}`;
      htmlContent = buildAlreadyUsedHtml(
        nomeUtente, localeNome, eventoNome,
        formatDateTime(firstScanAt)
      );
    }

    // ── 6. Invia via Brevo ────────────────────────────────────────────────────
    const brevoBody = {
      sender: { email: senderEmail, name: senderName },
      to: [{ email: toEmail, name: nomeUtente }],
      subject,
      htmlContent,
    };

    const resp = await fetch(BREVO_API_URL, {
      method: "POST",
      headers: {
        "api-key": apiKey,
        "Content-Type": "application/json",
        accept: "application/json",
      },
      body: JSON.stringify(brevoBody),
    });

    const data = await resp.json().catch(() => ({}));
    if (!resp.ok) {
      console.error("[on-scan-log] Brevo error", resp.status, data);
      return json({ ok: false, error: data?.message ?? "brevo_error", status: resp.status }, 502);
    }

    console.log(`[on-scan-log] email ${status} inviata a ${toEmail}`);

    // ── 7. SMS di notifica scansione ─────────────────────────────────────────
    // Non blocca la risposta: errori loggati e ignorati.
    try {
      const { data: phoneRow } = await admin
        .from("utenti_numeri_telefono")
        .select("telefono")
        .eq("id_utente", userId)
        .eq("is_primary", true)
        .maybeSingle();

      const telefono: string | null = phoneRow?.telefono ?? null;

      if (telefono) {
        let smsContent: string;
        if (status === "VALID") {
          smsContent = localeNome
            ? `OnListClub: ingresso confermato @ ${localeNome}. Divertiti!`
            : `OnListClub: il tuo ingresso e' stato confermato. Divertiti!`;
        } else {
          smsContent = localeNome
            ? `OnListClub: il tuo biglietto per ${localeNome} e' gia' stato utilizzato. Contattaci se non sei stato tu.`
            : `OnListClub: il tuo biglietto e' gia' stato utilizzato. Contattaci se non sei stato tu.`;
        }

        const BREVO_SMS_URL = "https://api.brevo.com/v3/transactionalSMS/sms";
        const smsBody = {
          sender: smsSenderName,
          recipient: telefono,
          content: smsContent,
          type: "transactional",
        };
        const smsResp = await fetch(BREVO_SMS_URL, {
          method: "POST",
          headers: {
            "api-key": apiKey,
            "Content-Type": "application/json",
            accept: "application/json",
          },
          body: JSON.stringify(smsBody),
        });
        if (smsResp.ok) {
          console.log(`[on-scan-log] SMS ${status} inviato a ${telefono}`);
        } else {
          const smsData = await smsResp.json().catch(() => ({}));
          console.warn(`[on-scan-log] SMS non inviato: ${smsResp.status}`, smsData);
        }
      }
    } catch (smsErr) {
      console.warn("[on-scan-log] SMS error (non critico):", smsErr);
    }

    return json({ ok: true, messageId: data?.messageId ?? null });
  } catch (e) {
    console.error("[on-scan-log] Unexpected error", e);
    return json({ ok: false, error: String(e) }, 500);
  }
});
