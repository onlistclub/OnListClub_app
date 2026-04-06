# Sprint MVP — Aprile 2026
> ~30 min/persona/giorno · 3 persone · 30 giorni

---

## ⏸ DOPO MVP — Task Stripe (posticipate)

> Queste task sono state spostate fuori dallo sprint corrente.
> Da riprendere dopo il rilascio del primo MVP funzionante.

| Task | Descrizione |
|---|---|
| Creare account Stripe | Verificare/creare account Stripe — raccogliere API keys; aggiungere come secret in Supabase Dashboard |
| Edge function `create_payment_intent` | Scrivere `create_payment_intent(importo, tipo)` — crea PaymentIntent Stripe e ritorna `client_secret` |
| Documentare endpoints pagamenti | Creare `docs/api_endpoints.md` con tutti gli endpoint/edge functions per biglietti e tavoli |

---

## Legenda
- **Dev A** — Flutter Frontend (UI, widget, design Figma)
- **Dev B** — Flutter + BLoC + Integrazione Supabase/pagamenti
- **Dev C** — Backend (Supabase tables, edge functions, Stripe)

---

## FASE 1 — Fix Critici + Setup (1–10 aprile)

---

### Lun 6 Aprile — *Pasquetta* 🔵
| | Task (~30 min) |
|---|---|
| **Dev A** 🔵 | Leggere `app_routes.dart` — verificare tutti i route definiti, annotare quelli mancanti o con navigazione errata |
| **Dev B** 🔵 | Leggere docs Supabase Realtime — capire come funziona la subscription a una tabella per feature bottiglie |
| **Dev C** 🔵 | Pianificare struttura delle edge functions necessarie per la Fase 2 (biglietti): input, output, casi di errore |

---

### Mar 7 Aprile
| | Task (~30 min) |
|---|---|
| **Dev A** | Aggiungere chip/pulsante "Rimuovi filtro raggio" in `nearby_clubs_screen.dart` che resetta al valore di default |
| **Dev B** | Fix query in `club_service.dart`: implementare filtro distanza con formula haversine o chiamata RPC Supabase |
| **Dev C** | Scrivere RLS policies per `biglietti` e `prenotazioni_tavolo` — solo il proprietario può leggere/modificare i propri record |

---

### Mer 8 Aprile
| | Task (~30 min) |
|---|---|
| **Dev A** | Confrontare Home Screen con Figma — annotare le 4–5 differenze visive prioritarie da correggere |
| **Dev B** | Testare fix GPS su emulatore: verificare che non richieda permesso ad ogni avvio; testare fix raggio |
| **Dev C** | ~~Creare account Stripe — raccogliere API keys~~ *(→ dopo MVP)* |

---

### Gio 9 Aprile
| | Task (~30 min) |
|---|---|
| **Dev A** | Allineare colori, font e spacing della Home Screen alle specifiche Figma (`theme_helper.dart`, `text_style_helper.dart`) |
| **Dev B** | Configurare OAuth Google: aggiungere SHA-1 fingerprint, aggiornare `google-services.json`, abilitare provider in Supabase Auth |
| **Dev C** | ~~Scrivere edge function `create_payment_intent`~~ *(→ dopo MVP)* |

---

### Ven 10 Aprile
| | Task (~30 min) |
|---|---|
| **Dev A** | Allineare layout card evento nella Home Screen (immagine, titolo, orario, badge club) al design Figma |
| **Dev B** | Testare OAuth Google su emulatore Android — flusso login → callback → sessione Supabase attiva |
| **Dev C** | ~~Documentare endpoints Stripe in `api_endpoints.md`~~ *(→ dopo MVP)* |

---

## FASE 2 — Feature Core: Acquisto Biglietti (11–17 aprile)

---

