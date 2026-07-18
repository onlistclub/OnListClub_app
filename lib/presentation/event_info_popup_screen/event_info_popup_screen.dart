import 'package:flutter/material.dart';

import '../../core/app_export.dart';
import '../../core/models/locale_model.dart';
import '../../core/models/serata_model.dart';
import '../../theme/onlist_colors.dart';
import '../../theme/onlist_text_styles.dart';
import '../../widgets/custom_top_bar.dart';
import '../../widgets/shared_footer.dart';

/// Pop-up info serata (Figma `off/19 - pop up info serata.png`).
///
/// Si raggiunge cliccando sulla **card serata** in schermata 10 (club detail).
/// Mostra tutte le info dell'evento: stile musicale, dress code, età minima,
/// sound system, parcheggio, line-up DJ. Il CTA "Acquista il tuo ticket"
/// naviga alla `bookingScreen` (pagina di scelta Tavolo / Prevendita).
///
/// Riceve come `arguments` una Map: `{'serata': SerataModel, 'club': LocaleModel}`.
///
/// ─────────────────────────────────────────────────────────────────────────────
/// SPAZIATURE: tutti i valori verticali/orizzontali sono **px design Figma**
/// (393×852, card 354×663 a top=119), poi scalati con [R.sp] per device reali.
/// Riferimento CSS: `docs/figma_screen/analisi/pop-up-info-club.css`.
/// ─────────────────────────────────────────────────────────────────────────────
class EventInfoPopupScreen extends StatelessWidget {
  const EventInfoPopupScreen({Key? key}) : super(key: key);

  static Widget builder(BuildContext context) => const EventInfoPopupScreen();

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final serata = args?['serata'] as SerataModel?;
    final club = args?['club'] as LocaleModel?;

