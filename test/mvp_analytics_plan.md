# 📊 Piano Analytics MVP — OnList (5 Discoteche Test)

## Obiettivo
Capire **cosa funziona, cosa no, e dove gli utenti si bloccano** prima di andare in produzione con i pagamenti attivi.

---

## 🔑 Le 7 Domande Chiave dell'MVP

| # | Domanda | Perché conta |
|---|---------|-------------|
| 1 | **Gli utenti completano la registrazione?** | Se il 60% abbandona al signup, hai un problema di onboarding |
| 2 | **Trovano il club giusto?** | Se nessuno arriva alla scheda club, il flusso posizione non funziona |
| 3 | **Prenotano?** | Se vedono il club ma non prenotano, c'è un problema di prezzo/UX/offerta |
| 4 | **Dove si bloccano nel funnel?** | Sapere l'esatto step dove abbandonano (es: "scelgo tavolo → abbandono al drink") |
| 5 | **Quanto tempo ci mettono?** | Se servono 8 minuti per prenotare, è troppo complicato |
| 6 | **Tornano?** | La retention è tutto: se tornano, il prodotto funziona |
| 7 | **L'app crasha o dà errori?** | Errori silenziosi che uccidono l'esperienza senza che tu lo sappia |

---

## 📋 Lista Completa Eventi da Tracciare

### 1. 🚪 Onboarding & Autenticazione

| Evento | Quando | Metadata | Cosa ci dice |
|--------|--------|----------|-------------|
| `app_opened` | Apertura app | `{is_first_open, days_since_last_open}` | Retention, frequenza uso |
| `auth_started` | Apertura schermata login | `{method: 'phone'/'google'/'apple'}` | Quale metodo preferiscono |
| `auth_completed` | Login/registrazione OK | `{method, is_new_user}` | Tasso di conversione registrazione |
| `auth_failed` | Errore in autenticazione | `{method, error}` | Problemi tecnici di accesso |
| `profile_completed` | Compilazione profilo | `{fields_filled: ['nome','cognome','data_nascita']}` | Quanti completano il profilo |
| `profile_skipped` | Salta completamento profilo | `{}` | Quanti saltano → ti dice se il profilo è troppo lungo |

### 2. 📍 Posizione (già parzialmente implementato)

| Evento | Quando | Metadata | Cosa ci dice |
|--------|--------|----------|-------------|
| `gps_permission` | Risposta al prompt GPS | `{granted}` | ✅ Già implementato |
| `gps_permission_skipped` | "Ricordamelo più tardi" | `{}` | Quanti evitano il GPS |
| `city_selected` | Scelta città manuale | `{city_name, city_id}` | ✅ Già implementato |
| `location_resolved` | Posizione risolta nella Home | `{source, lat, lng, club_name}` | ✅ Già implementato |
| `gps_forced_toggle` | Toggle "Usa GPS" | `{enabled}` | ✅ Già implementato |
| `radius_changed` | Cambio raggio ricerca | `{old_km, new_km}` | Capire se il raggio default (20km) è giusto |

### 3. 🔍 Ricerca & Scoperta Club

| Evento | Quando | Metadata | Cosa ci dice |
|--------|--------|----------|-------------|
| `search_opened` | Apertura NearbyClubsScreen | `{}` | Quanti cercano vs restano nella Home |
| `search_performed` | Ricerca testuale | `{query, results_count}` | Cosa cercano? Trovano risultati? |
| `search_city_filter` | Filtro per città in ricerca | `{city_name}` | Domanda in quali città |
| `search_sort_changed` | Cambio ordinamento | `{sort_mode: 'distanza'/'popolarita'}` | Preferiscono vicino o famoso? |
| `search_filter_applied` | Filtro genere/prezzo | `{generi, prezzo}` | Quali filtri usano di più |
| `search_no_results` | Ricerca senza risultati | `{query, city, radius}` | Dove mancano i locali |

### 4. 🏛️ Navigazione tra Pagine (con tempo di permanenza)

