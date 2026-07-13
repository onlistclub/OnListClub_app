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
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              const CustomTopBar(),
              Expanded(
                // La card (col suo sfondo gradiente) deve estendersi fino in
                // fondo allo spazio disponibile, non fermarsi a metà lasciando
                // uno sfondo piatto sotto. SliverFillRemaining(hasScrollBody:
                // false) fa da "Expanded dentro lo scroll": riempie tutta
                // l'altezza residua quando c'è spazio, e permette comunque lo
                // scroll se il contenuto (tanti DJ in line-up) supera lo
                // schermo. NON usare IntrinsicHeight qui — non è supportato
                // come discendente di uno scroll/LayoutBuilder e causa un
                // crash di layout.
                child: CustomScrollView(
                  slivers: [
                    SliverPadding(
                      // Margine card: 19px a sinistra/destra (Figma 393−354)/2.
                      // Gap sopra allineato alla proporzione Figma (header→card
                      // ~3.5% dell'altezza schermo, era 2.5%). Gap sotto ridotto
                      // verso il Figma ufficiale, dove la card tocca quasi la
                      // nav bar (Frame 416 bottom = nav bar top, gap zero).
                      padding: EdgeInsets.fromLTRB(
                          R.sp(19), R.sp(40), R.sp(19), R.sp(16)),
                      sliver: SliverFillRemaining(
                        hasScrollBody: false,
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

class _PopupCard extends StatelessWidget {
  const _PopupCard({required this.serata, required this.club});

  final SerataModel serata;
  final LocaleModel club;

  // ── Costanti Figma (px design) ─────────────────────────────────────────────
  // Riferite alla card 354×663. Le posizioni X dei contenuti sono sottratte
  // di 19 (offset card) per ottenere offset interni alla card.
  // Altezza del banner radiale superiore (Rectangle 211). Deve fermarsi
  // SUBITO DOPO l'indirizzo, PRIMA della pillola data (confronto con
  // l'ufficiale: il bagliore lì è una linea dritta che finisce sopra la
  // pillola, non curva/estesa fin dentro "STILE MUSICALE").
  static const double _bannerH = 112;
  // Padding di contenuto: la maggior parte usa ~16, la pill data e i box
  // usano ~12 (più stretti dal bordo card).
  static const double _padContent = 16; // x=35 → 16 da card-left
  static const double _padPill = 12;    // x=31 → 12 da card-left

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(R.sp(32));
    // Card linear gradient (Rectangle 210): #2600FF → #1500B2 @53.85% → #000.
    // Min-height ridotto (era 611, troppo rispetto ai gap ora più stretti):
    // con line-up+parcheggio popolati il contenuto reale supera già questo
    // minimo, quindi 611 lasciava un vuoto vistoso sotto "Acquista il tuo
    // ticket". Resta comunque un floor per eventi con poche info.
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
                  height: R.sp(_bannerH),
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
            _buildContent(context),
          ],
        ),
      ),
    );
  }

  /// Contenuto della card con spaziature Figma esatte (in design px → R.sp).
  Widget _buildContent(BuildContext context) {
    final hasGeneri = serata.generiMusicali.isNotEmpty;
    final hasLineup = serata.lineup.isNotEmpty;

    return Padding(
      // Padding "neutro" che ospita la pill data e i box (i contenuti che vanno
      // PIÙ a sinistra usano _padPill=12). Il testo a 16 lo otteniamo con un
      // ulteriore inset orizzontale di 4 sui sotto-blocchi.
      padding: EdgeInsets.fromLTRB(
        R.sp(_padPill),
        R.sp(6),  // top banner → primo elemento (QUESTA SERA): 6px
        R.sp(_padPill),
        R.sp(8),  // bottom card
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // QUESTA SERA badge + close (X) — gap interno standard pill
          _topBadgeAndClose(context),
          // Gap compattato (era 20px Figma): con line-up+parcheggio popolati
          // il contenuto è già alto, deve stare tutto senza scroll forzato.
          SizedBox(height: R.sp(14)),
          // Padding interno extra di +4px (16-12) per allineare titolo/indirizzo
          Padding(
            padding: EdgeInsets.symmetric(horizontal: R.sp(_padContent - _padPill)),
            child: _titleAndAddress(),
          ),
          SizedBox(height: R.sp(12)),
          _datePill(),
          SizedBox(height: R.sp(10)),
          if (hasGeneri) ...[
            Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: R.sp(_padContent - _padPill)),
              child: _section('STILE MUSICALE'),
            ),
            SizedBox(height: R.sp(4)),
            _chipsRow(serata.generiMusicali),
            SizedBox(height: R.sp(8)),
          ],
          // Box info allineati al titolo/indirizzo (16px dal bordo card):
          // +4px rispetto al padding base _padPill, come nel CSS (x≈36).
          Padding(
            padding: EdgeInsets.symmetric(
                horizontal: R.sp(_padContent - _padPill)),
            child: _infoBoxesGrid(),
          ),
          if (hasLineup) ...[
            SizedBox(height: R.sp(8)),
            Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: R.sp(_padContent - _padPill)),
              child: _section('LINE-UP'),
            ),
            SizedBox(height: R.sp(7)),
            for (final dj in serata.lineup) ...[
              // Righe DJ allineate al titolo (16px), come i box info.
              Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: R.sp(_padContent - _padPill)),
                child: _djRow(dj),
              ),
              SizedBox(height: R.sp(7)),
            ],
          ],
          // Gap finale prima del CTA (con lineup: 7px già dato dal loop + 20
          // qui = ~27px): aumentato, era ancora troppo stretto.
          SizedBox(height: R.sp(hasLineup ? 20 : 16)),
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

  Widget _titleAndAddress() {
    // Titolo con gradient text bianco→azzurrino + ombra blu (Figma):
    // background: radial-gradient(50% 50% at 50% 50%, #FFFFFF 0%, #E0E1FF 100%)
    // text-shadow: 0px 4px 4px rgba(38, 0, 255, 0.63)
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // FittedBox forza il titolo su UNA riga sola, rimpicciolendolo se
        // serve invece di andare a capo. maxLines:2 andava a capo su
        // viewport leggermente più stretti dell'ufficiale (es. "SPRING
        // PARTY" su due righe), sballando tutto il layout sotto.
        FittedBox(
          fit: BoxFit.scaleDown,
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
              style: OnlistTextStyles.hn(
                fontSize: R.sp(45),
                fontWeight: FontWeight.w700,
                color: Colors.white,
                height: 45 / 45,
                letterSpacing: -0.08 * 45,
              ).copyWith(
                shadows: [
                  Shadow(
                    color: const Color(0xA12600FF),
                    offset: Offset(0, R.sp(4)),
                    blurRadius: R.sp(4),
                  ),
                ],
              ),
              maxLines: 1,
            ),
          ),
        ),
        // Titolo h=45, baseline a y=45+rel49=94, indirizzo a 96 → 2px gap
        SizedBox(height: R.sp(2)),
        Text(
          club.indirizzoCompleto,
          style: OnlistTextStyles.hn(
            fontSize: R.sp(16),
            fontWeight: FontWeight.w400,
            color: Colors.white.withValues(alpha: 0.77),
            height: 16 / 16,
            letterSpacing: -0.08 * 16,
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
      // Padding verticale leggermente ridotto (7→5) per stare in una
      // schermata senza scroll forzato quando la line-up è popolata.
      padding: EdgeInsets.symmetric(
          horizontal: R.sp(11), vertical: R.sp(5)),
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
          // CSS Rectangle 229: gradient blu 51% (#1F00FF→#1900D8), r15.
          gradient: const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [Color(0x821F00FF), Color(0x821900D8)],
          ),
          borderRadius: BorderRadius.circular(R.sp(15)),
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
