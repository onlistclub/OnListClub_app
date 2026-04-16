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
- **Dev A** — Flutter Frontend (UI, widget, design, test mobile giornalieri)
- **Dev B** — Flutter + BLoC + Integrazione Supabase/autenticazione
- **Dev C** — Backend (Supabase tables, edge functions, chiavi/config)

---

## Note sui test mobile
> A partire dall'8 aprile, Dev A esegue ogni giorno una sessione di test su dispositivo fisico per rilevare latenze e bug.
> **Non correggere** transizioni animate o comportamenti di scroll — verranno affrontati in una fase separata post-MVP.

---

## FASE 1 — Fix Critici + Setup + Google Auth (6–12 aprile)

**Obiettivo entro domenica 12:** Google Auth funzionante ✅ · Chiavi e tabelle Supabase verificate ✅

### Sab 11 Aprile 🔵
| | Task (~30 min) |
|---|---|
| **Dev A** 🔵 | Pulizia UI: togliere i generi musicali e la label gialla dalle card; rimuovere il pulsante "profilo" in alto a destra e mantenerlo SOLO nella bottom nav. Implementare pagina del profilo prendendo i design di Figma.|
| **Dev B** 🔵 | Auth & Sessione: impostare la persistenza per rimanere sempre loggati (no re-login); testare registrazione con Google OAuth e forzare la compilazione manuale di data nascita e città se mancanti. |
| **Dev C** 🔵 | Controllo DB: riverificare l'intero database con AI e trovare eventuali incongruenze residue prima di procedere allo sviluppo dei biglietti e tavoli con errori. |

---

### Dom 12 Aprile 🔵
| | Task (~30 min) |
|---|---|
| **Dev A** 🔵 | Nuova UI: creare la pagina delle Informazioni dell'utente (layout base da riempire progressivamente col design); migliorare la Mappa del raggio (design moderno, non "anni 2000") per vedere bene le città. |
| **Dev B** 🔵 | Fix logica: risolvere il problema delle città duplicate che appaiono doppie durante la ricerca. |
| **Dev C** 🔵 | Supporto e validazione: testare assieme a Dev B la scrittura corretta su Supabase del profilo utente (dopo Google OAuth) e del nuovo flusso persistente di accesso. |

---

**ASPETTARE DESIGN UFFICIALE DI QUELLA PARTE DELLA RICERCA DI LOCALE!**

## FASE 2 — Feature Core: Acquisto Biglietti (13–19 aprile)

---

### Lun 13 Aprile
| | Task (~30 min) |
|---|---|
| **Dev A** | **Test mobile** — verificare fix della settimana precedente su dispositivo; annotare regressioni |
| **Dev B** | Creare `ticket_event.dart` e `ticket_state.dart` — stati: `Initial, Loading, Loaded, Purchasing, Success, Error` |
| **Dev C** | Edge function `check_ticket_availability(evento_id)` — ritorna posti disponibili e prezzo; testare su Dashboard |

---

### Mar 14 Aprile
| | Task (~30 min) |
|---|---|
| **Dev A** | Creare `ticket_purchase_screen.dart` con scaffold: AppBar, layout base, placeholder widget quantità e riepilogo |
| **Dev B** | Creare `ticket_bloc.dart` — evento `LoadTicketInfo`: chiama RPC `check_ticket_availability`, emette stato `Loaded` |
| **Dev C** | Edge function `create_ticket_order(evento_id, quantita, utente_id)` — inserisce ordine atomicamente, scala disponibilità |

---

### Mer 15 Aprile
| | Task (~30 min) |
|---|---|
| **Dev A** | Aggiungere widget selezione quantità biglietti (+/−) con limite max; mostrare prezzo unitario e totale dinamico |
| **Dev B** | Aggiungere evento `PurchaseTicket` nel BLoC — chiama `create_ticket_order`; emette stati appropriati |
| **Dev C** | Verificare edge function `create_ticket_order` — test concorrenza, availability scale, edge cases |

---

### Gio 16 Aprile
| | Task (~30 min) |
|---|---|
| **Dev A** | **Test mobile** — testare schermate biglietti su dispositivo fisico; annotare latenze e layout problems |
| **Dev B** | Aggiungere sezione riepilogo ordine in `ticket_purchase_screen.dart` e pulsante "Conferma acquisto" |
| **Dev C** | Test end-to-end flusso biglietti — acquisto → DB aggiornato → stato `confermato` |

---