| Evento | Quando | Metadata | Cosa ci dice |
|--------|--------|----------|-------------|
| `page_view` | Apertura di qualsiasi pagina | `{page_name, referrer_page}` | **Flusso di navigazione** — da dove vengono, dove vanno |
| `page_exit` | Uscita da una pagina | `{page_name, duration_seconds}` | **Tempo di permanenza** — se restano 2s sulla scheda club, non li interessa |
| `club_viewed` | Apertura dettaglio club | `{club_id, club_name, source: 'home'/'search'/'notification'}` | Come scoprono i club |
| `event_viewed` | Apertura dettaglio serata | `{event_id, event_name, club_name, date}` | Quali serate attirano |
| `home_scroll_depth` | Quanto scrollano nella Home | `{max_scroll_percent}` | Se vedono il contenuto sotto la fold |

### 5. 🎟️ Funnel di Prenotazione (IL PIÙ IMPORTANTE)

Questo è il cuore dell'MVP. Devi sapere **esattamente dove abbandonano**.

| Evento | Quando | Metadata | Cosa ci dice |
|--------|--------|----------|-------------|
| `booking_funnel_start` | Click su "Prenota" | `{club_id, event_id, type: 'tavolo'/'prevendita'}` | Quanti iniziano il funnel |
| `booking_table_selected` | Scelta tavolo | `{table_id, table_name, n_persons}` | Quale tavolo preferiscono |
| `booking_drink_selected` | Scelta drink | `{drink_id, drink_name, quantity, price}` | Quali drink vanno |
| `booking_prevendita_selected` | Scelta prevendita | `{prevendita_id, tipo, prezzo, quantity}` | Quale tipo di biglietto |
| `booking_ticket_form_started` | Inizio compilazione form biglietto | `{ticket_index}` | Quanti iniziano a compilare |
| `booking_ticket_form_completed` | Form biglietto completato | `{ticket_index, duration_seconds}` | Quanto ci mettono per form |
| `booking_cart_viewed` | Apertura carrello | `{items_count, total_price}` | Quanti arrivano al carrello |
| `booking_cart_abandoned` | Uscita dal carrello senza pagare | `{items_count, total_price, duration_seconds}` | **CRITICO** — perché abbandonano? |
| `booking_payment_started` | Avvio pagamento | `{total_price, payment_method}` | Quanti provano a pagare |
| `booking_payment_success` | Pagamento OK | `{total_price, type, club_id, event_id}` | 🎉 Conversione! |
| `booking_payment_failed` | Pagamento fallito | `{error, total_price}` | Problemi tecnici di pagamento |

> [!IMPORTANT]
> Il **funnel rate** (es: 100 iniziano → 60 scelgono tavolo → 30 vanno al carrello → 10 pagano = 10% conversione) è il numero più importante dell'intero MVP. Ti dice dove perdere utenti.

### 6. 📱 Sessione & Engagement

| Evento | Quando | Metadata | Cosa ci dice |
|--------|--------|----------|-------------|
| `session_start` | Apertura app (ogni volta) | `{session_id, platform, app_version}` | Sessioni giornaliere |
| `session_end` | App va in background/chiusa | `{session_id, duration_seconds, pages_visited}` | Durata sessioni |
| `notification_received` | Push notification ricevuta | `{notification_type}` | Quante notifiche arrivano |
| `notification_opened` | Click su notifica | `{notification_type}` | Tasso di apertura notifiche |
| `favorite_added` | Aggiunta a preferiti | `{club_id, club_name}` | Quali club piacciono |
| `favorite_removed` | Rimozione da preferiti | `{club_id, club_name}` | Cambio preferenze |
| `orders_viewed` | Apertura sezione ordini | `{orders_count}` | Quanti controllano i loro ordini |
| `qr_viewed` | Apertura QR code prenotazione | `{booking_id}` | Quanti usano effettivamente il QR |

### 7. ❌ Errori & Problemi

| Evento | Quando | Metadata | Cosa ci dice |
|--------|--------|----------|-------------|
| `error_api` | Errore Supabase/rete | `{endpoint, error, status_code}` | Problemi backend |
| `error_ui` | Crash/eccezione non gestita | `{error, stack_trace, page}` | Bug dell'app |
| `error_location` | GPS fallito | `{error_type}` | Problemi di geolocalizzazione |
| `error_payment` | Errore pagamento | `{error, provider}` | Problemi di pagamento |

---

## 📊 Le Metriche da Calcolare (query SQL)

### Funnel di Conversione
```sql
-- Funnel completo per un periodo
SELECT 
  event_name,
  COUNT(DISTINCT user_id) as utenti_unici
FROM analytics_events
WHERE event_name IN (
  'event_viewed',
  'booking_funnel_start', 
  'booking_cart_viewed',
  'booking_payment_started',
  'booking_payment_success'
)
AND created_at >= NOW() - INTERVAL '7 days'
GROUP BY event_name
ORDER BY utenti_unici DESC;
```

