// Edge Function: confirm-account-deletion
//
// Secondo e ultimo passo della cancellazione account. La chiama la pagina
// https://www.onlistclub.com/auth/delete-account con il token arrivato per
// email. Da qui in poi non si torna indietro.
//
// Perché non serve un JWT utente: chi apre il link dall'email non è loggato nel
// browser. L'autorizzazione è il token stesso (monouso, a scadenza, provato dal
// possesso della casella di posta), più una seconda prova d'identità:
//   - chi ha una password la digita;
//   - chi è entrato solo con Apple/Google una password non ce l'ha, quindi
//     ricopia la frase di conferma.
// La function resta comunque dietro verify_jwt: la pagina la invoca con la
// anon key, che Supabase accetta come JWT valido. Non serve deployarla con
// --no-verify-jwt.
//
// Input JSON:
//   { "token": "...", "check": true }            // la pagina chiede solo che
//                                                // campo mostrare: NON cancella
//                                                // e NON consuma il token
//   { "token": "...", "password": "..." }        // account con password
//   { "token": "...", "conferma": "Si, ..." }    // account solo social
//
// Output: { ok: true } oppure { ok: false, error: "<codice>" }
//   in modalità check: { ok: true, haPassword: bool, email: "..." }
//   invalid_token | expired_token | invalid_password | invalid_conferma

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders } from "../_shared/cors.ts";

const FRASE_CONFERMA = "Si, voglio eliminare definitivamente l'account";

async function sha256Hex(input: string): Promise<string> {
  const bytes = new TextEncoder().encode(input);
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return Array.from(new Uint8Array(digest))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

/// Confronto indulgente sulla forma, rigido sul contenuto: l'utente sta
/// ricopiando a mano una frase lunga. Ignora maiuscole, spazi doppi, accenti
/// (Si/Sì) e apostrofo tipografico, ma le parole devono esserci tutte.
function normalizza(s: string): string {
  return s
    .trim()
    .toLowerCase()
    .normalize("NFD")
    .replace(/[̀-ͯ]/g, "") // via gli accenti: "Si" accentato -> "Si"
    .replace(/[‘’`]/g, "'") // apostrofo tipografico → '
    .replace(/\s+/g, " ");
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

    const payload = await req.json().catch(() => null);
    const token = payload?.token?.toString() ?? "";
    if (!token) return json({ ok: false, error: "invalid_token" }, 400);

    const admin = createClient(supabaseUrl, serviceKey);

    // ── Token ────────────────────────────────────────────────────────────────
    const tokenHash = await sha256Hex(token);
    const { data: richiesta, error: selErr } = await admin
      .from("richieste_cancellazione")
      .select("id, id_utente, scadenza, usata_il")
      .eq("token_hash", tokenHash)
      .maybeSingle();

    if (selErr) {
      console.error("[confirm-account-deletion] select:", selErr);
      return json({ ok: false, error: "db_error" }, 500);
    }
    // Token inesistente e token già consumato danno lo stesso errore: non
    // raccontiamo a un curioso se un link è "esistito".
    if (!richiesta || richiesta.usata_il) {
      return json({ ok: false, error: "invalid_token" }, 400);
    }
    if (new Date(richiesta.scadenza).getTime() < Date.now()) {
      return json({ ok: false, error: "expired_token" }, 400);
    }

    // ── Identità e secondo fattore ───────────────────────────────────────────
    const { data: userRes, error: getErr } = await admin.auth.admin
      .getUserById(richiesta.id_utente);
    if (getErr || !userRes?.user) {
      console.error("[confirm-account-deletion] getUserById:", getErr);
      return json({ ok: false, error: "invalid_token" }, 400);
    }
    const user = userRes.user;

    // L'identity "email" esiste solo se l'account ha davvero una password.
    // Chi è entrato con Apple/Google ha solo quelle identity.
    const haPassword = (user.identities ?? []).some((i) => i.provider === "email");

    // Modalità check: la pagina deve sapere se chiedere la password o la frase.
    // Si ferma qui — token intatto, nessun dato toccato.
    if (payload?.check === true) {
      return json({ ok: true, haPassword, email: user.email });
    }

    if (haPassword) {
      const password = payload?.password?.toString() ?? "";
      if (!password) return json({ ok: false, error: "invalid_password" }, 400);

      // signInWithPassword su un client anon: l'unico modo di verificare la
      // password senza conoscerla. La sessione che ne esce non ci serve.
      const asAnon = createClient(supabaseUrl, anonKey);
      const { error: pwdErr } = await asAnon.auth.signInWithPassword({
        email: user.email!,
        password,
      });
      if (pwdErr) return json({ ok: false, error: "invalid_password" }, 400);
      await asAnon.auth.signOut().catch(() => {});
    } else {
      const conferma = payload?.conferma?.toString() ?? "";
      if (normalizza(conferma) !== normalizza(FRASE_CONFERMA)) {
        return json({ ok: false, error: "invalid_conferma" }, 400);
      }
    }

    // ── Punto di non ritorno ─────────────────────────────────────────────────

    // Il token si brucia PRIMA del lavoro vero: se due click partono insieme,
    // il secondo non trova più una richiesta aperta.
    const { data: bruciata, error: updErr } = await admin
      .from("richieste_cancellazione")
      .update({ usata_il: new Date().toISOString() })
      .eq("id", richiesta.id)
      .is("usata_il", null)
      .select("id")
      .maybeSingle();
    if (updErr) {
      console.error("[confirm-account-deletion] update:", updErr);
      return json({ ok: false, error: "db_error" }, 500);
    }
    if (!bruciata) return json({ ok: false, error: "invalid_token" }, 400);

    // Tabelle applicative: una transazione sola (vedi migration
    // 2026-07-16_cancellazione_account.sql).
    const { error: rpcErr } = await admin.rpc("anonimizza_utente", {
      p_id_utente: richiesta.id_utente,
    });
    if (rpcErr) {
      console.error("[confirm-account-deletion] anonimizza_utente:", rpcErr);
      return json({ ok: false, error: "db_error" }, 500);
    }

    // auth.users per ultimo: se fallisse qui, i dati personali sono comunque
    // già spariti e l'account resta orfano ma vuoto — mai il contrario.
    const { error: delErr } = await admin.auth.admin.deleteUser(
      richiesta.id_utente,
    );
    if (delErr) {
      console.error("[confirm-account-deletion] deleteUser:", delErr);
      return json({ ok: false, error: "auth_error" }, 500);
    }

    console.log("[confirm-account-deletion] account eliminato");
    return json({ ok: true });
  } catch (e) {
    console.error("[confirm-account-deletion] errore:", e);
    return json({ ok: false, error: "unexpected" }, 500);
  }
});
