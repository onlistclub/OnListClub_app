// Edge Function: send-sms
//
// Invia un SMS transazionale tramite l'API Brevo (ex Sendinblue).
// Nota importante: Supabase Auth NON supporta Brevo come provider SMS nativo
// (accetta solo Twilio/Vonage/MessageBird/Textlocal), quindi gli SMS passano
// per forza da questa function. Adatta a SMS informativi (promemoria serata,
// conferma prenotazione). Per OTP servirebbe logica di generazione/verifica
// codice lato server (non inclusa qui).
//
// Sicurezza: la BREVO_API_KEY vive SOLO nei secrets della function. Protetta
// da verify_jwt (default Supabase).
//
// Input JSON:
//   {
//     "recipient": "+393331234567",   // obbligatorio (E.164, con o senza +)
//     "content": "La tua serata...",  // obbligatorio (testo SMS)
//     "sender": "OnList"              // opzionale (alfanumerico, max 11 char)
//   }
//
// Output: { ok: true, messageId: "...", remainingCredits: N }
//         oppure { ok: false, error: "..." }

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { corsHeaders } from "../_shared/cors.ts";

const BREVO_SMS_URL = "https://api.brevo.com/v3/transactionalSMS/sms";

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
    const apiKey = Deno.env.get("BREVO_API_KEY");
    if (!apiKey) {
      console.error("[send-sms] BREVO_API_KEY non configurata");
      return json({ ok: false, error: "missing_api_key" }, 500);
    }

    // Mittente alfanumerico di default (registrabile su Brevo, max 11 char).
    const defaultSender = Deno.env.get("BREVO_SMS_SENDER") ?? "OnList";

    const payload = await req.json().catch(() => null);
    if (!payload) {
      return json({ ok: false, error: "invalid_json" }, 400);
    }

    const { recipient, content, sender } = payload;

    if (!recipient || !content) {
      return json({ ok: false, error: "missing_recipient_or_content" }, 400);
    }

    // Brevo vuole il numero internazionale SENZA il "+" iniziale.
    // (es. "+393331234567" -> "393331234567")
    const normalizedRecipient = String(recipient)
      .replace(/\s+/g, "")
      .replace(/^\+/, "")
      .replace(/^00/, "");

    if (normalizedRecipient.length < 8) {
      return json({ ok: false, error: "invalid_recipient" }, 400);
    }

    const smsSender = (sender ?? defaultSender).slice(0, 11);

    const resp = await fetch(BREVO_SMS_URL, {
      method: "POST",
      headers: {
        "api-key": apiKey,
        "Content-Type": "application/json",
        accept: "application/json",
      },
      body: JSON.stringify({
        sender: smsSender,
        recipient: normalizedRecipient,
        content,
        type: "transactional",
      }),
    });

    const data = await resp.json().catch(() => ({}));

    if (!resp.ok) {
      console.error("[send-sms] Brevo error", resp.status, data);
      return json(
        { ok: false, error: data?.message ?? "brevo_error", status: resp.status },
        502,
      );
    }

    return json({
      ok: true,
      messageId: data?.messageId ?? null,
      remainingCredits: data?.remainingCredits ?? null,
    });
  } catch (e) {
    console.error("[send-sms] Unexpected error", e);
    return json({ ok: false, error: String(e) }, 500);
  }
});
