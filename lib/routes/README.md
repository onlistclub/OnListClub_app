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

## Note

- `AppRoutes.eventDetailScreen` è un **alias retrocompatibile** che punta a
  `/home_screen`: serve a non rompere i vecchi push verso la ex-`EventDetailScreen`.
  La nuova home è `HomeScreen`.
- Quando aggiungi una nuova schermata:
  1. Aggiungi `static const String myNewScreen = '/my_new_screen';`
  2. Registra la riga `myNewScreen: MyNewScreen.builder` nella mappa `routes`.
  3. Esponi `static Widget builder(BuildContext context)` nel widget di schermata
     (di solito wrappato in un `BlocProvider`).
