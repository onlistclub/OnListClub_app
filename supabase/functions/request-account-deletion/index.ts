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

// ── Design system email (allineato al sito, src/lib/email-templates.ts) ──────
// Stesso stile delle altre email transazionali di OnListClub: sfondo chiaro di
// default (fallback universale per i client che ignorano prefers-color-scheme),
// variante scura via @media per chi la supporta. Card in vetro, CTA gradiente blu.
// Colori come resa sRGB delle custom property oklch() del sito.
//
// LOGO: un solo file, il marchio ufficiale Onlist (bianco, bagliore viola sulla
// "i"), mai swappato tra chiaro/scuro. Cambia solo la piastra dietro al logo:
// in chiaro un riquadro grigio tenue (il logo bianco altrimenti sparirebbe sullo
// sfondo chiaro), in scuro trasparente (il logo sta già bene sul suo sfondo nativo).
const LOGO_URL = "https://www.onlistclub.com/email-logo.png"; // logo ufficiale (bianco)
const LOGO_PLATE_BG_LIGHT = "#8f95aa"; // riquadro grigio tenue, solo in modalità chiara
const LOGO_PLATE_BORDER_LIGHT = "#747a90";

const LIGHT = {
  bgOuter: "#eef1f8",
  card: "#ffffff",
  cardBorder: "#e1e5f0",
  heading: "#12131c",
  body: "#525b70",
  muted: "#727b90",
  badgeBg: "rgba(19,62,255,0.08)",
  badgeBorder: "rgba(19,62,255,0.28)",
  badgeText: "#1b3fd6",
  link: "#1b3fd6",
};
const DARK = {
  bgOuter: "#05050f",
  card: "#0d0f24",
  cardBorder: "#24304d",
  heading: "#f4f6fb",
  body: "#a9b3c6",
  muted: "#8b93a7",
  badgeBg: "rgba(19,62,255,0.16)",
  badgeBorder: "rgba(19,62,255,0.35)",
  badgeText: "#8fb4ff",
  link: "#8fb4ff",
};
const GRADIENT_FROM = "#133eff";
const GRADIENT_TO = "#0098ff";
const FONT_DISPLAY = "'Space Grotesk', Helvetica, Arial, sans-serif";
const FONT_SANS = "'Inter', Helvetica, Arial, sans-serif";

