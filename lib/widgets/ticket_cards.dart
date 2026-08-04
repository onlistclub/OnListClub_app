import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:flutter_svg/flutter_svg.dart';

import '../core/constants/image_constant.dart';
import '../core/utils/responsive.dart';
import '../theme/onlist_colors.dart';
import '../theme/onlist_text_styles.dart';
import 'dashed_line.dart';
import 'staggered_item.dart';
import 'ticket_shape.dart';

/// Card-biglietto del design NUOVO condivise da "Ordine Effettuato" e
/// "Riepilogo ordini". Tre stati, ognuno un widget a sé:
///
/// - [TicketCollapsedCard] — biglietto chiuso (350×167): solo nome del locale
///   e "Apri biglietto" con la freccia giù.
/// - [TicketFrontCard] — biglietto aperto, FRONTE (350×614): tipo ticket,
///   quantità, dati personali, pagamento e il bottone "VISUALIZZA QR CODE".
/// - [TicketBackCard] — biglietto aperto, RETRO (350×614): nome locale,
///   evento e il QR code vero e proprio.
///
/// Fronte e retro sono due widget separati proprio per essere montati come le
/// due facce di una rotazione 3D: le schermate li passano a [FlipCard]
/// (`lib/widgets/flip_card.dart`), che gestisce l'animazione.
///
/// Tutte le misure sono px design (frame Figma 393×852) scalate con [R.sp].

// ── Geometria condivisa fronte/retro del biglietto aperto ────────────────────
// Card 350×614 a top 161 (CSS Rectangle 268, identico nei due CSS).

/// Altezza card del biglietto aperto (CSS Rectangle 268).
const double _openCardH = 614;

/// Quote delle separazioni, in px design dal bordo ALTO della card.
/// Nel CSS le linee tratteggiate cadono sul centro delle tacche
/// (`Ellipse 18` @282 → centro 301, @430 → centro 449) e la card sta a 161:
/// 301−161 = 140, 449−161 = 288.
///
/// Sono la FONTE DI VERITÀ UNICA per tacche e linee: prima le tacche stavano a
/// quota fissa mentre le linee scorrevano dentro la Column accumulando le
/// altezze reali dei testi, e finivano fuori asse (misurato: −8px sul fronte,
/// il retro era dichiarato a 142.5 invece di 140).
const double _separator1Y = 140;
const double _separator2Y = 288;

/// Semiassi della tacca (CSS `Ellipse 18` 41×38) e sporgenza del centro oltre
/// il bordo: 41/2 = 20.5, 38/2 = 19, centro 1.5px fuori → profondità 19.
const double _notchRx = 20.5;
const double _notchRy = 19;
const double _notchEdgeOffset = 1.5;

/// Tacca del biglietto aperto alla quota indicata (px design dal bordo alto).
TicketNotch _openNotch(double y) => TicketNotch(
      centerYFraction: y / _openCardH,
      radiusDesign: _notchRx,
      radiusYDesign: _notchRy,
      edgeOffsetDesign: _notchEdgeOffset,
    );

// ── Stato A: biglietto chiuso ────────────────────────────────────────────────
class TicketCollapsedCard extends StatelessWidget {
  final String clubName;
  final VoidCallback onTap;

  /// Riga sotto il nome del locale.
  ///
  /// "Apri biglietto" ovunque si tocchi per aprirlo (ordine effettuato e
  /// riepilogo ordini): il tocco apre la card, il QR è un passo successivo,
  /// quindi "Visualizza QR Code" prometteva la cosa sbagliata.
  ///
  /// Il carrello riusa la stessa card per gli ordini in sospeso e ci mette
  /// "Continua l'ordine": lì un biglietto da aprire non c'è ancora.
  final String label;

