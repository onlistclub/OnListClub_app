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

// ── Design tokens email (allineati a docs/email_templates/ e request-account-deletion) ─
// LOGO: un solo file, il marchio ufficiale Onlist (bianco, bagliore viola). La
// piastra dietro è grigio tenue solo in modalità chiara; in scuro è trasparente.
const LOGO_URL = "https://www.onlistclub.com/email-logo.png";
const LOGO_PLATE_BG_LIGHT = "#8f95aa";
const LOGO_PLATE_BORDER_LIGHT = "#747a90";
const FONT_DISPLAY = "'Space Grotesk', Helvetica, Arial, sans-serif";
const FONT_SANS = "'Inter', Helvetica, Arial, sans-serif";

function escHtml(s: string): string {
  return s
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

function htmlShell(preheader: string, title: string, cardContent: string): string {
  return `<!DOCTYPE html>
<html lang="it">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <meta name="color-scheme" content="light dark" />
    <meta name="supported-color-schemes" content="light dark" />
    <title>${title}</title>
    <style>
      body, .bg-outer { background-color: #eef1f8; }
      .card { background-color: #ffffff; border-color: #e1e5f0 !important; }
      .text-heading { color: #12131c !important; }
      .text-body { color: #525b70 !important; }
      .footer-link { color: #1b3fd6 !important; }
      .logo-plate { background-color: ${LOGO_PLATE_BG_LIGHT} !important; border-color: ${LOGO_PLATE_BORDER_LIGHT} !important; }
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
    <span style="display:none;max-height:0;overflow:hidden;opacity:0;">${preheader}</span>
    <table role="presentation" width="100%" cellpadding="0" cellspacing="0" class="bg-outer" bgcolor="#eef1f8" style="background-color:#eef1f8;padding:36px 16px;">
      <tr><td align="center">
        <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:560px;">
          <tr>
            <td align="center" style="padding-bottom:28px;">
              <table role="presentation" cellpadding="0" cellspacing="0" style="margin:0 auto;">
                <tr>
                  <td align="center" class="logo-plate" bgcolor="${LOGO_PLATE_BG_LIGHT}" style="background-color:${LOGO_PLATE_BG_LIGHT};border:1px solid ${LOGO_PLATE_BORDER_LIGHT};border-radius:20px;padding:20px 32px;">
                    <img src="${LOGO_URL}" alt="OnListClub" width="140" style="display:block;width:140px;height:auto;border:0;margin:0 auto;" />
                  </td>
                </tr>
              </table>
            </td>
          </tr>
          <tr>
            <td class="card" bgcolor="#ffffff" style="background-color:#ffffff;border:1px solid #e1e5f0;border-radius:24px;padding:36px 32px;">
              ${cardContent}
            </td>
          </tr>
          <tr>
            <td align="center" style="padding-top:28px;">
              <p class="text-body" style="margin:0 0 6px;font-family:${FONT_SANS};font-size:12px;color:#525b70;">
                OnListClub — Prenota tavoli, prevendite e drink nei migliori locali.
              </p>
              <p class="text-body" style="margin:0;font-family:${FONT_SANS};font-size:12px;color:#525b70;">
                Hai domande? Scrivici a <a href="mailto:info@onlistclub.com" class="footer-link" style="color:#1b3fd6;text-decoration:none;">info@onlistclub.com</a>
              </p>
            </td>
          </tr>
        </table>
      </td></tr>
    </table>
  </body>
</html>`;
}

function badge(label: string, bgLight: string, borderLight: string, textLight: string): string {
  return `<table role="presentation" cellpadding="0" cellspacing="0" style="margin-bottom:20px;"><tr>
    <td style="border-radius:999px;background-color:${bgLight};border:1px solid ${borderLight};padding:6px 14px;font-family:${FONT_SANS};font-size:11px;letter-spacing:.08em;text-transform:uppercase;color:${textLight};">
      ${label}
    </td>
  </tr></table>`;
}

function infoRow(label: string, value: string): string {
  return `<tr><td style="padding-bottom:10px;">
    <p style="margin:0;font-family:${FONT_SANS};font-size:12px;letter-spacing:.06em;text-transform:uppercase;color:#8b93a7;">${label}</p>
    <p class="text-heading" style="margin:4px 0 0;font-family:${FONT_DISPLAY};font-size:16px;font-weight:600;color:#12131c;">${value}</p>
  </td></tr>`;
}

function infoBox(rows: string[], bg: string, border: string): string {
  return `<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="margin-bottom:24px;"><tr>
    <td style="background-color:${bg};border:1px solid ${border};border-radius:14px;padding:18px 20px;">
      <table role="presentation" width="100%" cellpadding="0" cellspacing="0">${rows.join("")}</table>
    </td>
  </tr></table>`;
}

function ctaButton(label: string, href: string): string {
  return `<table role="presentation" cellpadding="0" cellspacing="0" style="margin-top:20px;"><tr>
    <td bgcolor="#0098ff" style="border-radius:999px;background-color:#0098ff;background-image:linear-gradient(135deg,#133eff,#0098ff);">
      <a href="${href}" style="display:inline-block;padding:13px 32px;font-family:${FONT_SANS};font-size:14px;font-weight:600;color:#ffffff;text-decoration:none;">${label}</a>
    </td>
  </tr></table>`;
}

// ─── Builder email VALID ──────────────────────────────────────────────────────
function buildValidHtml(nome: string, localeNome: string, eventoNome: string, checkinTime: string): string {
  const card =
    badge("Ingresso confermato", "rgba(22,163,74,0.08)", "rgba(22,163,74,0.28)", "#15803d") +
    `<h1 class="text-heading" style="margin:0 0 14px;font-family:${FONT_DISPLAY};font-size:24px;line-height:1.25;color:#12131c;letter-spacing:-0.02em;">
      Sei entrato! Divertiti 🎟️
    </h1>
    <p class="text-body" style="margin:0 0 24px;font-family:${FONT_SANS};font-size:15px;line-height:1.6;color:#525b70;">
      Ciao <strong style="color:#12131c;">${escHtml(nome)}</strong>, il tuo biglietto è stato scannerizzato con successo all'ingresso.
    </p>` +
    infoBox(
      [infoRow("Locale", escHtml(localeNome)), infoRow("Serata", escHtml(eventoNome)), infoRow("Check-in", escHtml(checkinTime))],
      "#f0fdf4", "rgba(22,163,74,0.25)"
    );
  return htmlShell(
    `Il tuo biglietto per ${escHtml(eventoNome)} è stato scannerizzato: ingresso confermato! Divertiti.`,
    "Ingresso confermato — OnListClub",
    card
  );
}

// ─── Builder email ALREADY_USED ───────────────────────────────────────────────
function buildAlreadyUsedHtml(nome: string, localeNome: string, eventoNome: string, firstScanTime: string): string {
  const card =
    badge("Biglietto già usato", "rgba(234,88,12,0.08)", "rgba(234,88,12,0.28)", "#c2410c") +
    `<h1 class="text-heading" style="margin:0 0 14px;font-family:${FONT_DISPLAY};font-size:24px;line-height:1.25;color:#12131c;letter-spacing:-0.02em;">
      Scansione non accettata ⚠️
    </h1>
    <p class="text-body" style="margin:0 0 24px;font-family:${FONT_SANS};font-size:15px;line-height:1.6;color:#525b70;">
      Ciao <strong style="color:#12131c;">${escHtml(nome)}</strong>, il tuo biglietto è stato rifiutato perché è già stato utilizzato in precedenza.
    </p>` +
    infoBox(
      [infoRow("Locale", escHtml(localeNome)), infoRow("Serata", escHtml(eventoNome)), infoRow("Prima scansione", escHtml(firstScanTime))],
      "#fff7ed", "rgba(234,88,12,0.22)"
    ) +
    `<p class="text-body" style="margin:0 0 8px;font-family:${FONT_SANS};font-size:14px;line-height:1.6;color:#525b70;">
      <strong style="color:#12131c;">Non sei stato tu?</strong><br />
      Se non riconosci questo accesso, il tuo QR potrebbe essere stato condiviso. Contattaci subito.
    </p>` +
    ctaButton("Vedi i tuoi ordini nell'app →", "onlistclub://orders");
  return htmlShell(
    `Attenzione: il tuo biglietto per ${escHtml(eventoNome)} è già stato utilizzato in precedenza.`,
    "Biglietto già utilizzato — OnListClub",
    card
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
      subject = `✅ Ingresso confermato — ${localeNome}`;
      htmlContent = buildValidHtml(
        nomeUtente, localeNome, eventoNome,
        formatDateTime(scannedAt)
      );
    } else {
      subject = `⚠️ Biglietto già utilizzato — ${localeNome}`;
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
          sender: senderName.length <= 11 ? senderName : "OnListClub",
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
