# PrevenditaDetailScreen — Dettaglio prevendita

## Cosa fa

Mostra il dettaglio di una **prevendita acquistata** dall'utente, con:
- I dati della serata (nome evento, locale, data, ora)
- Il **codice QR** per l'ingresso (generato lato client)
- Il pulsante **"Annulla prevendita"** (operazione irreversibile)

È la schermata di destinazione dei flussi:
- "I miei ordini" → tap su una prevendita → questa schermata
- Successo pagamento → QR code di ingresso

---

## File coinvolti

```
prevendita_detail_screen/
└── prevendita_detail_screen.dart   <- UI + logica annullamento (setState)
```

Schermata "semplice": niente BLoC. Lo stato locale (`_isAnnullando`, `_annullata`) è gestito con `setState`.

---

## Argomenti in input

Riceve via `ModalRoute.of(context).settings.arguments` una `Map<String, dynamic>` che è la stessa restituita da [`OrdersService.getPrevenditeOrdini()`](../../core/services/orders_service.dart).

Struttura attesa (parziale):

```dart
{
  'id': '<uuid prenotazione_prevendite>',
  'prenotazioni': {
    'id': '<uuid prenotazione>',
    'eventi': {
      'nome_evento': '...',
      'data_evento': '2026-06-15',
      'locali': { 'nome_locale': '...' }
    },
  },
  'prevendite': { 'tipo': 'VIP', 'prezzo': '...' },
}
```

---

## Come funziona (flusso)

```
Utente apre la schermata (dalla lista ordini o post-pagamento)
        |
        v
La schermata legge gli arguments e mostra:
   - dati evento + locale
   - QR code generato con qr_flutter
        |
        v
Se tocca "Annulla prevendita":
        |
        v
   AlertDialog di conferma ("Sei sicuro? Non è reversibile")
        |
        +---- No  --> torna alla schermata
        |
        +---- Sì  --> OrdersService.annullaPrevendita(idPrenotazione)
                       |
                       +-- successo --> SnackBar "Prevendita annullata"
                       |                _annullata = true (UI aggiornata)
                       |
                       +-- errore --> SnackBar con messaggio errore
```

---

## Dettagli implementativi

**QR code:** generato lato client con `qr_flutter` a partire dall'id della prenotazione. Non viene fatto un round-trip al server: l'unicità del codice è garantita dall'UUID Postgres.

**Annullamento:** chiama [`OrdersService.annullaPrevendita`](../../core/services/orders_service.dart) che setta `stato = 'annullata'` sulla riga `prenotazioni`. È un soft-delete (la riga non viene cancellata).

**Stato post-annullamento:** la UI mostra un banner che indica la prevendita annullata e nasconde il QR.

**Sicurezza dell'operazione:** la conferma è esplicita con `AlertDialog`. L'utente non può annullare per sbaglio con un tap accidentale.

---

## Dipendenze

| Da dove | Cosa usa |
|---|---|
| `core/services/orders_service.dart` | `annullaPrevendita(idPrenotazione)` |
| `qr_flutter` (pacchetto) | Generazione QR code |
| `widgets/custom_top_bar.dart`, `widgets/shared_footer.dart` | Top bar e bottom nav |
