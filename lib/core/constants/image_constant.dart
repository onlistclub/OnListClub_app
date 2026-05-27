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
}