### Ven 17 Aprile
| | Task (~30 min) |
|---|---|
| **Dev A** | Creare `ticket_confirmation_screen.dart`: riepilogo ordine, placeholder QR da ID ordine, pulsante "Torna alla home"; collegare pulsante in `event_detail_club_screen.dart` |
| **Dev B** | Test flusso completo acquisto biglietto su emulatore — loading state, errori, success; fix bug BLoC se presenti |
| **Dev C** | Fix bug emersi dai test flusso biglietti; verificare RLS policies in tutti i casi |

---

### Sab 18 Aprile 🔵
| | Task (~30 min) |
|---|---|
| **Dev A** 🔵 | **Test mobile** — test flusso completo biglietti su dispositivo fisico; annotare latenze e bug (no transizioni) |
| **Dev B** 🔵 | Code review `ticket_bloc.dart` — verificare stati, transizioni e gestione errori |
| **Dev C** 🔵 | Controllare log Supabase — verificare che le edge functions non abbiano errori silenziosi |

---

### Dom 19 Aprile 🔵
| | Task (~30 min) |
|---|---|
| **Dev A** 🔵 | Abbozzare layout `booking_screen.dart` — annotare componenti da costruire per prenotazione tavolo |
| **Dev B** 🔵 | Preparare dispositivo Android reale per i test della settimana prossima (abilitare developer mode, trust su ADB) |
| **Dev C** 🔵 | Scrivere query PostGIS di test nell'SQL Editor per `nearby_clubs(lat, lng, raggio_km)` |

---

## FASE 3 — Feature Core: Tavoli + Design Mark (20–26 aprile)

---

> ⚠️ **Design di Mark**: quando arriva, Dev A interrompe la task del giorno e dedica la sessione ad applicare le correzioni prioritarie. Usare il "Design Gap Document" (preparato il 12 apr) come guida.

---

### Lun 20 Aprile
| | Task (~30 min) |
|---|---|
| **Dev A** | Rifare scaffold `booking_screen.dart` (da design attuale o da Mark se già ricevuto): layout base, AppBar, sezioni "Dettagli tavolo" e "Riepilogo" |
| **Dev B** | Creare `booking_event.dart` e `booking_state.dart` — stati: `Initial, Loading, AvailabilityLoaded, Confirming, Success, Error` |
| **Dev C** | Edge function `check_table_availability(club_id, data, orario)` — verifica capienza residua per la fascia oraria |

---

### Mar 21 Aprile
| | Task (~30 min) |
|---|---|
| **Dev A** | **Test mobile** — testare schermate tavoli su dispositivo; annotare latenze e problemi UI (aggiornare Design Gap Document) |
| **Dev B** | Creare `booking_bloc.dart` — evento `CheckAvailability`: chiama RPC, emette `AvailabilityLoaded` con orari disponibili |
| **Dev C** | Edge function `create_table_booking(club_id, utente_id, num_persone, orario, note)` — crea prenotazione gestendo capienza massima |

---

### Mer 22 Aprile
| | Task (~30 min) |
|---|---|
| **Dev A** | Aggiungere in `booking_screen.dart`: widget selezione persone (+/−), chip orari disponibili, campo note speciali |
| **Dev B** | Aggiungere evento `ConfirmBooking` nel BLoC — chiama `create_table_booking`; gestire Success/Error state |
| **Dev C** | Edge function `cancel_booking(prenotazione_id)` con calcolo trattenuta: < 24h = 20%, < 6h = 50%, < 1h = 100% |

---

### Gio 23 Aprile
| | Task (~30 min) |
|---|---|
| **Dev A** | Creare `booking_confirmation_screen.dart` con riepilogo prenotazione; aggiungere badge/pulsante "Salta la coda" |
| **Dev B** | **Test biglietti su dispositivo Android fisico** — GPS reale, acquisto, QR confirmation |
| **Dev C** | Creare tabella `coda`: `id, evento_id, utente_id, posizione, stato`; scrivere RPC `skip_queue(utente_id, evento_id)` |

---

### Ven 24 Aprile
| | Task (~30 min) |
|---|---|
| **Dev A** | **Test mobile** — test flusso tavoli completo su dispositivo fisico; annotare bug e latenze |
| **Dev B** | Implementare logica "Salta la coda" nel BLoC: chiamata RPC `skip_queue` + snackbar di conferma |
| **Dev C** | Creare tabella `ordini_bottiglie`: `id, prenotazione_id, bottiglia_id, quantita, stato`; definire relazioni |

---

