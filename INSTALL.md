# Guida all'installazione — OnListClub

Questa guida ti accompagna passo per passo: dall'installazione di Flutter fino all'avvio dell'app su Android e iPhone.

---

## Indice

1. [Requisiti di sistema](#1-requisiti-di-sistema)
2. [Installa Flutter](#2-installa-flutter)
3. [Installa Android Studio e Android SDK](#3-installa-android-studio-e-android-sdk)
4. [Configurazione per iOS (solo macOS)](#4-configurazione-per-ios-solo-macos)
5. [Clona il progetto e configura l'ambiente](#5-clona-il-progetto-e-configura-lambiente)
6. [Avvia l'app su Android](#6-avvia-lapp-su-android)
7. [Avvia l'app su iPhone / Simulatore iOS](#7-avvia-lapp-su-iphone--simulatore-ios)
8. [Verifica tutto funzioni](#8-verifica-tutto-funzioni)
9. [Problemi comuni](#9-problemi-comuni)
10. [Workflow Git](#10-workflow-git)

---

## 1. Requisiti di sistema

| Sistema operativo | Android | iOS |
|---|---|---|
| Windows 10/11 | SI | NO (iOS richiede macOS) |
| macOS 12+ | SI | SI |
| Linux | SI | NO |

**Spazio disco minimo:** 10 GB liberi
**RAM minima:** 8 GB (16 GB consigliati)

---

## 2. Installa Flutter

### Passo 1 — Scarica Flutter

Vai su [flutter.dev/docs/get-started/install](https://docs.flutter.dev/get-started/install) e scegli il tuo sistema operativo.

**Windows:**
1. Scarica il file `.zip` dell'SDK Flutter
2. Estrailo in una cartella senza spazi, ad esempio: `C:\flutter`
3. **Non** metterlo in `C:\Program Files` (richiede permessi speciali)

**macOS:**
1. Scarica il file `.zip` o usa Homebrew:
   ```bash
   brew install --cask flutter
   ```

### Passo 2 — Aggiungi Flutter al PATH

**Windows:**
1. Apri *Impostazioni di sistema → Variabili d'ambiente*
2. In *Variabili utente*, seleziona `Path` e clicca *Modifica*
3. Aggiungi: `C:\flutter\bin`
4. Riavvia il terminale

**macOS / Linux:**
```bash
# Aggiungi questa riga a ~/.zshrc oppure ~/.bashrc
export PATH="$HOME/flutter/bin:$PATH"

# Ricarica il profilo
source ~/.zshrc
```

### Passo 3 — Verifica l'installazione

```bash
flutter --version
```

Dovresti vedere qualcosa come: `Flutter 3.x.x • channel stable`

---

## 3. Installa Android Studio e Android SDK

### Passo 1 — Scarica Android Studio

Vai su [developer.android.com/studio](https://developer.android.com/studio) e scarica Android Studio.

Installalo seguendo la procedura guidata. **Durante l'installazione**, assicurati che sia selezionato:
- Android SDK
- Android Virtual Device (AVD)

### Passo 2 — Installa i componenti SDK necessari

Apri Android Studio, poi:
1. Vai su *Settings → Languages & Frameworks → Android SDK*
2. Nella scheda **SDK Platforms**, installa: **Android 14 (API 34)** — deve essere spuntata anche la voce *Show Package Details* per verificare che il platform sia effettivamente scaricato
3. Nella scheda **SDK Tools**, assicurati che siano spuntati:
   - Android SDK Build-Tools 34.0.0 (o superiore)
   - Android Emulator
   - Android SDK Platform-Tools
   - NDK (Side by side) — versione **27.0.12077973**

Clicca *Apply* per installare.

> **Importante su Windows:** se il componente NDK viene scaricato in modo corrotto (errore `did not have a source.properties file`), eliminalo manualmente e riprova:
> ```powershell
> Remove-Item -Recurse -Force "C:\Users\<tuonome>\AppData\Local\Android\Sdk\ndk\27.0.12077973"
> flutter run   # Gradle lo riscarica automaticamente
> ```

### Passo 2b — Aggiungi ADB al PATH (solo Windows)

`adb` si trova in `platform-tools` ma non viene aggiunto automaticamente al PATH. Esegui in PowerShell:

```powershell
[Environment]::SetEnvironmentVariable("Path", $env:Path + ";C:\Users\<tuonome>\AppData\Local\Android\Sdk\platform-tools", "User")
```

Riavvia il terminale. Verifica con:
```powershell
adb version
```

### Passo 2c — Configura JAVA_HOME (solo Windows)

Alcuni comandi (es. `sdkmanager`) richiedono `JAVA_HOME`. Android Studio include un JDK. Aggiungilo:

```powershell
[Environment]::SetEnvironmentVariable("JAVA_HOME", "C:\Program Files\Android\Android Studio\jbr", "User")
```

Per verificare dove si trova il Java usato da Flutter:
```powershell
flutter doctor -v | Select-String "Java"
```

### Passo 3 — Accetta le licenze Android

```bash
flutter doctor --android-licenses
```

Rispondi `y` a tutte le domande.

### Passo 4 — Verifica

```bash
flutter doctor
```

Tutti i punti Android devono essere verdi. Se c'è qualcosa in rosso, leggi il messaggio: indica esattamente cosa fare.

---

## 4. Configurazione per iOS (solo macOS)

> Solo se hai un Mac. Su Windows e Linux non è possibile compilare per iPhone/iPad.

### Passo 1 — Installa Xcode

1. Apri l'App Store sul Mac
2. Cerca **Xcode** e installalo (è gratuito, ma pesa circa 15 GB)
3. Al termine, avvia Xcode almeno una volta per completare l'installazione

### Passo 2 — Installa gli strumenti da riga di comando

```bash
sudo xcode-select --install
sudo xcodebuild -license accept
```

### Passo 3 — Installa CocoaPods

CocoaPods gestisce le dipendenze native per iOS.

```bash
sudo gem install cocoapods
```

Se usi Apple Silicon (M1/M2/M3):
```bash
brew install cocoapods
```

### Passo 4 — Verifica

```bash
flutter doctor
```

Il punto *Xcode* deve essere verde.

---

## 5. Clona il progetto e configura l'ambiente

### Passo 1 — Clona il repository

```bash
git clone <URL_DEL_REPOSITORY>
cd OnListClub_app
```

### Passo 2 — Crea il file di configurazione env.json

Il file `env.json` contiene le credenziali Supabase. **Non è incluso nel repository** per motivi di sicurezza.

Crea il file nella cartella principale del progetto:

```json
{
  "SUPABASE_URL": "https://xxxxxxxxxxxxxxxx.supabase.co",
  "SUPABASE_ANON_KEY": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

> Chiedi le credenziali al responsabile del progetto.

### Passo 3 — Installa le dipendenze Flutter

```bash
flutter pub get
```

Questo scarica tutti i pacchetti elencati in `pubspec.yaml`.

---

## 6. Avvia l'app su Android

> **Prerequisito:** Prima di eseguire l'app assicurati di aver configurato il file `env.json` nella root del progetto con le credenziali corrette (chiavi Supabase, ecc.). Trovi tutti i valori necessari nello **zip con i dati sensibili** condiviso dal responsabile del progetto. Senza questo file l'app non si avvia. Vedi la [sezione 5, Passo 2](#5-clona-il-progetto-e-configura-lambiente) per il formato del file.

### Opzione A — Emulatore (senza dispositivo fisico)

1. Apri Android Studio
2. Vai su *Device Manager* (icona del telefono in alto a destra)
3. Clicca *Create Device*
4. Scegli un telefono (es. *Pixel 8*) e un'immagine di sistema (es. *API 34*)
5. Avvia l'emulatore cliccando il triangolo

Poi, da terminale:
```bash
flutter run
```

Flutter rileva automaticamente l'emulatore e installa l'app.

### Opzione B — Dispositivo fisico Android

1. Sul telefono: vai su *Impostazioni → Info telefono*
2. Tocca **Numero build** 7 volte — si attiva la *Modalità sviluppatore*
3. Vai su *Impostazioni → Opzioni sviluppatore*
4. Attiva **Debug USB**
5. Collega il telefono al PC con un cavo USB
6. Sul telefono: autorizza il computer quando richiesto

```bash
flutter devices          # Deve mostrare il tuo telefono
flutter run
```

---

## 7. Avvia l'app su iPhone / Simulatore iOS

> **Prerequisito:** Stessa cosa della sezione 6 — il file `env.json` deve essere presente e configurato con i dati dello **zip con i dati sensibili** prima di eseguire `flutter run`.

> Solo su macOS con Xcode installato.

### Opzione A — Simulatore iPhone

```bash
open -a Simulator
```

Oppure da Xcode: *Xcode → Open Developer Tool → Simulator*

Poi:
```bash
flutter run
```

### Opzione B — iPhone fisico

1. Apri Xcode
2. Collega l'iPhone al Mac
3. In Xcode: vai su *Signing & Capabilities* del target `Runner`
4. Aggiungi il tuo **Apple ID** come team (basta un account gratuito per sviluppo)
5. Da terminale:

```bash
flutter run
```

La prima volta Xcode potrebbe chiederti di *fidarti* del dispositivo sul Mac e sul telefono.

> **Nota:** Con un account gratuito puoi installare l'app, ma scade dopo 7 giorni. Con un account Apple Developer (99$/anno) dura 1 anno.

---

## 8. Verifica tutto funzioni

```bash
flutter doctor -v
```

L'output ideale:
```
[ok] Flutter (Channel stable, 3.x.x)
[ok] Android toolchain - develop for Android devices
[ok] Xcode - develop for iOS and macOS  <- solo su macOS
[ok] Android Studio
[ok] Connected device
[ok] Network resources
```

Per eseguire i test unitari del progetto:
```bash
flutter test test/core/utils/age_calculator_test.dart
```

---

## 9. Problemi comuni

| Problema | Soluzione |
|---|---|
| `flutter: command not found` | Flutter non è nel PATH. Ripeti il Passo 2 della sezione Flutter. |
| `Android licenses not accepted` | Esegui `flutter doctor --android-licenses` e rispondi `y` |
| `CocoaPods not installed` | Esegui `sudo gem install cocoapods` o `brew install cocoapods` |
| `No connected devices` | Verifica che Debug USB sia attivo sul telefono, o che l'emulatore sia avviato |
| `env.json not found` | Crea il file `env.json` nella root del progetto come descritto nel Passo 2 della sezione 5 |
| `Supabase initialization failed` | Controlla che le credenziali in `env.json` siano corrette |
| Build iOS fallisce con errore di firma | In Xcode, seleziona il tuo team in *Signing & Capabilities* |
| `flutter pub get` fallisce | Controlla la connessione internet. Poi: `flutter clean && flutter pub get` |
| `adb: comando non trovato` | Aggiungi `C:\Users\<tuonome>\AppData\Local\Android\Sdk\platform-tools` al PATH (vedi Passo 2b) |
| `JAVA_HOME is not set` | Imposta JAVA_HOME a `C:\Program Files\Android\Android Studio\jbr` (vedi Passo 2c) |
| `Failed to find Build Tools revision 34.0.0` | Installa Android SDK Platform 34 da Android Studio → SDK Manager → SDK Platforms |
| `Failed to install platforms;android-34` | Stessa soluzione: installa **Android 14 (API 34)** da SDK Manager |
| `Minimum supported Gradle version is 8.11.1` | In `android/gradle/wrapper/gradle-wrapper.properties` imposta `distributionUrl=https\://services.gradle.org/distributions/gradle-8.11.1-all.zip` |
| `Dependency requires Android Gradle plugin 8.9.1 or higher` | In `android/settings.gradle` aggiorna entrambe le versioni AGP da `8.6.0` a `8.9.1` |
| `NDK did not have a source.properties file` | L'NDK è corrotto. Elimina la cartella `ndk/27.0.12077973` dall'SDK e riesegui `flutter run` |
| Build si blocca per OOM / `file di paging troppo piccolo` | PC con poca RAM. In `android/gradle.properties` riduci: `org.gradle.jvmargs=-Xmx1536m -XX:MaxMetaspaceSize=256m` e aggiungi `org.gradle.daemon=false` e `org.gradle.parallel=false` |

---

## 10. Workflow Git

### Struttura dei branch

Il progetto usa tre livelli di branch:

```
feature/[nome_feature]    <-- sviluppo di una singola funzionalità
        |
        v
     develop               <-- branch di integrazione e test
        |
        v
       main                <-- codice stabile, pronto per produzione
```

**Regola base:** non si fa mai commit direttamente su `main` o `develop`. Si lavora sempre su un branch `feature/`.

---

### Flusso di lavoro giornaliero

#### 1. Prima di iniziare a lavorare — aggiorna il tuo develop locale

```bash
git checkout develop
git pull origin develop
```

Farlo sempre prima di creare un nuovo branch, per partire dall'ultimo codice.

#### 2. Crea un branch per la tua feature

```bash
git checkout -b feature/nome-della-feature
```

Usa nomi chiari e in minuscolo, con trattini:
- `feature/home-screen-animation`
- `feature/booking-form`
- `feature/fix-phone-validation`

#### 3. Lavora e fai commit regolari

```bash
git add lib/presentation/home_screen/home_screen.dart
git commit -m "aggiungi animazione entrata home screen"
```

Commit piccoli e frequenti sono preferibili a un unico commit enorme.

#### 4. Tieni il branch aggiornato con develop

Se nel frattempo qualcun altro ha fatto merge su `develop`, aggiorna il tuo branch:

```bash
git checkout feature/nome-della-feature
git merge develop
```

Se ci sono conflitti, risolvili manualmente, poi:

```bash
git add .
git commit -m "risolvi conflitti con develop"
```

#### 5. Fai merge su develop quando hai finito

```bash
git checkout develop
git merge feature/nome-della-feature
git push origin develop
```

#### 6. Elimina il branch feature (opzionale ma consigliato)

```bash
git branch -d feature/nome-della-feature
```

---

### Merge da develop a main

Il merge su `main` avviene solo quando `develop` è stabile e testato, tipicamente prima di una release:

```bash
git checkout main
git pull origin main
git merge develop
git push origin main
git tag v1.0.0   # aggiungi un tag di versione
git push origin v1.0.0
```

---

### Comandi Git utili

| Comando | Cosa fa |
|---|---|
| `git status` | Mostra i file modificati |
| `git log --oneline` | Cronologia dei commit in formato compatto |
| `git diff` | Mostra le differenze non ancora messe in stage |
| `git stash` | Mette da parte le modifiche temporaneamente |
| `git stash pop` | Riprende le modifiche messe da parte |
| `git branch -a` | Lista tutti i branch (locali e remoti) |
| `git checkout -` | Torna al branch precedente |

---

### Convenzioni per i messaggi di commit

Usa verbi in italiano o inglese all'imperativo, brevi e descrittivi:

```
aggiungi: schermata home con animazioni
correggi: validazione numero di telefono
aggiorna: query SQL locali vicini
rimuovi: dipendenza inutilizzata
refactor: sposta logica nel BLoC
```
