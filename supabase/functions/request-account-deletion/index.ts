// Edge Function: request-account-deletion
//
// Primo passo della cancellazione account: l'utente la avvia dall'app (tile
// "Elimina account" nel profilo) e questa function gli manda l'email col link
// di conferma. NON cancella niente: si limita a creare un token monouso.
//
// Sicurezza:
//   - Protetta da verify_jwt (default Supabase): serve un JWT valido.
//   - L'utente da cancellare si ricava DAL JWT, mai da un campo nel body:
//     altrimenti chiunque potrebbe far partire la cancellazione di un altro.
//   - Il token viaggia in chiaro solo nell'email; in DB finisce il suo hash
//     SHA-256. Chi legge il DB non può ricostruire un link valido.
//   - Rate limit: una richiesta ogni RATE_LIMIT_MINUTI per utente, così la
//     casella di posta di qualcuno non diventa un bersaglio.
//
// Input JSON: nessuno (l'identità arriva dal JWT).
// Output: { ok: true } — sempre lo stesso, anche se il rate limit ha bloccato
//         l'invio: non diamo a un chiamante modo di sondare lo stato altrui.

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders } from "../_shared/cors.ts";

const TOKEN_VALIDITA_MINUTI = 30;
const RATE_LIMIT_MINUTI = 5;
const DELETE_PAGE_URL = "https://www.onlistclub.com/auth/delete-account";

