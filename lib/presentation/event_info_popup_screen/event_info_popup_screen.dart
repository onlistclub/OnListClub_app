import 'package:flutter/material.dart';

import '../../core/app_export.dart';
import '../../core/models/locale_model.dart';
import '../../core/models/serata_model.dart';
import '../../theme/onlist_colors.dart';
import '../../theme/onlist_text_styles.dart';
import '../../widgets/custom_top_bar.dart';
import '../../widgets/shared_footer.dart';

/// Pop-up info serata (Figma `off/19 - pop up info club.png`).
///
/// Si raggiunge cliccando sulla **card serata** in schermata 10 (club detail).
/// Mostra tutte le info dell'evento: stile musicale, dress code, età minima,
/// sound system, parcheggio, line-up DJ. Il CTA "Acquista il tuo ticket"
/// naviga alla `bookingScreen` (pagina di scelta Tavolo / Prevendita).
///
/// Riceve come `arguments` una Map: `{'serata': SerataModel, 'club': LocaleModel}`.
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

    return Scaffold(
      backgroundColor: OnlistColors.black,
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: OnlistColors.screenBackground),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              const CustomTopBar(),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(12, R.sp(8), 12, R.sp(24)),
                  child: _PopupCard(serata: serata, club: club),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const SharedFooter(currentIndex: 0),
    );
  }
}

class _PopupCard extends StatelessWidget {
  const _PopupCard({required this.serata, required this.club});

