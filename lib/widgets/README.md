# `lib/widgets/`

Componenti UI **riutilizzabili globali**, condivisi tra più schermate. Tutto ciò
che è specifico di una sola schermata vive in `lib/presentation/<screen>/` accanto
al suo file UI.

Convenzioni:
- Tutti i widget qui sono `StatelessWidget` o `StatefulWidget` autonomi, mai
  collegati a un singolo BLoC di schermata.
- Devono rispettare i token del design system (vedi [theme/README.md](../theme/README.md)).
- I path delle immagini passano da `ImageConstant`
  ([core/constants/](../core/constants/)), mai stringhe hardcoded.

## File

| File | Cosa fa |
|---|---|
| `app_loading_indicator.dart` | `CircularProgressIndicator` con il colore brand (`#1D00FF`). Da usare ovunque serva uno spinner, per consistenza. |
| `custom_button.dart` | Button configurabile (testo, colore, bordo, padding, dimensioni responsive). Sostituisce `ElevatedButton` standard. |
| `custom_edit_text.dart` | Input text configurabile (email, password, generico) con validazione e stile coerente. |
| `custom_image_view.dart` | Widget unico per mostrare immagini di qualsiasi tipo (rete con `cached_network_image`, SVG con `flutter_svg`, file locale, asset). Decide il renderer guardando l'estensione/prefisso del path. |
| `custom_top_bar.dart` | App bar custom dell'app (logo OnList + icone profilo/ricerca). Variante "isHome" e variante con back. |
| `shared_footer.dart` | Bottom navigation bar condivisa tra le schermate principali. Legge il badge notifiche da `BadgeService`. |
