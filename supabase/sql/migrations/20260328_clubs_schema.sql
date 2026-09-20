-- =============================================================================
-- MIGRATION: Aggiunge campi a locali/eventi, crea preferiti
-- Basato sulla struttura reale del DB (tabelle: locali, eventi, utenti…)
-- PREREQUISITO: eseguire prima 20260328_location_data.sql (crea citta/provincia)
-- Idempotente: si può rieseguire senza danni.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 0. Città extra non presenti nella migration location_data
--    (hinterland milanese, aggiunto qui per coerenza)
-- ---------------------------------------------------------------------------
INSERT INTO citta (id_citta, nome_citta, id_provincia) VALUES
    ('b0000000-0000-0000-0000-000000000126', 'Sesto San Giovanni',
     (SELECT id_provincia FROM provincia WHERE sigla = 'MI'))
ON CONFLICT (id_citta) DO NOTHING;

-- ---------------------------------------------------------------------------
-- 1. Nuove colonne su `locali`
-- ---------------------------------------------------------------------------
ALTER TABLE locali
    ADD COLUMN IF NOT EXISTS id_citta          UUID       REFERENCES citta(id_citta),
    ADD COLUMN IF NOT EXISTS famosita          INTEGER    NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS generi_musicali   TEXT[]     NOT NULL DEFAULT '{}',
    ADD COLUMN IF NOT EXISTS foto_url          TEXT,           -- hero photo (≠ logo_url)
    ADD COLUMN IF NOT EXISTS prezzo_indicativo SMALLINT   NOT NULL DEFAULT 1,
    ADD COLUMN IF NOT EXISTS link_tripadvisor  TEXT,
    ADD COLUMN IF NOT EXISTS descrizione       TEXT,
    ADD COLUMN IF NOT EXISTS lat               DOUBLE PRECISION,
    ADD COLUMN IF NOT EXISTS lng               DOUBLE PRECISION;

-- id_citta: FK verso citta.id_citta (sostituisce il campo testo "citta")
-- famosita: 0-1000 (punteggio editoriale, gestito dagli admin)
-- prezzo_indicativo: 1 = €   2 = €€   3 = €€€   4 = €€€€

-- ---------------------------------------------------------------------------
-- 2. Nuove colonne su `eventi`
-- ---------------------------------------------------------------------------
ALTER TABLE eventi
    ADD COLUMN IF NOT EXISTS generi_musicali   TEXT[]     NOT NULL DEFAULT '{}',
    ADD COLUMN IF NOT EXISTS posti_prenotati   INTEGER    NOT NULL DEFAULT 0;

-- posti_prenotati: aggiornato manualmente o via trigger
-- ingressi_previsti (già esistente) = capienza totale (0 = illimitato)

-- ---------------------------------------------------------------------------
-- 3. Tabella `preferiti`
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS preferiti (
    id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID        NOT NULL REFERENCES utenti(id) ON DELETE CASCADE,
    locale_id   UUID        NOT NULL REFERENCES locali(id) ON DELETE CASCADE,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (user_id, locale_id)
);

ALTER TABLE preferiti ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "preferiti_own" ON preferiti;
CREATE POLICY "preferiti_own"
    ON preferiti FOR ALL
    USING (auth.uid() = user_id);

-- ---------------------------------------------------------------------------
-- 4. RLS su locali ed eventi (lettura pubblica)
-- ---------------------------------------------------------------------------
ALTER TABLE locali ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "locali_read_public" ON locali;
CREATE POLICY "locali_read_public"
    ON locali FOR SELECT
    USING (true);

ALTER TABLE eventi ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "eventi_read_public" ON eventi;
CREATE POLICY "eventi_read_public"
    ON eventi FOR SELECT
    USING (true);