### Sab 11 Aprile 🔵
| | Task (~30 min) |
|---|---|
| **Dev A** 🔵 | Testare su emulatore il fix "Questa sera" e il fix raggio — verificare che funzionino correttamente |
| **Dev B** 🔵 | Code review dei fix di `location_service.dart` e `club_service.dart` scritti questa settimana |
| **Dev C** 🔵 | Testare manualmente l'edge function `create_payment_intent` con Postman — verificare risposta Stripe |

---

### Dom 12 Aprile 🔵
| | Task (~30 min) |
|---|---|
| **Dev A** 🔵 | Abbozzare su carta/Figma il layout di `ticket_purchase_screen.dart` e `ticket_confirmation_screen.dart` |
| **Dev B** 🔵 | Studiare il pattern BLoC usato nel progetto (es. `club_detail_bloc.dart`) per coerenza nella scrittura del nuovo `ticket_bloc` |
| **Dev C** 🔵 | Verificare integrità referenziale del DB — controllare che tutti gli FK siano corretti nelle nuove tabelle |

---

### Lun 13 Aprile
| | Task (~30 min) |
|---|---|
| **Dev A** | Creare `ticket_purchase_screen.dart` con scaffold: AppBar, layout base, placeholder per widget quantità e riepilogo |
| **Dev B** | Creare `ticket_event.dart` e `ticket_state.dart` — stati: `Initial, Loading, Loaded, Purchasing, Success, Error` |
| **Dev C** | Edge function `check_ticket_availability(evento_id)` — ritorna posti disponibili e prezzo; testare su Dashboard |

---

### Mar 14 Aprile
| | Task (~30 min) |
|---|---|
| **Dev A** | Aggiungere widget selezione quantità biglietti (+/−) con limite max; mostrare prezzo unitario e totale dinamico |
| **Dev B** | Creare `ticket_bloc.dart` — evento `LoadTicketInfo`: chiama RPC `check_ticket_availability`, emette stato `Loaded` |
| **Dev C** | Edge function `create_ticket_order(evento_id, quantita, utente_id)` — inserisce ordine atomicamente, scala disponibilità |

---

### Mer 15 Aprile
| | Task (~30 min) |
|---|---|
| **Dev A** | Aggiungere sezione riepilogo ordine in `ticket_purchase_screen.dart`: n° biglietti × prezzo, totale, pulsante "Procedi al pagamento" |
| **Dev B** | Aggiungere evento `PurchaseTicket` nel BLoC — chiama `create_ticket_order` poi `create_payment_intent`; emette stati appropriati |
| **Dev C** | Configurare webhook Stripe: `payment_intent.succeeded` → aggiorna campo `stato` in `biglietti` a `confermato` |

---

### Gio 16 Aprile
| | Task (~30 min) |
|---|---|
| **Dev A** | Creare `ticket_confirmation_screen.dart`: riepilogo ordine, placeholder QR code generato da ID ordine, pulsante "Torna alla home" |
| **Dev B** | Integrare redirect Stripe Checkout: aprire URL pagamento con `url_launcher`, gestire ritorno nell'app e aggiornamento stato BLoC |
| **Dev C** | Test end-to-end flusso biglietti: acquisto → pagamento Stripe test → webhook → stato `confermato` in DB |

---

### Ven 17 Aprile
| | Task (~30 min) |
|---|---|
| **Dev A** | In `event_detail_club_screen.dart`: collegare pulsante "Acquista biglietto" → navigazione a `ticket_purchase_screen.dart` passando `evento_id` |
| **Dev B** | Test flusso completo acquisto biglietto su emulatore — loading state, errori, success; fix bug BLoC se presenti |
| **Dev C** | Fix bug emersi dai test del flusso biglietti; verificare RLS policies funzionino in tutti i casi |

---

### Sab 18 Aprile 🔵
| | Task (~30 min) |
|---|---|
| **Dev A** 🔵 | Test end-to-end flusso biglietti su emulatore — simulare disponibilità esaurita, errore pagamento, acquisto riuscito |
| **Dev B** 🔵 | Preparare dispositivo Android reale per i test della settimana prossima (abilitare developer mode, trust su ADB) |
| **Dev C** 🔵 | Controllare log Supabase e log Stripe — verificare che webhook funzioni e non ci siano errori silenziosi |

