-- =============================================================================
-- 003 — Cleanup indici duplicati
-- =============================================================================
--
-- Il DB sorgente conteneva due coppie di indici identici per definizione.
-- Manteniamo l'indice con il nome più descrittivo e rimuoviamo l'altro.
-- Non c'è perdita di copertura: per ogni coppia entrambi gli indici
-- coprivano esattamente la stessa query.
--
-- Impatto: meno overhead in scrittura su `ordini` e `utenti_numeri_telefono`,
-- meno spazio su disco. Nessun cambio di funzionalità.
-- =============================================================================

-- ── ordini.utente_id ──────────────────────────────────────────────────────────
-- `idx_ordini_utente` e `idx_ordini_utente_id` erano entrambi btree su
-- (utente_id). Manteniamo il primo (nome più conciso/idiomatico).
DROP INDEX IF EXISTS public.idx_ordini_utente_id;

-- ── utenti_numeri_telefono (id_utente, telefono) ──────────────────────────────
-- `users_phones_user_id_phone_uq` e `users_phones_user_id_tel_uq` erano
-- entrambi UNIQUE btree su (id_utente, telefono). Manteniamo `_phone_uq`
-- (nome più chiaro: "phone" è meno ambiguo di "tel").
DROP INDEX IF EXISTS public.users_phones_user_id_tel_uq;
