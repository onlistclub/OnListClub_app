# Post-MVP — Raffinamento posizione per CAP (app ufficiale)

> **Stato:** rimandato a DOPO il lancio dell'MVP. Per l'app ufficiale.
> **Contesto:** nell'MVP (TASK 5) è stata fatta solo la **versione A** — il CAP
> *generico* della città viene mostrato sotto il campo "Città" ed è modificabile
> a mano, e la lista suggerimenti mostra `[cap] - [nome_città]`. **Nessun
> raffinamento geografico per zona.**

## Obiettivo della feature B

Quando l'utente **non usa il GPS** (selezione manuale della posizione) e sceglie
una **città grande con più CAP** (es. Milano, Roma, Torino), il **CAP scelto**
deve raffinare la posizione di riferimento usata per i "locali vicini".
Per le città con **un solo CAP**, basta la città (nessuna scelta di CAP).

## Perché non si può fare con i dati attuali

La tabella `public.citta` oggi contiene:
- **un solo CAP generico per città** (Milano = `20100`, Roma = `00100`, …);
- **una sola coppia `lat`/`lng` per città**.

Mancano quindi:
1. l'elenco dei **CAP multipli** per città (es. tutti i CAP di Milano: 20121, 20122, …);
2. una **`lat`/`lng` per ciascun CAP** (senza coordinate, scegliere un CAP non
   sposterebbe i locali mostrati, che si basano su lat/lng — vedi `ClubService`).

## Task da fare (DOPO l'MVP)

### 1. Dataset CAP con coordinate
- [ ] Procurarsi un dataset dei CAP italiani **con coordinate** (centroide per
      CAP). Fonti possibili: dataset open dei CAP/ISTAT con lat/lng, oppure
      geocoding batch dei CAP.
- [ ] Valutare peso/qualità (copertura di tutti i ~8000 CAP, accuratezza
      coordinate). Preferire una fonte verificata.

### 2. Schema DB (migrazione — SQL lato dashboard)
- [ ] Nuova tabella `public.cap` (proposta):
      `cap text`, `nome_citta text`, `id_citta uuid null` (FK verso `citta` se
      mappabile), `lat double precision`, `lng double precision`,
      `provincia text` opzionale.
- [ ] Indici: su `cap` e su `lower(nome_citta)` per le ricerche.
- [ ] Seed dei dati dal dataset del punto 1.
- [ ] (Opzionale) collegare `citta.id_citta` ai CAP della stessa città.

### 3. Logica app
- [ ] In `LocationService`: dato un `id_citta`/nome città, sapere **quanti CAP**
      ha (1 o >1).
- [ ] In `LocationManualScreen` / `LocationManualBloc`:
      - se la città ha **1 CAP** → comportamento attuale (CAP mostrato, città =
        riferimento, lat/lng della città);
      - se la città ha **>1 CAP** → far **scegliere** il CAP (dropdown/lista) e
        usare la **lat/lng del CAP scelto** come posizione di riferimento.
- [ ] Persistere la posizione raffinata (lat/lng del CAP) dove oggi si salva la
      città: SharedPreferences + metadata `auth.users` (e/o profilo `utenti` se
      verrà aggiunta la colonna). Vedi `LocationService.saveManualLocation`.
- [ ] `ClubService`: assicurarsi che usi la lat/lng raffinata per i locali vicini.

### 4. UX
- [ ] Per città multi-CAP: input/selezione del CAP chiara (es. dropdown dei CAP
      della città, oppure campo CAP con validazione contro i CAP di quella città).
- [ ] Messaggio se il CAP inserito a mano non appartiene alla città scelta.

## Note
- Mantenere il vincolo MVP: **design system** e **sistema responsive** invariati.
- Verificare il peso aggiunto al bundle se il dataset CAP venisse incluso come
  asset locale invece che su DB (preferibile su DB per non appesantire l'app).
