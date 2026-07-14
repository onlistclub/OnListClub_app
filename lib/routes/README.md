# `lib/routes/`

Mappa delle rotte statiche dell'app. La definizione è centralizzata qui per evitare
stringhe magiche sparse nei push del Navigator.

## File

- **`app_routes.dart`** — classe `AppRoutes` con due ruoli:
  1. **Costanti `static const String`** per ogni nome di rotta (`/splash_screen`,
     `/home_screen`, ecc.). Usa sempre queste costanti, mai stringhe hardcoded.
  2. **Mappa `routes`** consumata da `MaterialApp(routes: ...)` in
     [`lib/main.dart`](../main.dart), che associa ogni nome al `builder` statico
     dello screen corrispondente.

  `initialRoute` è impostata su `splashScreen`.

- **`page_transitions.dart`** — transizione unica dell'app (`AppTransition.fade` /
  `AppTransition.sharedAxis`) e `AppPageRoute`, la `PageRoute` che implementa lo
  **swipe-back**.

## Swipe-back

Si torna indietro trascinando dal bordo sinistro verso destra. Il gesto non ha
un'animazione propria: pilota all'indietro il controller della rotta, cioè
"scrubba" con il dito la stessa transizione di uscita che si vede premendo il
back. Attivo su iOS e Android.

È acceso su tutte le rotte tranne quelle in `AppRoutes._noBackGestureRoutes`: il
flusso pre-home (splash → auth → registrazione → posizione), la home stessa
(più indietro non c'è nulla) e `paymentSuccess` (ordine già creato, tornare al
carrello non ha senso). `AppPageRoute` lo disabilita comunque da sé quando la
rotta è la prima dello stack, quando un `PopScope` blocca il pop o quando c'è
un'animazione in corso.

Test: [`test/routes/page_transitions_test.dart`](../../test/routes/page_transitions_test.dart).

## Note

- `AppRoutes.eventDetailScreen` è un **alias retrocompatibile** che punta a
  `/home_screen`: serve a non rompere i vecchi push verso la ex-`EventDetailScreen`.
  La nuova home è `HomeScreen`.
- Quando aggiungi una nuova schermata:
  1. Aggiungi `static const String myNewScreen = '/my_new_screen';`
  2. Registra la riga `myNewScreen: MyNewScreen.builder` nella mappa `routes`.
  3. Esponi `static Widget builder(BuildContext context)` nel widget di schermata
     (di solito wrappato in un `BlocProvider`).
