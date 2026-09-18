import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_export.dart';
import '../../core/models/locale_model.dart';
import '../../core/models/serata_model.dart';
import '../../core/services/analytics_service.dart';
import '../../core/utils/analytics_mixin.dart';
import '../../core/utils/date_formatter.dart';
import '../../theme/onlist_colors.dart';
import '../../theme/onlist_text_styles.dart';
import '../../widgets/back_row.dart';
import '../../widgets/card_prenota_button.dart';
import '../../widgets/top_bar_slot.dart';
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
                      child: const TopBarSlot(),
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
                          // La riga generi chiude a 506 e il CSS metterebbe il titolo a 514, ma il
                          // doc correzioni 18/09 chiede più respiro fra i due: 18 invece di 8.
                          SizedBox(height: R.sp(18)),
                          // Prossime serate. Il PRENOTA della card apre il
                          // POP-UP della serata, non la scelta ticket: prima di
                          // scegliere il biglietto l'utente deve poter leggere
                          // dress code, età minima e line-up. Alla scelta
                          // ticket si arriva dal pop-up, con "Acquista il tuo
                          // ticket".
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
      // CSS NUOVO (16/09): indirizzo 22/500 a left 14, 7px sotto il nome
      // (430 vs 423).
      padding: EdgeInsets.fromLTRB(R.sp(14), R.sp(7), R.sp(13), 0),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _openMaps(locale.indirizzoCompleto),
        child: Text(
          locale.indirizzoCompleto,
          style: OnlistTextStyles.hn(
            fontSize: R.sp(22),
            height: 22 / 22,
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

    // CSS NUOVO (16/09): clock 20×20 a (15,459), 7px sotto l'indirizzo (che
    // chiude a 452); music a (13,486), 7px sotto il fondo della riga orologio.
    // Testi 13px bold al 60%: orario a x 41, generi a x 37.
    // Le righe sono alte quanto l'icona (20), non quanto il testo.
    final TextStyle stileInfo = OnlistTextStyles.hn(
      fontSize: R.sp(13),
      fontWeight: FontWeight.w700,
      color: Colors.white.withValues(alpha: 0.6),
      height: 15 / 13,
    );
    return Padding(
      padding: EdgeInsets.fromLTRB(R.sp(15), R.sp(7), R.sp(13), 0),
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
                Text(orario, style: stileInfo),
              ],
            ),
          if (generi.isNotEmpty) ...[
            SizedBox(height: R.sp(7)),
            // La nota sta 2px più a sinistra dell'orologio (13 contro 15) e il
            // suo testo parte a 37, non a 41.
            Transform.translate(
              offset: Offset(-R.sp(2), 0),
              child: Row(
                children: [
                  _infoIcon(ImageConstant.imgMusic),
                  SizedBox(width: R.sp(4)),
                  Expanded(
                    child: Text(
                      generi,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: stileInfo,
                    ),
                  ),
                ],
              ),
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
          // CSS NUOVO (16/09): titolo 36/41 a left 14, prima card 7px sotto
          // il riquadro del testo (555 → 562).
          padding: EdgeInsets.fromLTRB(R.sp(14), 0, R.sp(13), R.sp(7)),
          child: Text(
            'Prossime serate',
            style: OnlistTextStyles.hn(
              fontSize: R.sp(36),
              fontWeight: FontWeight.w700,
              color: Colors.white,
              height: 41 / 36,
              letterSpacing: -0.08 * R.sp(36),
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
          // Oggi/domani → card alta con etichetta OGGI/DOMANI. Le altre date
          // → card come quelle della Home.
          ...serate.map((s) => _SerataCard(serata: s, locale: locale)),
      ],
    );
  }
}

/// Etichetta della serata imminente: "OGGI", "DOMANI", altrimenti vuota.
///
/// Il confronto è tra giorni normalizzati a mezzanotte, non tra istanti: una
/// serata che inizia alle 23:00 di stasera è "OGGI".
String _etichettaGiorno(DateTime data) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final d = DateTime(data.year, data.month, data.day);
  final diff = d.difference(today).inDays;
  if (diff == 0) return 'OGGI';
  if (diff == 1) return 'DOMANI';
  return '';
}

/// Posizioni (px design) di una variante della card serata.
class _LayoutSerata {
  final double h;
  final double fotoX, fotoY, fotoW, fotoH;
  final double testoX;
  final double dataY, orarioY, genereY;
  final double fontRiga;
  final double prenotaX, prenotaY;

  const _LayoutSerata({
    required this.h,
    required this.fotoX,
    required this.fotoY,
    required this.fotoW,
    required this.fotoH,
    required this.testoX,
    required this.dataY,
    required this.orarioY,
    required this.genereY,
    required this.fontRiga,
    required this.prenotaX,
    required this.prenotaY,
  });
}

// ── Serata card (CSS "Home Disco singola" del 16/09) ─────────────────────────
// Card 367 di larghezza, r7, stesso gradiente delle card club della Home.
// Due varianti con valori diversi, come da CSS:
//  - OGGI/DOMANI (Rectangle 301 alto 126): etichetta 19/500, data e orario a
//    16px, foto 153×111;
//  - altre date (Rectangle 301 alto 102): identica alla card della Home, data
//    e orario a 19px, foto 153×88.
// Nell'ultima riga il CSS mette la città: qui c'è il genere, perché si è già
// dentro il club.
class _SerataCard extends StatelessWidget {
  final SerataModel serata;
  final LocaleModel locale;

