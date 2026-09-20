-- =============================================================================
-- SEED: Aggiornamento Club Aosta Underground + Evento di test
-- =============================================================================

-- 1. Aggiorna il locale esistente per avere i dati corretti
UPDATE locali 
SET 
    generi_musicali = ARRAY['Techno', 'House', 'Hip Hop'],
    prezzo_indicativo = 1,
    descrizione = 'Club underground nel cuore di Aosta, specializzato in serate techno e house.',
    famosita = 650,
    lat = 45.7376,
    lng = 7.3210
WHERE id = 'ad3fc726-a623-4c3a-b472-e7a0e18b00c2';

-- 2. Elimina vecchi eventi di test per questo club (evita duplicati se lo lanci più volte)
DELETE FROM eventi WHERE club_id = 'ad3fc726-a623-4c3a-b472-e7a0e18b00c2';

-- 3. Inserisci Evento di test per stasera
INSERT INTO eventi (
    id, club_id, nome, inizio_evento, fine_evento,
    ingressi_previsti, posti_prenotati,
    locandina_url, generi_musicali, stato
) VALUES (
    'aa111111-1111-1111-1111-111111111111',
    'ad3fc726-a623-4c3a-b472-e7a0e18b00c2',
    'Underground Night',
    (CURRENT_DATE + interval '23 hours'),
    (CURRENT_DATE + interval '1 day 5 hours'),
    200, 0,
    NULL,
    ARRAY['Techno', 'House'],
    'attivo'
);

-- 4. Inserisci Prevendite per l'evento
INSERT INTO prevendite (
    id_prevendita, id_evento, tipo, prezzo, descrizione,
    validita, stock
) VALUES
    (
        'bb111111-1111-1111-1111-111111111111',
        'aa111111-1111-1111-1111-111111111111',
        'Normale', 10,
        '+ 2 drink omaggio',
        'Entrata valida per questo ticket entro le 00:00 am',
        100
    ),
    (
        'bb222222-2222-2222-2222-222222222222',
        'aa111111-1111-1111-1111-111111111111',
        'VIP', 25,
        '+ 2 drink omaggio\n+ Salta fila\n+ Guardaroba omaggio',
        'Entrata valida per questo ticket entro le 00:00 am',
        30
    );

-- 5. Inserisci Tavoli
INSERT INTO tavoli (
    id_tavolo, id_locale, nome_tavolo, capacita, prezzo_minimo
) VALUES
    ('cc111111-1111-1111-1111-111111111111', 'ad3fc726-a623-4c3a-b472-e7a0e18b00c2', 'A1', 8, 150),
    ('cc222222-2222-2222-2222-222222222222', 'ad3fc726-a623-4c3a-b472-e7a0e18b00c2', 'A2', 10, 200),
    ('cc333333-3333-3333-3333-333333333333', 'ad3fc726-a623-4c3a-b472-e7a0e18b00c2', 'B1', 6, 120),
    ('cc444444-4444-4444-4444-444444444444', 'ad3fc726-a623-4c3a-b472-e7a0e18b00c2', 'VIP1', 12, 350)
ON CONFLICT (id_tavolo) DO NOTHING;