### Retention (utenti che tornano)
```sql
-- Utenti attivi per giorno
SELECT 
  DATE(created_at) as giorno,
  COUNT(DISTINCT user_id) as utenti_attivi
FROM analytics_events
WHERE event_name = 'session_start'
GROUP BY DATE(created_at)
ORDER BY giorno;
```

### Tempo medio per pagina
```sql
-- Tempo medio su ogni pagina
SELECT 
  metadata->>'page_name' as pagina,
  AVG((metadata->>'duration_seconds')::float) as tempo_medio_sec,
  COUNT(*) as visite
FROM analytics_events
WHERE event_name = 'page_exit'
GROUP BY metadata->>'page_name'
ORDER BY tempo_medio_sec DESC;
```

### Dove abbandonano (drop-off)
```sql
-- Ultimo evento prima di chiudere l'app
SELECT 
  metadata->>'page_name' as ultima_pagina,
  COUNT(*) as abbandoni
FROM analytics_events
WHERE event_name = 'session_end'
GROUP BY metadata->>'page_name'
ORDER BY abbandoni DESC;
```

---

## 🎯 Priorità di Implementazione

### ✅ Già implementati (questa sessione)
- `location_resolved`
- `gps_permission`
- `city_selected`
- `gps_forced_toggle`

### 🔴 Priorità 1 — Da fare subito (fondamentali per l'MVP)
1. **`page_view` / `page_exit`** — Tempo per pagina e navigazione
2. **`session_start` / `session_end`** — Durata sessioni e retention
3. **`booking_funnel_start` → `booking_payment_success`** — L'intero funnel
4. **`error_api`** — Errori silenziosi

### 🟡 Priorità 2 — Da fare prima del test con le discoteche
5. **`auth_started` / `auth_completed`** — Onboarding
6. **`club_viewed` / `event_viewed`** — Scoperta
7. **`search_*`** — Ricerca
8. **`booking_cart_abandoned`** — Abbandono carrello

### 🟢 Priorità 3 — Nice to have
9. `notification_*` — Notifiche
10. `favorite_*` — Preferiti
11. `home_scroll_depth` — Engagement

---

## 🏗️ Implementazione Tecnica Consigliata

### Per il tracking del tempo per pagina (`page_view` / `page_exit`)

Serve un **mixin** da aggiungere a ogni screen, così non devi duplicare codice:

```dart
mixin ScreenAnalytics<T extends StatefulWidget> on State<T> {
  late final DateTime _pageOpenedAt;
  String get screenName; // Da implementare in ogni screen

  @override
  void initState() {
    super.initState();
    _pageOpenedAt = DateTime.now();
    AnalyticsService.log(
      event: 'page_view',
      metadata: {'page_name': screenName},
    );
  }

  @override
  void dispose() {
    final duration = DateTime.now().difference(_pageOpenedAt).inSeconds;
    AnalyticsService.log(
      event: 'page_exit',
      metadata: {
        'page_name': screenName,
        'duration_seconds': duration,
      },
    );
    super.dispose();
  }
}
```

Poi in ogni screen:

```dart
class _HomeScreenState extends State<HomeScreen> 
    with TickerProviderStateMixin, ScreenAnalytics {
  
  @override
  String get screenName => 'home';
  // ... resto del codice
}
```

### Per le sessioni (`session_start` / `session_end`)

Serve un `WidgetsBindingObserver` nel widget radice dell'app:

```dart
class _AppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      AnalyticsService.log(event: 'session_start');
    } else if (state == AppLifecycleState.paused) {
      AnalyticsService.log(event: 'session_end');
    }
  }
}
```

---

## ⚠️ Cose da NON Fare

1. **Non tracciare dati personali** (nome, cognome, telefono) nei log — solo `user_id`
2. **Non tracciare coordinate GPS precise** — arrotonda a 2 decimali (±1km)
3. **Non fare chiamate Supabase sincrone** — tutti i log devono essere fire-and-forget
4. **Non tracciare tutto subito** — inizia con Priorità 1, poi aggiungi gradualmente
5. **Non dimenticare la privacy policy** — menziona che raccogli dati anonimi di utilizzo