  final SerataModel serata;
  final LocaleModel club;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(R.sp(18), R.sp(18), R.sp(18), R.sp(22)),
      decoration: BoxDecoration(
        // Figma off/19 (Rectangle 210): gradiente blu vivo #2600FF→#1500B2→#000.
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF2600FF), Color(0xFF1500B2), Color(0xFF000000)],
          stops: [0.0, 0.5385, 1.0],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _topBadgeAndClose(context),
          SizedBox(height: R.sp(14)),
          _titleAndAddress(),
          SizedBox(height: R.sp(14)),
          _datePill(),
          if (serata.generiMusicali.isNotEmpty) ...[
            SizedBox(height: R.sp(20)),
            _section('STILE MUSICALE'),
            SizedBox(height: R.sp(10)),
            _chipsRow(serata.generiMusicali),
          ],
          SizedBox(height: R.sp(20)),
          _infoBoxesGrid(),
          if (serata.lineup.isNotEmpty) ...[
            SizedBox(height: R.sp(22)),
            _section('LINE-UP'),
            SizedBox(height: R.sp(10)),
            ...serata.lineup.map(_djRow),
          ],
          SizedBox(height: R.sp(24)),
          _acquistaCta(context),
        ],
      ),
    );
  }

  Widget _topBadgeAndClose(BuildContext context) {
    final label = _serataDayLabel();
    return Row(
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: R.sp(10), vertical: R.sp(4)),
          decoration: BoxDecoration(
            // CSS Rectangle 212: gradiente teal→blu 53%, r10.
            gradient: const LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [Color(0x8700A29A), Color(0x871E00FF)],
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            style: OnlistTextStyles.hn(
              fontSize: R.sp(13),
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: -0.08 * 13,
            ),
          ),
        ),
        const Spacer(),
        GestureDetector(
          onTap: () => NavigatorService.goBack(),
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: R.sp(24),
            height: R.sp(24),
            decoration: BoxDecoration(
              // CSS Ellipse 12: cerchio outline bordo 1px bianco 72%.
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.72)),
            ),
            alignment: Alignment.center,
            child: Icon(Icons.close, color: Colors.white, size: R.sp(14)),
          ),
        ),
      ],
    );
  }

  Widget _titleAndAddress() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          serata.nome.toUpperCase(),
          style: OnlistTextStyles.hn(
            fontSize: R.sp(45), // CSS "SPRING PARTY": 45/w700/-0.08
            fontWeight: FontWeight.w700,
            color: Colors.white,
            height: 45 / 45,
            letterSpacing: -0.08 * 45,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        SizedBox(height: R.sp(6)),
        Text(
          club.indirizzoCompleto,
          style: OnlistTextStyles.hn(
            fontSize: R.sp(16), // CSS indirizzo: 16/-0.08 white 77%
            fontWeight: FontWeight.w400,
            color: Colors.white.withValues(alpha: 0.77),
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
      padding: EdgeInsets.symmetric(horizontal: R.sp(14), vertical: R.sp(10)),
      decoration: BoxDecoration(
        // CSS Rectangle 213: nero 27%, r11.
        color: Colors.black.withValues(alpha: 0.27),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: OnlistTextStyles.hn(
          fontSize: R.sp(20), // CSS data: 20/w500/-0.08
          fontWeight: FontWeight.w500,
          color: Colors.white,
          letterSpacing: -0.08 * 20,
        ),
      ),
    );
  }

  Widget _section(String label) {
    return Text(
      label,
      // CSS "STILE MUSICALE"/"LINE-UP": 16/w500 bianco pieno, -0.05.
      style: OnlistTextStyles.hn(
        fontSize: R.sp(16),
        fontWeight: FontWeight.w500,
        color: Colors.white,
        letterSpacing: -0.05 * 16,
      ),
    );
  }

  Widget _chipsRow(List<String> generi) {
    // CSS off/19: primo genere "attivo" (blu 0.2), gli altri attenuati
    // (nero 0.2 @ 50%); rettangoli arrotondati r11, testo 16/w400/-0.08.
    return Wrap(
      spacing: R.sp(10),
      runSpacing: R.sp(10),
      children: [
        for (var i = 0; i < generi.length; i++)
          Opacity(
            opacity: i == 0 ? 1.0 : 0.5,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: R.sp(12), vertical: R.sp(4)),
              decoration: BoxDecoration(
                color: i == 0
                    ? const Color(0x330004FF) // rgba(0,4,255,0.2)
                    : const Color(0x33000000), // rgba(0,0,0,0.2)
                borderRadius: BorderRadius.circular(11),
              ),
              child: Text(
                generi[i],
                style: OnlistTextStyles.hn(
                  fontSize: R.sp(16),
                  fontWeight: FontWeight.w400,
                  color: Colors.white,
                  letterSpacing: -0.08 * 16,
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// Quattro box DRESS CODE / ETÀ MINIMA / SOUND SISTEM / PARCHEGGIO.
  /// I box senza valore vengono saltati (no placeholder).
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
    // Render a 2 colonne in righe da 2.
    final rows = <Widget>[];
    for (var i = 0; i < items.length; i += 2) {
      final left = items[i];
      final right = i + 1 < items.length ? items[i + 1] : null;
      rows.add(Padding(
        padding: EdgeInsets.only(bottom: R.sp(10)),
        // IntrinsicHeight: dà alla Row un'altezza finita dentro lo
        // SingleChildScrollView (vincolo verticale illimitato), così
        // CrossAxisAlignment.stretch può pareggiare i due box affiancati
        // senza generare "BoxConstraints forces an infinite height".
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _renderInfoBox(left)),
              SizedBox(width: R.sp(10)),
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
    return Container(
      padding: EdgeInsets.symmetric(horizontal: R.sp(12), vertical: R.sp(12)),
      decoration: BoxDecoration(
        color: const Color(0x291E00FF), // CSS rgba(30,0,255,0.16)
        borderRadius: BorderRadius.circular(11),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Etichetta su pill gradiente (CSS Rectangle 220: grigio44→blu44, r7).
          Container(
            padding: EdgeInsets.symmetric(horizontal: R.sp(6), vertical: R.sp(2)),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [Color(0x70D9D9D9), Color(0x701E00FF)],
              ),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Text(
              box.title,
              style: OnlistTextStyles.hn(
                fontSize: R.sp(10),
                fontWeight: FontWeight.w500,
                color: Colors.white,
                letterSpacing: -0.05 * 10,
              ),
            ),
          ),
          SizedBox(height: R.sp(8)),
          Text(
            box.value,
            style: OnlistTextStyles.hn(
              fontSize: R.sp(20), // CSS valore: 20/w500/-0.05
              fontWeight: FontWeight.w500,
              color: Colors.white,
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
      margin: EdgeInsets.only(bottom: R.sp(10)),
      padding: EdgeInsets.symmetric(horizontal: R.sp(11), vertical: R.sp(8)),
      decoration: BoxDecoration(
        color: const Color(0x291E00FF), // CSS rgba(30,0,255,0.16)
        borderRadius: BorderRadius.circular(19),
      ),
      child: Row(
        children: [
          Container(
            width: R.sp(35),
            height: R.sp(35),
            decoration: const BoxDecoration(
              // CSS Ellipse 13: gradiente bianco46→blu46.
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
                letterSpacing: -0.05 * 16,
              ),
            ),
          ),
          SizedBox(width: R.sp(12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dj.nome,
                  style: OnlistTextStyles.hn(
                    fontSize: R.sp(16),
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
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
                      letterSpacing: -0.05 * 13,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (dj.headliner)
            Container(
              padding: EdgeInsets.symmetric(horizontal: R.sp(10), vertical: R.sp(5)),
              decoration: BoxDecoration(
                // CSS Rectangle 227: bianco35→teal35, r9.
                gradient: const LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [Color(0x59FFFFFF), Color(0x59007D99)],
                ),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Text(
                'HEADLINER',
                style: OnlistTextStyles.hn(
                  fontSize: R.sp(13),
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
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
        padding: EdgeInsets.symmetric(vertical: R.sp(8)),
        decoration: BoxDecoration(
          // CSS Rectangle 229: gradiente blu 51% (#1F00FF→#1900D8), r15.
          gradient: const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [Color(0x821F00FF), Color(0x821900D8)],
          ),
          borderRadius: BorderRadius.circular(15),
        ),
        alignment: Alignment.center,
        child: Text(
          'Acquista il tuo ticket',
          style: OnlistTextStyles.hn(
            fontSize: R.sp(32), // CSS: 32/w500/-0.05
            fontWeight: FontWeight.w500,
            color: Colors.white,
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
