-- ============================================================
-- Migration: aggiunge nuovi club + prossime serate di test
-- Data: 2026-03-30
-- Idempotente: usa WHERE NOT EXISTS per evitare duplicati
-- ============================================================

-- ---- Nuovi club (inserisce solo se non esistono già per nome) ----

INSERT INTO locali (
    id, nome, indirizzo, id_citta,
    famosita, generi_musicali, foto_url,
    prezzo_indicativo, descrizione, lat, lng
)
SELECT
    gen_random_uuid(),
    'Cocoricò',
    'Via Covignano 260',
    (SELECT id_citta FROM citta WHERE nome_citta = 'Rimini' LIMIT 1),
    880,
    ARRAY['Trance', 'Techno', 'Progressive'],
    'https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?w=800&q=80',
    3,
    'Leggendaria discoteca della Riviera Romagnola. La piramide di vetro è il simbolo del clubbing italiano.',
    43.9997, 12.5867
WHERE NOT EXISTS (SELECT 1 FROM locali WHERE nome = 'Cocoricò');

INSERT INTO locali (
    id, nome, indirizzo, id_citta,
    famosita, generi_musicali, foto_url,
    prezzo_indicativo, descrizione, lat, lng
)
SELECT
    gen_random_uuid(),
    'The Club',
    'Via Giosuè Carducci 12',
    (SELECT id_citta FROM citta WHERE nome_citta = 'Milano' LIMIT 1),
    760,
    ARRAY['Hip Hop', 'R&B', 'Afrobeats'],
    'https://images.unsplash.com/photo-1524368535928-5b5e00ddc76b?w=800&q=80',
    3,
    'La destinazione milanese per gli amanti di hip hop, R&B e culture urbane.',
    45.4623, 9.1861
WHERE NOT EXISTS (SELECT 1 FROM locali WHERE nome = 'The Club');

INSERT INTO locali (
    id, nome, indirizzo, id_citta,
    famosita, generi_musicali, foto_url,
    prezzo_indicativo, descrizione, lat, lng
)
SELECT
    gen_random_uuid(),
    'Bobino Club',
    'Via Filippo Corridoni 8',
    (SELECT id_citta FROM citta WHERE nome_citta = 'Milano' LIMIT 1),
    710,
    ARRAY['Commerciale', 'Latin', 'Reggaeton'],
    'https://images.unsplash.com/photo-1429962714451-bb934ecdc4ec?w=800&q=80',
    2,
    'Atmosfera vivace con musica latina e commerciale. Ideale per una serata spensierata.',
    45.4610, 9.1789
WHERE NOT EXISTS (SELECT 1 FROM locali WHERE nome = 'Bobino Club');

INSERT INTO locali (
    id, nome, indirizzo, id_citta,
    famosita, generi_musicali, foto_url,
    prezzo_indicativo, descrizione, lat, lng
)
SELECT
    gen_random_uuid(),
    'NumberOne',
    'Via Giuseppe Mazzini 12',
    (SELECT id_citta FROM citta WHERE nome_citta = 'Milano' LIMIT 1),
    690,
    ARRAY['House', 'Commercial', 'Dance'],
    'https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=800&q=80',
    2,
    'Storico club milanese, tre sale e musica per tutti i gusti.',
    45.4583, 9.1943
WHERE NOT EXISTS (SELECT 1 FROM locali WHERE nome = 'NumberOne');

-- ============================================================
-- Serate — cerca i club per nome (robusto agli UUID reali)
-- ============================================================

-- Helper: nomi club come li trovi nel tuo DB.
-- Se il nome esatto differisce (es. "Amnesia Club" vs "Amnesia"),
-- modifica il filtro WHERE ILIKE di conseguenza.

-- ---- Amnesia ----
INSERT INTO eventi (
    id, club_id, nome, data,
    ora_apertura, ora_chiusura,
    ingressi_previsti, posti_prenotati,
    locandina_url, generi_musicali, stato, prezzo_ingresso
)
SELECT gen_random_uuid(),
       (SELECT id FROM locali WHERE nome ILIKE '%Amnesia%' LIMIT 1),
       v.nome, v.data, v.oa::time, v.oc::time, v.ip, v.pp, v.loc, v.generi, 'attivo', v.prezzo
FROM (VALUES
    ('Friday Madness',     '2026-04-03'::date, '23:00', '06:00', 400, 45,  'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=400&q=80', ARRAY['Techno','House']::text[],            15.00),
    ('Saturday Night Fever','2026-04-04'::date,'22:30', '06:00', 500, 210, 'https://images.unsplash.com/photo-1571266028243-e4733b0f0bb0?w=400&q=80', ARRAY['House','Commercial']::text[],       20.00),
    ('Amnesia Underground', '2026-04-10'::date,'23:00', '07:00', 300, 12,  NULL,                                                                        ARRAY['Tech House','Minimal']::text[],     18.00),
    ('La Notte Bianca',     '2026-04-11'::date,'22:00', '05:00', 600, 480, 'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=400&q=80', ARRAY['Commerciale','Pop']::text[],         25.00),
    ('Trance Night',        '2026-04-17'::date,'23:00', '07:00', 350, 0,   NULL,                                                                        ARRAY['Trance','Progressive']::text[],     15.00),
    ('House Nation',        '2026-04-18'::date,'22:30', '06:00', 450, 90,  'https://images.unsplash.com/photo-1545128485-c400e7702796?w=400&q=80', ARRAY['House','Deep House']::text[],       20.00)
) AS v(nome, data, oa, oc, ip, pp, loc, generi, prezzo)
WHERE (SELECT id FROM locali WHERE nome ILIKE '%Amnesia%' LIMIT 1) IS NOT NULL
  AND NOT EXISTS (
      SELECT 1 FROM eventi e
      WHERE e.club_id = (SELECT id FROM locali WHERE nome ILIKE '%Amnesia%' LIMIT 1)
        AND e.nome = v.nome
        AND e.data = v.data
  );

