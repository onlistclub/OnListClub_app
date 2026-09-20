-- ============================================================
-- Migration: aggiunge lat/lng alla tabella citta
-- Data: 2026-03-30
-- ============================================================

ALTER TABLE citta ADD COLUMN IF NOT EXISTS lat DOUBLE PRECISION;
ALTER TABLE citta ADD COLUMN IF NOT EXISTS lng DOUBLE PRECISION;

-- ---- Città principali italiane ----

UPDATE citta SET lat = 45.4642, lng = 9.1900  WHERE nome_citta = 'Milano';
UPDATE citta SET lat = 41.9028, lng = 12.4964 WHERE nome_citta = 'Roma';
UPDATE citta SET lat = 40.8518, lng = 14.2681 WHERE nome_citta = 'Napoli';
UPDATE citta SET lat = 45.0703, lng = 7.6869  WHERE nome_citta = 'Torino';
UPDATE citta SET lat = 43.7696, lng = 11.2558 WHERE nome_citta = 'Firenze';
UPDATE citta SET lat = 44.4949, lng = 11.3426 WHERE nome_citta = 'Bologna';
UPDATE citta SET lat = 45.4408, lng = 12.3155 WHERE nome_citta = 'Venezia';
UPDATE citta SET lat = 45.6495, lng = 13.7768 WHERE nome_citta = 'Trieste';
UPDATE citta SET lat = 45.4065, lng = 11.8768 WHERE nome_citta = 'Padova';
UPDATE citta SET lat = 45.5455, lng = 11.5354 WHERE nome_citta = 'Vicenza';
UPDATE citta SET lat = 45.4384, lng = 10.9916 WHERE nome_citta = 'Verona';
UPDATE citta SET lat = 44.4056, lng = 8.9463  WHERE nome_citta = 'Genova';
UPDATE citta SET lat = 43.8229, lng = 10.4617 WHERE nome_citta = 'Lucca';
UPDATE citta SET lat = 43.9097, lng = 10.8993 WHERE nome_citta = 'Prato';
UPDATE citta SET lat = 43.3615, lng = 11.3319 WHERE nome_citta = 'Siena';
UPDATE citta SET lat = 43.1119, lng = 12.3887 WHERE nome_citta = 'Perugia';
UPDATE citta SET lat = 41.6552, lng = 15.9756 WHERE nome_citta = 'Foggia';
UPDATE citta SET lat = 41.1171, lng = 16.8719 WHERE nome_citta = 'Bari';
UPDATE citta SET lat = 40.3516, lng = 18.1750 WHERE nome_citta = 'Lecce';
UPDATE citta SET lat = 37.5024, lng = 15.0873 WHERE nome_citta = 'Catania';
UPDATE citta SET lat = 38.1157, lng = 13.3615 WHERE nome_citta = 'Palermo';
UPDATE citta SET lat = 37.7749, lng = 12.4396 WHERE nome_citta = 'Trapani';
UPDATE citta SET lat = 40.9190, lng = 9.1338  WHERE nome_citta = 'Sassari';
UPDATE citta SET lat = 39.2238, lng = 9.1217  WHERE nome_citta = 'Cagliari';

-- ---- Città zona Milano ----

UPDATE citta SET lat = 45.5845, lng = 9.2744  WHERE nome_citta = 'Monza';
UPDATE citta SET lat = 45.6980, lng = 9.6706  WHERE nome_citta = 'Bergamo';
UPDATE citta SET lat = 45.5268, lng = 10.2118 WHERE nome_citta = 'Brescia';
UPDATE citta SET lat = 45.6669, lng = 8.8583  WHERE nome_citta = 'Varese';
UPDATE citta SET lat = 45.8063, lng = 9.0810  WHERE nome_citta = 'Como';
UPDATE citta SET lat = 45.4557, lng = 9.1614  WHERE nome_citta = 'Sesto San Giovanni';
UPDATE citta SET lat = 45.3628, lng = 9.1745  WHERE nome_citta = 'Pavia';

-- ---- Riviera Romagnola (nightlife) ----

UPDATE citta SET lat = 44.0594, lng = 12.5683 WHERE nome_citta = 'Rimini';
UPDATE citta SET lat = 44.0037, lng = 12.6566 WHERE nome_citta = 'Riccione';
UPDATE citta SET lat = 44.0219, lng = 12.7084 WHERE nome_citta = 'Misano Adriatico';
UPDATE citta SET lat = 44.0755, lng = 12.4851 WHERE nome_citta = 'Santarcangelo di Romagna';
UPDATE citta SET lat = 44.1391, lng = 12.2457 WHERE nome_citta = 'Cesena';
UPDATE citta SET lat = 44.2229, lng = 12.0407 WHERE nome_citta = 'Forlì';
UPDATE citta SET lat = 44.1416, lng = 12.2495 WHERE nome_citta = 'Cesenatico';
UPDATE citta SET lat = 44.0861, lng = 12.7590 WHERE nome_citta = 'Cattolica';

-- ---- Versilia ----

UPDATE citta SET lat = 43.8671, lng = 10.2321 WHERE nome_citta = 'Viareggio';
UPDATE citta SET lat = 43.9641, lng = 10.1716 WHERE nome_citta = 'Forte dei Marmi';
UPDATE citta SET lat = 43.9527, lng = 10.1997 WHERE nome_citta = 'Pietrasanta';

