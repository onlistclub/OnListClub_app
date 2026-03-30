# LocationManualScreen — Selezione Città Manuale

## Cosa fa

Permette all'utente di selezionare la propria città manualmente, digitandola in un campo di ricerca.
Viene mostrata quando l'utente ha scelto "Ricordamelo più tardi" nella schermata dei permessi GPS.

L'utente digita il nome della città e vede suggerimenti in tempo reale. Seleziona una città e preme "Entra".

---

## File coinvolti

```
location_manual_screen/
├── location_manual_screen.dart       <- UI con campo ricerca e lista suggerimenti
└── bloc/
    ├── location_manual_bloc.dart     <- logica: ricerca città, salvataggio
    ├── location_manual_event.dart    <- eventi (cerca, seleziona, conferma)
    └── location_manual_state.dart   <- stato (lista città, città selezionata, loading)
```

---

## Come funziona (flusso)

```
Utente digita il nome della città
        |
        v
[LocationManualBloc] riceve SearchCittaEvent(query)
        |
        v
Cerca le città nel database Supabase (o lista locale)
        |
        v
Aggiorna state.cities con i risultati
        |
        v
Utente vede la lista di suggerimenti sotto il campo
        |
        v
Tap su una città
        |
        v
[LocationManualBloc] riceve SelectCittaEvent(citta)
        |
        v
Salva la città selezionata nello stato
Il controller del campo viene aggiornato con il nome della città
        |
        v
Tap su "Entra"
        |
        v
[LocationManualBloc] riceve SubmitLocationEvent
        |
        v
Salva la città in SharedPreferences / database
        |
        v
EventDetailScreen
```

---

## Logica del BLoC

### Ricerca in tempo reale
```dart
on<SearchCittaEvent>((event, emit) async {
  emit(state.copyWith(isLoadingCities: true, selectedCitta: null));
  final results = await _searchCitta(event.query);
  emit(state.copyWith(cities: results, isLoadingCities: false));
});
```

### Selezione città
Quando l'utente tocca un suggerimento, il BLoC aggiorna lo stato con la città selezionata e svuota la lista dei suggerimenti:
```dart
on<SelectCittaEvent>((event, emit) {
  emit(state.copyWith(
    selectedCitta: event.citta,
    cities: [],  // chiude la lista suggerimenti
  ));
});
```

La schermata ascolta questa variazione nel `BlocConsumer.listener` e sincronizza il `TextEditingController` con il nome della città selezionata:
```dart
if (state.selectedCitta != null && _ctrl.text != state.selectedCitta!.nomeCitta) {
  _ctrl.text = state.selectedCitta!.nomeCitta;
}
```

---

## Dettagli dell'UI

**Sfondo:** blu brillante `#0000FF`

**Campo città:** `TextField` semplice (non `TextFormField`) con bordo solo in basso (stile minimalista). Quando è in caricamento, mostra un piccolo `CircularProgressIndicator` come `suffixIcon`. Quando una città è selezionata, mostra un'icona spunta verde (`Icons.check_circle`).

**Lista suggerimenti:** una card con bordi arrotondati solo in basso, attaccata visivamente al campo sopra. I bordi del campo cambiano dinamicamente:
```dart
// Il campo ha bordi arrotondati in basso solo se NON ci sono suggerimenti
bottomLeft: Radius.circular(hasSuggestions ? 0 : 16),
bottomRight: Radius.circular(hasSuggestions ? 0 : 16),
```
Questo crea un effetto di "dropdown" che sembra un'unica componente.

**Separatori:** ogni voce della lista è separata da un `Divider` semitrasparente

**Pulsante "Entra":** disabilitato finché non viene selezionata una città (`state.selectedCitta == null`). Quando disabilitato, ha un'opacità ridotta.

---

## Modello dati: CittaModel

```dart
// lib/core/models/citta_model.dart
class CittaModel {
  final String nomeCitta;
  // ... altri campi (ID, provincia, ecc.)
}
```
