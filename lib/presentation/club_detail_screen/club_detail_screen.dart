import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_export.dart';
import '../../core/models/locale_model.dart';
import '../../core/models/serata_model.dart';
import '../../core/services/analytics_service.dart';
import '../../core/utils/analytics_mixin.dart';
import '../../theme/onlist_text_styles.dart';
import '../../widgets/back_row.dart';
import '../../widgets/custom_top_bar.dart';
import '../../widgets/animated_press.dart';
import '../../widgets/favorite_banner.dart';
import '../../widgets/shared_footer.dart';
import '../../widgets/image_fallback.dart';
import 'bloc/club_detail_bloc.dart';

class ClubDetailScreen extends StatefulWidget {
  const ClubDetailScreen({Key? key}) : super(key: key);

  static Widget builder(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    LocaleModel? locale;

    if (args is LocaleModel) {
      locale = args;
    } else if (args is Map<String, dynamic>) {
      final id = args['id'] as String?;
      // Dai preferiti arriva solo {'id': ...} (senza 'nome'): costruiamo un
      // placeholder, il bloc carica poi i dati completi via getLocaleById.
      if (id != null && args['nome'] == null) {
        locale = LocaleModel(id: id, nome: '');
      } else {
        locale = LocaleModel.fromMap(args);
      }
    }

    if (locale == null) {
      WidgetsBinding.instance.addPostFrameCallback(
          (_) => Navigator.of(context, rootNavigator: true).maybePop());
      return const Scaffold(backgroundColor: Color(0xFF0D0D0D));
    }
    return BlocProvider<ClubDetailBloc>(
      create: (_) => ClubDetailBloc(ClubDetailState(locale: locale!))
        ..add(ClubDetailInitialEvent()),
      child: const ClubDetailScreen(),
    );
  }

  @override
  State<ClubDetailScreen> createState() => _ClubDetailScreenState();
}

