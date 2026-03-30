# BookingScreen — Prenotazione

## Cosa fa

Schermata di prenotazione del posto al club. Al momento è un **placeholder** — la funzionalità di prenotazione è ancora in sviluppo.

Mostra:
- Il nome e l'indirizzo del club per cui si sta prenotando
- Un box informativo che avvisa che la schermata è in costruzione

---

## File coinvolti

```
booking_screen/
└── booking_screen.dart    <- UI placeholder (nessun BLoC al momento)
```

---

## Come arriva a questa schermata

Dalla `ClubDetailScreen`, quando l'utente preme "RISERVA IL TUO POSTO ORA":
```dart
// club_detail_screen.dart
NavigatorService.pushNamed(
  '/booking_screen',
  arguments: locale,  // LocaleModel
);
```

La `BookingScreen` legge il `LocaleModel` dagli argomenti:
```dart
final locale = ModalRoute.of(context)?.settings.arguments as LocaleModel?;
```
Il `?` rende sicura la lettura: se gli argomenti non vengono passati, `locale` è null e il nome/indirizzo non viene mostrato (senza crash).

---

## Dettagli dell'UI

**Sfondo:** nero scuro `#0D0D0D`

**AppBar:** freccia indietro + testo "Prenota". La freccia chiama `NavigatorService.goBack`.

**Contenuto centrale:** centrato verticalmente nella schermata. Se `locale != null`, mostra nome e indirizzo del club sopra il box informativo.

**Box "in sviluppo":**
- Bordo blu semitrasparente `#0009FF` con opacità 0.4
- Icona `Icons.construction_rounded` blu
- Testo "Prenotazione in arrivo" + descrizione

---

## Prossimi sviluppi

Quando la funzionalità sarà implementata, questa schermata dovrà gestire:
- Selezione della data/serata
- Scelta del numero di posti
- Riepilogo e conferma
- Collegamento a un sistema di pagamento o lista d'attesa

Per questo motivo conviene aggiungere un BLoC quando si inizia l'implementazione reale.
