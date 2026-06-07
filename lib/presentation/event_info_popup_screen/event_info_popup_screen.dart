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
        gradient: OnlistColors.cardSummary,
        borderRadius: BorderRadius.circular(14),
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
          padding: EdgeInsets.symmetric(horizontal: R.sp(12), vertical: R.sp(5)),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: OnlistTextStyles.hn(
              fontSize: R.sp(11),
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: 1.2,
            ),
          ),
        ),
        const Spacer(),
        GestureDetector(
          onTap: () => NavigatorService.goBack(),
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: R.sp(28),
            height: R.sp(28),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(Icons.close, color: Colors.white, size: R.sp(18)),
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
            fontSize: R.sp(36),
            fontWeight: FontWeight.w700,
            color: Colors.white,
            height: 38 / 36,
            letterSpacing: -0.04 * 36,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        SizedBox(height: R.sp(4)),
        Text(
          club.indirizzoCompleto,
          style: OnlistTextStyles.hn(
            fontSize: R.sp(13),
            fontWeight: FontWeight.w400,
            color: Colors.white.withValues(alpha: 0.7),
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
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: OnlistTextStyles.hn(
          fontSize: R.sp(15),
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _section(String label) {
    return Text(
      label,
      style: OnlistTextStyles.hn(
        fontSize: R.sp(12),
        fontWeight: FontWeight.w700,
        color: Colors.white.withValues(alpha: 0.55),
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _chipsRow(List<String> generi) {
    return Wrap(
      spacing: R.sp(10),
      runSpacing: R.sp(10),
      children: [
        for (final g in generi)
          Container(
            padding: EdgeInsets.symmetric(horizontal: R.sp(14), vertical: R.sp(7)),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(1000),
              border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
            ),
            child: Text(
              g,
              style: OnlistTextStyles.hn(
                fontSize: R.sp(13),
                fontWeight: FontWeight.w500,
                color: Colors.white,
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
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            box.title,
            style: OnlistTextStyles.hn(
              fontSize: R.sp(10),
              fontWeight: FontWeight.w700,
              color: Colors.white.withValues(alpha: 0.55),
              letterSpacing: 1.2,
            ),
          ),
          SizedBox(height: R.sp(4)),
          Text(
            box.value,
            style: OnlistTextStyles.hn(
              fontSize: R.sp(14),
              fontWeight: FontWeight.w500,
              color: Colors.white,
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
      margin: EdgeInsets.only(bottom: R.sp(8)),
      padding: EdgeInsets.symmetric(horizontal: R.sp(12), vertical: R.sp(10)),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Container(
            width: R.sp(34),
            height: R.sp(34),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              init,
              style: OnlistTextStyles.hn(
                fontSize: R.sp(12),
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          SizedBox(width: R.sp(10)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dj.nome,
                  style: OnlistTextStyles.hn(
                    fontSize: R.sp(14),
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                if (subtitle.isNotEmpty) ...[
                  SizedBox(height: R.sp(2)),
                  Text(
                    subtitle,
                    style: OnlistTextStyles.hn(
                      fontSize: R.sp(11),
                      fontWeight: FontWeight.w400,
                      color: Colors.white.withValues(alpha: 0.65),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (dj.headliner)
            Container(
              padding: EdgeInsets.symmetric(horizontal: R.sp(10), vertical: R.sp(4)),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'HEADLINER',
                style: OnlistTextStyles.hn(
                  fontSize: R.sp(10),
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 1.0,
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
        padding: EdgeInsets.symmetric(vertical: R.sp(14)),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(40),
          border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 1.5),
        ),
        alignment: Alignment.center,
        child: Text(
          'Acquista il tuo ticket',
          style: OnlistTextStyles.hn(
            fontSize: R.sp(18),
            fontWeight: FontWeight.w600,
            color: Colors.white,
            letterSpacing: -0.05 * 18,
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