### Sab 25 Aprile — *Festa della Liberazione* 🔵
| | Task (~30 min) |
|---|---|
| **Dev A** 🔵 | Applicare correzioni design di Mark (se ricevuto) — allineare schermate prioritarie; aggiornare Design Gap Document |
| **Dev B** 🔵 | Code review `booking_bloc.dart` — verificare stati, transizioni e gestione errori |
| **Dev C** 🔵 | Ottimizzare indici DB su colonne frequenti: `evento_id`, `utente_id`, `club_id`, `stato` |

---

### Dom 26 Aprile 🔵
| | Task (~30 min) |
|---|---|
| **Dev A** 🔵 | **Test mobile** — test flusso completo; verificare fix applicati; aggiornare lista bug residui |
| **Dev B** 🔵 | Preparare checklist test iOS: schermate da testare, flussi da verificare, casi limite |
| **Dev C** 🔵 | Scrivere struttura catalogo bottiglie su Supabase: tabella `bottiglie` con `id, nome, prezzo, club_id` |

---

## FASE 4 — Secondarie + Design + Test Finale (27–30 aprile)

---

### Lun 27 Aprile
| | Task (~30 min) |
|---|---|
| **Dev A** | Applicare correzioni design Mark (se non ancora completato) — allineare `club_detail_screen.dart` e Home Screen; creare modale per ordine bottiglie |
| **Dev B** | Integrare Supabase Realtime nel BLoC: subscription a `ordini_bottiglie` per aggiornamenti live ordine |
| **Dev C** | Edge function `splitpay_request(prenotazione_id, amici[])` — divide il totale, genera link pagamento per ciascun amico |

---

### Mar 28 Aprile
| | Task (~30 min) |
|---|---|
| **Dev A** | **Test mobile** — test flusso completo app post-design; annotare bug residui e latenze; aggiornare lista finale |
| **Dev B** | Integrare BLoC splitpay: evento `RequestSplitPay` → chiama edge function → mostra stato pagamento amici |
| **Dev C** | Implementare RPC PostGIS `nearby_clubs(lat, lng, raggio_km)` in Supabase — sostituire query in `club_service.dart` |

---

### Mer 29 Aprile
| | Task (~30 min) |
|---|---|
| **Dev A** | UI cancellazione tavolo: pulsante "Cancella prenotazione" con modale che mostra trattenuta calcolata in tempo reale |
| **Dev B** | **Test iOS su dispositivo reale** (richiede Mac + Xcode) — GPS, login Google, biglietti, tavoli |
| **Dev C** | Audit sicurezza: revisione RLS su tutte le tabelle; validazione input nelle edge functions (importi > 0, campi obbligatori) |

---

### Gio 30 Aprile — **MVP DAY** ✅
| | Task (~30 min) |
|---|---|
| **Dev A** | **Test mobile finale** — loading state su tutti i pulsanti principali, empty state su liste vuote; lista bug residui per post-MVP |
| **Dev B** | Fix bug finali emersi dai test iOS/Android; verificare che tutti i flussi core funzionino end-to-end |
| **Dev C** | Preparare environment staging finale; aggiornare `docs/supabase_config.md` e `docs_utili/api_endpoints.md` |

---

## Riepilogo Milestone

| Data | Obiettivo |
|---|---|
| **Dom 12 apr** | Google Auth ✅ · Chiavi e tabelle Supabase verificate ✅ · Peso app analizzato ✅ |
| **Ven 17 apr** | Acquisto biglietti end-to-end funzionante (senza Stripe) |
| **Gio 23 apr** | Test biglietti su dispositivo Android reale ✅ |
| **Ven 24 apr** | Acquisto tavoli + salta coda funzionanti |
| **~Sab 25 apr** | Design di Mark applicato (appena ricevuto) |
| **Gio 30 apr** | MVP completo — tutti i flussi core testati su iOS e Android ✅ |

---

## Note operative
- 🔵 I giorni con task opzionali (weekend/festività) possono essere saltati senza impatto sul piano.
- Se una task richiede più di 30 min, si spezza nel giorno successivo senza spostare le altre.
- **Test mobile giornalieri**: ignorare volontariamente transizioni animate e comportamenti di scroll — verranno corretti in una fase separata post-MVP.
- **Design di Mark**: quando arriva, Dev A interrompe la task del giorno e applica le correzioni. Usare il "Design Gap Document" (preparato il 12 apr) come guida.
- **OAuth Apple** richiede Mac + Xcode: organizzare accesso entro il 28 aprile.
- **Test iOS fisico** (29 apr, Dev B): richiede Apple Developer Account attivo.
- **Stripe** è posticipato a dopo MVP — non blocca il completamento del piano.
