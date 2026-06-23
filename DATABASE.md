# Database OnList Club — guida rapida

> Questa pagina spiega in modo semplice com'è fatto il database dell'app. Pensata per chi non scrive codice ma vuole capire cosa contiene e perché è organizzato così.
>
> Per il documento tecnico completo (schema, sicurezza, trigger, flussi end-to-end), vedi → [docs/database/struttura_database.md](docs/database/struttura_database.md).

---

## 1. Cos'è

Il database di OnList Club è un **Postgres** ospitato su **Supabase**. È uno spazio condiviso in cui vivono tutti i dati dell'app: utenti, locali, serate, prenotazioni.

L'app mobile **non parla mai direttamente con le tabelle**: passa sempre attraverso Supabase, che si occupa di:

- gestire chi è loggato (autenticazione)
- decidere cosa ogni utente può leggere e scrivere (regole di sicurezza)
- garantire che le scritture siano coerenti (transazioni, vincoli)

Versione Postgres: **15** con estensione **PostGIS** (per calcolare le distanze geografiche tra utente e locali).

---

## 2. Le tabelle che contano

Il database ha più di 20 tabelle, ma queste sono quelle che ricorrono in quasi tutti i flussi dell'app:

| Tabella | Cosa contiene, in parole semplici |
|---|---|
| `utenti` | I dati di chi usa l'app: nome, cognome, data di nascita, raggio km preferito |
| `utenti_numeri_telefono` | I numeri di telefono di ciascun utente, con il prefisso paese |
| `locali` | I club / discoteche: nome, indirizzo, città, foto, generi musicali, capienza |
| `eventi` | Le serate dei locali: data, orari, descrizione |
| `prevendite` | I biglietti vendibili per una serata (Normale, VIP, Uomo, ecc.) |
| `prenotazioni_prevendite` | I biglietti effettivamente acquistati dagli utenti |
| `tavoli` / `tavoli_eventi` / `prenotazioni_tavolo` | I tavoli del locale, la loro disponibilità per ogni serata, e chi li ha prenotati |
| `drink` | Il catalogo delle bottiglie / drink (per i pacchetti tavolo) |
| `gestori` | I gestori dei locali. Ogni gestore appartiene a **un solo** locale |
| `notifiche` | Le notifiche inviate agli utenti (es. "nuovo evento al tuo club preferito") |

Tabelle "di servizio" (geografia, analytics, ordini, staff, ingressi, preferiti) sono descritte nel documento tecnico.

---

## 3. Come funziona la sicurezza (RLS, in 30 secondi)

Postgres ha una funzionalità chiamata **Row Level Security (RLS)**. Tradotto: *"per ogni riga del database, decidi tu chi la può vedere o modificare"*. È come avere un buttafuori personale su ogni singola tabella.

Le regole della nostra app:

### 👤 Utenti normali
**Vedono solo i propri dati.** Mario, quando interroga `utenti`, vede solo la riga `Mario`. Quando interroga `prenotazioni_tavolo`, vede solo le sue prenotazioni. Non può vedere quelle di Giulia, anche se sapesse il suo id utente.

La regola sotto al cofano è semplicissima: *"riga.id_utente = id_dell'utente_loggato"*.

### 🏢 Gestori dei locali
**Vedono solo i dati del loro club.** Mario è gestore del Club Hollywood, Luigi del Cocoricò. Quando Mario apre la dashboard del suo locale (in sviluppo, gestionale React), vede solo gli eventi, lo staff e gli ingressi di Hollywood. Mai quelli di Cocoricò.

Per identificare *"qual è il club di Mario"* esiste una piccola funzione nel database chiamata **`my_club_id()`**. Funziona così:

1. Mario fa login → Supabase gli dà il suo identificativo utente
2. `my_club_id()` cerca Mario nella tabella `gestori` → trova "Mario lavora per Hollywood"
3. Risponde con l'id di Hollywood
4. Tutte le regole di sicurezza dei gestori usano questa risposta per filtrare ("mostra solo se la riga ha club_id = id di Hollywood")

Se Mario non è gestore (= non è nella tabella `gestori`), la funzione risponde *"nessuno"* e Mario non vede dati di gestione, come previsto.

### 🌐 Tutti (anche senza login)
Alcune tabelle sono **pubbliche in lettura** perché servono per far vedere il catalogo dell'app prima del login: `locali`, `eventi`, `prevendite`, `tavoli`, `drink`. La scrittura su queste è bloccata.

### 🔑 Backend / amministratori
Quando l'app accede al database con la chiave `service_role` (mai dal client mobile, solo da script o dal pannello Supabase dei Soci), **bypassa tutte le regole RLS**. Serve per fare manutenzione, import, query di analytics.

> Ulteriori dettagli sulla sicurezza, le 7 policy attive e l'ultimo lavoro di hardening del 2026-05-31: vedi [docs/database/struttura_database.md §8.2](docs/database/struttura_database.md).

---

## 4. Dove sono i file SQL nel repo

| Cartella | Contenuto |
|---|---|
| [supabase/migrations/](supabase/migrations/) | Le migration "ufficiali" usate dalla CLI Supabase (`001_struttura_iniziale.sql`, `002_fix_get_gestore_by_codice.sql`, `003_cleanup_duplicate_indexes.sql`) |
| [docs/database/migrations/](docs/database/migrations/) | Le migration applicate dopo l'MVP (Fase A 2026-05-30, hardening RLS 2026-05-31). Vanno consolidate in `supabase/migrations/` man mano |
| [docs/database/schema.sql](docs/database/schema.sql) | Schema completo attuale (snapshot) |
| [docs/database/schema_futuro.sql](docs/database/schema_futuro.sql) | Schema target (cose che verranno aggiunte) |
| [docs/database/query/](docs/database/query/) | Query SQL usate ad hoc (creazione notifiche, aggiornamento coordinate città) |
| [docs/database/db_inserts_template.sql](docs/database/db_inserts_template.sql), [eventi_rows.sql](docs/database/eventi_rows.sql), [locali_rows.sql](docs/database/locali_rows.sql), [posti_famosi.sql](docs/database/posti_famosi.sql) | Template e dati di esempio per popolare il DB |
| [docs/SCHEMA_UFFICIALE_DB.sql](docs/SCHEMA_UFFICIALE_DB.sql) | Versione "ufficiale" dello schema condivisa col team |

---

## 5. Per approfondire

- **Documento tecnico completo:** [docs/database/struttura_database.md](docs/database/struttura_database.md)
   - Schema di tutte le tabelle con colonne e tipi
   - Tutte le policy RLS spiegate
   - Trigger e vincoli (anti-overbooking, decremento atomico, ecc.)
   - Diagrammi entità-relazione
   - Flussi end-to-end (registrazione, acquisto prevendita, prenotazione tavolo)
   - Mappa codice Flutter ↔ tabelle DB

- **Piano integrazione Stripe (futuro):** [docs/database/stripe_integration_plan.md](docs/database/stripe_integration_plan.md)

- **Regole di progetto:** [.claude/CLAUDE.md](.claude/CLAUDE.md)
