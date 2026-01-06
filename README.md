<<<<<<< HEAD
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

## ⚙️ Merging
```text
feature/[feature_name] -> develop -> main
```
```sh
git checkout -b [next_branch_name]
git merge [previous_branch_name]
```

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
=======
# OnListClub - For Developper

## Ambiente di sviluppo
- Configura `env.json` con le chiavi:
```json
{
  "DATABASE_URL": "https://<project>....",
  "DATABASE_ANON_KEY": "<anon-key>"
}
```

## Configurazioni
- Inizializzazione: [main.dart](file:///c:/Users/lucaa/git/work/OnListClub_app/lib/main.dart#L36-L55)
- Rotte: login come schermata iniziale: [app_routes.dart](file:///c:/Users/lucaa/git/work/OnListClub_app/lib/routes/app_routes.dart#L10-L27)
- Normalizzazione telefono (E.164): [phone_utils.dart](file:///c:/Users/lucaa/git/work/OnListClub_app/lib/core/utils/phone_utils.dart)
- Persistenza atomica post-verifica: [user_profile_manager.dart](file:///c:/Users/lucaa/git/work/OnListClub_app/lib/core/utils/user_profile_manager.dart#L65-L89), [register_service.dart](file:///c:/Users/lucaa/git/work/OnListClub_app/lib/core/services/register_service.dart)

---

## Login e Registrazione + Verifica
### Architettura Generale
- Flutter + BLoC per gestione stato e UI.
- Supabase Auth per autenticazione/registrazione.
- Persistenza post-verifica via RPC SQL atomica.

```mermaid
flowchart TD
  UI[SignUpScreen] -->|Eventi BLoC| BLOC[SignUpBloc]
  BLOC -->|auth.signUp + metadati| Auth[Supabase Auth]
  Confirm[Conferma Email] --> Login[Login]
  Login --> Manager[UserProfileManager.ensureProfileExists]
  Manager --> RPC[register_user_transaction (SQL)]
  RPC --> DB[(users, users_phones, countries)]
```

### Flusso Logico Principale
1. Registrazione: salvataggio metadati in `auth.users` (temporaneo, niente scrittura diretta su tabelle pubbliche).
2. Verifica email e login.
3. Post-verifica: chiamata RPC transazionale che inserisce/aggiorna:
   - `users`: `nome`, `cognome`, `data_nascita`, `maggiorenne`.
   - `users_phones`: `user_id`, `country_id`, `telefono`, `is_primary`, `is_verified`.

### Dipendenze e Requisiti Tecnici
- Flutter 3.6+
- Pacchetti: `supabase_flutter`, `flutter_bloc`, `equatable`, `intl_phone_field`.
- Supabase:
  - Funzione RPC: [register_user_transaction.sql](file:///c:/Users/lucaa/git/work/OnListClub_app/supabase/sql/register_user_transaction.sql)
  - Grant esecuzione:
    ```sql
    grant execute on function public.register_user_transaction(
      uuid, text, text, text, date, text, text
    ) to authenticated;
    ```
  - Indice consigliato:
    ```sql
    create unique index if not exists users_phones_user_id_tel_uq
      on public.users_phones(user_id, telefono);
    ```
### Avvio e test

- Avvio:
```bash
flutter run
```
- Test unitari (es. calcolo maggiore età):
```bash
flutter test test/core/utils/age_calculator_test.dart
```

### Relazioni tra Tabelle (concettuale)
- `users (1) ────< (N) users_phones (N) >──── (1) countries`
  - PK/FK: `users.id` (uuid), `users_phones.user_id` (uuid FK), `users_phones.country_id` (uuid FK).

**Esempi Query**:
```sql
-- Telefono principale
select up.telefono, c.name, c.dial_code
from public.users_phones up
left join public.countries c on c.id = up.country_id
where up.user_id = 'UUID_UTENTE' and up.is_primary = true;

-- Utenti maggiorenni
select id, nome, cognome, email
from public.users
where maggiorenne = true;
```

### Processo di Login (dettagli)
1. UI raccoglie credenziali: [authentication_screen.dart](file:///c:/Users/lucaa/git/work/OnListClub_app/lib/presentation/authentication_screen/authentication_screen.dart).
2. BLoC esegue login: [authentication_bloc.dart](file:///c:/Users/lucaa/git/work/OnListClub_app/lib/presentation/authentication_screen/bloc/authentication_bloc.dart#L65-L73).
3. Verifica email dalla schermata dedicata: [welcome_bloc.dart](file:///c:/Users/lucaa/git/work/OnListClub_app/lib/presentation/welcome_screen/bloc/welcome_bloc.dart#L120-L135).
4. Persistenza definitiva: [user_profile_manager.dart](file:///c:/Users/lucaa/git/work/OnListClub_app/lib/core/utils/user_profile_manager.dart#L65-L89).

#### Esempi di Codice

UI: Tasto "Accedi" per login [authentication_screen.dart:L187-L194](file:///c:/Users/lucaa/git/work/OnListClub_app/lib/presentation/authentication_screen/authentication_screen.dart#L187-L194)

```dart
  void _onTapAccedi(BuildContext context) {
    final bloc = context.read<AuthenticationBloc>();
    final state = bloc.state;

    if (state.formKey?.currentState?.validate() ?? false) {
      bloc.add(LoginButtonPressedEvent());
    }
  }
```
---

BLoC: autenticazione con Supabase [authentication_bloc.dart:L58-L79](file:///c:/Users/lucaa/git/work/OnListClub_app/lib/presentation/authentication_screen/bloc/authentication_bloc.dart#L58-L79)

```dart
emit(state.copyWith(isLoading: true));

  _onLoginButtonPressed(
    LoginButtonPressedEvent event,
    Emitter<AuthenticationState> emit,
  ) async {
    emit(state.copyWith(isLoading: true));

    try {
      final email = state.authenticationModel?.email ?? '';
      final password = state.authenticationModel?.password ?? '';
      final client = Supabase.instance.client;

      await client.auth.signInWithPassword(email: email, password: password);

      // Ensure profile exists in public.users table (post-verification check)
      await UserProfileManager().ensureProfileExists();

      emit(state.copyWith(isLoading: false, isLoginSuccess: true));

      state.emailController?.clear();
      state.passwordController?.clear();
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        errorMessage: e is AuthException ? e.message : 'Login fallito! Riprova di nuovo.',
      ));
    }
```

---

Verifica email: login dalla VerificationScreen [verification_bloc.dart:L109-L134](file:///c:/Users/lucaa/git/work/OnListClub_app/lib/presentation/welcome_screen/bloc/welcome_bloc.dart#L109-L134)

```dart
 Future<void> _onCheckVerification(
    CheckVerificationEvent event,
    Emitter<verificationState> emit,
  ) async {
    if (state.isExpired) {
       debugPrint('[verificationBloc] Attempted login after expiration.');
       return; 
    }

    emit(state.copyWith(isLoading: true, errorMessage: null));

    try {
      final client = Supabase.instance.client;
      final email = state.email;
      final password = state.password;

      debugPrint('[verificationBloc] Verifying email for: $email');

      if (email == null || password == null) {
        emit(state.copyWith(
            isLoading: false, errorMessage: "Credenziali mancanti."));
        return;
      }

      // Attempt login to check verification status
      final response = await client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user != null && response.session != null) {
        debugPrint('[verificationBloc] Verification successful. User logged in.');
        
        // Ensure profile exists in public.users table (post-verification check)
        await UserProfileManager().ensureProfileExists();

        emit(state.copyWith(isLoading: false, isVerified: true));
      } else {
        // This block might not be reached if signIn throws on unverified email
        // depending on Supabase config.
         debugPrint('[verificationBloc] Login success but no session.');
         emit(state.copyWith(isLoading: false, isVerified: true));
      }
```
---

Pagina profilo: ancora da modificare [user_profile_manager.dart:L66-L78](file:///c:/Users/lucaa/git/work/OnListClub_app/lib/core/utils/user_profile_manager.dart#L66-L78)

Gestione errori:
- Messaggi utente con SnackBar e log in caso di problemi di login/verifica.

Sicurezza:
- Password/Hash gestiti server-side da Supabase Auth.
- Token/Sessions sicuri tramite SDK.
- Persistenza su tabelle pubbliche solo post-verifica, limitando cirschi

---

## Licenza
- Progetto interno OnListClub. Vedere la [licenza](file:///c:/Users/lucaa/git/work/OnListClub_app/LICENSE) per i dettagli.

>>>>>>> b4a5980 (inserito:)
