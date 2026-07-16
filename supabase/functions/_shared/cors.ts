// Header CORS condivisi dalle Edge Functions.
//
// L'app mobile (Flutter) invoca le function via `functions.invoke`, ma teniamo
// gli header permissivi per consentire anche test da browser/curl in dev.
export const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
