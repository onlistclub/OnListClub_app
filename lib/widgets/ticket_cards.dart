import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

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
///   e "Visualizza QR Code" con la freccia giù.
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

// ── Stato A: biglietto chiuso ────────────────────────────────────────────────
class TicketCollapsedCard extends StatelessWidget {
  final String clubName;
  final VoidCallback onTap;

  const TicketCollapsedCard({
    Key? key,
    required this.clubName,
    required this.onTap,
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
                  'Visualizza QR Code',
                  style: OnlistTextStyles.hn(
                    color: Colors.white,
                    fontSize: R.sp(15),
                    fontWeight: FontWeight.w400,
                    letterSpacing: -0.1 * 15,
                  ),
                ),
                SizedBox(height: R.sp(9)),
                const _ArrowCircle(down: true),
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

  /// Richiude il biglietto ("Nascondi QR Code" + freccia su).
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

  /// Altezza card (CSS Rectangle 268: 350×614).
  static const double cardHeightDesign = 614;

  /// Quote delle DUE separazioni, in px design dal bordo alto della card.
  /// Nel CSS le linee tratteggiate (`Line 15` @301, `Line 16` @449) cadono
  /// esattamente sul centro delle tacche (`Ellipse 18` @282+38/2 e @430+38/2),
  /// con la card a top 161: 301−161 = 140 e 449−161 = 288.
  ///
  /// Sono la FONTE DI VERITÀ UNICA per tacche e linee: prima le tacche stavano
  /// a quota fissa mentre le linee scorrevano dentro la Column accumulando le
  /// altezze reali dei testi, e la seconda linea finiva 8px sopra la sua tacca.
  static const double _separator1Y = 140;
  static const double _separator2Y = 288;

  /// Semiassi della tacca (CSS `Ellipse 18` 41×38) e sporgenza del centro
  /// oltre il bordo: 41/2 = 20.5, 38/2 = 19, centro 1.5px fuori → profondità 19.
  static const double _notchRx = 20.5;
  static const double _notchRy = 19;
  static const double _notchEdgeOffset = 1.5;

  @override
  Widget build(BuildContext context) {
    const cardH = cardHeightDesign;
    return SizedBox(
      height: R.sp(cardH),
      width: double.infinity,
      child: TicketShape(
        notches: const [
          TicketNotch(
            centerYFraction: _separator1Y / cardH,
            radiusDesign: _notchRx,
            radiusYDesign: _notchRy,
            edgeOffsetDesign: _notchEdgeOffset,
          ),
          TicketNotch(
            centerYFraction: _separator2Y / cardH,
            radiusDesign: _notchRx,
            radiusYDesign: _notchRy,
            edgeOffsetDesign: _notchEdgeOffset,
          ),
        ],
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
                // "Nascondi QR Code" + freccia su → richiude il biglietto.
                Center(
                  child: GestureDetector(
                    onTap: onCollapse,
                    behavior: HitTestBehavior.opaque,
                    child: Column(
                      children: [
                        Text(
                          'Nascondi QR Code',
                          style: OnlistTextStyles.hn(
                            color: Colors.white,
                            fontSize: R.sp(15),
                            fontWeight: FontWeight.w400,
                            height: 15 / 15,
                            letterSpacing: -0.1 * 15,
                          ),
                        ),
                        SizedBox(height: R.sp(8)),
                        const _ArrowCircle(down: false),
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
      height: R.sp(614),
      width: double.infinity,
      child: TicketShape(
        // Una sola coppia di tacche, sulla linea tratteggiata (CSS Line 15
        // @299.55 su card a 157).
        notches: const [
          TicketNotch(centerYFraction: 142.5 / 614, radiusDesign: 20.5),
        ],
        borderWidthDesign: 3,
        borderColor: OnlistColors.ticketCardBorderOpen,
        // I blocchi entrano SFALSATI (stagger) quando il retro compare, cioè
        // a metà rotazione: slide orizzontale + fade, ritardo crescente —
        // stesso effetto della flip card di riferimento.
        child: Column(
          children: [
            SizedBox(height: R.sp(29)),
            // Nome locale 55/500 centrato.
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
                      fontWeight: FontWeight.w700,
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
              child: _QuantityRow(quantita: quantita, descrizione: descrizione),
            ),
            SizedBox(height: R.sp(15)),
            const _BackStagger(index: 2, child: DashedLine(widthDesign: 297)),
            SizedBox(height: R.sp(9)),
            // Evento: nome 48/500, sottotitolo 32/500, data 22/500 — centrati.
            _BackStagger(
              index: 3,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: R.sp(22)),
                child: Column(
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        eventoNome,
                        style: OnlistTextStyles.hn(
                          color: Colors.white,
                          fontSize: R.sp(48),
                          fontWeight: FontWeight.w500,
                          height: 47 / 48,
                        ),
                      ),
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
            // col QR VERO 228×228 su riquadro bianco 20% r16.
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
                      SizedBox(height: R.sp(38)),
                      Container(
                        width: R.sp(228),
                        height: R.sp(228),
                        decoration: BoxDecoration(
                          color: const Color(0x33FFFFFF),
                          borderRadius: BorderRadius.circular(R.sp(16)),
                        ),
                        padding: EdgeInsets.all(R.sp(12)),
                        // QR reale (scansionabile dallo staff), non decorativo.
                        child: QrImageView(
                          data: qrData,
                          version: QrVersions.auto,
                          backgroundColor: Colors.transparent,
                          eyeStyle: const QrEyeStyle(
                            eyeShape: QrEyeShape.square,
                            color: Colors.white,
                          ),
                          dataModuleStyle: const QrDataModuleStyle(
                            dataModuleShape: QrDataModuleShape.square,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      SizedBox(height: R.sp(27)),
                      TicketPillButton(label: 'NASCONDI', onTap: onHide),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
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
      padding: EdgeInsets.only(left: R.sp(26), right: R.sp(20)),
      child: Row(
        children: [
          Text('Ticket x $quantita', style: style),
          if (descrizione != null && descrizione!.isNotEmpty) ...[
            // CSS: la descrizione parte a x 170 e l'app c'era già (169). Gli 8px
            // in più (28 → 36) sono uno scostamento VOLUTO da Luca.
            SizedBox(width: R.sp(36)),
            Flexible(
              child: Text(
                descrizione!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: style,
              ),
            ),
          ],
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

/// Cerchio 28 con bordo 2px e freccia (CSS Ellipse 9 + arrow_back ruotata).
class _ArrowCircle extends StatelessWidget {
  final bool down;

  const _ArrowCircle({required this.down});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: R.sp(28),
      height: R.sp(28),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Icon(
        down ? Icons.arrow_downward : Icons.arrow_upward,
        color: Colors.white,
        size: R.sp(16),
      ),
    );
  }
}