-- ---- Costa Adriatica ----

UPDATE citta SET lat = 43.6158, lng = 13.5189 WHERE nome_citta = 'Ancona';
UPDATE citta SET lat = 43.7373, lng = 13.2168 WHERE nome_citta = 'Senigallia';
UPDATE citta SET lat = 44.8278, lng = 11.6196 WHERE nome_citta = 'Ferrara';
UPDATE citta SET lat = 44.7011, lng = 12.2394 WHERE nome_citta = 'Rovigo';

-- ---- Salento ----

UPDATE citta SET lat = 39.9933, lng = 18.0026 WHERE nome_citta = 'Gallipoli';
UPDATE citta SET lat = 40.1479, lng = 18.4944 WHERE nome_citta = 'Otranto';
UPDATE citta SET lat = 40.3532, lng = 18.1751 WHERE nome_citta = 'Brindisi';

-- ---- Sardegna (Costa Smeralda) ----

UPDATE citta SET lat = 40.9232, lng = 9.5025  WHERE nome_citta = 'Olbia';
UPDATE citta SET lat = 41.0828, lng = 9.6318  WHERE nome_citta = 'Arzachena';

-- ---- Costiera Amalfitana ----

UPDATE citta SET lat = 40.6263, lng = 14.3757 WHERE nome_citta = 'Sorrento';
UPDATE citta SET lat = 40.6280, lng = 14.4840 WHERE nome_citta = 'Positano';
UPDATE citta SET lat = 40.6349, lng = 14.6022 WHERE nome_citta = 'Amalfi';
UPDATE citta SET lat = 40.7982, lng = 14.4895 WHERE nome_citta = 'Salerno';

-- ---- Lago di Garda ----

UPDATE citta SET lat = 45.5555, lng = 10.7237 WHERE nome_citta = 'Bardolino';
UPDATE citta SET lat = 45.5082, lng = 10.7239 WHERE nome_citta = 'Lazise';
UPDATE citta SET lat = 45.4690, lng = 10.7120 WHERE nome_citta = 'Peschiera del Garda';
UPDATE citta SET lat = 45.5192, lng = 10.5245 WHERE nome_citta = 'Desenzano del Garda';

-- ---- Toscana / Umbria ----

UPDATE citta SET lat = 43.4673, lng = 11.8818 WHERE nome_citta = 'Arezzo';
UPDATE citta SET lat = 42.3498, lng = 11.3598 WHERE nome_citta = 'Grosseto';
UPDATE citta SET lat = 42.6938, lng = 11.8807 WHERE nome_citta = 'Viterbo';
UPDATE citta SET lat = 42.8671, lng = 11.6467 WHERE nome_citta = 'Orvieto';

-- ---- Nord-Est ----

UPDATE citta SET lat = 46.0748, lng = 11.1217 WHERE nome_citta = 'Trento';
UPDATE citta SET lat = 46.4983, lng = 11.3548 WHERE nome_citta = 'Bolzano';
UPDATE citta SET lat = 46.0601, lng = 13.2349 WHERE nome_citta = 'Udine';
UPDATE citta SET lat = 45.6503, lng = 12.2411 WHERE nome_citta = 'Treviso';

-- ---- Calabria / Sicilia ----

UPDATE citta SET lat = 38.9095, lng = 16.5879 WHERE nome_citta = 'Catanzaro';
UPDATE citta SET lat = 37.9289, lng = 15.6569 WHERE nome_citta = 'Reggio Calabria';
UPDATE citta SET lat = 37.7733, lng = 15.1852 WHERE nome_citta = 'Taormina';
UPDATE citta SET lat = 37.6528, lng = 12.8003 WHERE nome_citta = 'Agrigento';
UPDATE citta SET lat = 36.8959, lng = 14.7153 WHERE nome_citta = 'Ragusa';
UPDATE citta SET lat = 37.0750, lng = 15.2866 WHERE nome_citta = 'Siracusa';

-- ---- Campania ----

UPDATE citta SET lat = 40.8320, lng = 14.2501 WHERE nome_citta = 'Caserta';
UPDATE citta SET lat = 40.9266, lng = 14.7879 WHERE nome_citta = 'Avellino';
UPDATE citta SET lat = 40.3498, lng = 15.0050 WHERE nome_citta = 'Salerno';

-- ---- Lazio ----

UPDATE citta SET lat = 41.6559, lng = 13.7700 WHERE nome_citta = 'Frosinone';
UPDATE citta SET lat = 42.3613, lng = 13.3930 WHERE nome_citta = 'L\'Aquila';
UPDATE citta SET lat = 42.2053, lng = 14.2990 WHERE nome_citta = 'Pescara';

-- ---- Piemonte / Liguria ----

UPDATE citta SET lat = 44.4056, lng = 8.9463  WHERE nome_citta = 'Genova';
UPDATE citta SET lat = 44.0601, lng = 8.2303  WHERE nome_citta = 'Imperia';
UPDATE citta SET lat = 44.1015, lng = 7.6767  WHERE nome_citta = 'Cuneo';
UPDATE citta SET lat = 44.9070, lng = 8.6066  WHERE nome_citta = 'Alessandria';
UPDATE citta SET lat = 45.1391, lng = 7.9870  WHERE nome_citta = 'Novara';
