# ClubDetailScreen — Dettaglio Club

## Cosa fa

Mostra tutte le informazioni di un club specifico:
- Foto del locale
- Nome e indirizzo
- Orario di apertura e prezzo ingresso
- Generi musicali
- Pulsante per prenotare
- Sezioni informative: Come arrivare (Google Maps), Recensioni (TripAdvisor), Trasporti
- Funzione preferiti (salva il club con animazione)

---

## File coinvolti

```
club_detail_screen/
├── club_detail_screen.dart         <- UI completa con animazioni
├── bloc/
│   ├── club_detail_bloc.dart       <- logica: carica dati, gestisce preferiti
│   ├── club_detail_event.dart      <- eventi (inizializzazione, preferito, navigazione)
│   └── club_detail_state.dart     <- stato (club, evento, isPreferito, badge)
└── models/
    └── club_detail_model.dart     <- modello dati della schermata
```

---

## Come arriva a questa schermata

Dalla `EventDetailScreen`, quando l'utente preme "RISERVA IL TUO POSTO ORA":
```dart
// event_detail_screen.dart
NavigatorService.pushNamed(
  AppRoutes.clubDetailScreen,
  arguments: state.hottestClub,  // LocaleModel
);
```

Il `ClubDetailScreen.builder` legge il `LocaleModel` dagli argomenti:
```dart
final locale = ModalRoute.of(context)!.settings.arguments as LocaleModel;
```

---

## Come funziona (flusso)

```
Schermata aperta con LocaleModel
        |
        v
[ClubDetailBloc] riceve ClubDetailInitialEvent
        |
        v
Carica l'evento di stasera per questo club
        |
        v
UI mostra tutti i dati con animazioni di entrata

Tap su stella preferiti (icona bookmark)
        |
        v
[ClubDetailBloc] riceve ToggleFavoriteEvent
        |
        v
Toggle isPreferito
        |-- diventa preferito --> badge "Club aggiunto ai preferiti" appare
        |-- rimosso dai preferiti --> badge sparisce

Tap su "RISERVA IL TUO POSTO ORA"
        |
        v
Naviga a BookingScreen con il LocaleModel
```

---

## Animazioni

Come in `EventDetailScreen`, usa animazioni in cascata con `_staggerCtrl` (1400ms).

In più ci sono due animazioni extra:

### Bookmark bounce
Quando si preme l'icona preferiti, l'icona fa un effetto "rimbalzo":
```dart
_bookmarkCtrl = AnimationController(duration: Duration(milliseconds: 300));
_bookmarkScale = TweenSequence([
  TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.35), weight: 50),  // cresce
  TweenSequenceItem(tween: Tween(begin: 1.35, end: 1.0), weight: 50),  // torna
]).animate(...);
```

### Badge slide-in
Quando il club viene aggiunto ai preferiti, una pillola blu appare dall'alto sull'immagine con slide + fade:
```dart
_badgeSlide = Tween<Offset>(begin: Offset(0, -1), end: Offset.zero).animate(...);
_badgeFade = CurvedAnimation(parent: _badgeCtrl, curve: Curves.easeOut);
```
Il badge viene sincronizzato con lo stato del BLoC nel `listener`:
```dart
listener: (context, state) => _syncBadgeAnimation(state.showFavoriteBadge),
```

---

## Sezioni informative

La schermata ha tre sezioni in fondo, separate da divisori:

**Come arrivare:** pulsante "Mappe" che apre Google Maps con l'indirizzo del club:
```dart
final uri = Uri.parse('https://maps.google.com/?q=$encoded');
await launchUrl(uri, mode: LaunchMode.externalApplication);
```

**Recensioni:** pulsante "TripAdvisor" che apre il link se disponibile nel `LocaleModel`. Se `linkTripadvisor` è null, il callback è null e il pulsante appare disabilitato.

**Trasporti:** al momento solo il titolo, senza pulsante (da sviluppare).

---

## Dettagli dell'UI

**Sfondo:** nero scuro `#0D0D0D` (uguale a EventDetailScreen)

**Icona preferiti:** `Icons.bookmark_border` se non preferito, `Icons.bookmark` se preferito. Colore blu `#0009FF` quando attivo, bianco quando inattivo.

**Info rows:** due righe con icone:
- Riga 1: orologio + orario evento + prezzo locale
- Riga 2: nota musicale + generi musicali

I generi vengono presi dall'evento di stasera se disponibili, altrimenti dal locale:
```dart
final generi = (evento?.generiMusicali.isNotEmpty == true)
    ? evento!.generiMusicali.join(' - ')
    : locale.generiString;
```

**AppBar:** logo OnList cliccabile (torna indietro con `NavigatorService.goBack`) + icona cerca. Uguale all'EventDetailScreen ma con la navigazione back abilitata.
