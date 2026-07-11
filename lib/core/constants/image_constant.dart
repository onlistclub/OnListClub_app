// lib/core/constants/image_constant.dart
/// Path statici degli asset immagine usati dall'app.
///
/// Centralizza la base path (`assets/images/`) così che rinominare la cartella
/// asset richieda di toccare solo questo file. Usare sempre `ImageConstant.xxx`
/// nei widget, mai stringhe hardcoded.
class ImageConstant {
  // Base path for all assets
  static String _basePath = 'assets/images/';

  // Placeholder image for fallback
  static String imgPlaceholder = '${_basePath}placeholder.png';

  // Custom Image View Screen
  static String imgImageNotFound = '${_basePath}image_not_found.png';

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
  static String imgNavBagOld = '${_svgPath}bag.png';            // 34×32
  static String imgNavBellOld = '${_svgPath}notification.png';  // 31×34
  static String imgFooterPillOld = '${_svgPath}selezionato.png'; // 73×43
  static String imgFooterBorderOld = '${_svgPath}bordo_footer.png'; // 354×49

  // ── Asset ufficiali navbar/footer (assets/svg/ufficiali/) ─────────────────
  // Nuova footer a 3 icone (Ticket, Home, Carrello) + nuove icone top bar.
  // SVG con stroke bianco nativo: renderizzare con SvgPicture, non Image.asset.
  static const String _svgUfficiali = '${_svgPath}ufficiali/';
  static String imgNavTicket = '${_svgUfficiali}Ticket_Voucher.svg';        // 24×24
  static String imgNavHome = '${_svgUfficiali}Vector.svg';                  // 33×33
  static String imgNavCart = '${_svgUfficiali}Shopping_Cart_01.svg';        // 24×24
  static String imgNavSearch = '${_svgUfficiali}Search_Magnifying_Glass.svg'; // 24×24
  static String imgNavProfile = '${_svgUfficiali}User_01.svg';              // 24×24
  static String imgProfileBadgeDot = '${_svgUfficiali}Ellipse 17.svg';      // 16×16
  static String imgFooterCapsule = '${_svgUfficiali}Rectangle 261.svg';     // 213×48
}
