-- =============================================================================
-- SEED STAGING — OnListClub
-- Scopo: popolare il DB di staging con dati realistici per test e sviluppo.
-- Tabelle: locali (con GPS reali), eventi (date future), utenti di test.
-- Eseguire nel SQL Editor di Supabase Staging.
-- =============================================================================

-- UUID convention usata in questo seed:
--   locali:  c0000000-0000-0000-0000-00000000000{5..9}
--   eventi:  d0000000-0000-0000-0000-00000000000{5..c}

-- =============================================================================
-- 1. CITTÀ (se non già presenti nel DB)
-- =============================================================================

INSERT INTO citta (nome_citta, lat, lng)
SELECT v.nome, v.lat, v.lng
FROM (VALUES
  ('Roma',        41.9028,  12.4964),
  ('Rimini',      44.0594,  12.5683),
  ('Riccione',    44.0009,  12.6551),
  ('Gallipoli',   40.0566,  17.9929),
  ('Torino',      45.0703,   7.6869)
) AS v(nome, lat, lng)
WHERE NOT EXISTS (
  SELECT 1 FROM citta WHERE lower(nome_citta) = lower(v.nome)
);

-- =============================================================================
-- 2. LOCALI — club reali italiani con coordinate GPS precise
-- =============================================================================

INSERT INTO locali (
  id, nome, indirizzo, citta, id_citta,
  famosita, generi_musicali, foto_url,
  prezzo_indicativo, descrizione, lat, lng
) VALUES
  (
    'c0000000-0000-0000-0000-000000000005',
    'Cocoricò', 'Via Chieti 44', 'Riccione',
    (SELECT id_citta FROM citta WHERE lower(nome_citta) = 'riccione' LIMIT 1),
    1000, ARRAY['Techno','Trance','House'],
    'https://images.unsplash.com/photo-1571266028243-e4733b0f0bb0?w=800&q=80',
    3, 'La piramide della notte italiana — club leggendario sulla Riviera romagnola.',
    43.9967, 12.6664
  ),
  (
    'c0000000-0000-0000-0000-000000000006',
    'Praja', 'Via Galileo Galilei', 'Gallipoli',
    (SELECT id_citta FROM citta WHERE lower(nome_citta) = 'gallipoli' LIMIT 1),
    870, ARRAY['House','Afro','Commercial'],
    'https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?w=800&q=80',
    2, 'La discoteca estiva più famosa del Sud Italia, sulla spiaggia di Gallipoli.',
    40.0566, 17.9929
  ),
  (
    'c0000000-0000-0000-0000-000000000007',
    'Goa Club', 'Via Libetta 13', 'Roma',
    (SELECT id_citta FROM citta WHERE lower(nome_citta) = 'roma' LIMIT 1),
    810, ARRAY['Techno','Electronic'],
    'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=800&q=80',
    3, 'Il club techno di riferimento della Capitale, iconico nel quartiere Ostiense.',
    41.8490, 12.4670
  ),
  (
    'c0000000-0000-0000-0000-000000000008',
    'Altromondo Studios', 'Via Bruxelles 34', 'Rimini',
    (SELECT id_citta FROM citta WHERE lower(nome_citta) = 'rimini' LIMIT 1),
    760, ARRAY['Commercial','Hip Hop','EDM'],
    'https://images.unsplash.com/photo-1545128485-c400e7702796?w=800&q=80',
    3, 'Uno dei club più grandi d''Italia, punto di riferimento della Riviera romagnola.',
    44.0524, 12.5757
  ),
  (
    'c0000000-0000-0000-0000-000000000009',
    'Hiroshima Mon Amour', 'Via Carlo Bossoli 83', 'Torino',
    (SELECT id_citta FROM citta WHERE lower(nome_citta) = 'torino' LIMIT 1),
    680, ARRAY['Indie','Alternative','Electronic'],
    'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=800&q=80',
    2, 'Storico club e venue live di Torino, cuore della scena alternativa piemontese.',
    45.0411, 7.6633
  )
ON CONFLICT (id) DO UPDATE
  SET
    famosita        = EXCLUDED.famosita,
    generi_musicali = EXCLUDED.generi_musicali,
    descrizione     = EXCLUDED.descrizione,
    lat             = EXCLUDED.lat,
    lng             = EXCLUDED.lng;

-- =============================================================================
-- 3. EVENTI — serate con date future (dal giorno corrente in poi)
-- =============================================================================

