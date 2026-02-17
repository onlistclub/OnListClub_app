# Info tecnica del progetto


## 🛠 Stack Tecnologico

* **Framework:** [Flutter](https://flutter.dev/) (SDK: `^3.6.0`)
* **Linguaggio:** Dart
* **Backend & Auth:** [Supabase Flutter](https://pub.dev/packages/supabase_flutter) (`^2.6.0`)
* **State Management:** [Flutter Bloc](https://pub.dev/packages/flutter_bloc) (`^9.1.1`)
* **Confronto Oggetti:** [Equatable](https://pub.dev/packages/equatable)
* **Networking/Immagini:** `cached_network_image`, `connectivity_plus`
* **Storage Locale:** `shared_preferences`
* **UI/SVG:** `flutter_svg`, `gradient_borders`

---

## ⚙️ Git Path
```text
feature/[feature_name]
    |
    |
develop
    |
    |
main
```

## ⚙️ Merging
```text
feature/[feature_name] -> develop -> main
```
```sh
git checkout -b [next_branch_name]
git merge [previous_branch_name]

## Ambiente di sviluppo
- Configura `env.json` con le chiavi:
```json
{
  "DATABASE_URL": "https://<project>....",
  "DATABASE_ANON_KEY": "<anon-key>"
}
```