function escapeHtml(value: string): string {
  return value
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

function emailHtml(nome: string, link: string): string {
  const saluto = nome ? `Ciao ${escapeHtml(nome)}, ` : "";
  return `<!DOCTYPE html>
<html lang="it">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <meta name="color-scheme" content="light dark" />
    <meta name="supported-color-schemes" content="light dark" />
    <title>Conferma la cancellazione del tuo account</title>
    <style>
      body, .bg-outer { background-color: ${LIGHT.bgOuter}; }
      .card { background-color: ${LIGHT.card}; border-color: ${LIGHT.cardBorder} !important; }
      .text-heading { color: ${LIGHT.heading} !important; }
      .text-body { color: ${LIGHT.body} !important; }
      .text-muted { color: ${LIGHT.muted} !important; }
      .badge { background-color: ${LIGHT.badgeBg} !important; border-color: ${LIGHT.badgeBorder} !important; color: ${LIGHT.badgeText} !important; }
      .footer-link { color: ${LIGHT.link} !important; }
      .logo-plate { background-color: ${LOGO_PLATE_BG_LIGHT} !important; border-color: ${LOGO_PLATE_BORDER_LIGHT} !important; }

      @media (prefers-color-scheme: dark) {
        body, .bg-outer { background-color: ${DARK.bgOuter} !important; }
        .card { background-color: ${DARK.card} !important; border-color: ${DARK.cardBorder} !important; }
        .text-heading { color: ${DARK.heading} !important; }
        .text-body { color: ${DARK.body} !important; }
        .text-muted { color: ${DARK.muted} !important; }
        .badge { background-color: ${DARK.badgeBg} !important; border-color: ${DARK.badgeBorder} !important; color: ${DARK.badgeText} !important; }
        .footer-link { color: ${DARK.link} !important; }
        .logo-plate { background-color: transparent !important; border-color: transparent !important; }
      }
    </style>
  </head>
  <body class="bg-outer" style="margin:0;padding:0;background-color:${LIGHT.bgOuter};">
    <table role="presentation" width="100%" cellpadding="0" cellspacing="0" class="bg-outer" bgcolor="${LIGHT.bgOuter}" style="background-color:${LIGHT.bgOuter};padding:36px 16px;">
      <tr>
        <td align="center">
          <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:560px;">
            <tr>
              <td align="center" style="padding-bottom:28px;">
                <table role="presentation" cellpadding="0" cellspacing="0" style="margin:0 auto;">
                  <tr>
                    <td align="center" class="logo-plate" bgcolor="${LOGO_PLATE_BG_LIGHT}" style="background-color:${LOGO_PLATE_BG_LIGHT};border:1px solid ${LOGO_PLATE_BORDER_LIGHT};border-radius:20px;padding:20px 32px;">
                      <img src="${LOGO_URL}" alt="OnListClub" width="150" style="display:block;width:150px;height:auto;border:0;margin:0 auto;" />
                    </td>
                  </tr>
                </table>
              </td>
            </tr>
            <tr>
              <td class="card" bgcolor="${LIGHT.card}" style="background-color:${LIGHT.card};border:1px solid ${LIGHT.cardBorder};border-radius:24px;padding:36px 32px;">
                <table role="presentation" cellpadding="0" cellspacing="0" style="margin-bottom:20px;">
                  <tr>
                    <td class="badge" bgcolor="${LIGHT.badgeBg}" style="border-radius:999px;background-color:${LIGHT.badgeBg};border:1px solid ${LIGHT.badgeBorder};padding:6px 14px;font-family:${FONT_SANS};font-size:11px;letter-spacing:.08em;text-transform:uppercase;color:${LIGHT.badgeText};">
                      Cancellazione account
                    </td>
                  </tr>
                </table>
                <h1 class="text-heading" style="margin:0 0 14px;font-family:${FONT_DISPLAY};font-size:24px;line-height:1.25;color:${LIGHT.heading};letter-spacing:-0.02em;">
                  Vuoi eliminare il tuo account?
                </h1>
                <p class="text-body" style="margin:0 0 20px;font-family:${FONT_SANS};font-size:15px;line-height:1.6;color:${LIGHT.body};">
                  ${saluto}hai chiesto di eliminare definitivamente il tuo account OnListClub.
                </p>
                <p class="text-body" style="margin:0 0 28px;font-family:${FONT_SANS};font-size:15px;line-height:1.6;color:${LIGHT.body};">
                  Per completare, apri la pagina qui sotto e conferma. Il link vale <strong class="text-heading" style="color:${LIGHT.heading};">${TOKEN_VALIDITA_MINUTI} minuti</strong> e può essere usato una sola volta.
                </p>
                <table role="presentation" cellpadding="0" cellspacing="0">
                  <tr>
                    <td bgcolor="${GRADIENT_TO}" style="border-radius:999px;background-color:${GRADIENT_TO};background-image:linear-gradient(135deg, ${GRADIENT_FROM}, ${GRADIENT_TO});">
                      <a href="${link}" style="display:inline-block;padding:13px 28px;font-family:${FONT_SANS};font-size:14px;font-weight:600;color:#ffffff;text-decoration:none;">
                        Elimina il mio account →
                      </a>
                    </td>
                  </tr>
                </table>
                <p class="text-muted" style="margin:28px 0 0;font-family:${FONT_SANS};font-size:13px;line-height:1.6;color:${LIGHT.muted};">
                  L'operazione è definitiva: i tuoi dati personali verranno rimossi e non sarà possibile recuperare l'account.
                </p>
                <p class="text-muted" style="margin:12px 0 0;font-family:${FONT_SANS};font-size:13px;line-height:1.6;color:${LIGHT.muted};">
                  Se non sei stato tu, ignora questa email: senza la conferma non succede nulla.
                </p>
              </td>
            </tr>
            <tr>
              <td align="center" style="padding-top:28px;">
                <p class="text-body" style="margin:0 0 6px;font-family:${FONT_SANS};font-size:12px;color:${LIGHT.body};">
                  OnListClub — Il controllo del tuo locale, tutto in uno.
                </p>
                <p class="text-body" style="margin:0;font-family:${FONT_SANS};font-size:12px;color:${LIGHT.body};">
                  Hai domande? Scrivici a <a href="mailto:info@onlistclub.com" class="footer-link" style="color:${LIGHT.link};text-decoration:none;">info@onlistclub.com</a>
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
          `Hai chiesto di eliminare il tuo account Onlist Club.\n` +
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
