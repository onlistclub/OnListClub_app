# HomeScreen — Schermata Home

## Cosa fa

È la **schermata principale** dell'app, quella che l'utente vede dopo il login (o subito, se ha già una sessione attiva). Mostra:

- I **club vicini** all'utente, in base alla posizione (GPS o città manuale)
- Le **serate in evidenza** del momento
- L'accesso alle altre sezioni tramite la bottom navigation bar

All'apertura, controlla anche se ci sono **nuovi eventi nei locali preferiti** dell'utente, e li trasforma in notifiche.

---

## File coinvolti

```
home_screen/
├── home_screen.dart          <- UI della schermata (con animazioni staggered)
├── bloc/
│   ├── home_bloc.dart        <- carica i locali e gli eventi via ClubService
│   ├── home_event.dart       <- eventi (es. HomeInitialEvent)
│   └── home_state.dart       <- stato corrente (loading, club, errore)
└── models/                   <- view-model UI temporanei della schermata
```

---

## Come funziona (flusso)

```
Utente apre la home
        |
        v
HomeScreen.builder costruisce il widget
        |
        v
BlocProvider crea HomeBloc e gli manda HomeInitialEvent
        |
        v
HomeBloc carica:
   - locali vicini       (ClubService)
   - serate / eventi     (ClubService, già in embed)
        |
        v
In parallelo:
   NotificationService.checkNewEventsForFavorites()
   crea notifiche per nuovi eventi sui locali preferiti
        |
        v
La UI parte con un'animazione staggered (durata ~1.4s):
   barra in alto → hero → titolo → sottotitolo → card → bottom nav
```

---

## Dettagli implementativi

**State management:** `HomeBloc` (flutter_bloc). Stato letto via `BlocBuilder` / `BlocConsumer`.

**Animazioni:** la schermata usa un singolo `AnimationController` (`_staggerCtrl`, durata 1400 ms) e definisce 7 coppie di `Animation<double>` + `Animation<Offset>` per far entrare in sequenza ogni sezione (app bar, hero, titolo, sottotitolo, sezione club, card, bottom nav).

**Analytics:** apertura e tempo di permanenza (`screen_home` / `page_exit`) li registra `RootShell` al cambio tab, non la schermata: la Home è montata insieme alle altre tab. Lo State usa il mixin `ScreenAnalytics` (`screenName = 'home'`) solo per `load_time_home`. Ogni tap che apre un club registra `home_tap` con l'elemento toccato (`hero`, `riserva_posto`, `consigliati_card`, `consigliati_prenota`).

**Notifiche:** in `initState` viene chiamata `NotificationService.checkNewEventsForFavorites()` — fire-and-forget, non blocca il caricamento della UI.

---

## Dipendenze

| Da dove | Cosa usa |
|---|---|
| `core/services/club_service.dart` | Fetch dei locali e degli eventi |
| `core/services/notification_service.dart` | Notifica nuovi eventi dei preferiti |
| `core/models/locale_model.dart` | Modello del club |
| `widgets/custom_top_bar.dart`, `widgets/shared_footer.dart` | Top bar e bottom nav |

---

## Navigazione

Le altre schermate dell'app sono raggiungibili tramite:
- **Bottom nav** (`SharedFooter`) → Home, Carrello, Notifiche, Profilo
- **Tap su un club** → `ClubDetailScreen` (dettagli del locale e sue serate)
- **Tap su una serata** (dalla scheda club) → `EventInfoPopupScreen` (pop-up info serata, Figma 19)
