# TavoloDetailScreen — Dettaglio tavolo prenotato

## Cosa fa

Mostra il dettaglio di un **tavolo prenotato** dall'utente per una serata: nome del tavolo, dati dell'evento e (in futuro) la **piantina del locale** con la posizione del tavolo evidenziata.

È la schermata di destinazione dei flussi:
- "I miei ordini" → tab "Tavoli" → tap su un tavolo → questa schermata

---

## File coinvolti

```
tavolo_detail_screen/
└── tavolo_detail_screen.dart   <- UI (StatelessWidget, no BLoC)
```

Schermata **stateless**: legge tutto dagli arguments della rotta. Niente caricamenti, niente state interno.

---

## Argomenti in input

Riceve via `ModalRoute.of(context).settings.arguments` una `Map<String, dynamic>` che è la stessa restituita da [`OrdersService.getTavoliOrdini()`](../../core/services/orders_service.dart).

Struttura attesa (parziale):

```dart
{
  'eventi': {
    'nome_evento': '...',
    'data_evento': '...',
    'locali': {
      'nome_locale': '...',
      'piantina_url': '...',  // colonna futura, oggi può essere null
    }
  },
  'tavoli': {
    'nome_tavolo': '...',
  }
}
```

---

## Stato attuale e nota importante

La schermata legge una colonna `piantina_url` da `locali`. **Al momento questa colonna non esiste ancora nel DB** — è una predisposizione per quando si vorrà mostrare la mappa fisica del locale con la posizione del tavolo. Finché la colonna è assente, il valore è `null` e l'UI mostra un fallback.

> Prima di abilitare la feature in produzione: aggiungere la colonna `piantina_url text` a `locali` e popolarla.

---

## Dettagli implementativi

**State management:** nessuno (`StatelessWidget`).

**Layout:** box principale con bordo blu brand (`#1D00FF`), header in alto con il nome del tavolo e (quando ci sarà) immagine della piantina al centro.

**Navigazione "Torna indietro":** chiama `NavigatorService.goBack()` esplicitamente, non si appoggia al `Navigator` standard di Material.

---

## Dipendenze

| Da dove | Cosa usa |
|---|---|
| `core/services/navigator_service.dart` | `goBack()` |
| `widgets/custom_top_bar.dart`, `widgets/shared_footer.dart` | Top bar e bottom nav |
| `widgets/app_loading_indicator.dart` | Spinner brand (al momento non usato in UI, importato per coerenza) |
