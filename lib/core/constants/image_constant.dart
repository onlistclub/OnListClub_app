// lib/core/constants/image_constant.dart
/// Path statici degli asset immagine usati dall'app.
///
/// Centralizza la base path (`assets/images/`) così che rinominare la cartella
/// asset richieda di toccare solo questo file. Usare sempre `ImageConstant.xxx`
/// nei widget, mai stringhe hardcoded.
class ImageConstant {
  // Base path for all assets
  static const String _basePath = 'assets/images/';

  // Placeholder image for fallback
  static String imgPlaceholder = '${_basePath}placeholder.png';

  // Custom Image View Screen
  static String imgImageNotFound = '${_basePath}image_not_found.png';

  // Immagini di stock "stile disco" usate da ImageFallback quando la foto
  // remota di un locale/evento manca o non carica. Gli URL Unsplash del seed
  // non sono garantiti nel tempo (4 ID su 19 sono già stati rimossi a monte):
  // questi asset locali evitano che l'utente veda un buco.
  static const List<String> stockClub = [
    '${_basePath}stock_club_1.jpg',
    '${_basePath}stock_club_2.jpg',
    '${_basePath}stock_club_3.jpg',
    '${_basePath}stock_club_4.jpg',
  ];

  // Logo
  static String imgLogoOnlist = '${_basePath}logo_onlist.png';
  // Wordmark "OnList" ritagliato (senza il padding trasparente del quadrato
  // 4096², che rimpiccioliva il logo nella top bar). Aspect ≈ 2.625:1.
  static String imgLogoOnlistWordmark = '${_basePath}logo_onlist_wordmark.png';

  // Event Detail Screen
  static String imgHome = '${_basePath}img_home.svg';
  static String imgShoppingCart = '${_basePath}img_shopping_cart.svg';
  static String imgBell = '${_basePath}img_bell.svg';
  static String imgUser = '${_basePath}img_user.svg';

  // ── Asset VECCHI navbar/footer (assets/svg/) ──────────────────────────────
  // Non più referenziati da nessuno screen dopo il restyle a footer 3-icone
  // (vedi imgNavTicket/imgNavHome/imgNavCart sotto). Lasciati qui perché i
  // file .png esistono ancora su disco: valutare se rimuoverli.
  static const String _svgPath = 'assets/svg/';
  static String imgNavBagOld = '${_svgPath}bag.png'; // 34×32
  static String imgNavBellOld = '${_svgPath}notification.png'; // 31×34
  static String imgFooterPillOld = '${_svgPath}selezionato.png'; // 73×43
  static String imgFooterBorderOld = '${_svgPath}bordo_footer.png'; // 354×49

  // ── Asset ufficiali navbar/footer (assets/svg/ufficiali/) ─────────────────
  // Nuova footer a 3 icone (Ticket, Home, Carrello) + nuove icone top bar.
  // SVG con stroke bianco nativo: renderizzare con SvgPicture, non Image.asset.
  static const String _svgUfficiali = '${_svgPath}ufficiali/';
  static String imgNavTicket = '${_svgUfficiali}Vector.svg'; // 41×29
  static String imgNavHome = '${_svgUfficiali}home.svg'; // 33×33
  static String imgNavCart = '${_svgUfficiali}Shopping_Cart_01.svg'; // 31×32
  // Lente ufficiale fornita da Luca: 34×34, stroke bianco 3px (il vecchio
  // `Search_Magnifying_Glass.svg` era 24×24 e veniva scalato a 34).
  static String imgNavSearch = '${_svgUfficiali}Search.svg'; // 34×34
  static String imgNavProfile = '${_svgUfficiali}User_01.svg'; // 24×24
  static String imgProfileBadgeDot = '${_svgUfficiali}Ellipse 17.svg'; // 16×16

  // ── Cerchi e frecce ufficiali ─────────────────────────────────────────────
  /// Cerchio della X nel pop-up serata: 30×30, stroke bianco 1px.
  static String imgCirclePopup = '${_svgUfficiali}cerchio_pop_up_serata.svg';

  /// X del pop-up serata: 24×24, stroke bianco 2px.
  static String imgClose = '${_svgUfficiali}chiusura_media.svg';

  /// Cerchio delle frecce del biglietto: 28×28, stroke bianco 2px.
  static String imgCircleTicket = '${_svgUfficiali}cerchio_biglietto.svg';

  /// Freccia giù (apri biglietto / espandi sezione ordini): 15×15, piena.
  static String imgArrowDown = '${_svgUfficiali}freccia_giu.svg';

  /// Freccia su (chiudi biglietto): 22×22, piena.
  static String imgArrowUp = '${_svgUfficiali}freccia_su.svg';

  /// Freccia indietro ("Torna indietro"): 24×24, piena. Usata da [BackRow],
  /// che è l'unico punto in cui va referenziata.
  static String imgArrowLeft = '${_svgUfficiali}freccia_sinistra.svg';

  // ── Info del club (pagina locale) ─────────────────────────────────────────
  /// Orologio dell'orario di apertura: 19×19, stroke bianco 2px.
  static String imgClock = '${_svgUfficiali}clock.svg';

  /// Nota musicale dei generi: 17×17, stroke bianco 2px.
  static String imgMusic = '${_svgUfficiali}music.svg';

  /// Sfondo pill del tastino "Mappe" nel pop-up serata: 44×16, verde-teal 20%.
  static String imgMapButtonBg = '${_svgPath}tasto_mappe_pop_up_sserata.svg';

  /// Wordmark "Mappe" del tastino nel pop-up serata: 35×9, bianco pieno.
  static String imgMapButtonLabel = '${_svgPath}mappe.svg';

  /// Coriandoli della card "Tu e OnList": i 9 tracciati ufficiali estratti
  /// dall'export Figma del `Group 426`. Il viewBox coincide col rettangolo
  /// della card, quindi si sovrappone 1:1 senza calcoli.
  static String imgCoriandoli = '${_svgUfficiali}coriandoli.svg';

  // NB: `Rectangle 261.svg` (capsula footer) non è più referenziato: la capsula
  // è disegnata in Flutter (bordo + blur) secondo `footer-bar-ufficiale.css`.
}