---

### Dom 19 Aprile 🔵
| | Task (~30 min) |
|---|---|
| **Dev A** 🔵 | Abbozzare layout `booking_screen.dart` confrontandolo con Figma — annotare componenti da costruire |
| **Dev B** 🔵 | Leggere docs Stripe per gestione caparra/deposito in prenotazioni tavolo |
| **Dev C** 🔵 | Scrivere query PostGIS di test nell'SQL editor di Supabase per `nearby_clubs(lat, lng, raggio_km)` |

---

## FASE 3 — Feature Core: Tavoli + Inizio Secondarie (20–26 aprile)

---

### Lun 20 Aprile
| | Task (~30 min) |
|---|---|
| **Dev A** | Rifare scaffold `booking_screen.dart` dal design Figma: layout base, AppBar, sezioni "Dettagli tavolo" e "Riepilogo" |
| **Dev B** | Creare `booking_event.dart` e `booking_state.dart` — stati: `Initial, Loading, AvailabilityLoaded, Confirming, Success, Error` |
| **Dev C** | Edge function `check_table_availability(club_id, data, orario)` — verifica capienza residua per la fascia oraria richiesta |

---

### Mar 21 Aprile
| | Task (~30 min) |
|---|---|
| **Dev A** | Aggiungere in `booking_screen.dart`: widget selezione numero persone (slider o +/−) con min 1 e max capienza |
| **Dev B** | Creare `booking_bloc.dart` — evento `CheckAvailability`: chiama RPC, emette `AvailabilityLoaded` con orari disponibili |
| **Dev C** | Edge function `create_table_booking(club_id, utente_id, num_persone, orario, note)` — crea prenotazione gestendo capienza massima |

---

### Mer 22 Aprile
| | Task (~30 min) |
|---|---|
| **Dev A** | Aggiungere in `booking_screen.dart`: chip orari disponibili + campo testo note speciali |
| **Dev B** | Aggiungere evento `ConfirmBooking` nel BLoC — chiama `create_table_booking`, integra pagamento caparra con Stripe |
| **Dev C** | Edge function `cancel_booking(prenotazione_id)` con calcolo trattenuta progressiva: < 24h = 20%, < 6h = 50%, < 1h = 100% |

---

### Gio 23 Aprile
| | Task (~30 min) |
|---|---|
| **Dev A** | Creare `booking_confirmation_screen.dart` con riepilogo prenotazione; aggiungere badge/pulsante "Salta la coda" in `event_detail_club_screen.dart` |
| **Dev B** | **Testare acquisto biglietti su dispositivo Android fisico** — verificare GPS reale, pagamento, QR confirmation |
| **Dev C** | Creare tabella `coda`: `id, evento_id, utente_id, posizione, stato`; scrivere RPC `skip_queue(utente_id, evento_id)` |

---

### Ven 24 Aprile
| | Task (~30 min) |
|---|---|
| **Dev A** | Allineare `club_detail_screen.dart` al design Figma: header immagine, info club, lista eventi |
| **Dev B** | Implementare logica "Salta la coda" nel BLoC: chiamata RPC `skip_queue` + feedback UI (snackbar di conferma) |
| **Dev C** | Creare tabella `ordini_bottiglie`: `id, prenotazione_id, bottiglia_id, quantita, stato`; definire relazioni |

---

### Sab 25 Aprile — *Festa della Liberazione* 🔵
| | Task (~30 min) |
|---|---|
| **Dev A** 🔵 | Test flusso prenotazione tavolo su emulatore — simulare orario non disponibile, conferma, annullamento |
| **Dev B** 🔵 | Code review di `booking_bloc.dart` — verificare che tutti gli stati e le transizioni siano corretti |
| **Dev C** 🔵 | Ottimizzare indici DB su colonne frequentemente interrogate: `evento_id`, `utente_id`, `club_id`, `stato` |

