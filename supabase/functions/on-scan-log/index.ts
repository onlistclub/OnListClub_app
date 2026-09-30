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
// shell "mobile" ufficiale usato da tutti i template OnListClub. Color-scheme
// dark forzato, card blu notte #071421 con gradient e border blu chiaro #42A5FF,
// wordmark mail-dark.png esterno. Varianti badge: blu (default), verde (OK),
// arancio (WARN) — solo il colore del badge cambia per differenziare i due tipi
// di email; card, logo, footer, CTA sono identici a welcome/reset/deletion.
const LOGO_URL = "https://www.onlistclub.com/mail-dark.png";

function escHtml(s: string): string {
  return s
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

const SHELL_CSS = `
    :root{color-scheme:dark;}
    html,body{margin:0!important;padding:0!important;width:100%!important;min-width:100%!important;height:100%!important;-webkit-text-size-adjust:100%;-ms-text-size-adjust:100%;}
    body{background-color:transparent!important;color:#F2F7FC!important;}
    table,td{mso-table-lspace:0pt!important;mso-table-rspace:0pt!important;}
    img{border:0;height:auto;line-height:100%;outline:none;text-decoration:none;-ms-interpolation-mode:bicubic;}
    a{text-decoration:none;}
    .outer-wrapper{background-color:transparent!important;background-image:none!important;}
    .email-container,.details-box{box-sizing:border-box!important;background-color:rgba(10,27,45,.94)!important;background-image:linear-gradient(155deg,rgba(0,119,255,.24) 0%,rgba(10,27,45,.90) 42%,rgba(10,27,45,.96) 100%)!important;border:1px solid #42A5FF!important;border-radius:22px!important;box-shadow:inset 0 1px 0 rgba(130,195,255,.48),0 18px 42px rgba(4,13,24,.42),0 0 22px rgba(0,119,255,.18)!important;}
    .email-container{width:100%!important;max-width:600px!important;padding:36px 32px!important;background-color:#071421!important;background-image:linear-gradient(155deg,rgba(0,119,255,.10) 0%,rgba(7,20,33,.97) 42%,rgba(5,14,24,.99) 100%)!important;box-shadow:inset 0 1px 0 rgba(130,195,255,.28),0 18px 42px rgba(3,12,22,.62),0 0 30px rgba(0,119,255,.24)!important;}
    .logo-light{display:block!important;width:240px!important;max-width:78%!important;height:auto!important;margin:0 auto!important;}
    .text-title,.text-body,.text-bold-name,.details-value,.footer-text{color:#F2F7FC!important;}
    .details-label{color:#A9D6FF!important;}
    .detail-cell:first-child{padding-right:16px!important;}
    .detail-cell:nth-child(2){padding-left:16px!important;}
    .footer-divider{border-top-color:rgba(130,195,255,.42)!important;}
    .footer-link{color:#C7E6FF!important;text-decoration:underline!important;}
    .heading-status-row{width:100%!important;table-layout:fixed!important;}
    .heading-cell{width:48%!important;text-align:left!important;vertical-align:middle!important;}
    .status-cell{width:52%!important;text-align:right!important;vertical-align:middle!important;}
    .heading-cell .text-title{font-size:25px!important;}
    .badge-bg-ok{box-sizing:border-box!important;width:auto!important;padding:6px 9px!important;border:1px solid rgba(134,239,172,.55)!important;border-radius:26px!important;background-color:#0E2016!important;background-image:linear-gradient(150deg,rgba(22,163,74,.28),rgba(10,27,45,.96))!important;box-shadow:inset 0 1px 0 rgba(134,239,172,.35)!important;text-align:center!important;vertical-align:middle!important;}
    .badge-text-ok{color:#B7F5C7!important;font-size:16px!important;line-height:1.25!important;font-weight:700!important;}
    .badge-bg-warn{box-sizing:border-box!important;width:auto!important;padding:6px 9px!important;border:1px solid rgba(253,186,116,.55)!important;border-radius:26px!important;background-color:#241610!important;background-image:linear-gradient(150deg,rgba(234,88,12,.30),rgba(10,27,45,.96))!important;box-shadow:inset 0 1px 0 rgba(253,186,116,.35)!important;text-align:center!important;vertical-align:middle!important;}
    .badge-text-warn{color:#FDE1B2!important;font-size:16px!important;line-height:1.25!important;font-weight:700!important;}
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
      .badge-bg-ok,.badge-bg-warn{padding:4px 6px!important;}
      .badge-text-ok,.badge-text-warn{font-size:12px!important;letter-spacing:0!important;line-height:1.1!important;white-space:nowrap!important;}
      .text-body{font-size:14px!important;line-height:1.4!important;}
      .details-box{padding:12px!important;}
      .detail-cell:first-child{padding-right:6px!important;}
      .detail-cell:nth-child(2){padding-left:6px!important;}
      .details-value{font-size:14px!important;}
      .cta-link{min-height:42px!important;padding:10px 14px!important;}
      .footer-divider{padding-top:14px!important;}
      .footer-text{font-size:11px!important;line-height:1.3!important;}
    }
    @media only screen and (max-width:360px){
      .heading-cell,.status-cell{display:block!important;width:100%!important;text-align:center!important;}
      .heading-cell .text-title{text-align:center!important;}
      .status-cell{padding-top:8px!important;}
    }
`;

interface BadgeStyle {
  className: string;
  textClass: string;
  bg: string;
  border: string;
  grad: string;
  shadow: string;
  textColor: string;
}

const BADGE_OK: BadgeStyle = {
  className: "badge-bg-ok",
  textClass: "badge-text-ok",
  bg: "#0E2016",
  border: "rgba(134,239,172,.55)",
  grad: "linear-gradient(150deg,rgba(22,163,74,.28),rgba(10,27,45,.96))",
  shadow: "inset 0 1px 0 rgba(134,239,172,.35)",
  textColor: "#B7F5C7",
};

const BADGE_WARN: BadgeStyle = {
  className: "badge-bg-warn",
  textClass: "badge-text-warn",
  bg: "#241610",
  border: "rgba(253,186,116,.55)",
  grad: "linear-gradient(150deg,rgba(234,88,12,.30),rgba(10,27,45,.96))",
  shadow: "inset 0 1px 0 rgba(253,186,116,.35)",
  textColor: "#FDE1B2",
};

function headingWithBadge(title: string, badgeLabel: string, badge: BadgeStyle): string {
  return `
          <tr>
            <td style="padding-bottom:14px;">
              <table class="heading-status-row" width="100%" cellpadding="0" cellspacing="0" border="0" role="presentation" style="width:100%;table-layout:fixed;">
                <tr>
                  <td class="heading-cell" width="48%" align="left" valign="middle">
                    <h1 class="text-title" style="margin:0;font-family:'Helvetica Neue',Helvetica,Arial,sans-serif;font-size:26px;line-height:1.25;font-weight:700;">${title}</h1>
                  </td>
                  <td class="status-cell" width="52%" align="right" valign="middle">
                    <table align="right" cellpadding="0" cellspacing="0" border="0" role="presentation" style="width:auto;margin:0 0 0 auto;">
                      <tr>
                        <td class="${badge.className}" valign="middle" style="border:1px solid ${badge.border};border-radius:26px;padding:6px 9px;background-color:${badge.bg};background-image:${badge.grad};box-shadow:${badge.shadow};text-align:center;vertical-align:middle;">
                          <span class="${badge.textClass}" style="font-family:'Helvetica Neue',Helvetica,Arial,sans-serif;font-size:16px;font-weight:700;line-height:1.25;color:${badge.textColor};">${badgeLabel}</span>
                        </td>
                      </tr>
                    </table>
                  </td>
                </tr>
              </table>
            </td>
          </tr>
`;
}

function bodyRow(innerHtml: string, paddingBottom = 24, fontSize = 15): string {
  return `
          <tr>
            <td align="left" style="padding-bottom:${paddingBottom}px;">
              <p class="text-body" style="margin:0;font-family:'Helvetica Neue',Helvetica,Arial,sans-serif;font-size:${fontSize}px;line-height:1.6;">${innerHtml}</p>
            </td>
          </tr>
`;
}

function detailCell(label: string, value: string, bottomPadded = true): string {
  const pb = bottomPadded ? "padding-bottom:18px;" : "";
  return `<td class="detail-cell" width="50%" style="${pb}vertical-align:top;">
    <p class="details-label" style="margin:0 0 4px;font-family:'Helvetica Neue',Helvetica,Arial,sans-serif;font-size:11px;font-weight:400;text-transform:uppercase;letter-spacing:0.08em;color:#A9D6FF;">${label}</p>
    <p class="details-value" style="margin:0;font-family:'Helvetica Neue',Helvetica,Arial,sans-serif;font-size:16px;font-weight:700;color:#F2F7FC;">${value}</p>
  </td>`;
}

function emptyCell(): string {
  return `<td class="detail-cell" width="50%" style="vertical-align:top;"></td>`;
}

function detailsBox(rows: string[][]): string {
  const rowsHtml = rows.map((cells) => `<tr>${cells[0] ?? emptyCell()}${cells[1] ?? emptyCell()}</tr>`).join("");
  return `
          <tr>
            <td style="padding-bottom:24px;">
              <table bgcolor="#0B1B2D" class="details-box" width="100%" cellpadding="0" cellspacing="0" border="0" style="background-color:rgba(10,27,45,.94);background-image:linear-gradient(155deg,rgba(0,119,255,.24) 0%,rgba(10,27,45,.90) 42%,rgba(10,27,45,.96) 100%);border:1px solid #42A5FF;border-radius:22px;padding:20px 20px;box-shadow:inset 0 1px 0 rgba(130,195,255,.48),0 18px 42px rgba(4,13,24,.42),0 0 22px rgba(0,119,255,.18);">
                ${rowsHtml}
              </table>
            </td>
          </tr>
`;
}

function ctaButton(label: string, href: string): string {
  return `
          <tr>
            <td style="padding-bottom:28px;">
              <table width="100%" cellpadding="0" cellspacing="0" border="0"><tr>
                <td align="center" class="cta-cell" style="background:#0077FF;background-color:#0077FF;background-image:linear-gradient(135deg,#005CC8 0%,#0049A3 52%,#00377C 100%);border-radius:999px;box-shadow:inset 0 1px 0 rgba(255,255,255,.22),0 0 8px rgba(255,255,255,.28),0 0 18px rgba(255,255,255,.16),0 8px 20px rgba(255,255,255,.10);">
                  <a href="${href}" class="cta-link" style="display:block;min-height:48px;box-sizing:border-box;padding:14px 20px;font-family:'Helvetica Neue',Helvetica,Arial,sans-serif;font-size:15px;line-height:1.4;font-weight:600;letter-spacing:.3px;text-decoration:none;color:#FFFFFF;text-align:center;" target="_blank">${label}</a>
                </td>
              </tr></table>
            </td>
          </tr>
`;
}

function htmlShell(preheader: string, title: string, cardContent: string): string {
  return `<!DOCTYPE html>
<html lang="it" xmlns="http://www.w3.org/1999/xhtml" xmlns:v="urn:schemas-microsoft-com:vml" xmlns:o="urn:schemas-microsoft-com:office:office">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <meta name="color-scheme" content="dark">
  <meta name="supported-color-schemes" content="dark">
  <meta name="x-apple-disable-message-reformatting">
  <title>${title}</title>
  <!--[if mso]><noscript><xml><o:OfficeDocumentSettings><o:PixelsPerInch>96</o:PixelsPerInch></o:OfficeDocumentSettings></xml></noscript><![endif]-->
  <style>${SHELL_CSS}</style>
</head>
<body style="background:transparent;background-color:transparent;margin:0;padding:0;width:100%;min-width:100%;font-family:'Helvetica Neue',Helvetica,Arial,sans-serif;">
  <span style="display:none;font-size:1px;color:transparent;line-height:1px;max-height:0px;max-width:0px;opacity:0;overflow:hidden;">${preheader}</span>
  <table class="outer-wrapper" width="100%" height="100%" cellpadding="0" cellspacing="0" border="0" style="width:100%;min-width:100%;height:100%;table-layout:fixed;background-color:transparent;background-image:none;">
    <tr>
      <td align="center" valign="middle" class="outer-wrapper-cell" style="padding:28px 16px;vertical-align:middle;">
        <table bgcolor="#071421" class="email-container" width="100%" cellpadding="0" cellspacing="0" border="0" style="box-sizing:border-box;width:100%;max-width:560px;background-color:#071421;background-image:linear-gradient(155deg,rgba(0,119,255,.10) 0%,rgba(7,20,33,.97) 42%,rgba(5,14,24,.99) 100%);border:1px solid #42A5FF;border-radius:22px;padding:36px 32px;box-shadow:inset 0 1px 0 rgba(130,195,255,.28),0 18px 42px rgba(3,12,22,.62),0 0 30px rgba(0,119,255,.24);">
          <tr>
            <td class="header-logo-cell" align="center" style="padding-bottom:28px;">
              <img class="logo-light" src="${LOGO_URL}" alt="OnListClub" width="240" height="102" style="display:block;width:240px;max-width:78%;height:102px;border:0;margin:0 auto;">
            </td>
          </tr>
          ${cardContent}
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
</html>`;
}

function buildValidHtml(nome: string, localeNome: string, eventoNome: string, checkinTime: string): string {
  const rows: string[][] = [
    [detailCell("Locale", escHtml(localeNome)), detailCell("Serata", escHtml(eventoNome))],
    [detailCell("Check-in", escHtml(checkinTime), false), emptyCell()],
  ];
  const card =
    headingWithBadge("Sei entrato.", "Ingresso confermato", BADGE_OK) +
    bodyRow(`<strong class="text-bold-name" style="color:#F2F7FC;font-weight:700;">${escHtml(nome)}</strong>, il tuo biglietto e' stato scannerizzato all'ingresso.`) +
    detailsBox(rows);
  return htmlShell(
    `Il tuo biglietto per ${escHtml(eventoNome)} e' stato scannerizzato. Ingresso confermato.`,
    "Ingresso confermato",
    card,
  );
}

function buildAlreadyUsedHtml(nome: string, localeNome: string, eventoNome: string, firstScanTime: string): string {
  const rows: string[][] = [
    [detailCell("Locale", escHtml(localeNome)), detailCell("Serata", escHtml(eventoNome))],
    [detailCell("Prima scansione", escHtml(firstScanTime), false), emptyCell()],
  ];
  const card =
    headingWithBadge("Scansione non accettata.", "Biglietto gia' usato", BADGE_WARN) +
    bodyRow(`<strong class="text-bold-name" style="color:#F2F7FC;font-weight:700;">${escHtml(nome)}</strong>, il tuo biglietto e' stato rifiutato all'ingresso perche' e' gia' stato utilizzato.`) +
    detailsBox(rows) +
    bodyRow(`<strong class="text-bold-name" style="color:#F2F7FC;font-weight:700;">Non sei stato tu?</strong><br>Se non riconosci questo accesso, il tuo QR potrebbe essere stato condiviso. Contattaci subito.`, 24, 14) +
    ctaButton("Vedi i tuoi ordini nell'app", "onlistclub://orders");
  return htmlShell(
    `Il tuo biglietto per ${escHtml(eventoNome)} e' gia' stato utilizzato.`,
    "Biglietto gia' utilizzato",
    card,
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
