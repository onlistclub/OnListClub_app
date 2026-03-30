# EventDetailScreen — Schermata Home

## Cosa fa

È la **schermata principale** dell'app dopo il login. Mostra:
- Il club più popolare del momento ("hottest club") con foto e nome
- Un pulsante per prenotare un posto
- La serata in corso questa sera (se disponibile)
- Una barra di navigazione in basso

---

## File coinvolti

```
event_detail_screen/
├── event_detail_screen.dart         <- UI con animazioni e layout
├── bloc/
│   ├── event_detail_bloc.dart       <- logica: carica dati da Supabase
│   ├── event_detail_event.dart      <- eventi (inizializzazione, navigazione tab)
│   └── event_detail_state.dart     <- stato (club, evento, tab selezionato)
└── models/
    └── event_detail_model.dart     <- modello dati della schermata
```

---

## Come funziona (flusso)

```
Schermata aperta
        |
        v
[EventDetailBloc] riceve EventDetailInitialEvent
        |
        v
Fetch da Supabase: club più popolare + evento di stasera
        |
        v
Stato aggiornato con hottestClub e eventoOggi
        |
        v
UI mostra i dati con animazioni di entrata

Tap su "RISERVA IL TUO POSTO ORA"
        |
        v
Naviga a ClubDetailScreen passando l'oggetto LocaleModel
```

---

## Animazioni (Staggered Entrance)

Questa schermata usa un sistema di **animazioni in cascata**: ogni elemento appare con un leggero ritardo rispetto al precedente, creando un effetto di entrata fluido e sequenziale.

Due `AnimationController` coordinano tutto:
```dart
_staggerController = AnimationController(duration: Duration(milliseconds: 1400));
_heroController = AnimationController(duration: Duration(milliseconds: 800));
```

Ogni elemento ha la propria coppia di animazioni (fade + slide/scale), ognuna con un `Interval` che definisce quando parte e quando finisce nell'arco dei 1400ms:

| Elemento | Parte a | Finisce a |
|---|---|---|
| AppBar | 0ms | 390ms |
| Immagine hero | 100ms | 600ms |
| Titolo club | 250ms | 700ms |
| Indirizzo | 350ms | 800ms |
| Pulsante prenotazione | 450ms | 900ms |
| Sezione "Questa sera" | 600ms | 1050ms |
| Card evento | 750ms | 1200ms |
| Barra navigazione | 900ms | 1400ms |

```dart
_staggerController.forward();  // avvia tutto in initState
```

---

## Widget _AnimatedPressButton

Un widget riutilizzabile che aggiunge un effetto di "pressione" (scala al 95%) ai pulsanti principali:
```dart
// Quando si preme il dito:
_controller.forward();   // riduce a 0.95

// Quando si rilascia:
_controller.reverse();   // torna a 1.0
widget.onPressed();      // esegue l'azione
```

---

## Dettagli dell'UI

**Sfondo:** nero scuro `#0D0D0D`

**AppBar:** logo OnList a sinistra, icona cerca a destra. Nessuna barra standard di Flutter — è costruita manualmente come `Row`.

**Immagine hero:** `Image.network` dentro un `ClipRRect` con bordi arrotondati. Se l'URL non è disponibile o l'immagine non carica, viene mostrato un widget vuoto senza errori visibili.

**Card "Questa sera":** appare solo se `state.eventoOggi != null`. Mostra l'immagine della locandina, il nome e l'orario dell'evento.

**Barra di navigazione:** 4 icone (home, carrello, campanella, utente). L'icona selezionata appare in bianco e con scala 1.2, le altre in grigio con opacità 0.5. L'animazione di scala e opacità usa `AnimatedScale` e `AnimatedOpacity` con durata 200ms.

---

## Navigazione dal bottom nav

I tab della barra navigazione non cambiano schermata — inviano un evento al BLoC che aggiorna `selectedBottomNavIndex`:
```dart
context.read<EventDetailBloc>().add(BottomNavItemSelectedEvent(index));
```

La navigazione verso altre schermate (es. prenotazione) avviene dai pulsanti nel contenuto.
