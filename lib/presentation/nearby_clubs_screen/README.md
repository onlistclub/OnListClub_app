# NearbyClubsScreen — Locali vicini

## Cosa fa

Mostra la **lista dei club vicini** all'utente, con possibilità di filtrarli e visualizzarli anche su una **mappa**. Si raggiunge dalla home, tramite la voce "scopri locali" o la lente di ricerca.

I locali vengono ordinati per **distanza** o per **popolarità**, e si possono filtrare per:
- **Generi musicali** (es. techno, house, hip-hop)
- **Città** (utile quando l'utente cerca in un'altra zona)
- **Fascia di prezzo** (€ / €€ / €€€)
- **Stringa di ricerca** (per nome del locale)

---

## File coinvolti

```
nearby_clubs_screen/
└── nearby_clubs_screen.dart   <- UI + state della schermata (setState)
```

Schermata "semplice": niente BLoC. Lo stato locale (filtri, ordinamento, città custom) è gestito con `setState`.

---

## Come funziona (flusso)

```
Utente apre la schermata
        |
        v
_load() raccoglie i dati di posizione:
   1. raggio km dell'utente               (UserProfileManager)
   2. flag isGpsForced                    (LocationService)
   3. coordinate:
      - GPS in tempo reale (3s timeout)
      - se nega o timeout → città salvata in profilo
      - se anche quella manca → fallback su Roma
        |
        v
ClubService carica i locali entro il raggio
        |
        v
La lista viene filtrata e ordinata in memoria
in base a:
   _searchQuery, _selectedGeneri,
   _selectedCitta, _selectedPrezzo, _sortMode
        |
        v
Visualizzata come:
   - lista verticale di card (default)
   - mappa OpenStreetMap (toggle)
```

---

## Dettagli implementativi

**State management:** `setState` puro. Lo stato della schermata è autocontenuto, quindi non serve un BLoC.

**Mappa:** usa `flutter_map` con tile di OpenStreetMap e `latlong2` per le coordinate.

**Stock images fallback:** se un locale non ha foto, si usa una delle 4 immagini di stock in `assets/images/stock_club_<n>.jpg` (selezione deterministica in base all'id).

**Geolocator timeout:** la richiesta GPS scade in 3 secondi (`timeLimit: Duration(seconds: 3)`) per non bloccare l'apertura della schermata se la posizione è lenta.

**Analytics:** `screenName = 'search_nearby'` (via mixin `ScreenAnalytics`).

---

## Filtri disponibili

| Filtro | Valore | Come è applicato |
|---|---|---|
| Ricerca testuale | `_searchQuery` | Match su `nome.toLowerCase()` |
| Generi musicali | `Set<String> _selectedGeneri` | Intersezione con `generi_musicali` del locale |
| Città | `Set<String> _selectedCitta` | Match esatto sul nome città |
| Prezzo | `int? _selectedPrezzo` (1/2/3) | Confronto con la colonna `fascia_prezzo` |
| Ordinamento | `_SortMode` (distanza / popolarità) | Sort della lista in memoria |

---

## Dipendenze

| Da dove | Cosa usa |
|---|---|
| `core/services/club_service.dart` | Fetch dei locali |
| `core/services/location_service.dart` | Flag `isGpsForced`, città salvata |
| `core/services/user_profile_manager.dart` | Raggio km dell'utente |
| `core/models/locale_model.dart`, `citta_model.dart` | Modelli |
| `flutter_map` + `latlong2` + `geolocator` | Mappa e posizione |