  const TicketCollapsedCard({
    Key? key,
    required this.clubName,
    required this.onTap,
    this.label = 'Apri biglietto',
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: R.sp(167),
        width: double.infinity,
        child: TicketShape(
          // CSS Ellipse 20/21: top 477 su card a 392 → 85/167 ≈ 0.51 del
          // riquadro; centro tacca alla stessa quota della freccia.
          notches: const [
            TicketNotch(centerYFraction: 106.5 / 167, radiusDesign: 22),
          ],
          child: Padding(
            padding: EdgeInsets.fromLTRB(R.sp(30), R.sp(28), R.sp(30), 0),
            child: Column(
              children: [
                // Nome locale 64/500/-0.1em (CSS "NumberOne").
                SizedBox(
                  height: R.sp(63),
                  width: double.infinity,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      clubName,
                      style: OnlistTextStyles.hn(
                        color: Colors.white,
                        fontSize: R.sp(64),
                        fontWeight: FontWeight.w700,
                        height: 63 / 64,
                        letterSpacing: -0.1 * 64,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: R.sp(8)),
                Text(
                  label,
                  style: OnlistTextStyles.hn(
                    color: Colors.white,
                    fontSize: R.sp(15),
                    // "Grassetto leggero" richiesto nel doc correzioni: w500,
                    // non w700 — deve restare più leggero del nome del locale.
                    fontWeight: FontWeight.w500,
                    letterSpacing: -0.1 * 15,
                  ),
                ),
                SizedBox(height: R.sp(9)),
                const ArrowCircle(down: true),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Stato B: biglietto aperto, FRONTE ────────────────────────────────────────
class TicketFrontCard extends StatelessWidget {
  final String ticketType;
  final int quantita;
  final String? descrizione;
  final String nome;
  final String cognome;
  final String prezzo;

  /// Apre il retro col QR ("VISUALIZZA QR CODE").
  final VoidCallback onShowQr;

  /// Richiude il biglietto ("Chiudi Biglietto" + freccia su).
  final VoidCallback onCollapse;

  /// Azione "ANNULLA PREVENDITA" (flusso critico non previsto dal Figma:
  /// vedi CLAUDE.md §1).
  /// DISATTIVATA (MVP): la riga è commentata in `build`, quindi questo callback
  /// per ora non viene invocato. I parametri restano nella firma perché le
  /// schermate chiamanti li passano già e la logica di annullamento è intatta.
  final VoidCallback? onAnnulla;

  /// Mostra lo spinner al posto del testo mentre l'annullamento è in corso.
  /// Vedi [onAnnulla]: disattivato nell'MVP.
  final bool isAnnullando;

  /// Testo mostrato al posto del bottone quando la prevendita è annullata.
  /// Vedi [onAnnulla]: disattivato nell'MVP.
  final String? annullataLabel;

  const TicketFrontCard({
    Key? key,
    required this.ticketType,
    required this.quantita,
    required this.descrizione,
    required this.nome,
    required this.cognome,
    required this.prezzo,
    required this.onShowQr,
    required this.onCollapse,
    this.onAnnulla,
    this.isAnnullando = false,
    this.annullataLabel,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: R.sp(_openCardH),
      width: double.infinity,
      child: TicketShape(
        notches: [_openNotch(_separator1Y), _openNotch(_separator2Y)],
        borderWidthDesign: 3,
        borderColor: OnlistColors.ticketCardBorderOpen,
        child: Stack(
          children: [
            // Le due linee tratteggiate sono ANCORATE alle stesse quote delle
            // tacche, non più in flusso: non possono più separarsene.
            Positioned(
              left: R.sp(26),
              top: R.sp(_separator1Y),
              child: const DashedLine(widthDesign: 297),
            ),
            Positioned(
              left: R.sp(26),
              top: R.sp(_separator2Y),
              child: const DashedLine(widthDesign: 297),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: R.sp(29)),
                // "Ticket normale" 55/500/-0.1em.
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: R.sp(22)),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Ticket ${ticketType.toLowerCase()}',
                      style: OnlistTextStyles.hn(
                        color: Colors.white,
                        fontSize: R.sp(55),
                        fontWeight: FontWeight.w500,
                        height: 54 / 55,
                        letterSpacing: -0.1 * 55,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: R.sp(18)),
                _QuantityRow(quantita: quantita, descrizione: descrizione),
                // 15 + 1 (linea) + 18: lo spazio della 1ª separazione resta, la
                // linea ora la disegna lo Stack ancorata alla tacca.
                SizedBox(height: R.sp(34)),
                // "Dati personali" 48/500 — era w700, il CSS dice 500 come gli
                // altri due titoli della card.
                Padding(
                  padding: EdgeInsets.only(left: R.sp(26)),
                  child: Text(
                    'Dati personali',
                    style: OnlistTextStyles.hn(
                      color: Colors.white,
                      fontSize: R.sp(48),
                      fontWeight: FontWeight.w500,
                      height: 47 / 48,
                      letterSpacing: -0.1 * 48,
                    ),
                  ),
                ),
                SizedBox(height: R.sp(11)),
                _PersonalRow('Nome : $nome'),
                SizedBox(height: R.sp(5)),
                _PersonalRow('Cognome : $cognome'),
                // 26 + 1 (linea) + 25: idem per la 2ª separazione.
                SizedBox(height: R.sp(52)),
                // "Pagamento" 48/500 + testo statico + prezzo 96.
                Padding(
                  padding: EdgeInsets.only(left: R.sp(26)),
                  child: Text(
                    'Pagamento',
                    style: OnlistTextStyles.hn(
                      color: Colors.white,
                      fontSize: R.sp(48),
                      fontWeight: FontWeight.w500,
                      height: 47 / 48,
                      letterSpacing: -0.1 * 48,
                    ),
                  ),
                ),
                SizedBox(
                  height: R.sp(148),
                  child: Stack(
                    children: [
                      Positioned(
                        left: R.sp(30),
                        top: R.sp(16),
                        child: SizedBox(
                          width: R.sp(155),
                          child: Text(
                            'Il pagamento dovrà essere effettuato in struttura',
                            style: OnlistTextStyles.hn(
                              color: Colors.white,
                              fontSize: R.sp(20),
                              fontWeight: FontWeight.w400,
                              height: 20 / 20,
                              letterSpacing: -0.08 * 20,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        right: R.sp(28),
                        top: R.sp(31),
                        child: Text(
                          prezzo,
                          style: OnlistTextStyles.hn(
                            color: Colors.white,
                            fontSize: R.sp(96),
                            fontWeight: FontWeight.w400,
                            height: 96 / 96,
                            letterSpacing: -0.08 * 96,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Pill "VISUALIZZA QR CODE" → mostra il retro col QR.
                Center(
                  child: TicketPillButton(
                    label: 'VISUALIZZA QR CODE',
                    onTap: onShowQr,
                  ),
                ),
                SizedBox(height: R.sp(11)),
                // "Chiudi Biglietto" + freccia su → richiude il biglietto.
                // È l'opposto di "Apri biglietto" della card chiusa: prima
                // diceva "Nascondi QR Code", che è tutt'altra azione (quella
                // è la pill qui sopra).
                Center(
                  child: GestureDetector(
                    onTap: onCollapse,
                    behavior: HitTestBehavior.opaque,
                    child: Column(
                      children: [
                        Text(
                          'Chiudi Biglietto',
                          style: OnlistTextStyles.hn(
                            color: Colors.white,
                            fontSize: R.sp(15),
                            fontWeight: FontWeight.w400,
                            height: 15 / 15,
                            letterSpacing: -0.1 * 15,
                          ),
                        ),
                        SizedBox(height: R.sp(8)),
                        const ArrowCircle(down: false),
                      ],
                    ),
                  ),
                ),
                // ANNULLA PREVENDITA DISATTIVATO (MVP): il tasto non è nel Figma e
                // per ora non serve. Tolto anche perché allungava la card di 47px
                // (614 → 661) facendola finire SOTTO la footer bar, mentre nel CSS
                // il biglietto chiude a 775 e la footer parte a 780.
                //
                // ATTENZIONE: annullare la prevendita è il flusso critico #6 di
                // CLAUDE.md e questo era l'unico punto da cui partiva. Finché resta
                // commentato l'utente non può annullare dall'app.
                //
                // Per riattivare: togliere i commenti qui sotto, rimettere
                // `final hasAnnulla = onAnnulla != null || annullataLabel != null;`
                // e l'altezza variabile della card in `build`. La logica lato
                // schermata (`_annulla`, RPC `annulla_prevendita`) è rimasta intatta
                // in prevendita_detail_screen.dart.
                /*
            if (hasAnnulla) ...[
              SizedBox(height: R.sp(14)),
              Center(
                child: annullataLabel != null
                    ? Text(
                        annullataLabel!,
                        style: OnlistTextStyles.hn(
                          color: OnlistColors.destructive,
                          fontSize: R.sp(16),
                          fontWeight: FontWeight.w500,
                          height: 16 / 16,
                          letterSpacing: -0.1 * 16,
                        ),
                      )
                    : GestureDetector(
                        onTap: isAnnullando ? null : onAnnulla,
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          width: R.sp(186),
                          height: R.sp(33),
                          decoration: BoxDecoration(
                            color: const Color(0x33FFFFFF),
                            border: Border.all(
                                color: const Color(0x73FFFFFF), width: 1),
                            borderRadius: BorderRadius.circular(R.sp(18)),
                          ),
                          alignment: Alignment.center,
                          child: isAnnullando
                              ? SizedBox(
                                  width: R.sp(16),
                                  height: R.sp(16),
                                  child: const CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2),
                                )
                              : Text(
                                  'ANNULLA PREVENDITA',
                                  style: OnlistTextStyles.hn(
                                    color: Colors.white,
                                    fontSize: R.sp(16),
                                    fontWeight: FontWeight.w500,
                                    height: 16 / 16,
                                    letterSpacing: -0.1 * 16,
                                  ),
                                ),
                        ),
                      ),
              ),
            ],
            */
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Stato C: biglietto aperto, RETRO (QR) ────────────────────────────────────
class TicketBackCard extends StatelessWidget {
  final String clubName;
  final int quantita;
  final String? descrizione;
  final String eventoNome;
  final String? eventoSottotitolo;
  final String dataEvento;

  /// Dato codificato nel QR (URL /verify/<uuid> letto dallo scanner staff).
  final String qrData;

  /// Torna al fronte del biglietto ("NASCONDI").
  final VoidCallback onHide;

  const TicketBackCard({
    Key? key,
    required this.clubName,
    required this.quantita,
    required this.descrizione,
    required this.eventoNome,
    required this.eventoSottotitolo,
    required this.dataEvento,
    required this.qrData,
    required this.onHide,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: R.sp(_openCardH),
      width: double.infinity,
      child: TicketShape(
        // Una sola coppia di tacche (CSS Ellipse 18 @282 → centro 301 → 140
        // dal bordo card): stesse costanti del fronte.
        notches: [_openNotch(_separator1Y)],
        borderWidthDesign: 3,
        borderColor: OnlistColors.ticketCardBorderOpen,
        // I blocchi entrano SFALSATI (stagger) quando il retro compare, cioè
        // a metà rotazione: slide orizzontale + fade, ritardo crescente —
        // stesso effetto della flip card di riferimento.
        child: Stack(
          children: [
            // Linea tratteggiata ANCORATA alla quota della tacca, non più in
            // flusso: era dichiarata a 142.5 mentre la tacca sta a 140.
            Positioned(
              left: R.sp(26),
              top: R.sp(_separator1Y),
              child: const _BackStagger(
                index: 2,
                child: DashedLine(widthDesign: 297),
              ),
            ),
            Column(
              children: [
                SizedBox(height: R.sp(29)),
                // Nome locale 55/500 centrato (era w700: il CSS dice 500).
                _BackStagger(
                  index: 0,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: R.sp(22)),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        clubName,
                        style: OnlistTextStyles.hn(
                          color: Colors.white,
                          fontSize: R.sp(55),
                          fontWeight: FontWeight.w500,
                          height: 54 / 55,
                          letterSpacing: -0.1 * 55,
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: R.sp(20)),
                _BackStagger(
                  index: 1,
                  child: _QuantityRow(
                      quantita: quantita, descrizione: descrizione),
                ),
                // 15 + 1 (linea, ora nello Stack) + 9.
                SizedBox(height: R.sp(25)),
                // Evento: nome 48/500 su MAX 2 righe, sottotitolo 32/500,
                // data 22/500 — centrati.
                _BackStagger(
                  index: 3,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: R.sp(22)),
                    child: Column(
                      children: [
                        _TwoLineTitle(
                          text: eventoNome,
                          maxFontSizeDesign: 48,
                          minFontSizeDesign: 28,
                          lineHeight: 47 / 48,
                        ),
                        if (eventoSottotitolo != null &&
                            eventoSottotitolo!.isNotEmpty) ...[
                          SizedBox(height: R.sp(6)),
                          Text(
                            eventoSottotitolo!,
                            style: OnlistTextStyles.hn(
                              color: Colors.white,
                              fontSize: R.sp(32),
                              fontWeight: FontWeight.w500,
                              height: 32 / 32,
                            ),
                          ),
                        ],
                        SizedBox(height: R.sp(6)),
                        Text(
                          dataEvento,
                          style: OnlistTextStyles.hn(
                            color: Colors.white,
                            fontSize: R.sp(22),
                            fontWeight: FontWeight.w500,
                            height: 22 / 22,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: R.sp(14)),
                // Pannello QR (CSS Rectangle 295: 350×345 r32, rgba(0,5,214,.2))
                // col QR VERO su riquadro bianco 20% r16.
                //
                // QR PIÙ GRANDE DEL FIGMA (correzioni 1.1, punto 20, scelta di
                // Luca). Il Figma dà un riquadro 228 che riempiva già tutta
                // l'altezza utile del pannello:
                //   345 (pannello) − 38 (sopra) − 27 (in mezzo) − 33 (pill)
                //                 − 20 (respiro sotto) = 227 disponibili
                // Per crescere bisognava recuperare spazio dagli spazi vuoti:
                // 38→24 e 27→18 liberano 23 px, che vanno al riquadro (228→250).
                // Il respiro in fondo resta invariato: 24+250+18+33 = 325 su 345.
                // Moduli del QR: 195.5 → 216 px design (+10%).
                Expanded(
                  child: _BackStagger(
                    index: 4,
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0x330005D6),
                        borderRadius: BorderRadius.circular(R.sp(32)),
                      ),
                      child: Column(
                        children: [
                          SizedBox(height: R.sp(24)),
                          Container(
                            width: R.sp(250),
                            height: R.sp(250),
                            decoration: BoxDecoration(
                              // BIANCO PIENO con moduli NERI: la polarità
                              // standard del QR, la stessa del totem recensioni
                              // che lo scanner legge senza problemi.
                              //
                              // Prima era il contrario (moduli bianchi su fondo
                              // scuro): un QR "invertito". Lo standard dà per
                              // scontato scuro-su-chiaro, e parecchi lettori non
                              // provano nemmeno il caso opposto — per loro non
                              // c'è nessun codice da leggere. È il motivo per
                              // cui il QR dell'app non si scansionava mentre
                              // quello stampato sì.
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(R.sp(16)),
                            ),
                            // Cornice bianca attorno al QR. Non si stringe oltre:
                            // dentro, QrImageView tiene la sua "quiet zone" di
                            // 10 px (il margine che i lettori usano per
                            // agganciare il codice) — toglierla renderebbe il QR
                            // più grande ma più difficile da scansionare.
                            padding: EdgeInsets.all(R.sp(7)),
                            // QR reale (scansionabile dallo staff), non decorativo.
                            child: QrImageView(
                              data: qrData,
                              version: QrVersions.auto,
                              // Anche la quiet zone dev'essere bianca: se
                              // restasse trasparente il margine prenderebbe il
                              // blu del pannello e il lettore non troverebbe il
                              // bordo del codice.
                              backgroundColor: Colors.white,
                              eyeStyle: const QrEyeStyle(
                                eyeShape: QrEyeShape.square,
                                color: Colors.black,
                              ),
                              dataModuleStyle: const QrDataModuleStyle(
                                dataModuleShape: QrDataModuleShape.square,
                                color: Colors.black,
                              ),
                            ),
                          ),
                          SizedBox(height: R.sp(18)),
                          TicketPillButton(label: 'NASCONDI', onTap: onHide),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Titolo che sta su **massimo 2 righe**: parte da [maxFontSizeDesign] e scende
/// finché il testo ci entra, senza mai andare sotto [minFontSizeDesign].
///
/// Serve per il nome evento del retro: prima era dentro un `FittedBox`, che lo
/// teneva sempre su UNA riga rimpicciolendolo all'infinito — un nome lungo
/// diventava minuscolo. Qui un nome corto resta a 48 su una riga, uno lungo si
/// riduce quel tanto che basta per starci in due.
///
/// La misura la fa un [TextPainter] sulla larghezza reale disponibile: pochi
/// tentativi a step di 2px, solo al build della card (nessun costo per frame).
class _TwoLineTitle extends StatelessWidget {
  final String text;
  final double maxFontSizeDesign;
  final double minFontSizeDesign;
  final double lineHeight;

  const _TwoLineTitle({
    required this.text,
    required this.maxFontSizeDesign,
    required this.minFontSizeDesign,
    required this.lineHeight,
  });

  static const int _maxLines = 2;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth;
        double size = R.sp(maxFontSizeDesign);
        final minSize = R.sp(minFontSizeDesign);
        while (size > minSize) {
          final painter = TextPainter(
            text: TextSpan(text: text, style: _styleAt(size)),
            textDirection: TextDirection.ltr,
            maxLines: _maxLines,
            textAlign: TextAlign.center,
          )..layout(maxWidth: maxW);
          if (!painter.didExceedMaxLines) break;
          size -= 2;
        }
        return Text(
          text,
          textAlign: TextAlign.center,
          maxLines: _maxLines,
          // Se nemmeno al minimo ci sta, meglio troncare che sbordare.
          overflow: TextOverflow.ellipsis,
          style: _styleAt(size),
        );
      },
    );
  }

  TextStyle _styleAt(double size) => OnlistTextStyles.hn(
        color: Colors.white,
        fontSize: size,
        fontWeight: FontWeight.w500,
        height: lineHeight,
      );
}

/// Entrata sfalsata dei blocchi del retro: parte quando il retro viene
/// montato (metà rotazione), con slide orizzontale + fade e ritardo crescente
/// per indice — l'equivalente del `transitionDelay: index*100 + 200ms` della
/// flip card di riferimento.
class _BackStagger extends StatelessWidget {
  final int index;
  final Widget child;

  const _BackStagger({required this.index, required this.child});

  @override
  Widget build(BuildContext context) {
    return StaggeredItem(
      index: index,
      beginOffset: const Offset(-0.06, 0),
      step: const Duration(milliseconds: 90),
      // Il retro compare a metà rotazione: si aspetta che la card sia quasi
      // frontale prima di far entrare i contenuti.
      initialDelay: const Duration(milliseconds: 180),
      duration: const Duration(milliseconds: 300),
      child: child,
    );
  }
}

// ── Elementi comuni ──────────────────────────────────────────────────────────

/// Pill bianca traslucida del design NUOVO (CSS Rectangle 275/271: 186×33 r18,
/// bianco 20% + bordo 1px bianco 45%, testo 16/500/-0.1em).
class TicketPillButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const TicketPillButton({
    Key? key,
    required this.label,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: R.sp(186),
        height: R.sp(33),
        decoration: BoxDecoration(
          color: const Color(0x33FFFFFF),
          border: Border.all(color: const Color(0x73FFFFFF), width: 1),
          borderRadius: BorderRadius.circular(R.sp(18)),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: OnlistTextStyles.hn(
            color: Colors.white,
            fontSize: R.sp(16),
            fontWeight: FontWeight.w500,
            height: 16 / 16,
            letterSpacing: -0.1 * 16,
          ),
        ),
      ),
    );
  }
}

/// Riga "Ticket x N" + descrizione (24/-0.05em), comune a fronte e retro.
class _QuantityRow extends StatelessWidget {
  final int quantita;
  final String? descrizione;

  const _QuantityRow({required this.quantita, required this.descrizione});

  /// Margine sinistro della riga, in px design dal bordo della card.
  static const double _leftDesign = 26;

  /// Quota a cui parte la descrizione ("Welcome drink", "+ 2 drink"…), sempre
  /// in px design dal bordo della card.
  ///
  /// Il CSS la mette a 148 (left 169 su card a 21); nella 1.1 avevi chiesto di
  /// spostarla ancora a destra e nella 1.11 di nuovo, quindi qui sta a **160**.
  /// Con la card larga 350 e il margine destro di 20 restano 170 px per il
  /// testo, che a corpo 24 basta per "Welcome drink".
  static const double _descrizioneXDesign = 160;

  double get _rowLeft => R.sp(_leftDesign);

  @override
  Widget build(BuildContext context) {
    final style = OnlistTextStyles.hn(
      color: Colors.white,
      fontSize: R.sp(24),
      fontWeight: FontWeight.w400,
      height: 1.0,
      letterSpacing: -0.05 * 24,
    );
    return Padding(
      padding: EdgeInsets.only(left: _rowLeft, right: R.sp(20)),
      child: Row(
        children: [
          // Slot a larghezza FISSA per "Ticket x N": così la descrizione parte
          // sempre alla stessa quota. Prima era "testo + 36 di spazio", quindi
          // la sua posizione dipendeva da quanto misurava "Ticket x N" e
          // ballava da un biglietto all'altro (correzioni 1.11: "metti più a
          // destra l'info Welcome Drink").
          SizedBox(
            width: R.sp(_descrizioneXDesign - _leftDesign),
            child: Text('Ticket x $quantita', style: style),
          ),
          if (descrizione != null && descrizione!.isNotEmpty)
            Flexible(
              child: Text(
                descrizione!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: style,
              ),
            ),
        ],
      ),
    );
  }
}

/// Riga dati personali (16/-0.1em, CSS "Nome : Mario").
class _PersonalRow extends StatelessWidget {
  final String text;

  const _PersonalRow(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: R.sp(29)),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          style: OnlistTextStyles.hn(
            color: Colors.white,
            fontSize: R.sp(16),
            fontWeight: FontWeight.w400,
            height: 1.0,
            letterSpacing: -0.1 * 16,
          ),
        ),
      ),
    );
  }
}

/// Cerchio 28 con freccia, tutto da SVG ufficiali: `cerchio_biglietto.svg`
/// (28×28, stroke 2px) con dentro `freccia_giu.svg` o `freccia_su.svg`.
///
/// Prima erano un `Container` col bordo e le icone Material
/// (`Icons.arrow_downward`/`arrow_upward`). Essendo un widget condiviso, il
/// cambio vale sia per aprire sia per chiudere il biglietto, in tutte le
/// schermate che usano queste card.
///
/// Le due frecce hanno viewBox diverse (15 e 22) ma stesso ingombro ottico:
/// entrambe vengono disegnate dentro il riquadro da 16, come prima.
class ArrowCircle extends StatelessWidget {
  final bool down;

  const ArrowCircle({super.key, required this.down});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: R.sp(28),
      height: R.sp(28),
      child: Stack(
        alignment: Alignment.center,
        children: [
          SvgPicture.asset(
            ImageConstant.imgCircleTicket,
            width: R.sp(28),
            height: R.sp(28),
          ),
          SvgPicture.asset(
            down ? ImageConstant.imgArrowDown : ImageConstant.imgArrowUp,
            width: R.sp(14),
            height: R.sp(14),
          ),
        ],
      ),
    );
  }
}