/// SHA-256 in hex: stesso formato salvato in richieste_cancellazione.token_hash.
async function sha256Hex(input: string): Promise<string> {
  const bytes = new TextEncoder().encode(input);
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return Array.from(new Uint8Array(digest))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

// ── Design system email (shell light-first ufficiale) ────────────────────────
// Stesso layout di tutte le altre email OnListClub (docs/email_templates/*.html
// e messaging_service.dart): sfondo email #F5F6F8, card bianca con border
// grigio chiaro, testi scuri, accent viola/indigo per badge e CTA. Meta
// color-scheme:light: iOS Mail dark auto-inverte con contrasto (nessuna
// scritta nera su nero), tutti gli altri client mostrano la versione light
// come voluta. Wordmark mail.png (nero con alone viola) su fondo bianco.
const LOGO_URL = "https://www.onlistclub.com/mail.png";

function escapeHtml(value: string): string {
  return value
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

const SHELL_CSS = `
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
    .cta-cell{background:#4F46E5!important;background-image:linear-gradient(135deg,#4F46E5 0%,#7C3AED 100%)!important;border-radius:999px!important;box-shadow:0 6px 16px rgba(79,70,229,.28)!important;}
    .cta-link{display:block!important;min-height:48px!important;box-sizing:border-box!important;padding:14px 20px!important;font-size:15px!important;line-height:1.4!important;font-weight:600!important;letter-spacing:.2px!important;color:#FFFFFF!important;}
    .text-muted{color:#64748B!important;}
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
      .badge-bg{padding:4px 8px!important;}
      .badge-text{font-size:11px!important;letter-spacing:0!important;line-height:1.1!important;white-space:nowrap!important;}
      .text-body{font-size:14px!important;line-height:1.5!important;}
      .cta-link{min-height:42px!important;padding:12px 16px!important;}
      .footer-text{font-size:11px!important;line-height:1.3!important;}
    }
    @media only screen and (max-width:360px){
      .heading-cell,.status-cell{display:block!important;width:100%!important;text-align:center!important;}
      .status-cell{padding-top:10px!important;}
    }
`;

function emailHtml(nome: string, link: string): string {
  const saluto = nome
    ? `<strong class="text-bold-name" style="color:#0F172A;font-weight:700;">${escapeHtml(nome)}</strong>, hai `
    : `Hai `;
  return `<!DOCTYPE html>
<html lang="it" xmlns="http://www.w3.org/1999/xhtml" xmlns:v="urn:schemas-microsoft-com:vml" xmlns:o="urn:schemas-microsoft-com:office:office">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <meta name="color-scheme" content="light">
  <meta name="supported-color-schemes" content="light">
  <meta name="x-apple-disable-message-reformatting">
  <title>Conferma la cancellazione del tuo account</title>
  <!--[if mso]><noscript><xml><o:OfficeDocumentSettings><o:PixelsPerInch>96</o:PixelsPerInch></o:OfficeDocumentSettings></xml></noscript><![endif]-->
  <style>${SHELL_CSS}</style>
</head>
<body style="margin:0;padding:0;width:100%;min-width:100%;background-color:#F5F6F8;font-family:'Helvetica Neue',Helvetica,Arial,sans-serif;color:#0F172A;">
  <span style="display:none;font-size:1px;color:transparent;line-height:1px;max-height:0px;max-width:0px;opacity:0;overflow:hidden;">Hai chiesto di cancellare il tuo account OnListClub. Conferma il link entro ${TOKEN_VALIDITA_MINUTI} minuti.</span>
  <table role="presentation" width="100%" height="100%" cellpadding="0" cellspacing="0" border="0" bgcolor="#F5F6F8" style="width:100%;min-width:100%;height:100%;background-color:#F5F6F8;">
    <tr>
      <td align="center" valign="top" class="outer-wrapper-cell" style="padding:32px 16px;">
        <table bgcolor="#FFFFFF" class="email-container" width="100%" cellpadding="0" cellspacing="0" border="0" style="box-sizing:border-box;width:100%;max-width:560px;background-color:#FFFFFF;border:1px solid #E4E7EB;border-radius:22px;padding:36px 32px;box-shadow:0 1px 2px rgba(15,23,42,.04),0 12px 32px rgba(15,23,42,.06);">
          <tr>
            <td align="center" style="padding-bottom:28px;">
              <img class="logo-mark" src="${LOGO_URL}" alt="OnListClub" width="200" style="display:block;width:200px;max-width:70%;height:auto;border:0;margin:0 auto;">
            </td>
          </tr>
          <tr>
            <td style="padding-bottom:16px;">
              <table class="heading-status-row" width="100%" cellpadding="0" cellspacing="0" border="0" role="presentation" style="width:100%;table-layout:fixed;">
                <tr>
                  <td class="heading-cell" align="left" valign="middle" style="width:56%;text-align:left;vertical-align:middle;">
                    <h1 class="text-title" style="margin:0;font-family:'Helvetica Neue',Helvetica,Arial,sans-serif;font-size:26px;line-height:1.25;font-weight:700;color:#0F172A;">Conferma la cancellazione.</h1>
                  </td>
                  <td class="status-cell" align="right" valign="middle" style="width:44%;text-align:right;vertical-align:middle;">
                    <table align="right" cellpadding="0" cellspacing="0" border="0" role="presentation" style="width:auto;margin:0 0 0 auto;">
                      <tr>
                        <td class="badge-bg" valign="middle" bgcolor="#EDE9FE" style="border:1px solid #DDD6FE;border-radius:26px;padding:6px 12px;background-color:#EDE9FE;text-align:center;vertical-align:middle;">
                          <span class="badge-text" style="font-family:'Helvetica Neue',Helvetica,Arial,sans-serif;font-size:13px;font-weight:700;line-height:1.25;color:#5B21B6;letter-spacing:.02em;">Cancellazione account</span>
                        </td>
                      </tr>
                    </table>
                  </td>
                </tr>
              </table>
            </td>
          </tr>
          <tr>
            <td align="left" style="padding-bottom:20px;">
              <p class="text-body" style="margin:0;font-family:'Helvetica Neue',Helvetica,Arial,sans-serif;font-size:15px;line-height:1.6;color:#334155;">
                ${saluto}chiesto di eliminare definitivamente il tuo account OnListClub.
              </p>
            </td>
          </tr>
          <tr>
            <td align="left" style="padding-bottom:20px;">
              <p class="text-body" style="margin:0;font-family:'Helvetica Neue',Helvetica,Arial,sans-serif;font-size:15px;line-height:1.6;color:#334155;">
                Apri la pagina qui sotto per confermare. Il link vale <strong class="text-bold-name" style="color:#0F172A;font-weight:700;">${TOKEN_VALIDITA_MINUTI} minuti</strong> e puo' essere usato una sola volta.
              </p>
            </td>
          </tr>
          <tr>
            <td style="padding-bottom:20px;">
              <table width="100%" cellpadding="0" cellspacing="0" border="0"><tr>
                <td align="center" class="cta-cell" bgcolor="#4F46E5" style="background:#4F46E5;background-color:#4F46E5;background-image:linear-gradient(135deg,#4F46E5 0%,#7C3AED 100%);border-radius:999px;box-shadow:0 6px 16px rgba(79,70,229,.28);">
                  <a href="${link}" class="cta-link" style="display:block;min-height:48px;box-sizing:border-box;padding:14px 20px;font-family:'Helvetica Neue',Helvetica,Arial,sans-serif;font-size:15px;line-height:1.4;font-weight:600;letter-spacing:.2px;text-decoration:none;color:#FFFFFF;text-align:center;" target="_blank">Elimina il mio account</a>
                </td>
              </tr></table>
            </td>
          </tr>
          <tr>
            <td align="left" style="padding-bottom:12px;">
              <p class="text-muted" style="margin:0;font-family:'Helvetica Neue',Helvetica,Arial,sans-serif;font-size:13px;line-height:1.6;color:#64748B;">
                L'operazione e' definitiva. I tuoi dati personali verranno rimossi e l'account non sara' recuperabile.
              </p>
            </td>
          </tr>
          <tr>
            <td align="left" style="padding-bottom:28px;">
              <p class="text-muted" style="margin:0;font-family:'Helvetica Neue',Helvetica,Arial,sans-serif;font-size:13px;line-height:1.6;color:#64748B;">
                Non hai richiesto tu la cancellazione? Ignora questa email: senza la conferma non succede nulla.
              </p>
            </td>
          </tr>
          <tr>
            <td class="footer-divider" style="border-top:1px solid #E4E7EB;padding-top:22px;" align="center">
              <p class="footer-text" style="margin:0 0 6px;font-family:'Helvetica Neue',Helvetica,Arial,sans-serif;font-size:12px;text-align:center;color:#64748B;">
                OnListClub. Prenota tavoli, prevendite e drink nei migliori locali.
              </p>
              <p class="footer-text" style="margin:0;font-family:'Helvetica Neue',Helvetica,Arial,sans-serif;font-size:12px;text-align:center;color:#64748B;">
                Hai domande? Scrivici a <a href="mailto:info@onlistclub.com" class="footer-link" style="text-decoration:none;color:#4F46E5;" target="_blank">info@onlistclub.com</a>
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
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;

    // ── Identità: dal JWT, non dal body ──────────────────────────────────────
    const authHeader = req.headers.get("Authorization") ?? "";
    const asUser = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: { user }, error: userErr } = await asUser.auth.getUser();
    if (userErr || !user) {
      return json({ ok: false, error: "unauthorized" }, 401);
    }
    if (!user.email) {
      // Senza email non c'è dove mandare il link.
      console.error("[request-account-deletion] utente senza email", user.id);
      return json({ ok: false, error: "no_email" }, 400);
    }

    const admin = createClient(supabaseUrl, serviceKey);

    // ── Rate limit ───────────────────────────────────────────────────────────
    const soglia = new Date(Date.now() - RATE_LIMIT_MINUTI * 60_000)
      .toISOString();
    const { data: recenti, error: rlErr } = await admin
      .from("richieste_cancellazione")
      .select("id")
      .eq("id_utente", user.id)
      .gte("created_at", soglia)
      .limit(1);
    if (rlErr) {
      console.error("[request-account-deletion] rate limit query:", rlErr);
      return json({ ok: false, error: "db_error" }, 500);
    }
    if (recenti && recenti.length > 0) {
      // Silenzioso di proposito: l'email precedente è ancora valida.
      console.log("[request-account-deletion] rate limited", user.id);
      return json({ ok: true });
    }

    // ── Token monouso ────────────────────────────────────────────────────────
    const raw = crypto.randomUUID() + crypto.randomUUID();
    const tokenHash = await sha256Hex(raw);
    const scadenza = new Date(Date.now() + TOKEN_VALIDITA_MINUTI * 60_000);

    const { error: insErr } = await admin
      .from("richieste_cancellazione")
      .insert({
        id_utente: user.id,
        token_hash: tokenHash,
        scadenza: scadenza.toISOString(),
      });
    if (insErr) {
      console.error("[request-account-deletion] insert:", insErr);
      return json({ ok: false, error: "db_error" }, 500);
    }

    // ── Email ────────────────────────────────────────────────────────────────
    const { data: profilo } = await admin
      .from("utenti")
      .select("nome")
      .eq("id", user.id)
      .maybeSingle();
    const nome = profilo?.nome ?? "";
    const link = `${DELETE_PAGE_URL}?token=${raw}`;

    const { error: mailErr } = await admin.functions.invoke("send-email", {
      body: {
        to: user.email,
        toName: nome || undefined,
        subject: "Conferma la cancellazione del tuo account",
        htmlContent: emailHtml(nome, link),
        textContent:
          `Hai chiesto di eliminare il tuo account OnListClub.\n` +
          `Conferma qui (link valido ${TOKEN_VALIDITA_MINUTI} minuti): ${link}\n` +
          `Se non sei stato tu, ignora questa email.`,
      },
    });
    if (mailErr) {
      console.error("[request-account-deletion] send-email:", mailErr);
      return json({ ok: false, error: "email_error" }, 500);
    }

    return json({ ok: true });
  } catch (e) {
    console.error("[request-account-deletion] errore:", e);
    return json({ ok: false, error: "unexpected" }, 500);
  }
});
