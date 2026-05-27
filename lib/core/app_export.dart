/// File _barrel_ del layer `core/`.
///
/// Ri-esporta i tipi e gli helper usati da quasi tutte le schermate, così che un
/// singolo `import '../../core/app_export.dart';` evita di ripetere decine di
/// import sparsi. Aggiornare qui ogni volta che si sposta un file riesportato.
export 'services/navigator_service.dart';
export 'package:equatable/equatable.dart';
export 'package:flutter_bloc/flutter_bloc.dart';
export '../routes/app_routes.dart';
export '../theme/theme_helper.dart';
export '../theme/text_style_helper.dart';
export 'constants/image_constant.dart';
export 'utils/size_utils.dart';
export '../widgets/custom_image_view.dart';
