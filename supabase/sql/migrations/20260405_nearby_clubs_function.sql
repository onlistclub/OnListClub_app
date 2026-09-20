-- =============================================================================
-- Migration: funzione nearby_clubs(lat, lng, raggio_km)
-- Data: 2026-04-05
-- =============================================================================
-- Ritorna i locali ordinati per distanza dall'utente, filtrando per raggio.
-- Usa la formula Haversine via PostGIS (ST_DWithin + ST_Distance).
--
-- PREREQUISITI:
--   - Estensione PostGIS attiva su Supabase (già inclusa di default)
--   - Tabella `locali` con colonne `lat` (double precision) e `lng` (double precision)
--   - Tabella `citta` con colonne `lat` e `lng` per il fallback delle coordinate
--   - JOIN `locali.id_citta` → `citta.id_citta` già presente
--
-- NOTA: Supabase usa PostGIS automaticamente. Non serve abilitarla manualmente.
-- =============================================================================

-- ── Abilita PostGIS (idempotente, già presente su Supabase) ──────────────────
CREATE EXTENSION IF NOT EXISTS postgis;

-- =============================================================================
-- Funzione nearby_clubs
-- =============================================================================
-- Parametri:
--   user_lat    FLOAT  latitudine dell'utente
--   user_lng    FLOAT  longitudine dell'utente
--   raggio_km   FLOAT  raggio di ricerca in km (default 50)
--
-- Ritorna: colonne di `locali` + distanza_km calcolata, ordinate per distanza
-- =============================================================================

CREATE OR REPLACE FUNCTION nearby_clubs(
  user_lat   FLOAT,
  user_lng   FLOAT,
  raggio_km  FLOAT DEFAULT 50
)
RETURNS TABLE (
  id                UUID,
  nome              TEXT,
  indirizzo         TEXT,
  citta             TEXT,
  id_citta          UUID,
  logo_url          TEXT,
  foto_url          TEXT,
  famosita          INTEGER,
  generi_musicali   TEXT[],
  prezzo_indicativo SMALLINT,
  descrizione       TEXT,
  link_tripadvisor  TEXT,
  lat               DOUBLE PRECISION,
  lng               DOUBLE PRECISION,
  distanza_km       FLOAT
)
LANGUAGE sql
STABLE
AS $$
  SELECT
    l.id,
    l.nome,
    l.indirizzo,
    l.citta,
    l.id_citta,
    l.logo_url,
    l.foto_url,
    l.famosita,
    l.generi_musicali,
    l.prezzo_indicativo,
    l.descrizione,
    l.link_tripadvisor,
    -- Coordinate effettive usate per il calcolo:
    -- usa lat/lng del locale se presenti, altrimenti quelle della città (JOIN)
    COALESCE(l.lat, c.lat)          AS lat,
    COALESCE(l.lng, c.lng)          AS lng,
    -- Distanza in km con Haversine (ST_Distance su geography restituisce metri)
    ROUND(
      ST_Distance(
        ST_MakePoint(COALESCE(l.lng, c.lng), COALESCE(l.lat, c.lat))::geography,
        ST_MakePoint(user_lng, user_lat)::geography
      )::numeric / 1000,
      2
    )::FLOAT                        AS distanza_km
  FROM locali l
  LEFT JOIN citta c ON c.id_citta = l.id_citta
  WHERE
    -- Filtra solo locali con coordinate (proprie o della città)
    COALESCE(l.lat, c.lat) IS NOT NULL
    AND COALESCE(l.lng, c.lng) IS NOT NULL
    -- Filtro raggio con ST_DWithin (usa indice spaziale, molto performante)
    AND ST_DWithin(
      ST_MakePoint(COALESCE(l.lng, c.lng), COALESCE(l.lat, c.lat))::geography,
      ST_MakePoint(user_lng, user_lat)::geography,
      raggio_km * 1000  -- ST_DWithin usa metri
    )
  ORDER BY distanza_km ASC;
$$;

-- ── Commento sulla funzione ──────────────────────────────────────────────────
COMMENT ON FUNCTION nearby_clubs(FLOAT, FLOAT, FLOAT) IS
'Ritorna i locali entro raggio_km dall''utente (user_lat, user_lng),
ordinati per distanza crescente. Usa PostGIS Haversine via ST_Distance su geography.
Fallback automatico alle coordinate della città se il locale non ha lat/lng propri.';

-- ── Permessi: la funzione è pubblica (lettura anonima) ──────────────────────
GRANT EXECUTE ON FUNCTION nearby_clubs(FLOAT, FLOAT, FLOAT) TO anon, authenticated;

-- =============================================================================
-- Come chiamarla da Flutter (Supabase client)
-- =============================================================================
-- final result = await Supabase.instance.client
--     .rpc('nearby_clubs', params: {
--       'user_lat': 45.4654,
--       'user_lng': 9.1866,
--       'raggio_km': 30,
--     });
-- final locali = (result as List).map((m) => LocaleModel.fromMap(m)).toList();
-- =============================================================================

-- =============================================================================
-- Indice spaziale (OPZIONALE ma consigliato per performance con molti locali)
-- Crea un indice GIST sulle coordinate geografiche dei locali.
-- =============================================================================
-- Aggiunge colonna geography calcolata (solo se si vuole l'indice spaziale nativo):
--
-- ALTER TABLE locali ADD COLUMN IF NOT EXISTS geog GEOGRAPHY(Point, 4326)
--   GENERATED ALWAYS AS (
--     CASE WHEN lat IS NOT NULL AND lng IS NOT NULL
--          THEN ST_MakePoint(lng, lat)::geography
--          ELSE NULL END
--   ) STORED;
--
-- CREATE INDEX IF NOT EXISTS idx_locali_geog ON locali USING GIST (geog);
--
-- Con l'indice, la query scala a centinaia di migliaia di locali senza problemi.
-- Per l'MVP con <1000 locali, l'indice non è necessario.
