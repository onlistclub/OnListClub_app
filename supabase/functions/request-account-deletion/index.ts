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

// ── Design system email (shell mobile ufficiale) ─────────────────────────────
// Stesso layout di tutte le altre email OnListClub (docs/email_templates/*.html
// e messaging_service.dart): color-scheme:dark forzato, card blu notte #071421
// con gradient e border blu chiaro #42A5FF, wordmark mail-dark.png su
// onlistclub.com. Nessun adattamento light/dark, nessun swap CSS. iOS Mail non
// puo' invertire i colori perche' tutti gli sfondi scuri hanno background-image
// gradient che iOS non tocca.
const LOGO_URL = "https://www.onlistclub.com/mail-dark.png";

function escapeHtml(value: string): string {
  return value
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

const SHELL_CSS = `
  :root{color-scheme:dark;}
  html,body{margin:0!important;padding:0!important;width:100%!important;min-width:100%!important;height:100%!important;-webkit-text-size-adjust:100%;-ms-text-size-adjust:100%;}
  body{background-color:transparent!important;color:#F2F7FC!important;}
  table,td{mso-table-lspace:0pt!important;mso-table-rspace:0pt!important;}
  img{border:0;height:auto;line-height:100%;outline:none;text-decoration:none;-ms-interpolation-mode:bicubic;}
  a{text-decoration:none;}
  .outer-wrapper{background-color:transparent!important;background-image:none!important;}
  .email-container{box-sizing:border-box!important;width:100%!important;max-width:600px!important;padding:36px 32px!important;background-color:#071421!important;background-image:linear-gradient(155deg,rgba(0,119,255,.10) 0%,rgba(7,20,33,.97) 42%,rgba(5,14,24,.99) 100%)!important;border:1px solid #42A5FF!important;border-radius:22px!important;box-shadow:inset 0 1px 0 rgba(130,195,255,.28),0 18px 42px rgba(3,12,22,.62),0 0 30px rgba(0,119,255,.24)!important;}
  .logo-light{display:block!important;width:240px!important;max-width:78%!important;height:auto!important;margin:0 auto!important;}
  .text-title,.text-body,.text-bold-name,.text-muted,.footer-text{color:#F2F7FC!important;}
  .footer-divider{border-top-color:rgba(130,195,255,.42)!important;}
  .footer-link{color:#C7E6FF!important;text-decoration:underline!important;}
  .heading-status-row{width:100%!important;table-layout:fixed!important;}
  .heading-cell{width:48%!important;text-align:left!important;vertical-align:middle!important;}
  .status-cell{width:52%!important;text-align:right!important;vertical-align:middle!important;}
  .heading-cell .text-title{font-size:25px!important;}
  .badge-bg{box-sizing:border-box!important;width:auto!important;padding:6px 9px!important;border:1px solid rgba(130,195,255,.42)!important;border-radius:26px!important;background-color:#0B1B2D!important;background-image:linear-gradient(150deg,rgba(0,119,255,.14),rgba(10,27,45,.96))!important;box-shadow:inset 0 1px 0 rgba(130,195,255,.3)!important;text-align:center!important;vertical-align:middle!important;}
  .badge-text{color:#F2F7FC!important;font-size:16px!important;line-height:1.25!important;font-weight:700!important;}
  .cta-cell{background:#0077FF!important;background-image:linear-gradient(135deg,#005CC8 0%,#0049A3 52%,#00377C 100%)!important;border-radius:999px!important;box-shadow:inset 0 1px 0 rgba(255,255,255,.22),0 0 8px rgba(255,255,255,.28),0 0 18px rgba(255,255,255,.16),0 8px 20px rgba(255,255,255,.10)!important;}
  .cta-link{display:block!important;min-height:48px!important;box-sizing:border-box!important;padding:14px 20px!important;font-size:15px!important;line-height:1.4!important;font-weight:600!important;letter-spacing:.3px!important;color:#FFFFFF!important;}
  .text-muted{opacity:0.85!important;}
  @media only screen and (max-width:600px){
    .outer-wrapper-cell{vertical-align:middle!important;padding:12px 8px!important;}
    .email-container{padding:14px 12px!important;}
    .header-logo-cell{padding-bottom:12px!important;}
    .logo-light{width:190px!important;}
    .heading-cell,.status-cell{display:table-cell!important;vertical-align:middle!important;}
    .heading-cell{width:57%!important;text-align:left!important;}
    .status-cell{width:43%!important;text-align:center!important;}
    .heading-cell .text-title{font-size:24px!important;line-height:1.2!important;}
    .badge-bg{padding:4px 6px!important;}
    .badge-text{font-size:12px!important;letter-spacing:0!important;line-height:1.1!important;white-space:nowrap!important;}
    .text-body{font-size:14px!important;line-height:1.4!important;}
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

function emailHtml(nome: string, link: string): string {
  const saluto = nome
    ? `<strong class="text-bold-name" style="color:#F2F7FC;font-weight:700;">${escapeHtml(nome)}</strong>, hai `
    : `Hai `;
  return `<!DOCTYPE html>
<html lang="it" xmlns="http://www.w3.org/1999/xhtml" xmlns:v="urn:schemas-microsoft-com:vml" xmlns:o="urn:schemas-microsoft-com:office:office">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <meta name="color-scheme" content="dark">
  <meta name="supported-color-schemes" content="dark">
  <meta name="x-apple-disable-message-reformatting">
  <title>Conferma la cancellazione del tuo account</title>
  <!--[if mso]><noscript><xml><o:OfficeDocumentSettings><o:PixelsPerInch>96</o:PixelsPerInch></o:OfficeDocumentSettings></xml></noscript><![endif]-->
  <style>${SHELL_CSS}</style>
</head>
<body style="background:transparent;background-color:transparent;margin:0;padding:0;width:100%;min-width:100%;font-family:'Helvetica Neue',Helvetica,Arial,sans-serif;">
  <span style="display:none;font-size:1px;color:transparent;line-height:1px;max-height:0px;max-width:0px;opacity:0;overflow:hidden;">Hai chiesto di cancellare il tuo account OnListClub. Conferma il link entro ${TOKEN_VALIDITA_MINUTI} minuti.</span>
  <table class="outer-wrapper" width="100%" height="100%" cellpadding="0" cellspacing="0" border="0" style="width:100%;min-width:100%;height:100%;table-layout:fixed;background-color:transparent;background-image:none;">
    <tr>
      <td align="center" valign="middle" class="outer-wrapper-cell" style="padding:28px 16px;vertical-align:middle;">
        <table bgcolor="#071421" class="email-container" width="100%" cellpadding="0" cellspacing="0" border="0" style="box-sizing:border-box;width:100%;max-width:560px;background-color:#071421;background-image:linear-gradient(155deg,rgba(0,119,255,.10) 0%,rgba(7,20,33,.97) 42%,rgba(5,14,24,.99) 100%);border:1px solid #42A5FF;border-radius:22px;padding:36px 32px;box-shadow:inset 0 1px 0 rgba(130,195,255,.28),0 18px 42px rgba(3,12,22,.62),0 0 30px rgba(0,119,255,.24);">
          <tr>
            <td class="header-logo-cell" align="center" style="padding-bottom:28px;">
              <img class="logo-light" src="${LOGO_URL}" alt="OnListClub" width="240" height="102" style="display:block;width:240px;max-width:78%;height:102px;border:0;margin:0 auto;">
            </td>
          </tr>
          <tr>
            <td style="padding-bottom:14px;">
              <table class="heading-status-row" width="100%" cellpadding="0" cellspacing="0" border="0" role="presentation" style="width:100%;table-layout:fixed;">
                <tr>
                  <td class="heading-cell" width="48%" align="left" valign="middle">
                    <h1 class="text-title" style="margin:0;font-family:'Helvetica Neue',Helvetica,Arial,sans-serif;font-size:26px;line-height:1.25;font-weight:700;">Conferma la cancellazione.</h1>
                  </td>
                  <td class="status-cell" width="52%" align="right" valign="middle">
                    <table align="right" cellpadding="0" cellspacing="0" border="0" role="presentation" style="width:auto;margin:0 0 0 auto;">
                      <tr>
                        <td class="badge-bg" valign="middle" style="border:1px solid rgba(130,195,255,.42);border-radius:26px;padding:6px 9px;background-color:#0B1B2D;background-image:linear-gradient(150deg,rgba(0,119,255,.14),rgba(10,27,45,.96));box-shadow:inset 0 1px 0 rgba(130,195,255,.3);text-align:center;vertical-align:middle;">
                          <span class="badge-text" style="font-family:'Helvetica Neue',Helvetica,Arial,sans-serif;font-size:16px;font-weight:700;line-height:1.25;color:#F2F7FC;">Cancellazione account</span>
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
              <p class="text-body" style="margin:0;font-family:'Helvetica Neue',Helvetica,Arial,sans-serif;font-size:15px;line-height:1.6;">
                ${saluto}chiesto di eliminare definitivamente il tuo account OnListClub.
              </p>
            </td>
          </tr>
          <tr>
            <td align="left" style="padding-bottom:20px;">
              <p class="text-body" style="margin:0;font-family:'Helvetica Neue',Helvetica,Arial,sans-serif;font-size:15px;line-height:1.6;">
                Apri la pagina qui sotto per confermare. Il link vale <strong class="text-bold-name" style="color:#F2F7FC;font-weight:700;">${TOKEN_VALIDITA_MINUTI} minuti</strong> e puo' essere usato una sola volta.
              </p>
            </td>
          </tr>
          <tr>
            <td style="padding-bottom:20px;">
              <table width="100%" cellpadding="0" cellspacing="0" border="0"><tr>
                <td align="center" class="cta-cell" style="background:#0077FF;background-color:#0077FF;background-image:linear-gradient(135deg,#005CC8 0%,#0049A3 52%,#00377C 100%);border-radius:999px;box-shadow:inset 0 1px 0 rgba(255,255,255,.22),0 0 8px rgba(255,255,255,.28),0 0 18px rgba(255,255,255,.16),0 8px 20px rgba(255,255,255,.10);">
                  <a href="${link}" class="cta-link" style="display:block;min-height:48px;box-sizing:border-box;padding:14px 20px;font-family:'Helvetica Neue',Helvetica,Arial,sans-serif;font-size:15px;line-height:1.4;font-weight:600;letter-spacing:.3px;text-decoration:none;color:#FFFFFF;text-align:center;" target="_blank">Elimina il mio account</a>
                </td>
              </tr></table>
            </td>
          </tr>
          <tr>
            <td align="left" style="padding-bottom:12px;">
              <p class="text-muted" style="margin:0;font-family:'Helvetica Neue',Helvetica,Arial,sans-serif;font-size:13px;line-height:1.6;color:#F2F7FC;opacity:0.85;">
                L'operazione e' definitiva. I tuoi dati personali verranno rimossi e l'account non sara' recuperabile.
              </p>
            </td>
          </tr>
          <tr>
            <td align="left" style="padding-bottom:28px;">
              <p class="text-muted" style="margin:0;font-family:'Helvetica Neue',Helvetica,Arial,sans-serif;font-size:13px;line-height:1.6;color:#F2F7FC;opacity:0.85;">
                Non hai richiesto tu la cancellazione? Ignora questa email: senza la conferma non succede nulla.
              </p>
            </td>
          </tr>
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
