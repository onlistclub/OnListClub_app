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

  // Event Detail Screen
  static String imgHome = '${_basePath}img_home.svg';
  static String imgShoppingCart = '${_basePath}img_shopping_cart.svg';
  static String imgBell = '${_basePath}img_bell.svg';
  static String imgUser = '${_basePath}img_user.svg';

  // ── Asset ufficiali navbar/footer (assets/svg/) ──────────────────────────
  // Icone bianche, pill "selezionato" e bordo capsula, dimensioni native dal
  // design (footer-bar 354×49, pill 73×43, icone ~34).
  static const String _svgPath = 'assets/svg/';
  static String imgNavHome = '${_svgPath}home.png';          // 34×34
  static String imgNavBag = '${_svgPath}bag.png';            // 34×32
  static String imgNavCart = '${_svgPath}carrello.png';      // 34×34
  static String imgNavBell = '${_svgPath}notification.png';  // 31×34
  static String imgNavSearch = '${_svgPath}search.png';      // 34×34
  static String imgNavProfile = '${_svgPath}profile.png';    // 23×29
  static String imgFooterPill = '${_svgPath}selezionato.png'; // 73×43
  static String imgFooterBorder = '${_svgPath}bordo_footer.png'; // 354×49
}
