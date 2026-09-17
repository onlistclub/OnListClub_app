# NearbyClubsScreen — Ricerca club

Design: `docs/figma_screen/off/NUOVO/Ricerca Club*.css` (aggiornati il
16/09/2026), riprodotto alla lettera.

## Cosa fa

- **Barra** "Cerca locale o città..." e tre **chip**: raggio (apre il popup
  raggio), "Usa GPS" (al 50% quando è spento), "Filtri".
- **Senza testo** (o con meno di 2 caratteri): lista dei locali nel raggio,
  ordinati per distanza, con i filtri applicati.
- **Con testo**:
  - riquadro con fino a 3 città/luoghi e "Cerca qui";
  - "Forse stai cercando :": locali il cui nome contiene il testo, in tutte
    le città;
  - "Altri locali in linea con la tua ricerca :": altri locali delle stesse
    città, comprese quelle che corrispondono al testo.
- **"Cerca qui"**: la città diventa il centro della ricerca e il suo nome
  resta nella barra; la X la toglie e si torna alla posizione automatica.
- **Popup raggio**: mappa OpenStreetMap scurita (`darkModeTileBuilder`: le
  basemap CARTO ora chiedono una API key) con cerchio del raggio, slider 2–50 km.
- **Pannello filtri**: macro-categorie musicali (mappa `_categorieGeneri`
  sui generi del DB) e prezzo a 5 livelli (`locali.prezzo_indicativo` 1–5,
  migration `docs/database/migrations/2026-09-17_prezzo_indicativo_5_livelli.sql`).
  Le scelte si applicano subito; il bottone mostra quanti risultati restano.

## Posizione (ordine di priorità in `_load`)

1. Città scelta con "Cerca qui".
2. GPS forzato (se fallisce: città salvata).
3. Città salvata nelle impostazioni.
4. Città più vicina all'ultima posizione GPS in cache.
5. Nessuna: locali più popolari e un avviso con "Riprova".

## Note

- Stato con `setState`, nessun BLoC. I dati restano in una cache statica
  (`_cachedData`) così riaprendo la Ricerca non lampeggia lo scheletro.
- Ricerca testuale con debounce di 300 ms e numero di sequenza per scartare
  le risposte superate.
