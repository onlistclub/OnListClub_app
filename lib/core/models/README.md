# `lib/core/models/`

Domain model condivisi tra più schermate. Ogni file qui rappresenta un'**entità del
dominio** (un locale, una serata, una città, una notifica) — di solito mappata 1:1
su una tabella Supabase. Sono modelli puri: nessun import di `flutter/material.dart`,
nessuna chiamata di rete.

Estendono `Equatable` per il confronto valore-per-valore usato dai BLoC.

> NB: i model "di schermata" (state delle form, view-model UI temporanei) NON vanno
> qui — vivono in `lib/presentation/<screen>/models/`.

## File

| File | Tabella Supabase | Cosa rappresenta |
|---|---|---|
| `locale_model.dart` | `locali` | Club/discoteca: nome, indirizzo, città, foto, generi musicali, prezzo indicativo, coordinate. |
| `serata_model.dart` | `eventi` | Evento/serata di un club: data, orari, biglietti, prezzo, locandina. (Nome legacy: serata.) |
| `citta_model.dart`  | `citta`   | Città: id, nome, coordinate. Usata dalla schermata di selezione manuale. |
| `notification_model.dart` | `notifiche` | Notifica utente: titolo, messaggio, tipo, stato letto/non letto. |
