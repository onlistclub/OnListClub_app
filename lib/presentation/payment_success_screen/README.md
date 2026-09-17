# PaymentSuccessScreen — Ordine effettuato

## Cosa fa

Schermata di conferma mostrata dopo "PRENOTA ORA" (`BookingScreen`). Riceve
`{'idPrenotazione': ...}` negli arguments e mostra i biglietti di QUELLA
prenotazione (fallback: la prenotazione con `created_at` più recente).

Design: CSS `docs/figma_screen/off/NUOVO/Ordine Effettuato + Visualizza Ticket*.css`
(aggiornati il 16/09/2026).

## Layout

- Intestazione "ORDINE" (bianco che sfuma) + "effettuato" + spunta blu.
- "Visualizza ticket" e i biglietti chiusi (`TicketCollapsedCard`): nome del
  locale sfumato con "Apri biglietto" attaccato sotto.
- Tap su un biglietto: si apre (`TicketFrontCard`) e l'intestazione sparisce;
  "VISUALIZZA QR CODE" o il tap sulla card lo girano (`FlipCard`) sul retro
  col QR reale (`TicketBackCard`).
- "torna alla home": fisso appena sopra la footer, con la freccia verso
  l'icona Home, finché i biglietti sono chiusi; con un biglietto aperto
  scende in coda allo scroll.

## Dipendenze

| Da dove | Cosa usa |
|---|---|
| `core/services/orders_service.dart` | `getPrevenditeOrdini()` |
| `core/services/navigator_service.dart` | ritorno alla Home |
| `widgets/ticket_cards.dart`, `widgets/flip_card.dart` | card biglietto |
| `widgets/shared_footer.dart` | ingombro della footer globale |