  const _SerataCard({required this.serata, required this.locale});

  static const double _w = 367;

  // Rectangle 301 a (14,562): foto (21,570), testi a x 180, OGGI 607,
  // data 628, orario 645, città 669, PRENOTA (305,652).
  static const _LayoutSerata _imminente = _LayoutSerata(
    h: 126,
    fotoX: 7,
    fotoY: 8,
    fotoW: 153,
    fotoH: 111,
    testoX: 166,
    dataY: 66,
    orarioY: 83,
    genereY: 107,
    fontRiga: 16,
    prenotaX: 291,
    prenotaY: 90,
  );

  // Rectangle 301 a (14,698): foto (20,706), testi a x 181, data 741,
  // orario 761, città 782, PRENOTA (308,765).
  static const _LayoutSerata _normale = _LayoutSerata(
    h: 102,
    fotoX: 6,
    fotoY: 8,
    fotoW: 153,
    fotoH: 88,
    testoX: 167,
    dataY: 43,
    orarioY: 63,
    genereY: 84,
    fontRiga: 19,
    prenotaX: 294,
    prenotaY: 67,
  );

  void _apriPopup() => NavigatorService.pushNamed(
        AppRoutes.eventInfoPopupScreen,
        arguments: {'serata': serata, 'club': locale},
      );

  @override
  Widget build(BuildContext context) {
    final bool isSoldOut = serata.statusPosti == 'Sold Out';
    final String etichetta = _etichettaGiorno(serata.data);
    final _LayoutSerata l = etichetta.isNotEmpty ? _imminente : _normale;
    // Card imminente: tutti i generi ("House - Deep House"); le altre solo il
    // primo, per non troncarlo.
    final List<String> generiList = serata.generiMusicali.isNotEmpty
        ? serata.generiMusicali
        : locale.generiMusicali;
    final String generi = etichetta.isNotEmpty
        ? generiList.join(' - ')
        : (generiList.isNotEmpty ? generiList.first : '');
    // Le righe si fermano prima del bottone PRENOTA, che l'orario affianca.
    final double larghezzaRiga = l.prenotaX - l.testoX - 4;
    final TextStyle riga = OnlistTextStyles.hn(
      fontSize: l.fontRiga,
      fontWeight: FontWeight.w400,
      color: Colors.white,
      height: 1,
    );

    return Padding(
      // CSS: card a left 14, 10px tra una card e l'altra (688 → 698).
      padding: const EdgeInsets.fromLTRB(13, 0, 13, 10),
      // Tap sulla card → pop-up info serata.
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _apriPopup,
        child: _scaleToWidth(
          designW: _w,
          designH: l.h,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(7),
            child: SizedBox(
              width: _w,
              height: l.h,
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: OnlistColors.homeClubCard,
                ),
                child: Stack(
                  children: [
                    Positioned(
                      left: l.fotoX,
                      top: l.fotoY,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: SizedBox(
                          width: l.fotoW,
                          height: l.fotoH,
                          child: serata.locandinaUrl != null
                              ? CachedNetworkImage(
                                  imageUrl: serata.locandinaUrl!,
                                  fit: BoxFit.cover,
                                  memCacheWidth: 459,
                                  errorWidget: (_, __, ___) =>
                                      ImageFallback(seed: serata.id),
                                )
                              : ImageFallback(seed: serata.id),
                        ),
                      ),
                    ),
                    // Titolo 32/37/700 a y 6.
                    Positioned(
                      left: 166,
                      top: 6,
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
                    // "OGGI"/"DOMANI" 19/500 a y 45, solo sulle imminenti.
                    if (etichetta.isNotEmpty)
                      Positioned(
                        left: l.testoX,
                        top: 45,
                        child: Text(
                          etichetta,
                          style: OnlistTextStyles.hn(
                            fontSize: 19,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                            height: 1,
                          ),
                        ),
                      ),
                    Positioned(
                      left: l.testoX,
                      top: l.dataY,
                      width: larghezzaRiga,
                      child: Text(
                        DateFormatter.formatBreve(serata.data),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: riga,
                      ),
                    ),
                    if (serata.orarioString.isNotEmpty)
                      Positioned(
                        left: l.testoX,
                        top: l.orarioY,
                        width: larghezzaRiga,
                        child: Text(
                          serata.orarioString,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: riga,
                        ),
                      ),
                    // Genere 12/500 all'80% (slot "città" del CSS).
                    Positioned(
                      left: l.testoX,
                      top: l.genereY,
                      width: larghezzaRiga,
                      child: Opacity(
                        opacity: 0.8,
                        child: Text(
                          generi,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: OnlistTextStyles.hn(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                            height: 1,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: l.prenotaX,
                      top: l.prenotaY,
                      child: Opacity(
                        opacity: isSoldOut ? 0.5 : 1,
                        child: CardPrenotaButton(
                          label: isSoldOut ? 'ESAURITO' : 'PRENOTA',
                          onTap: isSoldOut ? null : _apriPopup,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
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
