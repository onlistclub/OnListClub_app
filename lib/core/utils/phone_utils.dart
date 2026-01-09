class PhoneUtils {
  static const Map<String, String> _dialByIso = {
    'IT': '+39',
    'CH': '+41',
    'FR': '+33',
    'DE': '+49',
    'ES': '+34',
  };

  static String normalize({String? countryIso, String? nationalNumber, String? completeNumber}) {
    final iso = countryIso?.toUpperCase();
    final expectedDial = iso != null ? _dialByIso[iso] : null;
    if (expectedDial == null) {
      return completeNumber ?? (nationalNumber ?? '');
    }
    final nn = (nationalNumber ?? '').replaceAll(RegExp(r'\D'), '');
    if (nn.isNotEmpty) {
      return '$expectedDial$nn';
    }
    final cn = (completeNumber ?? '').replaceAll(RegExp(r'\s'), '');
    if (cn.startsWith('+')) {
      final digits = cn.substring(1);
      if (digits.startsWith(expectedDial.substring(1))) {
        return cn;
      }
      return expectedDial + digits.replaceFirst(RegExp(r'^\d+'), '');
    }
    return expectedDial + cn.replaceAll(RegExp(r'^\+'), '');
  }
}
