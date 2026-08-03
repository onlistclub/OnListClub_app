import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_export.dart';
import '../../core/models/locale_model.dart';
import '../../core/models/serata_model.dart';
import '../../theme/onlist_colors.dart';
import '../../theme/onlist_text_styles.dart';
import '../../widgets/custom_top_bar.dart';
import '../../widgets/glow_card.dart';
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
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final serata = args?['serata'] as SerataModel?;
    final club = args?['club'] as LocaleModel?;

    if (serata == null || club == null) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => NavigatorService.goBack());
      return const Scaffold(backgroundColor: Colors.black);
    }

    // Design NUOVO: sfondo NERO FISSO dietro tutte le schermate.
    return ColoredBox(
      color: Colors.black,
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
        // Footer: unica e globale, montata da RootShell (non qui).
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
  // CSS NUOVO "pop up info club": card 354×629 a left 20. Le posizioni dei
  // contenuti sono relative al bordo card.
  // Altezza del banner radiale superiore (Rectangle 211): 129 relativi al
  // bordo card. Finisce sopra la pillola data: il bagliore non la tocca MAI.
  static const double _bannerBaseH = 129;

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

  // Padding di contenuto: nel CSS NUOVO tutto è allineato a ~17 dal bordo
  // card (badge/pill data/box a x=37 su card a 20; line-up 36, CTA 35).
  static const double _padContent = 17;
  static const double _padPill = 17;

  /// Centro del gradiente del badge (CSS `at 93.16% 25%`), in coordinate
  /// Alignment: 2·0.9316−1 e 2·0.25−1.
  static const Alignment _badgeGradientCenter = Alignment(0.8632, -0.5);

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
        constraints: BoxConstraints(minHeight: R.sp(500)),
        // CSS NUOVO Rectangle 210: bordo 1px bianco PIENO sopra tutto.
        foregroundDecoration: BoxDecoration(
          border: Border.all(color: Colors.white, width: 1),
          borderRadius: radius,
        ),
        // Clip così banner e glow non sbordano dagli angoli arrotondati.
        child: ClipRRect(
          borderRadius: radius,
          child: GlowCard(
            // CSS NUOVO: 180deg #2600FF → #00308B (resta blu fino in fondo)
            // + glow interno `inset 0 0 50px #0033FF` (Frame 416).
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF2600FF), Color(0xFF00308B)],
            ),
            radius: R.sp(32),
            glowColor: const Color(0xFF0033FF),
            glowSigma: R.sp(25), // blur CSS 50
            child: Stack(
              children: [
                // Banner radiale top (Rectangle 211) — overlay sopra il linear
                // gradient e SOTTO il testo. Lo Stack disegna i figli nell'ordine
                // dichiarato, quindi questo viene prima del contenuto.
                // CSS NUOVO: radial(34.4% at 31.78% 68.44%, #0031D2 → #0077FF),
                // bordo basso 1px bianco 59% che separa banner e corpo card.
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: IgnorePointer(
                    child: Container(
                      key: bannerKey,
                      height: R.sp(bannerH),
                      decoration: const BoxDecoration(
                        gradient: RadialGradient(
                          center: Alignment(-0.36, 0.37),
                          radius: 1.1,
                          colors: [Color(0xFF0031D2), Color(0xFF0077FF)],
                        ),
                        border: Border(
                          bottom:
                              BorderSide(color: Color(0x96FFFFFF), width: 1),
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
        R.sp(12), // CSS NUOVO: badge a rel y 12 dal bordo card
        R.sp(_padPill),
        R.sp(13), // bottom card (CTA bottom rel 618 su card 631)
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // QUESTA SERA badge + close (X) — gap interno standard pill
          _topBadgeAndClose(context),
          // Gap badge → titolo: CSS NUOVO — titolo a rel 51; la riga badge è
          // alta 30 (X inclusa) e parte da rel 12 → 51−42 = 9.
          SizedBox(height: R.sp(9)),
          // Padding interno extra di +4px (16-12) per allineare titolo/indirizzo
          Padding(
            padding:
                EdgeInsets.symmetric(horizontal: R.sp(_padContent - _padPill)),
            child: _titleAndAddress(titleFit),
          ),
          // Gap indirizzo → pillola data: Figma 17 (indirizzo bottom rel 126,
          // Rectangle 213 rel 143). Il banner finisce a rel 134 → 9px di
          // stacco pulito, la pillola non tocca mai il bagliore viola.
          SizedBox(height: R.sp(17)),
          _datePill(),
          // Gap pillola data → STILE MUSICALE: CSS NUOVO 13 (pillola bottom
          // rel 176, sezione rel 189).
          SizedBox(height: R.sp(13)),
          if (hasGeneri) ...[
            Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: R.sp(_padContent - _padPill)),
              child: _section('STILE MUSICALE'),
            ),
            SizedBox(height: R.sp(8)),
            _chipsRow(serata.generiMusicali),
            // Gap chip → box info: CSS NUOVO 10 (chip bottom 236, box 246).
            SizedBox(height: R.sp(10)),
          ],
          // Box info allineati al titolo/indirizzo (16px dal bordo card):
          // +4px rispetto al padding base _padPill, come nel CSS (x≈36).
          Padding(
            padding:
                EdgeInsets.symmetric(horizontal: R.sp(_padContent - _padPill)),
            child: _infoBoxesGrid(),
          ),
          if (hasLineup) ...[
            // Gap box info → LINE-UP: CSS NUOVO 13 (box bottom 412, sez. 425).
            SizedBox(height: R.sp(13)),
            Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: R.sp(_padContent - _padPill)),
              child: _section('LINE-UP'),
            ),
            // Gap LINE-UP → 1° DJ: CSS NUOVO 7 (sezione bottom 441, riga 448).
            SizedBox(height: R.sp(7)),
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
          // CSS NUOVO: ultima riga line-up bottom rel 557 → CTA rel 574 = 17
          // (senza line-up resta un respiro maggiore).
          SizedBox(height: R.sp(hasLineup ? 8 : 28)),
          _acquistaCta(context),
        ],
      ),
    );
  }

  Widget _topBadgeAndClose(BuildContext context) {
    final label = _serataDayLabel();
    // Riga alta quanto la X (30): il badge (23) sta in alto come nel CSS
    // (badge rel y 12, X rel y 8 — la X sporge un filo sopra).
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Badge QUESTA SERA: Rectangle 212, radial gradient teal→blu.
        Container(
          // Padding interno: badge h=23, font 16 → ~3 vert / 12 horiz
          padding:
              EdgeInsets.symmetric(horizontal: R.sp(12), vertical: R.sp(3)),
          decoration: BoxDecoration(
            // CSS: radial-gradient(90.17% 90.17% at 93.16% 25%,
            //      rgba(0,162,154,.53) 0%, rgba(30,0,255,.53) 100%)
            // I due raggi sono 90.17% della LARGHEZZA e dell'ALTEZZA: su una
            // pill 117×23 è un'ellisse 105×20.7. Con `radius: 1.0` Flutter
            // misurava sul lato corto e disegnava un cerchio di 23, quindi il
            // teal restava confinato in un puntino e il badge usciva blu
            // piatto (misurato: canale verde 0x19÷0x21 costante, contro lo
            // 0x2A→0x71 crescente del Figma).
            gradient: const RadialGradient(
              center: _badgeGradientCenter,
              radius: 0.9017,
              colors: [Color(0x8700A29A), Color(0x871E00FF)],
              transform: CssEllipticalGradient(_badgeGradientCenter),
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
        // Close (X) — SVG ufficiali: cerchio 30×30 (stroke 1px) con dentro la
        // X 24×24 (stroke 2px), portata a 16 come nel design. Erano un
        // Container con bordo e l'icona Material `Icons.close`.
        GestureDetector(
          onTap: () => NavigatorService.goBack(),
          behavior: HitTestBehavior.opaque,
          child: SizedBox(
            width: R.sp(30),
            height: R.sp(30),
            child: Stack(
              alignment: Alignment.center,
              children: [
                SvgPicture.asset(
                  ImageConstant.imgCirclePopup,
                  width: R.sp(30),
                  height: R.sp(30),
                ),
                SvgPicture.asset(
                  ImageConstant.imgClose,
                  width: R.sp(16),
                  height: R.sp(16),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _titleAndAddress(_TitleFit fit) {
    // Titolo BIANCO PIENO, senza effetti (scelta di Luca).
    //
    // Prima c'erano il gradient text del CSS (radial #FFFFFF → #E0E1FF) e la
    // sua ombra blu (0 4px 4px). Il problema: il `ShaderMask` con
    // `BlendMode.srcIn` ricolora TUTTO ciò che non è trasparente, ombra
    // compresa — l'ombra blu stretta diventava una macchia BIANCA e sfocata
    // attorno alle lettere, cioè l'alone che nel Figma non c'è.
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
            child: Text(
              serata.nome.toUpperCase(),
              style: _titleStyleFs(fit.fsDesign),
              maxLines: fit.lines,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        // CSS NUOVO: blocco titolo bottom rel 96 → indirizzo rel 102 = 6px gap
        SizedBox(height: R.sp(6)),
        // Indirizzo indentato +4px rispetto al titolo: Figma titolo x=35 (rel16),
        // indirizzo x=39 (rel20). Accanto, il tastino che apre le mappe.
        Padding(
          padding: EdgeInsets.only(left: R.sp(4)),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  club.indirizzoCompleto,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: OnlistTextStyles.hn(
                    fontSize: R.sp(16),
                    fontWeight: FontWeight.w400,
                    color: Colors.white.withValues(alpha: 0.77),
                    height: 16 / 16,
                    letterSpacing: -0.08 * 16,
                  ),
                ),
              ),
              SizedBox(width: R.sp(8)),
              _mapButton(),
            ],
          ),
        ),
      ],
    );
  }

  /// Tastino "mappe" accanto all'indirizzo. Non è nel Figma: aggiunto su
  /// richiesta di Luca.
  ///
  /// Usa `url_launcher`, già nel progetto e già impiegato allo stesso scopo in
  /// `club_detail_screen._openMaps`, invece di aggiungere `map_launcher` per un
  /// solo bottone (CLAUDE.md §5.3: niente dipendenze evitabili).
  ///
  /// SVG ufficiali forniti da Luca: sfondo pill 44×16 (`imgMapButtonBg`) +
  /// wordmark "Mappe" 35×9 (`imgMapButtonLabel`) sovrapposto, stesso pattern
  /// cerchio+X del bottone di chiusura sopra.
  ///
  /// Deliberatamente COMPATTO (16px di altezza): l'indirizzo chiude a rel 126 e
  /// il banner radiale finisce a rel 134, quindi il bottone deve stare in quegli
  /// 8px di franco o sborda dal banner.
  Widget _mapButton() {
    return GestureDetector(
      onTap: _openMaps,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: R.sp(44),
        height: R.sp(16),
        child: Stack(
          alignment: Alignment.center,
          children: [
            SvgPicture.asset(
              ImageConstant.imgMapButtonBg,
              width: R.sp(44),
              height: R.sp(16),
            ),
            SvgPicture.asset(
              ImageConstant.imgMapButtonLabel,
              width: R.sp(35),
              height: R.sp(9),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openMaps() async {
    final encoded = Uri.encodeComponent(club.indirizzoCompleto);
    final uri = Uri.parse('https://maps.google.com/?q=$encoded');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Widget _datePill() {
    final date = _dateLong(serata.data);
    final orario = serata.orarioString;
    final text =
        orario.isNotEmpty ? '$date · ${orario.replaceAll(' - ', ' → ')}' : date;
    return Container(
      key: datePillKey,
      width: double.infinity,
      // Figma height 41, font 20 → ~10 padding verticale
      padding: EdgeInsets.symmetric(horizontal: R.sp(14), vertical: R.sp(10)),
      decoration: BoxDecoration(
        // CSS NUOVO Rectangle 213: fill trasparente + bordo 1px bianco 38%,
        // r19 (319×41).
        border: Border.all(color: const Color(0x61FFFFFF), width: 1),
        borderRadius: BorderRadius.circular(R.sp(19)),
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
          // WORKAROUND w500 → w700: vedi nota in `_renderInfoBox`.
          style: OnlistTextStyles.hn(
            fontSize: R.sp(20),
            fontWeight: FontWeight.w700,
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
              padding:
                  EdgeInsets.symmetric(horizontal: R.sp(12), vertical: R.sp(4)),
              decoration: BoxDecoration(
                // CSS NUOVO Rectangle 214-217: bianco 20%, r11, senza bordo
                // (l'attenuazione delle chip non attive resta con Opacity).
                color: const Color(0x33FFFFFF),
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
        // CSS NUOVO Rectangle 218/219/222/224: bordo 1px bianco 36%.
        border: Border.all(color: const Color(0x5CFFFFFF), width: 1),
        borderRadius: BorderRadius.circular(R.sp(11)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Etichetta pill: h=15, font 10 → padding ~2.5 vert / 5 horiz
          Container(
            padding:
                EdgeInsets.symmetric(horizontal: R.sp(5), vertical: R.sp(2)),
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
            // WORKAROUND w500: il CSS dice 500 e il codice lo chiedeva già, ma
            // la faccia Medium non viene agganciata e usciva in Roman. w700 su
            // scelta di Luca per vederlo grassetto SUBITO — da riportare a
            // w500 quando il bug del w500 sarà risolto. Il titoletto sopra
            // resta leggero, come da design.
            style: OnlistTextStyles.hn(
              fontSize: R.sp(20),
              fontWeight: FontWeight.w700,
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
      padding: EdgeInsets.symmetric(horizontal: R.sp(11), vertical: R.sp(7)),
      decoration: BoxDecoration(
        color: const Color(0x291E00FF),
        // CSS NUOVO Rectangle 226/228: bordo 1px bianco ~36%, r19.
        border: Border.all(color: const Color(0x5CFFFFFF), width: 1),
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
              padding:
                  EdgeInsets.symmetric(horizontal: R.sp(10), vertical: R.sp(6)),
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
        height: R.sp(44),
        decoration: BoxDecoration(
          // CSS NUOVO Rectangle 229: fill scuro traslucido rgba(28,0,93,0.22)
          // + bordo 1px bianco 46%, r20 (323×44).
          color: const Color(0x381C005D),
          border: Border.all(color: const Color(0x75FFFFFF), width: 1),
          borderRadius: BorderRadius.circular(R.sp(20)),
        ),
        alignment: Alignment.center,
        child: Text(
          'Acquista il tuo ticket',
          // WORKAROUND w500 → w700: vedi nota in `_renderInfoBox`.
          style: OnlistTextStyles.hn(
            fontSize: R.sp(32),
            fontWeight: FontWeight.w700,
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
      'Lunedì',
      'Martedì',
      'Mercoledì',
      'Giovedì',
      'Venerdì',
      'Sabato',
      'Domenica'
    ];
    const mesi = [
      'Gennaio',
      'Febbraio',
      'Marzo',
      'Aprile',
      'Maggio',
      'Giugno',
      'Luglio',
      'Agosto',
      'Settembre',
      'Ottobre',
      'Novembre',
      'Dicembre'
    ];
    return '${giorni[d.weekday - 1]} ${d.day} ${mesi[d.month - 1]}';
  }

  String _initialsFromName(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1)
      return parts.first.substring(0, parts.first.length.clamp(0, 2));
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