---

### Dom 26 Aprile 🔵
| | Task (~30 min) |
|---|---|
| **Dev A** 🔵 | Rivedere `event_detail_club_screen.dart` — annotare miglioramenti UI per la settimana finale |
| **Dev B** 🔵 | Preparare checklist test iOS: schermate da testare, flussi da verificare, casi limite |
| **Dev C** 🔵 | Scrivere struttura catalologo bottiglie su Supabase: tabella `bottiglie` con `id, nome, prezzo, club_id` |

---

## FASE 4 — Secondarie + Design + Test Finale (27–30 aprile)

---

### Lun 27 Aprile
| | Task (~30 min) |
|---|---|
| **Dev A** | Allineare `event_detail_club_screen.dart` al Figma; creare bottom sheet/modale per visualizzare e aggiungere ordine bottiglie |
| **Dev B** | Integrare Supabase Realtime nel BLoC: subscription a `ordini_bottiglie` per aggiornamenti live dell'ordine durante la serata |
| **Dev C** | Edge function `splitpay_request(prenotazione_id, amici[])` — divide il totale, genera un link di pagamento Stripe per ciascun amico |

---

### Mar 28 Aprile
| | Task (~30 min) |
|---|---|
| **Dev A** | UI splitpay in `booking_confirmation_screen.dart`: sezione "Dividi spesa", inserimento amici (nome/telefono), pulsante "Invia richiesta" |
| **Dev B** | Integrare BLoC splitpay: evento `RequestSplitPay` → chiama edge function → mostra stato pagamento per ciascun amico |
| **Dev C** | Implementare RPC PostGIS `nearby_clubs(lat, lng, raggio_km)` in Supabase — sostituire l'attuale query in `club_service.dart` |

---

### Mer 29 Aprile
| | Task (~30 min) |
|---|---|
| **Dev A** | UI cancellazione tavolo: pulsante "Cancella prenotazione" con modale che mostra trattenuta calcolata in tempo reale |
| **Dev B** | **Test iOS su dispositivo reale** (richiede Mac + Xcode) — testare GPS, login, biglietti, tavoli |
| **Dev C** | Audit sicurezza: revisione RLS policies su tutte le tabelle; aggiungere validazione input nelle edge functions (importi > 0, campi obbligatori) |

---

### Gio 30 Aprile — **MVP DAY** ✅
| | Task (~30 min) |
|---|---|
| **Dev A** | Revisione UX generale: loading state su tutti i pulsanti principali, empty state su liste vuote, transizioni tra schermate |
| **Dev B** | Fix bug finali emersi dai test iOS/Android; verificare che tutti i flussi core funzionino end-to-end |
| **Dev C** | Preparare environment staging finale; aggiornare `docs_utili/api_endpoints.md` con stato finale di tutti gli endpoint |

---

## Riepilogo Milestone

| Data | Obiettivo |
|---|---|
| **Ven 3 apr** | Bug GPS + raggio identificati; tabelle DB create su Supabase |
| **Ven 10 apr** | Fix visivi Home, OAuth Google attivo, infra Stripe operativa |
| **Ven 17 apr** | Acquisto biglietti end-to-end funzionante |
| **Gio 23 apr** | Test biglietti su dispositivo Android reale ✅ |
| **Ven 24 apr** | Acquisto tavoli + salta coda funzionanti |
| **Gio 30 apr** | MVP completo — tutti i flussi core testati su iOS e Android ✅ |

---

## Note operative
- 🔵 I giorni con task opzionali (weekend/festività) possono essere saltati senza impatto sul piano.
- Se una task richiede più di 30 min, si spezza nel giorno successivo senza spostare le altre.
- **OAuth Apple** richiede Mac + Xcode: organizzare l'accesso entro il 28 aprile.
- **Test iOS fisico** (29 apr, Dev B): richiede Apple Developer Account attivo.