INSERT INTO eventi (
  id, club_id, nome, descrizione, data,
  ora_apertura, ora_chiusura,
  ingressi_previsti, posti_prenotati,
  prezzo_ingresso, locandina_url,
  generi_musicali, stato
) VALUES

  -- Cocoricò — fra 2 giorni
  (
    'd0000000-0000-0000-0000-000000000005',
    'c0000000-0000-0000-0000-000000000005',
    'Pyramid Night', 'Una serata imperdibile nella piramide più famosa d''Italia.',
    CURRENT_DATE + INTERVAL '2 days',
    '22:30', '06:00', 2000, 650,
    22.00,
    'https://images.unsplash.com/photo-1571266028243-e4733b0f0bb0?w=400&q=80',
    ARRAY['Techno','Trance'], 'attivo'
  ),

  -- Cocoricò — fra 9 giorni
  (
    'd0000000-0000-0000-0000-000000000006',
    'c0000000-0000-0000-0000-000000000005',
    'Trance Nation', 'I migliori dj di trance europei in un''unica notte.',
    CURRENT_DATE + INTERVAL '9 days',
    '23:00', '06:00', 2000, 200,
    30.00, NULL,
    ARRAY['Trance','Progressive'], 'attivo'
  ),

  -- Praja — fra 3 giorni
  (
    'd0000000-0000-0000-0000-000000000007',
    'c0000000-0000-0000-0000-000000000006',
    'Afro Vibes', 'La notte afro più calda del Salento.',
    CURRENT_DATE + INTERVAL '3 days',
    '23:00', '05:00', 1500, 800,
    15.00,
    'https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?w=400&q=80',
    ARRAY['Afro','House'], 'attivo'
  ),

  -- Goa Club — fra 1 giorno (quasi sold out)
  (
    'd0000000-0000-0000-0000-000000000008',
    'c0000000-0000-0000-0000-000000000007',
    'Dark Matter', 'Techno brutale per le notti romane.',
    CURRENT_DATE + INTERVAL '1 day',
    '23:30', '05:30', 400, 380,
    18.00, NULL,
    ARRAY['Techno','Industrial'], 'attivo'
  ),

  -- Goa Club — fra 8 giorni
  (
    'd0000000-0000-0000-0000-000000000009',
    'c0000000-0000-0000-0000-000000000007',
    'Ostiense Rave', 'Una serata techno underground nel cuore di Roma.',
    CURRENT_DATE + INTERVAL '8 days',
    '23:00', '06:00', 400, 90,
    15.00, NULL,
    ARRAY['Techno','Minimal'], 'attivo'
  ),

  -- Altromondo — fra 5 giorni
  (
    'd0000000-0000-0000-0000-00000000000a',
    'c0000000-0000-0000-0000-000000000008',
    'Summer Explosion', 'Il party più grande della Riviera.',
    CURRENT_DATE + INTERVAL '5 days',
    '22:00', '05:00', 3000, 1200,
    20.00,
    'https://images.unsplash.com/photo-1545128485-c400e7702796?w=400&q=80',
    ARRAY['Commercial','EDM','Hip Hop'], 'attivo'
  ),

  -- Hiroshima Mon Amour — fra 4 giorni
  (
    'd0000000-0000-0000-0000-00000000000b',
    'c0000000-0000-0000-0000-000000000009',
    'Alternative Sessions', 'Indie, shoegaze e post-punk per una notte torinese.',
    CURRENT_DATE + INTERVAL '4 days',
    '22:30', '04:00', 500, 150,
    12.00, NULL,
    ARRAY['Indie','Alternative'], 'attivo'
  ),

  -- Hiroshima Mon Amour — fra 11 giorni (sold out simulato)
  (
    'd0000000-0000-0000-0000-00000000000c',
    'c0000000-0000-0000-0000-000000000009',
    'Electronic Night', 'Serata elettronica con dj set e live act.',
    CURRENT_DATE + INTERVAL '11 days',
    '22:00', '05:00', 500, 500,
    15.00, NULL,
    ARRAY['Electronic','Synth'], 'attivo'
  )

ON CONFLICT (id) DO UPDATE
  SET
    data              = EXCLUDED.data,
    ingressi_previsti = EXCLUDED.ingressi_previsti,
    posti_prenotati   = EXCLUDED.posti_prenotati,
    stato             = EXCLUDED.stato;

-- =============================================================================
-- 4. UTENTI DI TEST
-- =============================================================================
-- ISTRUZIONI:
-- 1. Creare gli utenti via Supabase Auth Dashboard (Authentication > Users > Add user)
--    oppure via: supabase.auth.admin.createUser({ email, password })
-- 2. Copiare i loro UUID e aggiornare gli INSERT sotto.
-- 3. Gli utenti creati da Auth vengono automaticamente inseriti in utenti
--    tramite il trigger "on_auth_user_created" (se configurato).
--
-- Credenziali di test suggerite:
--   mario.rossi@test.onlist.app    / TestPassword123!
--   giulia.bianchi@test.onlist.app / TestPassword123!
--   luca.verdi@test.onlist.app     / TestPassword123!  (minorenne: 2010-03-20)

-- INSERT INTO utenti (id, email, nome, cognome, data_nascita, maggiorenne)
-- VALUES
--   ('<<UUID_MARIO>>',  'mario.rossi@test.onlist.app',    'Mario',  'Rossi',   '1998-05-15', true),
--   ('<<UUID_GIULIA>>', 'giulia.bianchi@test.onlist.app', 'Giulia', 'Bianchi', '2000-11-03', true),
--   ('<<UUID_LUCA>>',   'luca.verdi@test.onlist.app',     'Luca',   'Verdi',   '2010-03-20', false)
-- ON CONFLICT (id) DO NOTHING;
