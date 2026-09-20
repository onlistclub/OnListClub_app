-- =============================================================================
-- MIGRATION: Location data (province, città) + lat/lng su locale
-- Eseguire nel SQL editor di Supabase.
-- Idempotente: si può rieseguire senza danni.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. Crea tabelle se non esistono
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS provincia (
    id_provincia UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sigla        VARCHAR(3)  UNIQUE NOT NULL,
    nome_provincia TEXT       NOT NULL
);

CREATE TABLE IF NOT EXISTS citta (
    id_citta     UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nome_citta   TEXT        NOT NULL,
    id_provincia UUID        REFERENCES provincia(id_provincia)
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_citta_unique
    ON citta (nome_citta, id_provincia);

CREATE INDEX IF NOT EXISTS idx_citta_nome
    ON citta (nome_citta text_pattern_ops); -- ottimizza ILIKE 'x%'

CREATE TABLE IF NOT EXISTS cap (
    id_cap       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    cap_valore   VARCHAR(5)  NOT NULL,
    id_citta     UUID        REFERENCES citta(id_citta)
);

-- ---------------------------------------------------------------------------
-- 2. Aggiunge lat/lng a locale (per ricerca geografica futura)
-- ---------------------------------------------------------------------------
ALTER TABLE locali
    ADD COLUMN IF NOT EXISTS lat DOUBLE PRECISION,
    ADD COLUMN IF NOT EXISTS lng DOUBLE PRECISION;

-- ---------------------------------------------------------------------------
-- 3. Province italiane (tutte e 107)
--    UUID formato: a0000000-0000-0000-0000-{numero a 12 cifre}
-- ---------------------------------------------------------------------------
INSERT INTO provincia (id_provincia, sigla, nome_provincia) VALUES
    ('a0000000-0000-0000-0000-000000000001', 'AG', 'Agrigento'),
    ('a0000000-0000-0000-0000-000000000002', 'AL', 'Alessandria'),
    ('a0000000-0000-0000-0000-000000000003', 'AN', 'Ancona'),
    ('a0000000-0000-0000-0000-000000000004', 'AO', 'Aosta'),
    ('a0000000-0000-0000-0000-000000000005', 'AP', 'Ascoli Piceno'),
    ('a0000000-0000-0000-0000-000000000006', 'AQ', 'L''Aquila'),
    ('a0000000-0000-0000-0000-000000000007', 'AR', 'Arezzo'),
    ('a0000000-0000-0000-0000-000000000008', 'AT', 'Asti'),
    ('a0000000-0000-0000-0000-000000000009', 'AV', 'Avellino'),
    ('a0000000-0000-0000-0000-000000000010', 'BA', 'Bari'),
    ('a0000000-0000-0000-0000-000000000011', 'BG', 'Bergamo'),
    ('a0000000-0000-0000-0000-000000000012', 'BI', 'Biella'),
    ('a0000000-0000-0000-0000-000000000013', 'BL', 'Belluno'),
    ('a0000000-0000-0000-0000-000000000014', 'BN', 'Benevento'),
    ('a0000000-0000-0000-0000-000000000015', 'BO', 'Bologna'),
    ('a0000000-0000-0000-0000-000000000016', 'BR', 'Brindisi'),
    ('a0000000-0000-0000-0000-000000000017', 'BS', 'Brescia'),
    ('a0000000-0000-0000-0000-000000000018', 'BT', 'Barletta-Andria-Trani'),
    ('a0000000-0000-0000-0000-000000000019', 'BZ', 'Bolzano/Bozen'),
    ('a0000000-0000-0000-0000-000000000020', 'CA', 'Cagliari'),
    ('a0000000-0000-0000-0000-000000000021', 'CB', 'Campobasso'),
    ('a0000000-0000-0000-0000-000000000022', 'CE', 'Caserta'),
    ('a0000000-0000-0000-0000-000000000023', 'CH', 'Chieti'),
    ('a0000000-0000-0000-0000-000000000024', 'CL', 'Caltanissetta'),
    ('a0000000-0000-0000-0000-000000000025', 'CN', 'Cuneo'),
    ('a0000000-0000-0000-0000-000000000026', 'CO', 'Como'),
    ('a0000000-0000-0000-0000-000000000027', 'CR', 'Cremona'),
    ('a0000000-0000-0000-0000-000000000028', 'CS', 'Cosenza'),
    ('a0000000-0000-0000-0000-000000000029', 'CT', 'Catania'),
    ('a0000000-0000-0000-0000-000000000030', 'CZ', 'Catanzaro'),
    ('a0000000-0000-0000-0000-000000000031', 'EN', 'Enna'),
    ('a0000000-0000-0000-0000-000000000032', 'FC', 'Forlì-Cesena'),
    ('a0000000-0000-0000-0000-000000000033', 'FE', 'Ferrara'),
    ('a0000000-0000-0000-0000-000000000034', 'FG', 'Foggia'),
    ('a0000000-0000-0000-0000-000000000035', 'FI', 'Firenze'),
    ('a0000000-0000-0000-0000-000000000036', 'FM', 'Fermo'),
    ('a0000000-0000-0000-0000-000000000037', 'FR', 'Frosinone'),
    ('a0000000-0000-0000-0000-000000000038', 'GE', 'Genova'),
    ('a0000000-0000-0000-0000-000000000039', 'GO', 'Gorizia'),
    ('a0000000-0000-0000-0000-000000000040', 'GR', 'Grosseto'),
    ('a0000000-0000-0000-0000-000000000041', 'IM', 'Imperia'),
    ('a0000000-0000-0000-0000-000000000042', 'IS', 'Isernia'),
    ('a0000000-0000-0000-0000-000000000043', 'KR', 'Crotone'),
    ('a0000000-0000-0000-0000-000000000044', 'LC', 'Lecco'),
    ('a0000000-0000-0000-0000-000000000045', 'LE', 'Lecce'),
    ('a0000000-0000-0000-0000-000000000046', 'LI', 'Livorno'),
    ('a0000000-0000-0000-0000-000000000047', 'LO', 'Lodi'),
    ('a0000000-0000-0000-0000-000000000048', 'LT', 'Latina'),
    ('a0000000-0000-0000-0000-000000000049', 'LU', 'Lucca'),
    ('a0000000-0000-0000-0000-000000000050', 'MB', 'Monza e della Brianza'),
    ('a0000000-0000-0000-0000-000000000051', 'MC', 'Macerata'),
    ('a0000000-0000-0000-0000-000000000052', 'ME', 'Messina'),
    ('a0000000-0000-0000-0000-000000000053', 'MI', 'Milano'),
    ('a0000000-0000-0000-0000-000000000054', 'MN', 'Mantova'),
    ('a0000000-0000-0000-0000-000000000055', 'MO', 'Modena'),
    ('a0000000-0000-0000-0000-000000000056', 'MS', 'Massa-Carrara'),
    ('a0000000-0000-0000-0000-000000000057', 'MT', 'Matera'),
    ('a0000000-0000-0000-0000-000000000058', 'NA', 'Napoli'),
    ('a0000000-0000-0000-0000-000000000059', 'NO', 'Novara'),
    ('a0000000-0000-0000-0000-000000000060', 'NU', 'Nuoro'),
    ('a0000000-0000-0000-0000-000000000061', 'OR', 'Oristano'),
    ('a0000000-0000-0000-0000-000000000062', 'PA', 'Palermo'),
    ('a0000000-0000-0000-0000-000000000063', 'PC', 'Piacenza'),
    ('a0000000-0000-0000-0000-000000000064', 'PD', 'Padova'),
    ('a0000000-0000-0000-0000-000000000065', 'PE', 'Pescara'),
    ('a0000000-0000-0000-0000-000000000066', 'PG', 'Perugia'),
    ('a0000000-0000-0000-0000-000000000067', 'PI', 'Pisa'),
    ('a0000000-0000-0000-0000-000000000068', 'PN', 'Pordenone'),
    ('a0000000-0000-0000-0000-000000000069', 'PO', 'Prato'),
    ('a0000000-0000-0000-0000-000000000070', 'PR', 'Parma'),
    ('a0000000-0000-0000-0000-000000000071', 'PT', 'Pistoia'),
    ('a0000000-0000-0000-0000-000000000072', 'PU', 'Pesaro e Urbino'),
    ('a0000000-0000-0000-0000-000000000073', 'PV', 'Pavia'),
    ('a0000000-0000-0000-0000-000000000074', 'PZ', 'Potenza'),
    ('a0000000-0000-0000-0000-000000000075', 'RA', 'Ravenna'),
    ('a0000000-0000-0000-0000-000000000076', 'RC', 'Reggio Calabria'),
    ('a0000000-0000-0000-0000-000000000077', 'RE', 'Reggio Emilia'),
    ('a0000000-0000-0000-0000-000000000078', 'RG', 'Ragusa'),
    ('a0000000-0000-0000-0000-000000000079', 'RI', 'Rieti'),
    ('a0000000-0000-0000-0000-000000000080', 'RM', 'Roma'),
    ('a0000000-0000-0000-0000-000000000081', 'RN', 'Rimini'),
    ('a0000000-0000-0000-0000-000000000082', 'RO', 'Rovigo'),
    ('a0000000-0000-0000-0000-000000000083', 'SA', 'Salerno'),
    ('a0000000-0000-0000-0000-000000000084', 'SI', 'Siena'),
    ('a0000000-0000-0000-0000-000000000085', 'SO', 'Sondrio'),
    ('a0000000-0000-0000-0000-000000000086', 'SP', 'La Spezia'),
    ('a0000000-0000-0000-0000-000000000087', 'SR', 'Siracusa'),
    ('a0000000-0000-0000-0000-000000000088', 'SS', 'Sassari'),
    ('a0000000-0000-0000-0000-000000000089', 'SU', 'Sud Sardegna'),
    ('a0000000-0000-0000-0000-000000000090', 'SV', 'Savona'),
    ('a0000000-0000-0000-0000-000000000091', 'TA', 'Taranto'),
    ('a0000000-0000-0000-0000-000000000092', 'TE', 'Teramo'),
    ('a0000000-0000-0000-0000-000000000093', 'TN', 'Trento'),
    ('a0000000-0000-0000-0000-000000000094', 'TO', 'Torino'),
    ('a0000000-0000-0000-0000-000000000095', 'TP', 'Trapani'),
    ('a0000000-0000-0000-0000-000000000096', 'TR', 'Terni'),
    ('a0000000-0000-0000-0000-000000000097', 'TS', 'Trieste'),
    ('a0000000-0000-0000-0000-000000000098', 'TV', 'Treviso'),
    ('a0000000-0000-0000-0000-000000000099', 'UD', 'Udine'),
    ('a0000000-0000-0000-0000-000000000100', 'VA', 'Varese'),
    ('a0000000-0000-0000-0000-000000000101', 'VB', 'Verbano-Cusio-Ossola'),
    ('a0000000-0000-0000-0000-000000000102', 'VC', 'Vercelli'),
    ('a0000000-0000-0000-0000-000000000103', 'VE', 'Venezia'),
    ('a0000000-0000-0000-0000-000000000104', 'VI', 'Vicenza'),
    ('a0000000-0000-0000-0000-000000000105', 'VR', 'Verona'),
    ('a0000000-0000-0000-0000-000000000106', 'VT', 'Viterbo'),
    ('a0000000-0000-0000-0000-000000000107', 'VV', 'Vibo Valentia')
ON CONFLICT (id_provincia) DO NOTHING;

-- ---------------------------------------------------------------------------
-- 4. Città: tutti i 107 capoluoghi + principali città turistiche/nightlife
--    UUID formato: b0000000-0000-0000-0000-{numero a 12 cifre}
-- ---------------------------------------------------------------------------
INSERT INTO citta (id_citta, nome_citta, id_provincia) VALUES
    -- Capoluoghi (ordinati per sigla provincia) ----------------------
    ('b0000000-0000-0000-0000-000000000001', 'Agrigento',        (SELECT id_provincia FROM provincia WHERE sigla = 'AG')),
    ('b0000000-0000-0000-0000-000000000002', 'Alessandria',      (SELECT id_provincia FROM provincia WHERE sigla = 'AL')),
    ('b0000000-0000-0000-0000-000000000003', 'Ancona',           (SELECT id_provincia FROM provincia WHERE sigla = 'AN')),
    ('b0000000-0000-0000-0000-000000000004', 'Aosta',            (SELECT id_provincia FROM provincia WHERE sigla = 'AO')),
    ('b0000000-0000-0000-0000-000000000005', 'Ascoli Piceno',    (SELECT id_provincia FROM provincia WHERE sigla = 'AP')),
    ('b0000000-0000-0000-0000-000000000006', 'L''Aquila',        (SELECT id_provincia FROM provincia WHERE sigla = 'AQ')),
    ('b0000000-0000-0000-0000-000000000007', 'Arezzo',           (SELECT id_provincia FROM provincia WHERE sigla = 'AR')),
    ('b0000000-0000-0000-0000-000000000008', 'Asti',             (SELECT id_provincia FROM provincia WHERE sigla = 'AT')),
    ('b0000000-0000-0000-0000-000000000009', 'Avellino',         (SELECT id_provincia FROM provincia WHERE sigla = 'AV')),
    ('b0000000-0000-0000-0000-000000000010', 'Bari',             (SELECT id_provincia FROM provincia WHERE sigla = 'BA')),
    ('b0000000-0000-0000-0000-000000000011', 'Bergamo',          (SELECT id_provincia FROM provincia WHERE sigla = 'BG')),
    ('b0000000-0000-0000-0000-000000000012', 'Biella',           (SELECT id_provincia FROM provincia WHERE sigla = 'BI')),
    ('b0000000-0000-0000-0000-000000000013', 'Belluno',          (SELECT id_provincia FROM provincia WHERE sigla = 'BL')),
    ('b0000000-0000-0000-0000-000000000014', 'Benevento',        (SELECT id_provincia FROM provincia WHERE sigla = 'BN')),
    ('b0000000-0000-0000-0000-000000000015', 'Bologna',          (SELECT id_provincia FROM provincia WHERE sigla = 'BO')),
    ('b0000000-0000-0000-0000-000000000016', 'Brindisi',         (SELECT id_provincia FROM provincia WHERE sigla = 'BR')),
    ('b0000000-0000-0000-0000-000000000017', 'Brescia',          (SELECT id_provincia FROM provincia WHERE sigla = 'BS')),
    ('b0000000-0000-0000-0000-000000000018', 'Barletta',         (SELECT id_provincia FROM provincia WHERE sigla = 'BT')),
    ('b0000000-0000-0000-0000-000000000019', 'Bolzano',          (SELECT id_provincia FROM provincia WHERE sigla = 'BZ')),
    ('b0000000-0000-0000-0000-000000000020', 'Cagliari',         (SELECT id_provincia FROM provincia WHERE sigla = 'CA')),
    ('b0000000-0000-0000-0000-000000000021', 'Campobasso',       (SELECT id_provincia FROM provincia WHERE sigla = 'CB')),
    ('b0000000-0000-0000-0000-000000000022', 'Caserta',          (SELECT id_provincia FROM provincia WHERE sigla = 'CE')),
    ('b0000000-0000-0000-0000-000000000023', 'Chieti',           (SELECT id_provincia FROM provincia WHERE sigla = 'CH')),
    ('b0000000-0000-0000-0000-000000000024', 'Caltanissetta',    (SELECT id_provincia FROM provincia WHERE sigla = 'CL')),
    ('b0000000-0000-0000-0000-000000000025', 'Cuneo',            (SELECT id_provincia FROM provincia WHERE sigla = 'CN')),
    ('b0000000-0000-0000-0000-000000000026', 'Como',             (SELECT id_provincia FROM provincia WHERE sigla = 'CO')),
    ('b0000000-0000-0000-0000-000000000027', 'Cremona',          (SELECT id_provincia FROM provincia WHERE sigla = 'CR')),
    ('b0000000-0000-0000-0000-000000000028', 'Cosenza',          (SELECT id_provincia FROM provincia WHERE sigla = 'CS')),
    ('b0000000-0000-0000-0000-000000000029', 'Catania',          (SELECT id_provincia FROM provincia WHERE sigla = 'CT')),
    ('b0000000-0000-0000-0000-000000000030', 'Catanzaro',        (SELECT id_provincia FROM provincia WHERE sigla = 'CZ')),
    ('b0000000-0000-0000-0000-000000000031', 'Enna',             (SELECT id_provincia FROM provincia WHERE sigla = 'EN')),
    ('b0000000-0000-0000-0000-000000000032', 'Forlì',            (SELECT id_provincia FROM provincia WHERE sigla = 'FC')),
    ('b0000000-0000-0000-0000-000000000033', 'Ferrara',          (SELECT id_provincia FROM provincia WHERE sigla = 'FE')),
    ('b0000000-0000-0000-0000-000000000034', 'Foggia',           (SELECT id_provincia FROM provincia WHERE sigla = 'FG')),
    ('b0000000-0000-0000-0000-000000000035', 'Firenze',          (SELECT id_provincia FROM provincia WHERE sigla = 'FI')),
    ('b0000000-0000-0000-0000-000000000036', 'Fermo',            (SELECT id_provincia FROM provincia WHERE sigla = 'FM')),
    ('b0000000-0000-0000-0000-000000000037', 'Frosinone',        (SELECT id_provincia FROM provincia WHERE sigla = 'FR')),
    ('b0000000-0000-0000-0000-000000000038', 'Genova',           (SELECT id_provincia FROM provincia WHERE sigla = 'GE')),
    ('b0000000-0000-0000-0000-000000000039', 'Gorizia',          (SELECT id_provincia FROM provincia WHERE sigla = 'GO')),
    ('b0000000-0000-0000-0000-000000000040', 'Grosseto',         (SELECT id_provincia FROM provincia WHERE sigla = 'GR')),
    ('b0000000-0000-0000-0000-000000000041', 'Imperia',          (SELECT id_provincia FROM provincia WHERE sigla = 'IM')),
    ('b0000000-0000-0000-0000-000000000042', 'Isernia',          (SELECT id_provincia FROM provincia WHERE sigla = 'IS')),
    ('b0000000-0000-0000-0000-000000000043', 'Crotone',          (SELECT id_provincia FROM provincia WHERE sigla = 'KR')),
    ('b0000000-0000-0000-0000-000000000044', 'Lecco',            (SELECT id_provincia FROM provincia WHERE sigla = 'LC')),
    ('b0000000-0000-0000-0000-000000000045', 'Lecce',            (SELECT id_provincia FROM provincia WHERE sigla = 'LE')),
    ('b0000000-0000-0000-0000-000000000046', 'Livorno',          (SELECT id_provincia FROM provincia WHERE sigla = 'LI')),
    ('b0000000-0000-0000-0000-000000000047', 'Lodi',             (SELECT id_provincia FROM provincia WHERE sigla = 'LO')),
    ('b0000000-0000-0000-0000-000000000048', 'Latina',           (SELECT id_provincia FROM provincia WHERE sigla = 'LT')),
    ('b0000000-0000-0000-0000-000000000049', 'Lucca',            (SELECT id_provincia FROM provincia WHERE sigla = 'LU')),
    ('b0000000-0000-0000-0000-000000000050', 'Monza',            (SELECT id_provincia FROM provincia WHERE sigla = 'MB')),
    ('b0000000-0000-0000-0000-000000000051', 'Macerata',         (SELECT id_provincia FROM provincia WHERE sigla = 'MC')),
    ('b0000000-0000-0000-0000-000000000052', 'Messina',          (SELECT id_provincia FROM provincia WHERE sigla = 'ME')),
    ('b0000000-0000-0000-0000-000000000053', 'Milano',           (SELECT id_provincia FROM provincia WHERE sigla = 'MI')),
    ('b0000000-0000-0000-0000-000000000054', 'Mantova',          (SELECT id_provincia FROM provincia WHERE sigla = 'MN')),
    ('b0000000-0000-0000-0000-000000000055', 'Modena',           (SELECT id_provincia FROM provincia WHERE sigla = 'MO')),
    ('b0000000-0000-0000-0000-000000000056', 'Massa',            (SELECT id_provincia FROM provincia WHERE sigla = 'MS')),
    ('b0000000-0000-0000-0000-000000000057', 'Matera',           (SELECT id_provincia FROM provincia WHERE sigla = 'MT')),
    ('b0000000-0000-0000-0000-000000000058', 'Napoli',           (SELECT id_provincia FROM provincia WHERE sigla = 'NA')),
    ('b0000000-0000-0000-0000-000000000059', 'Novara',           (SELECT id_provincia FROM provincia WHERE sigla = 'NO')),
    ('b0000000-0000-0000-0000-000000000060', 'Nuoro',            (SELECT id_provincia FROM provincia WHERE sigla = 'NU')),
    ('b0000000-0000-0000-0000-000000000061', 'Oristano',         (SELECT id_provincia FROM provincia WHERE sigla = 'OR')),
    ('b0000000-0000-0000-0000-000000000062', 'Palermo',          (SELECT id_provincia FROM provincia WHERE sigla = 'PA')),
    ('b0000000-0000-0000-0000-000000000063', 'Piacenza',         (SELECT id_provincia FROM provincia WHERE sigla = 'PC')),
    ('b0000000-0000-0000-0000-000000000064', 'Padova',           (SELECT id_provincia FROM provincia WHERE sigla = 'PD')),
    ('b0000000-0000-0000-0000-000000000065', 'Pescara',          (SELECT id_provincia FROM provincia WHERE sigla = 'PE')),
    ('b0000000-0000-0000-0000-000000000066', 'Perugia',          (SELECT id_provincia FROM provincia WHERE sigla = 'PG')),
    ('b0000000-0000-0000-0000-000000000067', 'Pisa',             (SELECT id_provincia FROM provincia WHERE sigla = 'PI')),
    ('b0000000-0000-0000-0000-000000000068', 'Pordenone',        (SELECT id_provincia FROM provincia WHERE sigla = 'PN')),
    ('b0000000-0000-0000-0000-000000000069', 'Prato',            (SELECT id_provincia FROM provincia WHERE sigla = 'PO')),
    ('b0000000-0000-0000-0000-000000000070', 'Parma',            (SELECT id_provincia FROM provincia WHERE sigla = 'PR')),
    ('b0000000-0000-0000-0000-000000000071', 'Pistoia',          (SELECT id_provincia FROM provincia WHERE sigla = 'PT')),
    ('b0000000-0000-0000-0000-000000000072', 'Pesaro',           (SELECT id_provincia FROM provincia WHERE sigla = 'PU')),
    ('b0000000-0000-0000-0000-000000000073', 'Pavia',            (SELECT id_provincia FROM provincia WHERE sigla = 'PV')),
    ('b0000000-0000-0000-0000-000000000074', 'Potenza',          (SELECT id_provincia FROM provincia WHERE sigla = 'PZ')),
    ('b0000000-0000-0000-0000-000000000075', 'Ravenna',          (SELECT id_provincia FROM provincia WHERE sigla = 'RA')),
    ('b0000000-0000-0000-0000-000000000076', 'Reggio Calabria',  (SELECT id_provincia FROM provincia WHERE sigla = 'RC')),
    ('b0000000-0000-0000-0000-000000000077', 'Reggio Emilia',    (SELECT id_provincia FROM provincia WHERE sigla = 'RE')),
    ('b0000000-0000-0000-0000-000000000078', 'Ragusa',           (SELECT id_provincia FROM provincia WHERE sigla = 'RG')),
    ('b0000000-0000-0000-0000-000000000079', 'Rieti',            (SELECT id_provincia FROM provincia WHERE sigla = 'RI')),
    ('b0000000-0000-0000-0000-000000000080', 'Roma',             (SELECT id_provincia FROM provincia WHERE sigla = 'RM')),
    ('b0000000-0000-0000-0000-000000000081', 'Rimini',           (SELECT id_provincia FROM provincia WHERE sigla = 'RN')),
    ('b0000000-0000-0000-0000-000000000082', 'Rovigo',           (SELECT id_provincia FROM provincia WHERE sigla = 'RO')),
    ('b0000000-0000-0000-0000-000000000083', 'Salerno',          (SELECT id_provincia FROM provincia WHERE sigla = 'SA')),
    ('b0000000-0000-0000-0000-000000000084', 'Siena',            (SELECT id_provincia FROM provincia WHERE sigla = 'SI')),
    ('b0000000-0000-0000-0000-000000000085', 'Sondrio',          (SELECT id_provincia FROM provincia WHERE sigla = 'SO')),
    ('b0000000-0000-0000-0000-000000000086', 'La Spezia',        (SELECT id_provincia FROM provincia WHERE sigla = 'SP')),
    ('b0000000-0000-0000-0000-000000000087', 'Siracusa',         (SELECT id_provincia FROM provincia WHERE sigla = 'SR')),
    ('b0000000-0000-0000-0000-000000000088', 'Sassari',          (SELECT id_provincia FROM provincia WHERE sigla = 'SS')),
    ('b0000000-0000-0000-0000-000000000089', 'Carbonia',         (SELECT id_provincia FROM provincia WHERE sigla = 'SU')),
    ('b0000000-0000-0000-0000-000000000090', 'Savona',           (SELECT id_provincia FROM provincia WHERE sigla = 'SV')),
    ('b0000000-0000-0000-0000-000000000091', 'Taranto',          (SELECT id_provincia FROM provincia WHERE sigla = 'TA')),
    ('b0000000-0000-0000-0000-000000000092', 'Teramo',           (SELECT id_provincia FROM provincia WHERE sigla = 'TE')),
    ('b0000000-0000-0000-0000-000000000093', 'Trento',           (SELECT id_provincia FROM provincia WHERE sigla = 'TN')),
    ('b0000000-0000-0000-0000-000000000094', 'Torino',           (SELECT id_provincia FROM provincia WHERE sigla = 'TO')),
    ('b0000000-0000-0000-0000-000000000095', 'Trapani',          (SELECT id_provincia FROM provincia WHERE sigla = 'TP')),
    ('b0000000-0000-0000-0000-000000000096', 'Terni',            (SELECT id_provincia FROM provincia WHERE sigla = 'TR')),
    ('b0000000-0000-0000-0000-000000000097', 'Trieste',          (SELECT id_provincia FROM provincia WHERE sigla = 'TS')),
    ('b0000000-0000-0000-0000-000000000098', 'Treviso',          (SELECT id_provincia FROM provincia WHERE sigla = 'TV')),
    ('b0000000-0000-0000-0000-000000000099', 'Udine',            (SELECT id_provincia FROM provincia WHERE sigla = 'UD')),
    ('b0000000-0000-0000-0000-000000000100', 'Varese',           (SELECT id_provincia FROM provincia WHERE sigla = 'VA')),
    ('b0000000-0000-0000-0000-000000000101', 'Verbania',         (SELECT id_provincia FROM provincia WHERE sigla = 'VB')),
    ('b0000000-0000-0000-0000-000000000102', 'Vercelli',         (SELECT id_provincia FROM provincia WHERE sigla = 'VC')),
    ('b0000000-0000-0000-0000-000000000103', 'Venezia',          (SELECT id_provincia FROM provincia WHERE sigla = 'VE')),
    ('b0000000-0000-0000-0000-000000000104', 'Vicenza',          (SELECT id_provincia FROM provincia WHERE sigla = 'VI')),
    ('b0000000-0000-0000-0000-000000000105', 'Verona',           (SELECT id_provincia FROM provincia WHERE sigla = 'VR')),
    ('b0000000-0000-0000-0000-000000000106', 'Viterbo',          (SELECT id_provincia FROM provincia WHERE sigla = 'VT')),
    ('b0000000-0000-0000-0000-000000000107', 'Vibo Valentia',    (SELECT id_provincia FROM provincia WHERE sigla = 'VV')),

    -- Città extra: riviera romagnola ------------------------------------
    ('b0000000-0000-0000-0000-000000000108', 'Riccione',         (SELECT id_provincia FROM provincia WHERE sigla = 'RN')),
    ('b0000000-0000-0000-0000-000000000109', 'Cattolica',        (SELECT id_provincia FROM provincia WHERE sigla = 'RN')),
    ('b0000000-0000-0000-0000-000000000110', 'Misano Adriatico', (SELECT id_provincia FROM provincia WHERE sigla = 'RN')),
    ('b0000000-0000-0000-0000-000000000111', 'Cesenatico',       (SELECT id_provincia FROM provincia WHERE sigla = 'FC')),

    -- Città extra: costa veneta ----------------------------------------
    ('b0000000-0000-0000-0000-000000000112', 'Jesolo',           (SELECT id_provincia FROM provincia WHERE sigla = 'VE')),
    ('b0000000-0000-0000-0000-000000000113', 'Caorle',           (SELECT id_provincia FROM provincia WHERE sigla = 'VE')),

    -- Città extra: Versilia --------------------------------------------
    ('b0000000-0000-0000-0000-000000000114', 'Viareggio',        (SELECT id_provincia FROM provincia WHERE sigla = 'LU')),
    ('b0000000-0000-0000-0000-000000000115', 'Forte dei Marmi',  (SELECT id_provincia FROM provincia WHERE sigla = 'LU')),

    -- Città extra: Salento ---------------------------------------------
    ('b0000000-0000-0000-0000-000000000116', 'Gallipoli',        (SELECT id_provincia FROM provincia WHERE sigla = 'LE')),
    ('b0000000-0000-0000-0000-000000000117', 'Otranto',          (SELECT id_provincia FROM provincia WHERE sigla = 'LE')),

    -- Città extra: Sardegna nord ---------------------------------------
    ('b0000000-0000-0000-0000-000000000118', 'Olbia',            (SELECT id_provincia FROM provincia WHERE sigla = 'SS')),
    ('b0000000-0000-0000-0000-000000000119', 'Arzachena',        (SELECT id_provincia FROM provincia WHERE sigla = 'SS')),

    -- Città extra: Sicilia ---------------------------------------------
    ('b0000000-0000-0000-0000-000000000120', 'Taormina',         (SELECT id_provincia FROM provincia WHERE sigla = 'ME')),

    -- Città extra: costiera amalfitana / sorrentina --------------------
    ('b0000000-0000-0000-0000-000000000121', 'Sorrento',         (SELECT id_provincia FROM provincia WHERE sigla = 'NA')),
    ('b0000000-0000-0000-0000-000000000122', 'Positano',         (SELECT id_provincia FROM provincia WHERE sigla = 'SA')),
    ('b0000000-0000-0000-0000-000000000123', 'Amalfi',           (SELECT id_provincia FROM provincia WHERE sigla = 'SA')),

    -- Città extra: lago di Garda ---------------------------------------
    ('b0000000-0000-0000-0000-000000000124', 'Bardolino',        (SELECT id_provincia FROM provincia WHERE sigla = 'VR')),
    ('b0000000-0000-0000-0000-000000000125', 'Lazise',           (SELECT id_provincia FROM provincia WHERE sigla = 'VR'))

ON CONFLICT (id_citta) DO NOTHING;

-- ---------------------------------------------------------------------------
-- 5. Abilita RLS (Row Level Security) in lettura pubblica per citta
--    L'autocomplete deve poter leggere le città senza autenticazione.
-- ---------------------------------------------------------------------------
ALTER TABLE citta ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "citta_read_public" ON citta;
CREATE POLICY "citta_read_public"
    ON citta FOR SELECT
    USING (true);

ALTER TABLE provincia ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "provincia_read_public" ON provincia;
CREATE POLICY "provincia_read_public"
    ON provincia FOR SELECT
    USING (true);
