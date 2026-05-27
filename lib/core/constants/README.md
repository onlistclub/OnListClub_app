# `lib/core/constants/`

Valori costanti statici condivisi dall'app: path di asset, chiavi note, identificatori.
Per ora c'è solo un file, ma la cartella è il punto di atterraggio per future
costanti (chiavi di `shared_preferences`, nomi di tabelle Supabase, ecc.).

## File

| File | Cosa contiene |
|---|---|
| `image_constant.dart` | Classe `ImageConstant` con i path di tutti gli asset immagine. Centralizza la base path (`assets/images/`) così da poter rinominare la cartella senza toccare tutta la UI. |