-- ---- Volt ----
INSERT INTO eventi (
    id, club_id, nome, data,
    ora_apertura, ora_chiusura,
    ingressi_previsti, posti_prenotati,
    locandina_url, generi_musicali, stato, prezzo_ingresso
)
SELECT gen_random_uuid(),
       (SELECT id FROM locali WHERE nome ILIKE '%Volt%' LIMIT 1),
       v.nome, v.data, v.oa::time, v.oc::time, v.ip, v.pp, v.loc, v.generi, 'attivo', v.prezzo
FROM (VALUES
    ('Industrial Night', '2026-04-04'::date, '23:00', '06:00', 250, 30,  NULL, ARRAY['Industrial','EBM']::text[],        12.00),
    ('Raw Techno',       '2026-04-11'::date, '23:30', '07:00', 250, 180, NULL, ARRAY['Techno','Hard Techno']::text[],    15.00),
    ('Void Sessions',    '2026-04-18'::date, '23:00', '07:00', 250, 5,   NULL, ARRAY['Dark Techno','Noise']::text[],     12.00)
) AS v(nome, data, oa, oc, ip, pp, loc, generi, prezzo)
WHERE (SELECT id FROM locali WHERE nome ILIKE '%Volt%' LIMIT 1) IS NOT NULL
  AND NOT EXISTS (
      SELECT 1 FROM eventi e
      WHERE e.club_id = (SELECT id FROM locali WHERE nome ILIKE '%Volt%' LIMIT 1)
        AND e.nome = v.nome
        AND e.data = v.data
  );

-- ---- Fabrique ----
INSERT INTO eventi (
    id, club_id, nome, data,
    ora_apertura, ora_chiusura,
    ingressi_previsti, posti_prenotati,
    locandina_url, generi_musicali, stato, prezzo_ingresso
)
SELECT gen_random_uuid(),
       (SELECT id FROM locali WHERE nome ILIKE '%Fabrique%' LIMIT 1),
       v.nome, v.data, v.oa::time, v.oc::time, v.ip, v.pp, v.loc, v.generi, 'attivo', v.prezzo
FROM (VALUES
    ('Fabrique Open Air', '2026-04-05'::date, '14:00', '23:00', 0,    0,   'https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?w=400&q=80', ARRAY['House','Tech House']::text[],   20.00),
    ('Fabrique Saturday', '2026-04-12'::date, '23:00', '05:00', 1200, 340, NULL,                                                                        ARRAY['Commercial','Dance']::text[],   18.00),
    ('Spring Vibes',      '2026-04-19'::date, '23:00', '05:00', 1200, 200, NULL,                                                                        ARRAY['House','Afro House']::text[],   20.00)
) AS v(nome, data, oa, oc, ip, pp, loc, generi, prezzo)
WHERE (SELECT id FROM locali WHERE nome ILIKE '%Fabrique%' LIMIT 1) IS NOT NULL
  AND NOT EXISTS (
      SELECT 1 FROM eventi e
      WHERE e.club_id = (SELECT id FROM locali WHERE nome ILIKE '%Fabrique%' LIMIT 1)
        AND e.nome = v.nome
        AND e.data = v.data
  );

-- ---- Cocoricò (appena inserito sopra) ----
INSERT INTO eventi (
    id, club_id, nome, data,
    ora_apertura, ora_chiusura,
    ingressi_previsti, posti_prenotati,
    locandina_url, generi_musicali, stato, prezzo_ingresso
)
SELECT gen_random_uuid(),
       (SELECT id FROM locali WHERE nome = 'Cocoricò' LIMIT 1),
       v.nome, v.data, v.oa::time, v.oc::time, v.ip, v.pp, v.loc, v.generi, 'attivo', v.prezzo
FROM (VALUES
    ('Opening Season 2026',      '2026-04-04'::date, '22:00', '06:00', 3000, 1200, 'https://images.unsplash.com/photo-1524368535928-5b5e00ddc76b?w=400&q=80', ARRAY['Trance','Progressive']::text[],          25.00),
    ('Pyramid of Sound',         '2026-04-11'::date, '23:00', '07:00', 3000, 450,  NULL,                                                                        ARRAY['Techno','Progressive Techno']::text[],   20.00),
    ('La Primavera del Trance',  '2026-04-25'::date, '22:00', '07:00', 3000, 200,  NULL,                                                                        ARRAY['Trance','Uplifting Trance']::text[],     22.00)
) AS v(nome, data, oa, oc, ip, pp, loc, generi, prezzo)
WHERE (SELECT id FROM locali WHERE nome = 'Cocoricò' LIMIT 1) IS NOT NULL
  AND NOT EXISTS (
      SELECT 1 FROM eventi e
      WHERE e.club_id = (SELECT id FROM locali WHERE nome = 'Cocoricò' LIMIT 1)
        AND e.nome = v.nome
        AND e.data = v.data
  );