-- ---------------------------------------------------------------------------
-- 5. Dati di test — 4 club
--    UUID formato: c0000000-0000-0000-0000-{numero a 12 cifre}
--    Milano       → b0000000-0000-0000-0000-000000000053
--    Sesto S.G.   → b0000000-0000-0000-0000-000000000126
-- ---------------------------------------------------------------------------
INSERT INTO locali (
    id, nome, indirizzo, id_citta,
    famosita, generi_musicali, foto_url,
    prezzo_indicativo, descrizione, lat, lng
) VALUES
    (
        'c0000000-0000-0000-0000-000000000001',
        'Amnesia Club',
        'Via Alfonso Gatto 4',
        'b0000000-0000-0000-0000-000000000053',  -- Milano
        950,
        ARRAY['Trap', 'Techno House'],
        'https://images.unsplash.com/photo-1545128485-c400e7702796?w=800&q=80',
        4,
        'Uno dei club più iconici di Milano, famoso per le notti techno e trap.',
        45.4654, 9.1866
    ),
    (
        'c0000000-0000-0000-0000-000000000002',
        'Volt Club',
        'Via Lavoratori Autobianchi 1',
        'b0000000-0000-0000-0000-000000000126',  -- Sesto San Giovanni
        820,
        ARRAY['Techno', 'Industrial'],
        'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=800&q=80',
        3,
        'Club underground dedicato alla musica techno industriale.',
        45.5358, 9.2364
    ),
    (
        'c0000000-0000-0000-0000-000000000003',
        'Fabrique',
        'Via Fantoli 9',
        'b0000000-0000-0000-0000-000000000053',  -- Milano
        780,
        ARRAY['House', 'Commercial'],
        'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=800&q=80',
        3,
        'Grande venue per concerti e serate clubbing a Milano Est.',
        45.4512, 9.2301
    ),
    (
        'c0000000-0000-0000-0000-000000000004',
        'Plastic',
        'Viale Umbria 120',
        'b0000000-0000-0000-0000-000000000053',  -- Milano
        700,
        ARRAY['Electro', 'Indie', 'New Wave'],
        'https://images.unsplash.com/photo-1571266028243-e4733b0f0bb0?w=800&q=80',
        2,
        'Storico club milanese, punto di riferimento per la scena alternative.',
        45.4507, 9.2189
    )
ON CONFLICT (id) DO NOTHING;

-- ---------------------------------------------------------------------------
-- 6. Serate di stasera per i 4 club
-- ---------------------------------------------------------------------------
INSERT INTO eventi (
    id, club_id, nome, data,
    ora_apertura, ora_chiusura,
    ingressi_previsti, posti_prenotati,
    locandina_url, generi_musicali, stato
) VALUES
    -- Amnesia: quasi sold out → "Ultimi posti: 80"
    (
        'd0000000-0000-0000-0000-000000000001',
        'c0000000-0000-0000-0000-000000000001',
        'The Club', CURRENT_DATE,
        '23:00', '04:00', 500, 420,
        'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=400&q=80',
        ARRAY['Trap', 'Techno House'], 'attivo'
    ),
    -- Volt: sold out
    (
        'd0000000-0000-0000-0000-000000000002',
        'c0000000-0000-0000-0000-000000000002',
        'Nocturnal', CURRENT_DATE,
        '23:30', '05:00', 300, 300,
        NULL, ARRAY['Techno'], 'attivo'
    ),
    -- Fabrique: illimitato (ingressi_previsti = 0)
    (
        'd0000000-0000-0000-0000-000000000003',
        'c0000000-0000-0000-0000-000000000003',
        'Friday Fever', CURRENT_DATE,
        '23:00', '05:00', 0, 0,
        NULL, ARRAY['House', 'Commercial'], 'attivo'
    ),
    -- Plastic: posti normali
    (
        'd0000000-0000-0000-0000-000000000004',
        'c0000000-0000-0000-0000-000000000004',
        'Alternative Night', CURRENT_DATE,
        '22:30', '04:00', 200, 60,
        NULL, ARRAY['Indie', 'Electro'], 'attivo'
    )
ON CONFLICT (id) DO NOTHING;
