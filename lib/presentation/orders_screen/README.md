# OrdersScreen — I miei ordini

## Cosa fa

Mostra all'utente lo **storico delle sue prenotazioni**, diviso in due tab:

1. **Prevendite** — biglietti acquistati (con stato confermato / annullato)
2. **Tavoli** — prenotazioni tavolo per le serate

Tap su una riga apre la schermata di dettaglio: [`PrevenditaDetailScreen`](../prevendita_detail_screen/README.md) o [`TavoloDetailScreen`](../tavolo_detail_screen/README.md).

---

## File coinvolti

```
orders_screen/
└── orders_screen.dart   <- UI + caricamento dati (setState)
```

Schermata "semplice": niente BLoC. Lo state interno (lista prevendite, lista tavoli, flag di loading) è gestito con `setState`.

---

## Come funziona (flusso)

```
Utente apre la schermata
        |
        v
initState:
   - crea TabController(length: 2)
   - chiama _loadData()
        |
        v
_loadData():
   Future.wait([
     OrdersService.getPrevenditeOrdini(),
     OrdersService.getTavoliOrdini(),
   ])
        |
        v
Le due liste arrivano in parallelo
        |
        v
setState aggiorna _prevendite, _tavoli, _isLoading=false
        |
        v
La UI mostra:
   tab "Prevendite" → ListView di card prevendite
   tab "Tavoli"     → ListView di card tavoli
        |
        v
Tap su una card:
   - Prevendita → NavigatorService.pushNamed(
       prevenditaDetailScreen, arguments: <map della prevendita>)
   - Tavolo     → NavigatorService.pushNamed(
       tavoloDetailScreen, arguments: <map del tavolo>)
```

---

## Dettagli implementativi

**State management:** `setState` puro + `TabController` per le tab.

**Caricamento parallelo:** le due query (`getPrevenditeOrdini`, `getTavoliOrdini`) vengono lanciate in parallelo con `Future.wait`, così la schermata si popola in un unico round-trip "logico" anche se sono due chiamate distinte. Vedi anche il commit `1225e02 perf(ordini): unisci i 5 round-trip degli ordini in 1 con embedding` che ha ottimizzato le query lato backend.

**Errori:** in caso di errore, la schermata smette di mostrare il loader e logga su `debugPrint`. Non c'è (per ora) un retry visibile in UI.

**Back button:** se c'è uno stack su cui tornare, `NavigatorService.goBack()`; altrimenti `pushNamedAndRemoveUntil(homeScreen)` per evitare di chiudere l'app a sorpresa.

**Date:** le date negli ordini sono formattate con `DateFormatter.formatLong` (es. *"15 giu 2026"*).

**Analytics:** `screenName = 'orders_list'`.

---

## Dati restituiti da `OrdersService`

`OrdersService.getPrevenditeOrdini()` e `OrdersService.getTavoliOrdini()` restituiscono `List<Map<String, dynamic>>` con un embedding nidificato (prenotazione → evento → locale). Per la struttura esatta vedi:
- [`lib/core/services/orders_service.dart`](../../core/services/orders_service.dart)
- I README di [`prevendita_detail_screen`](../prevendita_detail_screen/README.md) e [`tavolo_detail_screen`](../tavolo_detail_screen/README.md) descrivono la forma del singolo elemento (= dei arguments passati alla rotta di dettaglio).

---

## Dipendenze

| Da dove | Cosa usa |
|---|---|
| `core/services/orders_service.dart` | `getPrevenditeOrdini()`, `getTavoliOrdini()` |
| `core/utils/date_formatter.dart` | Formattazione date |
| `widgets/app_loading_indicator.dart` | Spinner di caricamento |
| `widgets/custom_top_bar.dart`, `widgets/shared_footer.dart` | Top bar e bottom nav |
