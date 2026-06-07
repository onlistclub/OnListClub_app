# PaymentSuccessScreen — Conferma ordine

## Cosa fa

È la **schermata di conferma** mostrata dopo che `CartScreen` ha creato con successo la prenotazione su Supabase. Comunica all'utente che l'ordine è andato a buon fine.

Visualizza un titolo grande "ORDINE EFFETTUATO / Buon divertimento!" e un unico pulsante: **"TORNA NELLA HOME"**.

---

## File coinvolti

```
payment_success_screen/
└── payment_success_screen.dart   <- UI (StatelessWidget, no BLoC)
```

Schermata **stateless**: nessun caricamento, nessun stato interno. Pura UI di conferma.

---

## Come funziona

```
CartScreen → pagamento riuscito
        |
        v
NavigatorService.pushNamed(PaymentSuccessScreen)
        |
        v
La schermata mostra:
   - barra in alto (CustomTopBar)
   - titolo "ORDINE EFFETTUATO" (display 64pt)
   - sottotitolo "Buon divertimento!" (body 20pt)
   - pulsante "TORNA NELLA HOME"
        |
        v
Tap sul pulsante:
   NavigatorService.pushNamedAndRemoveUntil(homeScreen)
   (svuota lo stack: l'utente non può tornare al carrello)
```

---

## Dettagli implementativi

**State management:** nessuno (`StatelessWidget`).

**Layout:** segue il design Figma "off / 21" con titolo a cascata sfasato (le righe partono da posizioni orizzontali diverse). Per evitare overflow sui telefoni stretti, il blocco di testo è dentro un `FittedBox(BoxFit.scaleDown)` che lo riduce proporzionalmente mantenendo la spaziatura originale.

**Navigazione:** il pulsante usa `pushNamedAndRemoveUntil` invece di `pushNamed`, così l'intero stack di navigazione viene resettato. L'utente non può tornare indietro a `CartScreen` con il back, perché a quel punto la prenotazione è già stata creata.

---

## Dipendenze

| Da dove | Cosa usa |
|---|---|
| `core/services/navigator_service.dart` | `pushNamedAndRemoveUntil(homeScreen)` |
| `theme/onlist_text_styles.dart` | Stili `display64Light`, `title36Light`, `body20Light` |
| `theme/onlist_colors.dart` | Gradient `screenBackground` |
| `widgets/onlist_primary_button.dart` | Pulsante "TORNA NELLA HOME" |
| `widgets/custom_top_bar.dart`, `widgets/shared_footer.dart` | Top bar e bottom nav |

---

## Cosa NON contiene

A differenza di `PrevenditaDetailScreen`, questa schermata **non mostra il QR code**: serve solo come transizione visiva. Il QR viene mostrato successivamente da `PrevenditaDetailScreen` quando l'utente apre la propria prevendita dalla sezione "I miei ordini".