    if (serata == null || club == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => NavigatorService.goBack());
      return const Scaffold(backgroundColor: Colors.black);
    }

    // Gradient applicato come "sfondo schermo" dietro l'intero Scaffold (incluso
    // il footer): stesso fix di carrello/booking — il footer semi-trasparente
    // lasciava intravedere il nero piatto sotto la card.
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: OnlistColors.screenBackground),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        // Footer flottante: il contenuto scorre dietro la capsula (non la oscura).
        extendBody: true,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              const CustomTopBar(),
              Expanded(
                // La card deve essere alta quanto il suo contenuto (non
                // forzata a riempire tutto lo schermo): SliverFillRemaining
                // stirava la card fino al fondo del viewport lasciando una
                // coda di gradiente vuoto sotto il CTA (o, con contenuto
                // lungo, andava in overflow e nascondeva il CTA dietro la
                // footer). SliverToBoxAdapter dimensiona la card al
                // contenuto e rende la CustomScrollView scrollabile SOLO
                // se il contenuto non ci sta nello schermo. NON usare
                // IntrinsicHeight qui — non è supportato come discendente
                // di uno scroll/LayoutBuilder e causa un crash di layout.
                child: CustomScrollView(
                  slivers: [
                    SliverPadding(
                      // Margine card: 19px a sinistra/destra (Figma 393−354)/2.
                      // Gap sopra ridotto ulteriormente: la card deve stare
                      // a filo con l'header come nel Figma.
                      // Gap sotto: SOLO la clearance della capsula flottante
                      // (SharedFooter.height), senza margine extra — il CTA
                      // deve stare vicino alla footer come nel Figma, non
                      // con un vuoto aggiuntivo sopra di essa.
                      padding: EdgeInsets.fromLTRB(
                          R.sp(19), R.sp(8), R.sp(19), SharedFooter.height),
                      sliver: SliverToBoxAdapter(
                        child: _PopupCard(serata: serata, club: club),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: const SharedFooter(currentIndex: 1),
      ),
    );
  }
}

/// Key del banner radiale superiore, usata dai test di layout per verificare
/// che la pillola data non ci finisca mai sotto.
const Key bannerKey = Key('popup_banner');

/// Key della pillola data/orario (Rectangle 213), usata dai test di layout.
const Key datePillKey = Key('popup_date_pill');

class _PopupCard extends StatelessWidget {
  const _PopupCard({required this.serata, required this.club});

  final SerataModel serata;
  final LocaleModel club;

  // ── Costanti Figma (px design) ─────────────────────────────────────────────
  // Riferite alla card 354×663. Le posizioni X dei contenuti sono sottratte
  // di 19 (offset card) per ottenere offset interni alla card.
  // Altezza del banner radiale superiore (Rectangle 211) col titolo su UNA
  // riga: Figma top=105 h=134, card top=105 → 134 relativi al bordo card.
  // Finisce 9px sopra la pillola data (Rectangle 213 @143): il bagliore non
  // deve MAI toccare la pillola.
  static const double _bannerBaseH = 134;

  // ── Titolo adattivo ────────────────────────────────────────────────────────
  // Il blocco titolo ha ALTEZZA FISSA = 1 riga a _titleMaxFs (45px): così il
  // contenuto sotto (indirizzo, pillola data, tutto il resto) NON si sposta mai,
  // qualunque sia la lunghezza del nome serata. Comportamento in 3 stadi
  // (vedi _fitTitle):
  //   1. normale         → 1 riga a 45px piena
  //   2. più lungo        → shrink graduale su 1 riga fino a _titleMinFs (22px)
  //   3. oltre ~28 char   → 2 righe a 22px, che stanno nell'altezza di 1 riga a
  //                         45px (2×22=44 ≤ 45) → sotto non si muove nulla.
  static const double _titleMaxFs = 45;
  // 22px è il MASSIMO a cui 2 righe entrano nell'altezza di 1 riga a 45px. Non
  // alzarlo senza alzare anche l'altezza del blocco, o il layout sotto si sposta.
  static const double _titleMinFs = 22;

  // Padding di contenuto: la maggior parte usa ~16, la pill data e i box
  // usano ~12 (più stretti dal bordo card).
  static const double _padContent = 16; // x=35 → 16 da card-left
  static const double _padPill = 12;    // x=31 → 12 da card-left

  /// Stile del titolo serata (Figma: Helvetica Neue w700 LS -0.08em). [fsDesign]
  /// è in px-design (scalato con R.sp); il letter-spacing scala in proporzione
  /// così la spaziatura resta coerente a ogni dimensione.
  TextStyle _titleStyleFs(double fsDesign) => OnlistTextStyles.hn(
        fontSize: R.sp(fsDesign),
        fontWeight: FontWeight.w700,
        color: Colors.white,
        height: 1.0,
        letterSpacing: -0.08 * fsDesign,
      );

  /// Sceglie dimensione font e numero di righe del titolo alla [maxWidth]
  /// disponibile, misurando sui glifi reali: 1 riga il più a lungo possibile
  /// (45→22px), poi 2 righe a 22px. Le 2 righe a 22px stanno nell'altezza fissa
  /// di 1 riga a 45px → il layout sotto non si muove mai.
  _TitleFit _fitTitle(BuildContext context, String text, double maxWidth) {
    final scaler = MediaQuery.textScalerOf(context);
    double oneLineWidth(double fsDesign) {
      final tp = TextPainter(
        text: TextSpan(text: text, style: _titleStyleFs(fsDesign)),
        maxLines: 1,
        textDirection: TextDirection.ltr,
        textScaler: scaler,
      )..layout();
      final w = tp.width;
      tp.dispose();
      return w;
    }

    // Sta già su 1 riga a piena dimensione?
    if (oneLineWidth(_titleMaxFs) <= maxWidth) {
      return const _TitleFit(_titleMaxFs, 1);
    }
    // Font più grande in [min,max] che sta su 1 riga (ricerca binaria, ~5 giri).
    int lo = _titleMinFs.toInt(), hi = _titleMaxFs.toInt(), best = -1;
    while (lo <= hi) {
      final mid = (lo + hi) ~/ 2;
      if (oneLineWidth(mid.toDouble()) <= maxWidth) {
        best = mid;
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }
    if (best >= 0) return _TitleFit(best.toDouble(), 1);
    // Nemmeno a 22px sta su 1 riga → 2 righe a 22px.
    return const _TitleFit(_titleMinFs, 2);
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(R.sp(32));
    // Card linear gradient (Rectangle 210): #2600FF → #1500B2 @53.85% → #000.
    // Min-height ridotto (era 611, troppo rispetto ai gap ora più stretti):
    // con line-up+parcheggio popolati il contenuto reale supera già questo
    // minimo, quindi 611 lasciava un vuoto vistoso sotto "Acquista il tuo
    // ticket". Resta comunque un floor per eventi con poche info.
    return LayoutBuilder(builder: (context, constraints) {
      // Il titolo è inserito a _padContent (16px design) da entrambi i bordi
      // della card: è la larghezza su cui va misurata la resa adattiva.
      final titleFit = _fitTitle(context, serata.nome.toUpperCase(),
          constraints.maxWidth - R.sp(_padContent) * 2);
      // Banner FISSO: il blocco titolo ha ora altezza costante (vedi _fitTitle),
      // quindi il banner resta sempre a 9px sopra la pillola data senza doverlo
      // allungare per le righe extra.
      const double bannerH = _bannerBaseH;
      return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF2600FF), Color(0xFF1500B2), Color(0xFF000000)],
          stops: [0.0, 0.5385, 1.0],
        ),
        borderRadius: radius,
      ),
      constraints: BoxConstraints(minHeight: R.sp(500)),
      // Clip così il banner radiale non sborda dagli angoli arrotondati.
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          children: [
            // Banner radiale top (Rectangle 211) — overlay sopra il linear
            // gradient e SOTTO il testo. Lo Stack disegna i figli nell'ordine
            // dichiarato, quindi questo viene prima del contenuto.
            // CSS: radial-gradient(34.4% 200.32% at 31.78% 68.44%, #0031D2, #2E0098)
            // Centro (31.78%, 68.44%) → Alignment(-0.36, 0.37).
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: Container(
                  key: bannerKey,
                  height: R.sp(bannerH),
                  decoration: const BoxDecoration(
                    // Stessi colori Figma (nessun nuovo hex), ma radius più
                    // stretto: il bagliore risulta più concentrato/intenso
                    // dietro nome e indirizzo, invece di stemperarsi piatto.
                    gradient: RadialGradient(
                      center: Alignment(-0.36, 0.37),
                      radius: 1.1,
                      colors: [Color(0xFF0031D2), Color(0xFF2E0098)],
                    ),
                  ),
                ),
              ),
            ),
            // Contenuto: badge, titolo, indirizzo, data, info, line-up, CTA.
            _buildContent(context, titleFit),
          ],
        ),
      ),
      );
    });
  }

  /// Contenuto della card con spaziature Figma esatte (in design px → R.sp).
  Widget _buildContent(BuildContext context, _TitleFit titleFit) {
    final hasGeneri = serata.generiMusicali.isNotEmpty;
    final hasLineup = serata.lineup.isNotEmpty;

    return Padding(
      // Padding "neutro" che ospita la pill data e i box (i contenuti che vanno
      // PIÙ a sinistra usano _padPill=12). Il testo a 16 lo otteniamo con un
      // ulteriore inset orizzontale di 4 sui sotto-blocchi.
      padding: EdgeInsets.fromLTRB(
        R.sp(_padPill),
        R.sp(20), // top card → badge (Figma: Rectangle 212 @125, card @105)
        R.sp(_padPill),
        R.sp(8),  // bottom card
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // QUESTA SERA badge + close (X) — gap interno standard pill
          _topBadgeAndClose(context),
          // Gap badge → titolo: Figma 20 (badge bottom rel 43, titolo rel 63).
          SizedBox(height: R.sp(20)),
          // Padding interno extra di +4px (16-12) per allineare titolo/indirizzo
          Padding(
            padding: EdgeInsets.symmetric(horizontal: R.sp(_padContent - _padPill)),
            child: _titleAndAddress(titleFit),
          ),
          // Gap indirizzo → pillola data: Figma 17 (indirizzo bottom rel 126,
          // Rectangle 213 rel 143). Il banner finisce a rel 134 → 9px di
          // stacco pulito, la pillola non tocca mai il bagliore viola.
          SizedBox(height: R.sp(17)),
          _datePill(),
          // Gap pillola data → STILE MUSICALE: Figma 15 (pillola bottom rel 170,
          // sezione rel 185).
          SizedBox(height: R.sp(15)),
          if (hasGeneri) ...[
            Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: R.sp(_padContent - _padPill)),
              child: _section('STILE MUSICALE'),
            ),
            SizedBox(height: R.sp(4)),
            _chipsRow(serata.generiMusicali),
            // Gap chip → box info: Figma 12 (chip bottom rel 228, box rel 240).
            SizedBox(height: R.sp(12)),
          ],
          // Box info allineati al titolo/indirizzo (16px dal bordo card):
          // +4px rispetto al padding base _padPill, come nel CSS (x≈36).
          Padding(
            padding: EdgeInsets.symmetric(
                horizontal: R.sp(_padContent - _padPill)),
            child: _infoBoxesGrid(),
          ),
          if (hasLineup) ...[
            // Gap box info → LINE-UP: Figma 11 (box bottom rel 406, sezione rel 417).
            SizedBox(height: R.sp(11)),
            Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: R.sp(_padContent - _padPill)),
              child: _section('LINE-UP'),
            ),
            // Gap LINE-UP → 1° DJ: Figma 9 (sezione bottom rel 433, riga DJ rel 442).
            SizedBox(height: R.sp(9)),
            for (final dj in serata.lineup) ...[
              // Righe DJ allineate al titolo (16px), come i box info.
              Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: R.sp(_padContent - _padPill)),
                child: _djRow(dj),
              ),
              // Gap tra righe DJ: Figma 9 (riga1 bottom rel 492, riga2 rel 501).
              SizedBox(height: R.sp(9)),
            ],
          ],
          // Gap finale prima del CTA (con lineup: 7px già dato dal loop + 20
          // qui = ~27px).
          // NOTA: qui c'era un Expanded per spingere il CTA verso il fondo
          // della card (matchando la proporzione Figma ~93-97%), ma con
          // line-up popolato (2+ DJ) il contenuto fisso è già più alto
          // dello spazio disponibile nella card (SliverFillRemaining forza
          // un'altezza fissa) — l'Expanded andava in overflow e spingeva
          // "Acquista il tuo ticket" fuori dall'area visibile, dietro la
          // footer. Il bottone d'acquisto è un flusso critico (non deve
          // MAI sparire), quindi resta un gap FISSO (sicuro: la card ora
          // si dimensiona sul contenuto, quindi aumentarlo la allunga
          // semplicemente un po', senza rischio di overflow). Aumentato
          // leggermente su richiesta per staccare di più il CTA dalla
          // line-up.
          SizedBox(height: R.sp(hasLineup ? 32 : 28)),
          _acquistaCta(context),
        ],
      ),
    );
  }

  Widget _topBadgeAndClose(BuildContext context) {
    final label = _serataDayLabel();
    return SizedBox(
      // Figma badge height 23
      height: R.sp(23),
      child: Row(
        children: [
          // Badge QUESTA SERA: Rectangle 212, radial gradient teal→blu.
          Container(
            // Padding interno: badge h=23, font 16 → ~3 vert / 12 horiz
            padding: EdgeInsets.symmetric(
                horizontal: R.sp(12), vertical: R.sp(3)),
            decoration: BoxDecoration(
              // CSS: radial-gradient(... rgba(0,162,154,0.53) 0%, rgba(30,0,255,0.53) 100%)
              gradient: const RadialGradient(
                center: Alignment(0.86, -0.5), // 93.16%, 25%
                radius: 1.0,
                colors: [Color(0x8700A29A), Color(0x871E00FF)],
              ),
              borderRadius: BorderRadius.circular(R.sp(10)),
              boxShadow: [
                // box-shadow: 0px 2px 10px rgba(0, 5, 96, 0.48)
                BoxShadow(
                  color: const Color(0x7A000560),
                  offset: Offset(0, R.sp(2)),
                  blurRadius: R.sp(10),
                ),
              ],
            ),
            child: Text(
              label,
              style: OnlistTextStyles.hn(
                fontSize: R.sp(16),
                fontWeight: FontWeight.w700,
                color: Colors.white,
                height: 16 / 16,
                letterSpacing: -0.08 * 16,
              ),
            ),
          ),
          const Spacer(),
          // Close (X) — cerchio outline 24×24, bordo bianco 72%
          GestureDetector(
            onTap: () => NavigatorService.goBack(),
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: R.sp(24),
              height: R.sp(24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.72),
                    width: R.sp(1)),
              ),
              alignment: Alignment.center,
              child: Icon(Icons.close, color: Colors.white, size: R.sp(14)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _titleAndAddress(_TitleFit fit) {
    // Titolo con gradient text bianco→azzurrino + ombra blu (Figma):
    // background: radial-gradient(50% 50% at 50% 50%, #FFFFFF 0%, #E0E1FF 100%)
    // text-shadow: 0px 4px 4px rgba(38, 0, 255, 0.63)
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Blocco titolo ad ALTEZZA FISSA (1 riga a 45px): dimensione font e
        // numero righe li sceglie _fitTitle (1 riga piena → shrink su 1 riga →
        // 2 righe a 22px), senza MAI spostare il contenuto sotto. Il titolo è
        // centrato in verticale nel blocco così, quando è rimpicciolito, non
        // lascia buchi né verso il badge né verso l'indirizzo.
        SizedBox(
          height: R.sp(_titleMaxFs),
          width: double.infinity,
          child: Align(
            alignment: Alignment.centerLeft,
            child: ShaderMask(
              shaderCallback: (Rect bounds) {
                return const RadialGradient(
                  center: Alignment.center,
                  radius: 0.7,
                  colors: [Color(0xFFFFFFFF), Color(0xFFE0E1FF)],
                ).createShader(bounds);
              },
              blendMode: BlendMode.srcIn,
              child: Text(
                serata.nome.toUpperCase(),
                style: _titleStyleFs(fit.fsDesign).copyWith(
                  shadows: [
                    Shadow(
                      color: const Color(0xA12600FF),
                      offset: Offset(0, R.sp(4)),
                      blurRadius: R.sp(4),
                    ),
                  ],
                ),
                maxLines: fit.lines,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
        // Titolo h=45, baseline a y=45+rel49=94, indirizzo a 96 → 2px gap
        SizedBox(height: R.sp(2)),
        // Indirizzo indentato +4px rispetto al titolo: Figma titolo x=35 (rel16),
        // indirizzo x=39 (rel20).
        Padding(
          padding: EdgeInsets.only(left: R.sp(4)),
          child: Text(
            club.indirizzoCompleto,
            style: OnlistTextStyles.hn(
              fontSize: R.sp(16),
              fontWeight: FontWeight.w400,
              color: Colors.white.withValues(alpha: 0.77),
              height: 16 / 16,
              letterSpacing: -0.08 * 16,
            ),
          ),
        ),
      ],
    );
  }

  Widget _datePill() {
    final date = _dateLong(serata.data);
    final orario = serata.orarioString;
    final text = orario.isNotEmpty
        ? '$date · ${orario.replaceAll(' - ', ' → ')}'
        : date;
    return Container(
      key: datePillKey,
      width: double.infinity,
      // Figma height 41, font 20 → ~10 padding verticale
      padding: EdgeInsets.symmetric(
          horizontal: R.sp(14), vertical: R.sp(10)),
      decoration: BoxDecoration(
        // CSS Rectangle 213: nero 27%, r11.
        color: Colors.black.withValues(alpha: 0.27),
        borderRadius: BorderRadius.circular(R.sp(11)),
      ),
      alignment: Alignment.center,
      // FittedBox forza il testo (con la freccia "→") su UNA riga sola,
      // rimpicciolendolo se serve invece di andare a capo (il wrap
      // spingeva l'orario su una seconda riga, "coprendo" il layout sotto).
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          text,
          maxLines: 1,
          style: OnlistTextStyles.hn(
            fontSize: R.sp(20),
            fontWeight: FontWeight.w500,
            color: Colors.white,
            height: 20 / 20,
            letterSpacing: -0.08 * 20,
          ),
        ),
      ),
    );
  }

  Widget _section(String label) {
    return Text(
      label,
      style: OnlistTextStyles.hn(
        fontSize: R.sp(16),
        fontWeight: FontWeight.w500,
        color: Colors.white,
        height: 16 / 16,
        letterSpacing: -0.05 * 16,
      ),
    );
  }

  Widget _chipsRow(List<String> generi) {
    // CSS chip height 23, font 16 → ~4 vert / 12 horiz
    return Wrap(
      spacing: R.sp(10),
      runSpacing: R.sp(8),
      children: [
        for (var i = 0; i < generi.length; i++)
          Opacity(
            opacity: i == 0 ? 1.0 : 0.5,
            child: Container(
              padding: EdgeInsets.symmetric(
                  horizontal: R.sp(12), vertical: R.sp(4)),
              decoration: BoxDecoration(
                color: i == 0
                    ? const Color(0x330004FF)
                    : const Color(0x33000000),
                // Bordo bianco 1px ~20%, coerente con i box info.
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2), width: 1),
                borderRadius: BorderRadius.circular(R.sp(11)),
              ),
              child: Text(
                generi[i],
                style: OnlistTextStyles.hn(
                  fontSize: R.sp(16),
                  fontWeight: FontWeight.w400,
                  color: Colors.white,
                  height: 16 / 16,
                  letterSpacing: -0.08 * 16,
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// Quattro box DRESS CODE / ETÀ MINIMA / SOUND SISTEM / PARCHEGGIO.
  Widget _infoBoxesGrid() {
    final items = <_InfoBox>[
      if (serata.dressCode != null && serata.dressCode!.isNotEmpty)
        _InfoBox('DRESS CODE', serata.dressCode!),
      if (serata.etaMinima != null && serata.etaMinima!.isNotEmpty)
        _InfoBox('ETÀ MINIMA', serata.etaMinima!),
      if (serata.soundSystem != null && serata.soundSystem!.isNotEmpty)
        _InfoBox('SOUND SISTEM', serata.soundSystem!),
      if (serata.parcheggio != null && serata.parcheggio!.isNotEmpty)
        _InfoBox('PARCHEGGIO', serata.parcheggio!),
    ];
    if (items.isEmpty) return const SizedBox.shrink();
    final rows = <Widget>[];
    for (var i = 0; i < items.length; i += 2) {
      final left = items[i];
      final right = i + 1 < items.length ? items[i + 1] : null;
      // Gap inter-riga 8px Figma (row1@240 → row2@327; 327-240-79=8)
      final bool isLast = i + 2 >= items.length;
      rows.add(Padding(
        padding: EdgeInsets.only(bottom: isLast ? 0 : R.sp(8)),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _renderInfoBox(left)),
              SizedBox(width: R.sp(7)), // 199-(36+156)=7 → gap centrale
              Expanded(
                child: right != null
                    ? _renderInfoBox(right)
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ));
    }
    return Column(children: rows);
  }

  Widget _renderInfoBox(_InfoBox box) {
    // Box 156×79: pill etichetta a y=7 (366-359), label x=5 dal box (46-41),
    // valore a y=36 (395-359).
    return Container(
      padding: EdgeInsets.fromLTRB(R.sp(5), R.sp(7), R.sp(5), R.sp(8)),
      decoration: BoxDecoration(
        color: const Color(0x291E00FF),
        // Bordo bianco 1px ~20%: rende il box leggibile sul gradiente blu
        // (il fill 16% da solo era quasi invisibile).
        border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1),
        borderRadius: BorderRadius.circular(R.sp(11)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Etichetta pill: h=15, font 10 → padding ~2.5 vert / 5 horiz
          Container(
            padding: EdgeInsets.symmetric(
                horizontal: R.sp(5), vertical: R.sp(2)),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [Color(0x70D9D9D9), Color(0x701E00FF)],
              ),
              borderRadius: BorderRadius.circular(R.sp(7)),
            ),
            child: Text(
              box.title,
              style: OnlistTextStyles.hn(
                fontSize: R.sp(10),
                fontWeight: FontWeight.w500,
                color: Colors.white,
                height: 10 / 10,
                letterSpacing: -0.05 * 10,
              ),
            ),
          ),
          // Pill bottom @22, valore top @36 → 14 px gap
          SizedBox(height: R.sp(14)),
          Text(
            box.value,
            style: OnlistTextStyles.hn(
              fontSize: R.sp(20),
              fontWeight: FontWeight.w500,
              color: Colors.white,
              height: 20 / 20,
              letterSpacing: -0.05 * 20,
            ),
          ),
        ],
      ),
    );
  }

  Widget _djRow(LineupDj dj) {
    final init = (dj.iniziali ?? _initialsFromName(dj.nome)).toUpperCase();
    final orario = dj.orarioString;
    final stage = dj.stage ?? '';
    final subtitle = [
      if (stage.isNotEmpty) stage,
      if (orario.isNotEmpty) orario,
    ].join(' · ');
    return Container(
      // Figma box DJ: 320×50, x=35 (cioè 16 dal bordo card). Riempie la card
      // con _padPill=12; aggiungiamo solo un margine interno coerente.
      // Padding verticale ~7: avatar 35 + 2×7 ≈ 49 ≈ altezza Figma 50.
      padding: EdgeInsets.symmetric(
          horizontal: R.sp(11), vertical: R.sp(7)),
      decoration: BoxDecoration(
        color: const Color(0x291E00FF),
        // Bordo bianco 1px ~20%, coerente con box info e chip.
        border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1),
        borderRadius: BorderRadius.circular(R.sp(19)),
      ),
      child: Row(
        children: [
          Container(
            width: R.sp(35),
            height: R.sp(35),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x75FFFFFF), Color(0x753700FF)],
              ),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              init,
              style: OnlistTextStyles.hn(
                fontSize: R.sp(16),
                fontWeight: FontWeight.w500,
                color: Colors.white,
                height: 16 / 16,
                letterSpacing: -0.05 * 16,
              ),
            ),
          ),
          SizedBox(width: R.sp(7)), // 88-(46+35)=7
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  dj.nome,
                  style: OnlistTextStyles.hn(
                    fontSize: R.sp(16),
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                    height: 16 / 16,
                    letterSpacing: -0.05 * 16,
                  ),
                ),
                if (subtitle.isNotEmpty) ...[
                  SizedBox(height: R.sp(3)),
                  Text(
                    subtitle,
                    style: OnlistTextStyles.hn(
                      fontSize: R.sp(13),
                      fontWeight: FontWeight.w300,
                      color: Colors.white,
                      height: 13 / 13,
                      letterSpacing: -0.05 * 13,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (dj.headliner)
            Container(
              // Figma: 79×26, font 13 → padding ~6 vert / 10 horiz
              padding: EdgeInsets.symmetric(
                  horizontal: R.sp(10), vertical: R.sp(6)),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [Color(0x59FFFFFF), Color(0x59007D99)],
                ),
                borderRadius: BorderRadius.circular(R.sp(9)),
              ),
              child: Text(
                'HEADLINER',
                style: OnlistTextStyles.hn(
                  fontSize: R.sp(13),
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  height: 13 / 13,
                  letterSpacing: -0.05 * 13,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _acquistaCta(BuildContext context) {
    return GestureDetector(
      onTap: () => NavigatorService.pushNamed(
        AppRoutes.bookingScreen,
        arguments: {'serata': serata, 'club': club},
      ),
      child: Container(
        width: double.infinity,
        // Figma 323×45, font 32 → padding ~6 vert
        padding: EdgeInsets.symmetric(vertical: R.sp(6)),
        decoration: BoxDecoration(
          // CSS Rectangle 229: gradient blu 51% (#1F00FF→#1900D8). Il Figma
          // esporta r15, ma su richiesta gli angoli sono più arrotondati (r26)
          // per un look più morbido, senza arrivare alla capsula piena.
          gradient: const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [Color(0x821F00FF), Color(0x821900D8)],
          ),
          borderRadius: BorderRadius.circular(R.sp(26)),
        ),
        alignment: Alignment.center,
        child: Text(
          'Acquista il tuo ticket',
          style: OnlistTextStyles.hn(
            fontSize: R.sp(32),
            fontWeight: FontWeight.w500,
            color: Colors.white,
            height: 32 / 32,
            letterSpacing: -0.05 * 32,
          ),
        ),
      ),
    );
  }

  String _serataDayLabel() {
    final now = DateTime.now();
    final d = serata.data;
    final today = DateTime(now.year, now.month, now.day);
    final eventDay = DateTime(d.year, d.month, d.day);
    final diff = eventDay.difference(today).inDays;
    if (diff == 0) return 'QUESTA SERA';
    if (diff == 1) return 'DOMANI';
    return 'PROSSIMA SERATA';
  }

  String _dateLong(DateTime d) {
    const giorni = [
      'Lunedì', 'Martedì', 'Mercoledì', 'Giovedì', 'Venerdì', 'Sabato', 'Domenica'
    ];
    const mesi = [
      'Gennaio', 'Febbraio', 'Marzo', 'Aprile', 'Maggio', 'Giugno',
      'Luglio', 'Agosto', 'Settembre', 'Ottobre', 'Novembre', 'Dicembre'
    ];
    return '${giorni[d.weekday - 1]} ${d.day} ${mesi[d.month - 1]}';
  }

  String _initialsFromName(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, parts.first.length.clamp(0, 2));
    return '${parts.first[0]}${parts.last[0]}';
  }
}

class _InfoBox {
  final String title;
  final String value;
  const _InfoBox(this.title, this.value);
}

/// Risultato di [_PopupCard._fitTitle]: dimensione font (px-design) e numero di
/// righe con cui rendere il titolo serata.
class _TitleFit {
  final double fsDesign;
  final int lines;
  const _TitleFit(this.fsDesign, this.lines);
}
