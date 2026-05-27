# `lib/core/utils/`

Helper **puri**: ricevono input, restituiscono output, niente effetti collaterali.
Nessuna chiamata a Supabase, nessuno stato persistente, nessuna `BuildContext`.

> Se un "util" inizia a tenere stato o a parlare con Supabase, è un servizio:
> spostalo in `lib/core/services/`. Vedi `navigator_service.dart` e
> `user_profile_manager.dart`, recentemente migrati per questo motivo.

## File

| File | Cosa fa |
|---|---|
| `age_calculator.dart` | `AgeCalculator.isAdult(dob)` → true se la persona ha ≥ 18 anni a una data data. Usata in registrazione e dopo OAuth. |
| `analytics_mixin.dart` | Mixin `ScreenAnalytics<T>` per gli `State` degli screen: traccia automaticamente apertura pagina e tempo di permanenza via `AnalyticsService`. |
| `date_formatter.dart` | Wrapper su `intl.DateFormat`: `formatLong` (`d MMM yyyy`, it_IT) e `formatShort` (`dd/MM/yyyy`). |
| `phone_normalizer.dart` | `normalizeToE164(input, iso)` → numero in formato internazionale tramite `phone_numbers_parser`. |
| `phone_utils.dart` | Mappa statica ISO ↔ prefisso telefonico (`IT → +39`, ecc.) per i paesi supportati. |
| `size_utils.dart` | Estensioni `num.h`, `num.fSize` e classe `SizeUtils` per layout responsive sui breakpoint del design Figma (`393 × 822`). |
