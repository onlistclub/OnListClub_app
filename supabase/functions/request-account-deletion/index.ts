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

function emailHtml(nome: string, link: string): string {
  // Palette e font dal design system (CLAUDE.md §2). Stili inline: i client
  // di posta ignorano quasi sempre il <style> in head.
  return `
<div style="margin:0;padding:32px 16px;background:#000000;font-family:Helvetica,'Helvetica Neue',Arial,sans-serif;">
  <div style="max-width:520px;margin:0 auto;background:linear-gradient(180deg,#000000 0%,#060037 100%);border-radius:10px;padding:32px;">
    <h1 style="margin:0 0 24px;color:#FFFFFF;font-size:24px;font-weight:700;">Vuoi eliminare il tuo account?</h1>
    <p style="margin:0 0 16px;color:#FFFFFF;font-size:16px;line-height:24px;">
      Ciao ${nome}, hai chiesto di eliminare definitivamente il tuo account Onlist Club.
    </p>
    <p style="margin:0 0 24px;color:#FFFFFF;font-size:16px;line-height:24px;">
      Per completare, apri la pagina qui sotto e conferma. Il link vale
      ${TOKEN_VALIDITA_MINUTI} minuti e puo essere usato una sola volta.
    </p>
    <a href="${link}" style="display:inline-block;background:#1E00FF;color:#FFFFFF;text-decoration:none;font-size:16px;font-weight:700;padding:14px 28px;border-radius:7px;">
      ELIMINA IL MIO ACCOUNT
    </a>
    <p style="margin:24px 0 0;color:#8E8E93;font-size:14px;line-height:20px;">
      L'operazione e definitiva: i tuoi dati personali verranno rimossi e non
      sara possibile recuperare l'account.
    </p>
    <p style="margin:16px 0 0;color:#8E8E93;font-size:14px;line-height:20px;">
      Se non sei stato tu, ignora questa email: senza la conferma non succede nulla.
    </p>
  </div>
</div>`.trim();
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
