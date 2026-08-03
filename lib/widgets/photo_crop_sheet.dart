import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../core/utils/responsive.dart';
import '../theme/onlist_colors.dart';
import '../theme/onlist_text_styles.dart';

/// Regolazione della foto profilo: l'utente sposta e ingrandisce l'immagine
/// dentro la cornice, poi conferma. Restituisce i **byte PNG** del ritaglio.
///
/// Fatto in-app di proposito, senza `image_cropper`: quel pacchetto porta
/// configurazione nativa su Android (activity nel manifest) e iOS (pod), e lo
/// sviluppo qui è su Windows — la parte iOS non sarebbe verificabile.
/// CLAUDE.md §5.3 chiede comunque di non aggiungere dipendenze evitabili.
///
/// Come funziona: l'immagine sta dentro un [InteractiveViewer] clippato alla
/// cornice; alla conferma si rasterizza il RepaintBoundary della cornice con
/// `toImage`, quindi il ritaglio è **esattamente quello che si vede**, senza
/// dover replicare a mano la matrice di trasformazione.
///
/// Apri con [show]; restituisce null se l'utente annulla.
class PhotoCropSheet extends StatefulWidget {
  const PhotoCropSheet({
    super.key,
    required this.file,
    this.aspectRatio = 114 / 120,
  });

  /// Immagine scelta dalla galleria.
  final File file;

  /// Proporzioni della cornice. Default: quelle del riquadro foto
  /// dell'Account (114×120 px design).
  final double aspectRatio;

  /// Lato lungo del PNG prodotto. 800 come `ImagePicker.maxWidth` usato a
  /// monte: inutile caricare più risoluzione di quella che si aveva.
  static const int _outputMaxSide = 800;

  static Future<Uint8List?> show(BuildContext context, File file) {
    return showModalBottomSheet<Uint8List>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      // Fuori dalla sheet resta il nero della schermata sotto.
      barrierColor: Colors.black.withValues(alpha: 0.85),
      builder: (_) => PhotoCropSheet(file: file),
    );
  }

  @override
  State<PhotoCropSheet> createState() => _PhotoCropSheetState();
}

class _PhotoCropSheetState extends State<PhotoCropSheet> {
  final _cropKey = GlobalKey();
  final _controller = TransformationController();
  bool _isSaving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Rasterizza la cornice e restituisce il PNG.
  Future<void> _conferma() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      final boundary =
          _cropKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) throw Exception('cornice non pronta');

      // pixelRatio scelto per arrivare a ~_outputMaxSide sul lato lungo, senza
      // mai INGRANDIRE oltre quello che c'è a schermo (min con 3).
      final lato = math.max(boundary.size.width, boundary.size.height);
      final ratio =
          math.min(3.0, PhotoCropSheet._outputMaxSide / math.max(lato, 1));

      final ui.Image img = await boundary.toImage(pixelRatio: ratio);
      final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
      img.dispose();
      if (bytes == null) throw Exception('conversione PNG fallita');

      if (!mounted) return;
      Navigator.of(context).pop(bytes.buffer.asUint8List());
    } catch (e) {
      debugPrint('[PhotoCropSheet] ritaglio fallito: $e');
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Non sono riuscito a ritagliare la foto')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: R.sp(18)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: R.sp(20)),
            Text(
              'Regola la foto',
              style: OnlistTextStyles.hn(
                fontSize: R.sp(24),
                fontWeight: FontWeight.w700,
                color: OnlistColors.white,
              ),
            ),
            SizedBox(height: R.sp(6)),
            Text(
              'Trascina per spostarla, pizzica per ingrandirla',
              textAlign: TextAlign.center,
              style: OnlistTextStyles.hn(
                fontSize: R.sp(13),
                color: OnlistColors.white.withValues(alpha: 0.55),
              ),
            ),
            SizedBox(height: R.sp(18)),
            // La cornice: ciò che sta qui dentro è esattamente ciò che verrà
            // salvato, perché è questo boundary a essere rasterizzato.
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(R.sp(32)),
                child: RepaintBoundary(
                  key: _cropKey,
                  child: AspectRatio(
                    aspectRatio: widget.aspectRatio,
                    child: ColoredBox(
                      color: const Color(0xFF1A1A1A),
                      child: InteractiveViewer(
                        transformationController: _controller,
                        minScale: 1,
                        maxScale: 5,
                        // Senza questo l'immagine può essere trascinata fuori
                        // dalla cornice lasciando bordi vuoti nel ritaglio.
                        clipBehavior: Clip.none,
                        child: Image.file(widget.file, fit: BoxFit.cover),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: R.sp(22)),
            Row(
              children: [
                Expanded(
                  child: _bottone(
                    'Annulla',
                    onTap: _isSaving ? null : () => Navigator.of(context).pop(),
                    primario: false,
                  ),
                ),
                SizedBox(width: R.sp(12)),
                Expanded(
                  child: _bottone(
                    'Usa questa',
                    onTap: _isSaving ? null : _conferma,
                    primario: true,
                    caricamento: _isSaving,
                  ),
                ),
              ],
            ),
            SizedBox(height: R.sp(20)),
          ],
        ),
      ),
    );
  }

  Widget _bottone(
    String label, {
    required VoidCallback? onTap,
    required bool primario,
    bool caricamento = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: R.sp(48),
        decoration: BoxDecoration(
          gradient: primario ? OnlistColors.primaryCTA : null,
          color: primario ? null : OnlistColors.white.withValues(alpha: 0.08),
          border: primario
              ? null
              : Border.all(color: OnlistColors.white.withValues(alpha: 0.2)),
          borderRadius: BorderRadius.circular(R.sp(10)),
        ),
        alignment: Alignment.center,
        child: caricamento
            ? SizedBox(
                width: R.sp(20),
                height: R.sp(20),
                child: const CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2),
              )
            : Text(
                label,
                style: OnlistTextStyles.hn(
                  fontSize: R.sp(16),
                  fontWeight: FontWeight.w500,
                  color: OnlistColors.white,
                ),
              ),
      ),
    );
  }
}
