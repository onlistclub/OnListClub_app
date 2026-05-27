# `lib/theme/`

Design system applicato all'app. **La fonte ufficiale del design è
[`.claude/CLAUDE.md`](../../.claude/CLAUDE.md), sezione "Design System"** — i file
qui dentro sono l'implementazione Dart di quei valori.

## File

| File | Espone | Cosa fa |
|---|---|---|
| `theme_helper.dart` | `appTheme`, `theme`, `LightCodeColors`, `ThemeHelper` | Singleton per il `ThemeData` di MaterialApp e la palette colori dell'app (riga 49 in poi). |
| `text_style_helper.dart` | `TextStyleHelper.instance` | Tutte le `TextStyle` riusate (display, heading, body, caption) calibrate sul Figma con `size_utils.fSize` per essere responsive. |

## Regole

- **Non introdurre nuovi colori o raggi** che non siano nella sezione 2 del file
  `.claude/CLAUDE.md`. Se trovi un valore "quasi uguale" a uno ufficiale
  (`#1800D2` vs `#1900D8`), proponilo per consolidamento ma non cambiarlo
  unilateralmente.
- **Non hardcodare `TextStyle` nei widget**: usa `TextStyleHelper.instance.xxx`.
- **Niente font pesanti** aggiunti in `assets/fonts/`: la regola del progetto è
  preferire i font di sistema (`SF Pro` su iOS, `Roboto` su Android) e
  `google_fonts` per i pochi casi necessari. Vedi pubspec e CLAUDE.md.

> Discrepanza nota: alcuni nomi in `LightCodeColors` (`deep_purple_900 #1600BC`,
> `indigo_900 #090050`) sono leggermente diversi dai valori ufficiali di CLAUDE.md
> (`#1900D8`, `#060037`). Da consolidare — vedi sezione 2 del CLAUDE.md.
