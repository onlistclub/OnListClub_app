# CartScreen — Carrello

## Cosa fa

È il **carrello / checkout** dell'app. Mostra il riepilogo di quello che l'utente sta per acquistare (prevendita o tavolo) e, al tap del pulsante "Procedi al pagamento", crea effettivamente la prenotazione su Supabase chiamando `BookingService.createReservation()`.

Nell'MVP estate 2026 **non c'è un vero pagamento**: il pulsante "paga" crea la prenotazione e basta. L'integrazione Stripe è documentata come predisposizione futura (vedi [docs/database/stripe_integration_plan.md](../../../docs/database/stripe_integration_plan.md)).

---

## File coinvolti

```
cart_screen/
└── cart_screen.dart   <- UI + chiamata a BookingService (setState)
```

Schermata "semplice": niente BLoC. State con `setState` per `_isPaying` (loading spinner sul pulsante) e `_ticketQuantity` (per le prevendite).

---

## Argomenti in input

Riceve via `ModalRoute.of(context).settings.arguments` una `Map<String, dynamic>` che descrive l'oggetto in carrello. Il campo `type` discrimina il flusso:

- `type: 'table'` → prenotazione tavolo (con drink/bottiglie scelti)
- `type: 'ticket'` → acquisto di una prevendita (con quantità ticket)

Struttura attesa:

```dart
{
  'type': 'table' | 'ticket',
  'id_evento': '<uuid>',
  'ticketId': '<uuid prevendite>',   // solo se type=ticket
  'tableId':  '<uuid tavoli>',       // solo se type=table
  'drinkId':  '<uuid drink>',        // solo se type=table
  'quantity': 1,                     // bottiglie (per table)
  'nPersone': 4,                     // numero persone al tavolo
  'price':    '150€',
}
```

Se `args == null`, la schermata mostra lo stato "carrello vuoto".

---

## Come funziona (flusso)

```
Utente apre il carrello (con arguments dal pulsante "Aggiungi")
        |
        v
La UI mostra:
   - card del prodotto (nome locale, serata, tipo)
   - selettore quantità (solo per i ticket)
   - totale
   - pulsante "Procedi al pagamento"
        |
        v
Tap "Paga":
   setState(_isPaying = true)
        |
        v
BookingService.createReservation(
   bookingType, ticketId|tavoloId, drinkId,
   bottleQuantity, eventoId, nPersone, ticketHolders
)
        |
   |----+-----|
successo    errore
   |          |
   v          v
1. AnalyticsService.log('booking_payment_success', ...)
2. BadgeService.incrementNotificationBadge()
3. NavigatorService.pushNamed(PaymentSuccessScreen)
            |
            v
            SnackBar "Errore durante l'ordine: ..."
            setState(_isPaying = false)
```

---

## Dettagli implementativi

**State management:** `setState`. La schermata non ha logica complessa, è essenzialmente un wrapper UI attorno a una sola chiamata di servizio.

**Quantità ticket:** `_incQty()` / `_decQty()` aggiornano `_ticketQuantity` (minimo 1). Per i tavoli, `nPersone` arriva già fissato dagli arguments e non si modifica qui.

**Loading:** durante il pagamento, `_isPaying = true` disabilita il pulsante e mostra uno spinner; al termine torna `false` (anche in caso di errore).

**Notifica conferma:** subito dopo il successo, `BadgeService().incrementNotificationBadge()` incrementa il contatore della bottom nav così l'utente vede subito il bollino sulle notifiche.

**Analytics:** logga `booking_payment_success` con `type` e `amount`.

---

## Dipendenze

| Da dove | Cosa usa |
|---|---|
| `core/services/booking_service.dart` | `createReservation(...)` |
| `core/services/analytics_service.dart` | Log dell'evento di pagamento riuscito |
| `core/services/badge_service.dart` | Incremento badge notifiche |
| `core/services/navigator_service.dart` | Navigazione a `PaymentSuccessScreen` |
| `core/utils/responsive.dart` | Dimensioni responsive |
| `widgets/onlist_primary_button.dart` | Pulsante "Paga" |
