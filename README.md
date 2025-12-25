# OnListClub App

**OnListClub** è un'applicazione mobile sviluppata in **Flutter** progettata per la gestione di eventi e liste (club). Il progetto utilizza un'architettura basata su **BLoC** per la gestione dello stato e **Supabase** come backend per l'autenticazione e il database in tempo reale.

---

## 📋 Indice

- [Caratteristiche Principali](#-caratteristiche-principali)
- [Stack Tecnologico](#-stack-tecnologico)
- [Struttura del Progetto](#-struttura-del-progetto)
- [Prerequisiti](#-prerequisiti)
- [Configurazione e Installazione](#-configurazione-e-installazione)
- [Regole Critiche di Sviluppo](#-regole-critiche-di-sviluppo)
- [Gestione Assets e Font](#-gestione-assets-e-font)
- [Documentazione Aggiuntiva](#-documentazione-aggiuntiva)

---

## 🚀 Caratteristiche Principali

* **Autenticazione Sicura:** Login e Registrazione tramite Email/Password gestiti con Supabase Auth.
* **Social Login (In Sviluppo):** Predisposizione per autenticazione tramite Google e Apple ID.
* **Gestione Eventi:** Visualizzazione dettagliata degli eventi (`EventDetailScreen`).
* **Navigazione Fluida:** Gestione centralizzata delle rotte tramite `NavigatorService`.
* **UI Responsiva:** Adattamento alle dimensioni dello schermo con `Sizer` e blocco orientamento in Portrait.
* **Design Personalizzato:** Utilizzo di font custom ("Tilt Warp") e gradienti specifici.

---

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
---
## ⚙️ Git Path
    ```text
    feature/[feature_name] -> develop -> main
    ```
    ```sh
    git checkout -b [next_branch_name]
    git merge [previous_branch_name]
    ```
---

## 📂 Struttura del Progetto

Il codice sorgente si trova nella cartella `lib/` ed è organizzato secondo pattern architetturali scalabili (Feature-first / Clean Architecture semplificata):

```text
lib/
├── core/                   # Componenti core condivisi
│   ├── app_export.dart     # Export centralizzato delle dipendenze comuni
│   └── utils/              # Utility (NavigatorService, ImageConstant, SizeUtils)
├── presentation/           # UI e Logica (BLoC) divisi per feature
│   ├── authentication_screen/
│   │   ├── bloc/           # AuthenticationBloc, Events, States
│   │   ├── models/         # Modelli dati specifici della UI
│   │   └── authentication_screen.dart
│   ├── event_detail_screen/# Schermata dettagli evento
│   └── app_navigation_screen/
├── routes/                 # Definizione delle rotte (AppRoutes)
├── theme/                  # Stili, Temi e Helper per il testo
├── widgets/                # Widget riutilizzabili (CustomButton, CustomEditText)
└── main.dart               # Entry point e inizializzazione