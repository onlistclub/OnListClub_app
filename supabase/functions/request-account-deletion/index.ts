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

// ── Design system email (shell ZUCC ufficiale) ───────────────────────────────
// Stesso layout di tutte le altre email OnListClub (docs/email_templates/*.html
// e messaging_service.dart): card trasparente su color:inherit del client,
// border viola, wordmark mail.png dentro plate #0a0a0a (non #000000 per non
// farsi invertire da iOS Mail dark mode), CTA in gradient viola/indigo.
// Tutto inline: nessuna dipendenza esterna oltre alle immagini su onlistclub.com.
const LOGO_URL = "https://www.onlistclub.com/mail.png";

function escapeHtml(value: string): string {
  return value
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

function emailHtml(nome: string, link: string): string {
  const saluto = nome
    ? `<strong class="text-bold-name" style="font-weight:700;">${escapeHtml(nome)}</strong>, hai `
    : `Hai `;
  return `<!DOCTYPE html>
<html lang="it" xmlns="http://www.w3.org/1999/xhtml" xmlns:v="urn:schemas-microsoft-com:vml" xmlns:o="urn:schemas-microsoft-com:office:office">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <meta name="color-scheme" content="light dark">
  <meta name="supported-color-schemes" content="light dark">
  <meta name="x-apple-disable-message-reformatting">
  <title>Conferma la cancellazione del tuo account</title>
  <!--[if mso]>
  <noscript><xml><o:OfficeDocumentSettings><o:PixelsPerInch>96</o:PixelsPerInch></o:OfficeDocumentSettings></xml></noscript>
  <![endif]-->
  <style>
    html,body{margin:0!important;padding:0!important;width:100%!important;min-width:100%!important;height:100%!important;-webkit-text-size-adjust:100%;-ms-text-size-adjust:100%;}
    body{background-color:transparent!important;color:inherit;}
    table,td{mso-table-lspace:0pt!important;mso-table-rspace:0pt!important;}
    img{border:0;height:auto;line-height:100%;outline:none;text-decoration:none;-ms-interpolation-mode:bicubic;}
    a{text-decoration:none;}
    .email-container{box-sizing:border-box!important;width:100%!important;max-width:560px!important;background-color:transparent!important;border:2px solid #A78BFA!important;border-radius:22px!important;padding:36px 32px!important;box-shadow:0 0 0 1px rgba(139,92,246,.10),0 0 22px rgba(139,92,246,.18),0 18px 42px rgba(47,34,77,.08)!important;}
    .logo-plate{background-color:#0a0a0a!important;background-image:linear-gradient(#0a0a0a,#0a0a0a)!important;border-radius:20px!important;}
    .logo-mark{display:block!important;width:200px!important;max-width:78%!important;height:auto!important;margin:0 auto!important;}
    .text-title,.text-body,.text-bold-name,.text-muted,.footer-text{color:inherit!important;}
    .footer-divider{border-top-color:rgba(127,111,150,.35)!important;}
    .footer-link{color:#7C3AED!important;}
    .cta-cell{background:#7C3AED!important;background-image:linear-gradient(135deg,#7C3AED 0%,#6366F1 52%,#4F46E5 100%)!important;border-radius:999px!important;box-shadow:0 8px 22px rgba(124,58,237,.22)!important;}
    .cta-link{display:block!important;min-height:48px!important;box-sizing:border-box!important;padding:14px 20px!important;color:#FFFFFF!important;}
    @media only screen and (max-width:600px){
      .outer-wrapper-cell{padding:20px 10px 36px 10px!important;}
      .email-container{max-width:100%!important;padding:26px 20px!important;border-radius:18px!important;}
      .logo-mark{width:170px!important;max-width:72%!important;}
      .text-title{font-size:24px!important;}
    }
    @media (prefers-color-scheme: dark){
      .email-container{border-color:#A78BFA!important;box-shadow:0 0 0 1px rgba(167,139,250,.12),0 0 24px rgba(139,92,246,.22),0 18px 44px rgba(0,0,0,.16)!important;}
    }
  </style>
</head>
<body style="background:transparent;margin:0;padding:0;width:100%;min-width:100%;font-family:'Helvetica Neue',Helvetica,Arial,sans-serif;">
  <span style="display:none;font-size:1px;color:transparent;line-height:1px;max-height:0px;max-width:0px;opacity:0;overflow:hidden;">
    Hai chiesto di cancellare il tuo account OnListClub. Conferma il link entro ${TOKEN_VALIDITA_MINUTI} minuti.
  </span>
  <table class="outer-wrapper" width="100%" height="100%" cellpadding="0" cellspacing="0" border="0" style="width:100%;min-width:100%;height:100%;table-layout:fixed;">
    <tr>
      <td align="center" valign="top" class="outer-wrapper-cell" style="padding:28px 16px 48px 16px;">
        <!--[if mso]><table align="center" width="560" style="width:560px;"><tr><td><![endif]-->
        <table class="email-container" width="100%" cellpadding="0" cellspacing="0" border="0" style="box-sizing:border-box;width:100%;max-width:560px;background-color:transparent;border:2px solid #A78BFA;border-radius:22px;padding:36px 32px;box-shadow:0 0 0 1px rgba(139,92,246,.12),0 0 22px rgba(139,92,246,.26),0 18px 42px rgba(47,34,77,.12);">
          <tr>
            <td align="center" style="padding-bottom:28px;">
              <table role="presentation" cellpadding="0" cellspacing="0" border="0" style="margin:0 auto;"><tr>
                <td class="logo-plate" align="center" bgcolor="#0a0a0a" style="background-color:#0a0a0a;background-image:linear-gradient(#0a0a0a,#0a0a0a);border-radius:20px;padding:22px 44px;">
                  <img class="logo-mark" src="${LOGO_URL}" alt="OnListClub" width="200" style="display:block;width:200px;max-width:78%;height:auto;border:0;margin:0 auto;">
                </td>
              </tr></table>
            </td>
          </tr>
          <tr>
            <td align="left" style="padding-bottom:18px;">
              <table cellpadding="0" cellspacing="0" border="0"><tr>
                <td style="border:1.5px solid rgba(124,58,237,0.35);border-radius:9999px;padding:6px 14px;">
                  <span style="font-family:'Helvetica Neue',Helvetica,Arial,sans-serif;font-size:11px;font-weight:700;letter-spacing:0.08em;text-transform:uppercase;color:#7C3AED;">Cancellazione account</span>
                </td>
              </tr></table>
            </td>
          </tr>
          <tr>
            <td align="left" style="padding-bottom:14px;">
              <h1 class="text-title" style="margin:0;font-family:'Helvetica Neue',Helvetica,Arial,sans-serif;font-size:26px;line-height:1.25;font-weight:700;">
                Conferma la cancellazione.
              </h1>
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
                Apri la pagina qui sotto per confermare. Il link vale <strong class="text-bold-name" style="font-weight:700;">${TOKEN_VALIDITA_MINUTI} minuti</strong> e puo' essere usato una sola volta.
              </p>
            </td>
          </tr>
          <tr>
            <td style="padding-bottom:20px;">
              <table width="100%" cellpadding="0" cellspacing="0" border="0"><tr>
                <td align="center" class="cta-cell" style="background:#7C3AED;background-color:#7C3AED;background-image:linear-gradient(135deg,#7C3AED 0%,#6366F1 52%,#4F46E5 100%);border-radius:999px;box-shadow:0 8px 22px rgba(124,58,237,.28);">
                  <a href="${link}" class="cta-link" style="display:block;min-height:48px;box-sizing:border-box;padding:14px 20px;font-family:'Helvetica Neue',Helvetica,Arial,sans-serif;font-size:15px;font-weight:600;text-decoration:none;color:#FFFFFF;text-align:center;" target="_blank">Elimina il mio account</a>
                </td>
              </tr></table>
            </td>
          </tr>
          <tr>
            <td align="left" style="padding-bottom:12px;">
              <p class="text-muted" style="margin:0;font-family:'Helvetica Neue',Helvetica,Arial,sans-serif;font-size:13px;line-height:1.6;opacity:0.75;">
                L'operazione e' definitiva. I tuoi dati personali verranno rimossi e l'account non sara' recuperabile.
              </p>
            </td>
          </tr>
          <tr>
            <td align="left" style="padding-bottom:28px;">
              <p class="text-muted" style="margin:0;font-family:'Helvetica Neue',Helvetica,Arial,sans-serif;font-size:13px;line-height:1.6;opacity:0.75;">
                Non hai richiesto tu la cancellazione? Ignora questa email: senza la conferma non succede nulla.
              </p>
            </td>
          </tr>
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