class _ClubDetailScreenState extends State<ClubDetailScreen>
    with TickerProviderStateMixin, ScreenAnalytics {
  @override
  String get screenName => 'club_detail';

  // ── Staggered entrance animations ──────────────────────────────────────────
  late AnimationController _staggerCtrl;
  late Animation<double> _appBarFade;
  late Animation<Offset> _appBarSlide;
  late Animation<double> _heroFade;
  late Animation<double> _heroScale;
  late Animation<double> _titleFade;
  late Animation<Offset> _titleSlide;
  late Animation<double> _subtitleFade;
  late Animation<Offset> _subtitleSlide;
  late Animation<double> _infoFade;
  late Animation<Offset> _infoSlide;
  late Animation<double> _sectionsFade;
  late Animation<Offset> _sectionsSlide;

  // ── Bookmark icon bounce ────────────────────────────────────────────────────
  late AnimationController _bookmarkCtrl;
  late Animation<double> _bookmarkScale;

  @override
  void initState() {
    super.initState();

    // Analytics: log club visualizzato
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final locale = ModalRoute.of(context)?.settings.arguments as LocaleModel?;
      if (locale != null) {
        AnalyticsService.logClubViewed(
            clubId: locale.id, clubName: locale.nome);
        // Funnel: apertura dettaglio (type 'locale').
        AnalyticsService.logViewDetail(
          type: 'locale',
          id: locale.id,
          name: locale.nome,
        );
      }
    });

    _staggerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    // AppBar 0–400ms
    _appBarFade = _tween(0, 0.28);
    _appBarSlide = _slideTween(Offset(0, -0.5), 0, 0.28);

    // Hero 100–600ms
    _heroFade = _tween(0.07, 0.43);
    _heroScale = Tween<double>(begin: 0.95, end: 1).animate(
      CurvedAnimation(
          parent: _staggerCtrl,
          curve: const Interval(0.07, 0.43, curve: Curves.easeOut)),
    );

    // Title 250–700ms
    _titleFade = _tween(0.18, 0.50);
    _titleSlide = _slideTween(Offset(0, 0.3), 0.18, 0.50);

    // Subtitle 350–800ms
    _subtitleFade = _tween(0.25, 0.57);
    _subtitleSlide = _slideTween(Offset(0, 0.3), 0.25, 0.57);

    // Info rows 420–850ms
    _infoFade = _tween(0.30, 0.61);
    _infoSlide = _slideTween(Offset(0, 0.3), 0.30, 0.61);

    // Sections 600–1100ms
    _sectionsFade = _tween(0.43, 0.78);
    _sectionsSlide = _slideTween(Offset(0, 0.3), 0.43, 0.78);

    _staggerCtrl.forward();

    // Bookmark bounce
    _bookmarkCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _bookmarkScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.35), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.35, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _bookmarkCtrl, curve: Curves.easeOut));
  }

  Animation<double> _tween(double begin, double end) {
    return Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
          parent: _staggerCtrl,
          curve: Interval(begin, end, curve: Curves.easeOut)),
    );
  }

  Animation<Offset> _slideTween(Offset from, double begin, double end) {
    return Tween<Offset>(begin: from, end: Offset.zero).animate(
      CurvedAnimation(
          parent: _staggerCtrl,
          curve: Interval(begin, end, curve: Curves.easeOut)),
    );
  }

  @override
  void dispose() {
    _staggerCtrl.dispose();
    _bookmarkCtrl.dispose();
    super.dispose();
  }

  // ── Open Google Maps ────────────────────────────────────────────────────────
  Future<void> _openMaps(String address) async {
    final encoded = Uri.encodeComponent(address);
    final uri = Uri.parse('https://maps.google.com/?q=$encoded');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Design NUOVO: sfondo NERO FISSO (niente gradiente screenBackground).
      backgroundColor: Colors.black,
      // Footer flottante: il contenuto scorre dietro la capsula (non la oscura).
      extendBody: true,
      body: ColoredBox(
        color: Colors.black,
        child: BlocConsumer<ClubDetailBloc, ClubDetailState>(
          listenWhen: (prev, curr) => prev.isLoading && !curr.isLoading,
          listener: (context, state) {
            // Dati del dettaglio locale pronti → tempo di caricamento.
            if (!state.isLoading) reportLoadTime('load_time_dettaglio_locale');
          },
          buildWhen: (prev, curr) =>
              prev.locale != curr.locale ||
              prev.eventoOggi != curr.eventoOggi ||
              prev.serate != curr.serate ||
              prev.isLoading != curr.isLoading ||
              prev.isPreferito != curr.isPreferito ||
              // Il banner preferiti ora è dichiarativo: senza questa riga non
              // si vedrebbe comparire/sparire.
              prev.showFavoriteBadge != curr.showFavoriteBadge ||
              prev.selectedBottomNavIndex != curr.selectedBottomNavIndex,
          builder: (context, state) {
            return SafeArea(
              bottom: false,
              child: Column(
                children: [
                  // AppBar
                  SlideTransition(
                    position: _appBarSlide,
                    child: FadeTransition(
                      opacity: _appBarFade,
                      child: const CustomTopBar(),
                    ),
                  ),
                  // Torna indietro
                  SlideTransition(
                    position: _appBarSlide,
                    child: FadeTransition(
                      opacity: _appBarFade,
                      child: _buildBackRow(),
                    ),
                  ),
                  // Body
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.only(bottom: SharedFooter.height),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Hero image + badge overlay
                          FadeTransition(
                            opacity: _heroFade,
                            child: ScaleTransition(
                              scale: _heroScale,
                              child: _buildHeroWithBadge(context, state),
                            ),
                          ),
                          // Title row: nome club + bookmark a destra (Figma 10).
                          SlideTransition(
                            position: _titleSlide,
                            child: FadeTransition(
                              opacity: _titleFade,
                              child: _buildTitleRow(context, state),
                            ),
                          ),
                          // Indirizzo (tappable → apre Google Maps)
                          SlideTransition(
                            position: _subtitleSlide,
                            child: FadeTransition(
                              opacity: _subtitleFade,
                              child: _buildSubtitle(state.locale),
                            ),
                          ),
                          // Info rows: orario evento + generi musicali (no prezzo)
                          SlideTransition(
                            position: _infoSlide,
                            child: FadeTransition(
                              opacity: _infoFade,
                              child: _buildInfoRows(
                                  state.locale, state.eventoOggi),
                            ),
                          ),
                          // CSS NUOVO: la riga generi chiude a 510 (icona 490+20,
                          // non il testo a 509) → titolo sezione a 519.
                          SizedBox(height: R.sp(9)),
                          // Prossime serate (la PRENOTA serata naviga alla
                          // bookingScreen, pagina di scelta Tavolo/Prevendita)
                          if (state.serate.isNotEmpty || !state.isLoading)
                            SlideTransition(
                              position: _sectionsSlide,
                              child: FadeTransition(
                                opacity: _sectionsFade,
                                child: _buildSerateSection(
                                    context, state.serate, state.locale),
                              ),
                            ),
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
      // Footer: unica e globale, montata da RootShell (non qui).
    );
  }

  // ── Torna indietro ───────────────────────────────────────────────────────
  Widget _buildBackRow() => const BackRow();

  // ── Hero + badge ────────────────────────────────────────────────────────────
  Widget _buildHeroWithBadge(BuildContext context, ClubDetailState state) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Stack(
        // Serve allo stile `fromBookmark` del banner preferiti: parte fuori
        // dai bordi dell'hero e ci rientra volando. L'immagine ha comunque il
        // suo ClipRRect, quindi non straborda nulla di suo.
        clipBehavior: Clip.none,
        children: [
          // Hero image: morph condiviso dalla lista/home (tag = club id).
          Hero(
            tag: 'club-img-${state.locale.id}',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: double.infinity,
                height: 217,
                color: const Color(0xFF1A1A2E),
                child: state.locale.fotoUrl != null
                    ? CachedNetworkImage(
                        imageUrl: state.locale.fotoUrl!,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) =>
                            ImageFallback(seed: state.locale.id),
                      )
                    : ImageFallback(seed: state.locale.id),
              ),
            ),
          ),
          // Bookmark spostato nel title row (Figma 10).
          // "Club aggiunto ai preferiti": il banner si anima da solo in base a
          // `showFavoriteBadge` (vedi [FavoriteBanner], correzioni 1.1 punto 4).
          Positioned(
            top: 10,
            // Ancorato a sinistra (correzioni 1.11), staccato di 10 dal bordo
            // arrotondato dell'immagine.
            left: R.sp(10),
            right: 50,
            child: FavoriteBanner(visible: state.showFavoriteBadge),
          ),
        ],
      ),
    );
  }

  // ── Title row: nome club + bookmark a destra ────────────────────────────────
  // CSS NUOVO: nome a left 14, 11px sotto l'hero (382 vs hero bottom 371).
  Widget _buildTitleRow(BuildContext context, ClubDetailState state) {
    return Padding(
      padding: EdgeInsets.fromLTRB(R.sp(14), R.sp(11), R.sp(13), 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              state.locale.nome,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: OnlistTextStyles.hn(
                fontSize: R.sp(36),
                fontWeight: FontWeight.w700,
                color: Colors.white,
                height: 41 / 36, // CSS: line-height 41
                letterSpacing: -0.08 * 36,
              ),
            ),
          ),
          const SizedBox(width: 8),
          AnimatedPress(
            onPressed: () =>
                context.read<ClubDetailBloc>().add(ToggleFavoriteEvent()),
            child: AnimatedBuilder(
              animation: _bookmarkScale,
              builder: (_, child) => Transform.scale(
                scale: _bookmarkScale.value,
                child: child,
              ),
              // Segnalibro ufficiale: icona 32×40 dentro il riquadro 48×48 del
              // CSS. Pieno = club salvato, vuoto = non salvato (il Figma
              // disegna solo il vuoto, vedi [ImageConstant.imgBookmarkLargeFilled]).
              //
              // Il passaggio vuoto→pieno è una DISSOLVENZA (correzioni 1.11):
              // le due versioni stanno una sopra l'altra e cambia solo
              // l'opacità di quella piena — nessun cambio di layout, quindi
              // costa niente e non fa saltare l'icona.
              child: SizedBox(
                width: R.sp(48),
                height: R.sp(48),
                child: Center(
                  child: SizedBox(
                    width: R.sp(32),
                    height: R.sp(40),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        SvgPicture.asset(ImageConstant.imgBookmarkLarge,
                            fit: BoxFit.contain),
                        AnimatedOpacity(
                          opacity: state.isPreferito ? 1 : 0,
                          duration: const Duration(milliseconds: 260),
                          curve: Curves.easeOut,
                          child: SvgPicture.asset(
                              ImageConstant.imgBookmarkLargeFilled,
                              fit: BoxFit.contain),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Subtitle (indirizzo) — tap → Google Maps ────────────────────────────────
  Widget _buildSubtitle(LocaleModel locale) {
    return Padding(
      // CSS NUOVO: indirizzo a left 15, 5px sotto il nome (428 vs 423).
      padding: EdgeInsets.fromLTRB(R.sp(15), R.sp(5), R.sp(13), 0),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _openMaps(locale.indirizzoCompleto),
        child: Text(
          locale.indirizzoCompleto,
          style: OnlistTextStyles.hn(
            fontSize: R.sp(23),
            fontWeight: FontWeight.w500,
            // Il CSS dice `opacity: 0.8`, che su nero fa #CCCCCC: e' il design
            // stesso a renderla grigia. Bianco pieno per scelta di Luca, in
            // coerenza con la via della Home.
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  // ── Info rows: orario apertura locale + generi musicali (Figma off) ────────
  Widget _buildInfoRows(LocaleModel locale, SerataModel? evento) {
    // Orario di APERTURA DEL LOCALE (non dell'evento): è informazione stabile
    // del club, mostrata sotto l'indirizzo. Letto da locali.orario_apertura/_chiusura.
    final orario = locale.orarioString;
    // generi: preferenza all'evento, fallback al locale
    final generi = (evento?.generiMusicali.isNotEmpty == true)
        ? evento!.generiMusicali.join(' - ')
        : locale.generiString;

    // CSS NUOVO: clock a (15,459) → 8px sotto l'indirizzo (che chiude a 451);
    // icona music a 490, cioè 11px sotto il fondo della riga orologio (459+20).
    // Le righe sono alte quanto l'icona (20), non quanto il testo.
    //
    // ICONE: SVG ufficiali (`clock.svg` 19×19 e `music.svg` 17×17), renderizzati
    // dentro il box 20×20 delle vecchie Icon Material così le misure di riga e
    // l'offset del testo (41 = 15 + 20 + 6) restano identici al CSS.
    return Padding(
      padding: EdgeInsets.fromLTRB(R.sp(15), R.sp(8), R.sp(13), 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (orario.isNotEmpty)
            Row(
              children: [
                // R.sp anche su icona e gap: erano px fissi, quindi su schermi
                // diversi il testo si spostava rispetto ai 41 del CSS
                // (15 + 20 + 6 = 41).
                _infoIcon(ImageConstant.imgClock),
                SizedBox(width: R.sp(6)),
                Text(
                  orario,
                  style: OnlistTextStyles.hn(
                    fontSize: R.sp(18),
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          if (generi.isNotEmpty) ...[
            SizedBox(height: R.sp(11)),
            Row(
              children: [
                // La nota va 2px più a sinistra dell'orologio: nel CSS sta a
                // left 13 contro i 15 dell'orologio, e otticamente si allinea.
                // Transform e non padding, così il testo resta a 41 come da CSS.
                Transform.translate(
                  offset: Offset(-R.sp(2), 0),
                  child: _infoIcon(ImageConstant.imgMusic),
                ),
                SizedBox(width: R.sp(6)),
                Expanded(
                  child: Text(
                    generi,
                    style: OnlistTextStyles.hn(
                      fontSize: R.sp(16), // CSS generi: 16px (orario è 18)
                      fontWeight: FontWeight.w700,
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Icona SVG delle righe info (orario / generi): box 20×20 come le vecchie
  /// Icon Material, bianco al 60% come il testo affiancato.
  Widget _infoIcon(String asset) {
    return SizedBox(
      width: R.sp(20),
      height: R.sp(20),
      child: SvgPicture.asset(
        asset,
        fit: BoxFit.contain,
        colorFilter: ColorFilter.mode(
          Colors.white.withValues(alpha: 0.6),
          BlendMode.srcIn,
        ),
      ),
    );
  }

  // ── Prossime serate ─────────────────────────────────────────────────────────
  Widget _buildSerateSection(
      BuildContext context, List<SerataModel> serate, LocaleModel locale) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          // CSS NUOVO: titolo a left 15, 10px sopra la prima card (556→566).
          padding: EdgeInsets.fromLTRB(R.sp(15), 0, R.sp(13), R.sp(10)),
          child: Text(
            'Prossime serate',
            style: OnlistTextStyles.hn(
              fontSize: R.sp(32),
              fontWeight: FontWeight.w700,
              color: Colors.white,
              height: 37 / 32, // CSS: 32px line-height 37, LS -0.08
              letterSpacing: -0.08 * 32,
            ),
          ),
        ),
        if (serate.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13),
            child: Text(
              'Nessuna serata in programma',
              style: OnlistTextStyles.hn(
                  fontSize: R.sp(14), color: Colors.white38),
            ),
          )
        else
          // Oggi/domani → card grande con etichetta OGGI/DOMANI (evidenziata).
          // Le altre date → card compatta in stile "Club consigliati" (stessa
          // grandezza delle card club) col GENERE al posto del luogo.
          ...serate.map((s) => _isOggiODomani(s.data)
              ? _SerataCard(serata: s, locale: locale)
              : _SerataCompactCard(serata: s, locale: locale)),
      ],
    );
  }
}

/// Gradiente PRENOTA del design NUOVO (Home Disco singola, Rectangle 164):
/// `linear-gradient(90deg, #0040A1 0%, #0084FF 100%)`.
const LinearGradient _prenotaGradient = LinearGradient(
  begin: Alignment.centerLeft,
  end: Alignment.centerRight,
  colors: [Color(0xFF0040A1), Color(0xFF0084FF)],
);

/// Vero se la serata è oggi o domani (data di calendario, mezzanotte-normalizzata).
/// Stessa regola di `_SerataCard._dayLabel`: decide quale card usare.
bool _isOggiODomani(DateTime data) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final d = DateTime(data.year, data.month, data.day);
  final diff = d.difference(today).inDays;
  return diff == 0 || diff == 1;
}

// ── Serata card (Figma 10-aggiornato) ──────────────────────────────────────────
// Card con gradiente blu cardSummary: locandina a sinistra, titolo + "OGGI"
// (se evento di oggi) + data + orario + generi a destra, bottone PRENOTA.
class _SerataCard extends StatelessWidget {
  final SerataModel serata;
  final LocaleModel locale;

  const _SerataCard({required this.serata, required this.locale});

  static const _giorniLunghi = [
    'Lunedì',
    'Martedì',
    'Mercoledì',
    'Giovedì',
    'Venerdì',
    'Sabato',
    'Domenica'
  ];
  static const _mesiLunghi = [
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

  String _formatData(DateTime d) =>
      '${_giorniLunghi[d.weekday - 1]} ${d.day} ${_mesiLunghi[d.month - 1]}';

  /// Etichetta giorno: solo per le serate imminenti. Per tutte le altre resta
  /// vuota e la card mostra la sola data completa, già presente sotto.
  ///
  /// Nel Figma (vetrina-club.css) la slot a (106,39) contiene soltanto "OGGI":
  /// il countdown "-N giorni" che stava qui non è mai esistito nel design.
  ///
  /// Il confronto è tra giorni normalizzati a mezzanotte, non tra istanti: una
  /// serata che inizia alle 23:00 di stasera è "OGGI", non "fra 0 giorni".
  String get _dayLabel {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final serataDate =
        DateTime(serata.data.year, serata.data.month, serata.data.day);
    final diff = serataDate.difference(today).inDays;
    if (diff == 0) return 'OGGI';
    if (diff == 1) return 'DOMANI';
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final isSoldOut = serata.statusPosti == 'Sold Out';
    // Card grande OGGI/DOMANI: mostra ENTRAMBI i generi (es. "House - Deep House").
    // La card compatta [_SerataCompactCard] mostra invece solo il primo.
    final generi = serata.generiMusicali.isNotEmpty
        ? serata.generiMusicali.join(' - ')
        : locale.generiString;

    // Card "Prossime serate" — layout Figma 10 (Frame 351, design 369×132):
    // locandina 95×119 a sx, titolo/OGGI/data/orario/generi a dx, PRENOTA 86×38.
    // Disegnata a dimensione fissa e scalata a larghezza, come le card della home.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      // Tap sulla card serata → schermata 19 (pop-up info serata).
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => NavigatorService.pushNamed(
          AppRoutes.eventInfoPopupScreen,
          arguments: {'serata': serata, 'club': locale},
        ),
        child: _scaleToWidth(
          designW: 369,
          designH: 132,
          child: Container(
            width: 369,
            height: 132,
            decoration: BoxDecoration(
              // CSS NUOVO Frame 351: 90deg #0077FF 28.37% → #0002AE 79.33%.
              gradient: const LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [Color(0xFF0077FF), Color(0xFF0002AE)],
                stops: [0.2837, 0.7933],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Stack(
              children: [
                // Pill dietro data+orario (CSS Rectangle 273: 162×34 r4 a
                // (103,69), blu 20% × opacity .3 ≈ 6%).
                Positioned(
                  left: 103,
                  top: 69,
                  child: Container(
                    width: 162,
                    height: 34,
                    decoration: BoxDecoration(
                      color: const Color(0x0F002AFF),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                // Locandina 95×119 @ (6,6)
                Positioned(
                  left: 6,
                  top: 6,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      width: 95,
                      height: 119,
                      child: serata.locandinaUrl != null
                          ? CachedNetworkImage(
                              imageUrl: serata.locandinaUrl!,
                              fit: BoxFit.cover,
                              memCacheWidth: 285,
                              errorWidget: (_, __, ___) =>
                                  ImageFallback(seed: serata.id),
                            )
                          : ImageFallback(seed: serata.id),
                    ),
                  ),
                ),
                // Titolo serata @ (106,2)
                Positioned(
                  left: 106,
                  top: 2,
                  right: 8,
                  child: Text(
                    serata.nome,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: OnlistTextStyles.hn(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 37 / 32,
                      letterSpacing: -0.08 * 32,
                    ),
                  ),
                ),
                // Label giorno @ (106,39): "OGGI"/"DOMANI", assente sulle altre.
                if (_dayLabel.isNotEmpty)
                  Positioned(
                    left: 106,
                    top: 39,
                    child: Text(
                      _dayLabel,
                      style: OnlistTextStyles.hn(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        height: 28 / 24,
                        letterSpacing: -0.08 * 24,
                      ),
                    ),
                  ),
                // Data @ (105,70)
                Positioned(
                  left: 105,
                  top: 70,
                  child: Text(
                    _formatData(serata.data),
                    style: OnlistTextStyles.hn(
                      fontSize: 18,
                      fontWeight: FontWeight.w400,
                      color: Colors.white,
                      height: 18 / 18,
                    ),
                  ),
                ),
                // Orario @ (106,90)
                if (serata.orarioString.isNotEmpty)
                  Positioned(
                    left: 106,
                    top: 90,
                    child: Text(
                      serata.orarioString,
                      style: OnlistTextStyles.hn(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: Colors.white,
                        height: 13 / 13,
                      ),
                    ),
                  ),
                // Generi @ (106,109)
                Positioned(
                  left: 106,
                  top: 109,
                  right: 100,
                  child: Text(
                    generi,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: OnlistTextStyles.hn(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 13 / 13,
                    ),
                  ),
                ),
                // PRENOTA @ (273,87) — 86×38 (CSS NUOVO)
                Positioned(
                  left: 273,
                  top: 87,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: isSoldOut
                        ? null
                        : () => NavigatorService.pushNamed(
                              AppRoutes.bookingScreen,
                              arguments: {'serata': serata, 'club': locale},
                            ),
                    child: Container(
                      width: 86,
                      height: 38,
                      decoration: BoxDecoration(
                        // CSS NUOVO: 90deg #0040A1 → #0084FF.
                        gradient: isSoldOut ? null : _prenotaGradient,
                        color: isSoldOut
                            ? Colors.white.withValues(alpha: 0.18)
                            : null,
                        borderRadius: BorderRadius.circular(6.48),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.25),
                            offset: const Offset(0, 4),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        isSoldOut ? 'ESAURITO' : 'PRENOTA',
                        style: OnlistTextStyles.hn(
                          fontSize: 15.55,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          height: 18 / 15.55,
                          letterSpacing: -0.1 * 15.55,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Serata card compatta (serate NON oggi/domani) ─────────────────────────────
// Stesso stile identico delle card "Club consigliati" della home (369×108,
// immagine orizzontale a sinistra, testo a destra, bottone PRENOTA). Rispetto a
// quella, al posto della CITTÀ mostra il GENERE musicale (siamo già dentro il
// club, il luogo è ridondante). Le serate di oggi/domani usano invece la card
// grande [_SerataCard] con l'etichetta OGGI/DOMANI evidenziata.
class _SerataCompactCard extends StatelessWidget {
  final SerataModel serata;
  final LocaleModel locale;

  const _SerataCompactCard({required this.serata, required this.locale});

  static const _giorniBrevi = ['Lun', 'Mar', 'Mer', 'Gio', 'Ven', 'Sab', 'Dom'];
  static const _mesiBrevi = [
    'Gen',
    'Feb',
    'Mar',
    'Apr',
    'Mag',
    'Giu',
    'Lug',
    'Ago',
    'Set',
    'Ott',
    'Nov',
    'Dic'
  ];

  String _dataBreve(DateTime d) =>
      '${_giorniBrevi[d.weekday - 1]} ${d.day} ${_mesiBrevi[d.month - 1]}';

  @override
  Widget build(BuildContext context) {
    final isSoldOut = serata.statusPosti == 'Sold Out';
    // Card compatta: mostra SOLO il primo genere (niente "House - Deep House"
    // troncato). La card grande OGGI/DOMANI mostra invece entrambi i generi.
    final generiList = serata.generiMusicali.isNotEmpty
        ? serata.generiMusicali
        : locale.generiMusicali;
    final generi = generiList.isNotEmpty ? generiList.first : '';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        // Tap sulla card → pop-up info serata (come la card grande).
        onTap: () => NavigatorService.pushNamed(
          AppRoutes.eventInfoPopupScreen,
          arguments: {'serata': serata, 'club': locale},
        ),
        child: _scaleToWidth(
          designW: 369,
          designH: 108,
          child: Container(
            width: 369,
            height: 108,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              // Palette NUOVO allineata alla card OGGI (stesso gradiente).
              gradient: const LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [Color(0xFF0077FF), Color(0xFF0002AE)],
                stops: [0.2837, 0.7933],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Stack(
              children: [
                // Immagine 165×96 @ (6,6) — orizzontale, come le card club.
                Positioned(
                  left: 6,
                  top: 6,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      width: 165,
                      height: 96,
                      child: serata.locandinaUrl != null
                          ? CachedNetworkImage(
                              imageUrl: serata.locandinaUrl!,
                              fit: BoxFit.cover,
                              memCacheWidth: 495,
                              errorWidget: (_, __, ___) =>
                                  ImageFallback(seed: serata.id),
                            )
                          : ImageFallback(seed: serata.id),
                    ),
                  ),
                ),
                // Nome serata @ (176,7). Era a 189: la foto chiude a 171, quindi
                // restava un buco di 18px mentre nel Figma (e nelle card della
                // Home, stesso layout 369×108) il testo parte 5px dopo la foto.
                // Le larghezze crescono di 13 per tenere fermo il bordo destro.
                Positioned(
                  left: 176,
                  top: 7,
                  child: SizedBox(
                    width: 172,
                    child: Text(
                      serata.nome,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: OnlistTextStyles.hn(
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        height: 37 / 32,
                        letterSpacing: -0.08 * 32,
                      ),
                    ),
                  ),
                ),
                // Data @ (189,46)
                Positioned(
                  left: 176,
                  top: 46,
                  child: Text(
                    _dataBreve(serata.data),
                    style: OnlistTextStyles.hn(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                      height: 12 / 12,
                    ),
                  ),
                ),
                // Ora @ (189,64) — stesso formato della card grande.
                if (serata.orarioString.isNotEmpty)
                  Positioned(
                    left: 176,
                    top: 64,
                    child: SizedBox(
                      width: 80,
                      child: Text(
                        serata.orarioString,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: OnlistTextStyles.hn(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: Colors.white,
                          height: 12 / 12,
                        ),
                      ),
                    ),
                  ),
                // Genere @ (176,88) — AL POSTO della città (come card club).
                // 97 di larghezza: chiude a 273, appena prima del PRENOTA (274).
                Positioned(
                  left: 176,
                  top: 88,
                  child: Opacity(
                    opacity: 0.8,
                    child: SizedBox(
                      width: 97,
                      child: Text(
                        generi,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: OnlistTextStyles.hn(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          height: 12 / 12,
                        ),
                      ),
                    ),
                  ),
                ),
                // PRENOTA @ (274,62) — 86×38, stesso stile card grande/club.
                Positioned(
                  left: 274,
                  top: 62,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: isSoldOut
                        ? null
                        : () => NavigatorService.pushNamed(
                              AppRoutes.bookingScreen,
                              arguments: {'serata': serata, 'club': locale},
                            ),
                    child: Container(
                      width: 86,
                      height: 38,
                      decoration: BoxDecoration(
                        gradient: isSoldOut ? null : _prenotaGradient,
                        color: isSoldOut
                            ? Colors.white.withValues(alpha: 0.18)
                            : null,
                        borderRadius: BorderRadius.circular(6.48),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.25),
                            offset: const Offset(0, 4),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        isSoldOut ? 'ESAURITO' : 'PRENOTA',
                        style: OnlistTextStyles.hn(
                          fontSize: 15.55,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          height: 18 / 15.55,
                          letterSpacing: -0.1 * 15.55,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Scala-a-larghezza ────────────────────────────────────────────────────────
// Scala un contenuto progettato a dimensione fissa (designW×designH) per
// riempire la larghezza disponibile mantenendo le proporzioni esatte del Figma.
Widget _scaleToWidth({
  required double designW,
  required double designH,
  required Widget child,
}) {
  return LayoutBuilder(
    builder: (context, constraints) {
      final ratio = constraints.maxWidth / designW;
      final scale = ratio < 1.15 ? ratio : 1.15;
      return Center(
        child: SizedBox(
          width: designW * scale,
          height: designH * scale,
          child: FittedBox(
            fit: BoxFit.fill,
            child: SizedBox(width: designW, height: designH, child: child),
          ),
        ),
      );
    },
  );
}
