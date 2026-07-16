// Edge Function: send-email
//
// Invia un'email transazionale tramite l'API Brevo (ex Sendinblue).
// Usata per email NON di autenticazione (conferma ordine, QR di entrata,
// annullamento prevendita, ecc.). Le email di verifica/reset password partono
// invece da Supabase Auth, che usa Brevo come SMTP (configurato in dashboard).
//
// Sicurezza: la BREVO_API_KEY vive SOLO nei secrets della function, mai nel
// client né nel repo. La function è protetta da verify_jwt (default Supabase):
// solo chiamate con un JWT valido (utente loggato o service_role dal cron)
// possono invocarla.
//
// Input JSON:
//   {
//     "to": "mario@example.com",        // obbligatorio (string o string[])
//     "toName": "Mario Rossi",          // opzionale
//     "subject": "Conferma prevendita", // obbligatorio
//     "htmlContent": "<h1>...</h1>",    // obbligatorio (oppure templateId)
//     "textContent": "...",             // opzionale (fallback testo)
//     "templateId": 12,                 // opzionale (template Brevo)
//     "params": { "nome": "Mario" },    // opzionale (variabili template)
//     "replyTo": "info@onlist.club",    // opzionale
//     "senderEmail": "...",             // opzionale (override mittente)
//     "senderName": "..."               // opzionale (override mittente)
//   }
//
// Output: { ok: true, messageId: "..." } oppure { ok: false, error: "..." }

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { corsHeaders } from "../_shared/cors.ts";

const BREVO_API_URL = "https://api.brevo.com/v3/smtp/email";

serve(async (req) => {
  // Preflight CORS
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const json = (body: unknown, status = 200) =>
    new Response(JSON.stringify(body), {
      status,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });

  try {
    const apiKey = Deno.env.get("BREVO_API_KEY");
    if (!apiKey) {
      console.error("[send-email] BREVO_API_KEY non configurata");
      return json({ ok: false, error: "missing_api_key" }, 500);
    }

    // Mittente di default: deve essere un sender verificato su Brevo.
    const defaultSenderEmail =
      Deno.env.get("BREVO_SENDER_EMAIL") ?? "no-reply@onlist.club";
    const defaultSenderName =
      Deno.env.get("BREVO_SENDER_NAME") ?? "Onlist Club";

    const payload = await req.json().catch(() => null);
    if (!payload) {
      return json({ ok: false, error: "invalid_json" }, 400);
    }

    const {
      to,
      toName,
      subject,
      htmlContent,
      textContent,
      templateId,
      params,
      replyTo,
      senderEmail,
      senderName,
    } = payload;

    // Validazione minima
    if (!to) {
      return json({ ok: false, error: "missing_recipient" }, 400);
    }
    if (!templateId && (!subject || !htmlContent)) {
      return json(
        { ok: false, error: "missing_subject_or_content" },
        400,
      );
    }

    // Normalizza i destinatari: accetta string singola o array di string.
    const recipients = (Array.isArray(to) ? to : [to]).map(
      (email: string) => ({
        email,
        ...(toName && !Array.isArray(to) ? { name: toName } : {}),
      }),
    );

    const brevoBody: Record<string, unknown> = {
      sender: {
        email: senderEmail ?? defaultSenderEmail,
        name: senderName ?? defaultSenderName,
      },
      to: recipients,
    };

    if (templateId) {
      brevoBody.templateId = templateId;
      if (params) brevoBody.params = params;
    } else {
      brevoBody.subject = subject;
      brevoBody.htmlContent = htmlContent;
      if (textContent) brevoBody.textContent = textContent;
    }
    if (replyTo) brevoBody.replyTo = { email: replyTo };

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
      console.error("[send-email] Brevo error", resp.status, data);
      return json(
        { ok: false, error: data?.message ?? "brevo_error", status: resp.status },
        502,
      );
    }

    return json({ ok: true, messageId: data?.messageId ?? null });
  } catch (e) {
    console.error("[send-email] Unexpected error", e);
    return json({ ok: false, error: String(e) }, 500);
  }
});
