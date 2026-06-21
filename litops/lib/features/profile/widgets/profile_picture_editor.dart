import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/widgets/common_widgets.dart';

class ProfilePictureEditor extends StatefulWidget {
  final XFile imageFile;

  const ProfilePictureEditor({super.key, required this.imageFile});

  static Future<Uint8List?> show(BuildContext context, XFile imageFile) {
    return Navigator.push<Uint8List>(
      context,
      MaterialPageRoute(
        builder: (context) => ProfilePictureEditor(imageFile: imageFile),
        fullscreenDialog: true,
      ),
    );
  }

  @override
  State<ProfilePictureEditor> createState() => _ProfilePictureEditorState();
}

class _ProfilePictureEditorState extends State<ProfilePictureEditor> {
  final GlobalKey _repaintKey = GlobalKey();
  final TransformationController _transformationController = TransformationController();
  int _quarterTurns = 0;
  bool _isSaving = false;

  void _zoom(double factor) {
    final matrix = _transformationController.value.clone();
    final double currentScale = matrix.getMaxScaleOnAxis();
    final double targetScale = (currentScale * factor).clamp(0.5, 5.0);

    final size = MediaQuery.of(context).size;
    final cx = size.width / 2;
    final cy = size.height / 2;

    final translation = matrix.getTranslation();
    final double tx = translation.x;
    final double ty = translation.y;

    final double newTx = cx - (cx - tx) * (targetScale / currentScale);
    final double newTy = cy - (cy - ty) * (targetScale / currentScale);

    setState(() {
      _transformationController.value = Matrix4.identity()
        ..translate(newTx, newTy)
        ..scale(targetScale);
    });
  }

  void _rotate() {
    setState(() {
      _quarterTurns = (_quarterTurns + 1) % 4;
      _transformationController.value = Matrix4.identity(); // Reset transform on rotate to avoid weird offsets
    });
  }

  void _reset() {
    setState(() {
      _quarterTurns = 0;
      _transformationController.value = Matrix4.identity();
    });
  }

  Future<void> _cropAndSave() async {
    setState(() => _isSaving = true);
    try {
      // Small delay to ensure any UI update completes
      await Future.delayed(const Duration(milliseconds: 50));
      
      final boundary = _repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) throw Exception('Failed to find boundary context');

      // Capture at high quality
      final ui.Image fullImage = await boundary.toImage(pixelRatio: 2.5);

      final RenderBox box = _repaintKey.currentContext?.findRenderObject() as RenderBox;
      final size = box.size;
      final double W = size.width;
      final double H = size.height;

      final double cropSize = W * 0.8 < 300.0 ? W * 0.8 : 300.0;
      final double left = (W - cropSize) / 2;
      final double top = (H - cropSize) / 2;

      // Convert logical crop area coordinates to physical image pixels
      final double ratio = fullImage.width / W;
      final cropRect = Rect.fromLTWH(
        left * ratio,
        top * ratio,
        cropSize * ratio,
        cropSize * ratio,
      );

      // Draw onto target square canvas
      const int targetSize = 512;
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      final dstRect = Rect.fromLTWH(0, 0, targetSize.toDouble(), targetSize.toDouble());
      canvas.drawImageRect(fullImage, cropRect, dstRect, Paint()..filterQuality = ui.FilterQuality.high);

      final picture = recorder.endRecording();
      final croppedImage = await picture.toImage(targetSize, targetSize);
      final byteData = await croppedImage.toByteData(format: ui.ImageByteFormat.png);
      final Uint8List croppedBytes = byteData!.buffer.asUint8List();

      if (mounted) {
        Navigator.pop(context, croppedBytes);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error cropping image: $e'),
            backgroundColor: LitColors.coral,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final double W = size.width;
    final double cropSize = W * 0.8 < 300.0 ? W * 0.8 : 300.0;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: LitColors.bone),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Crop Profile Image',
          style: GoogleFonts.fredoka(color: LitColors.bone, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (_isSaving)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: LitColors.ember),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.check, color: LitColors.moss, size: 28),
              onPressed: _cropAndSave,
            ),
        ],
      ),
      body: Stack(
        children: [
          // 1. Zoomable Image Container inside a RepaintBoundary
          Positioned.fill(
            child: RepaintBoundary(
              key: _repaintKey,
              child: Container(
                color: Colors.black,
                alignment: Alignment.center,
                child: InteractiveViewer(
                  transformationController: _transformationController,
                  minScale: 0.5,
                  maxScale: 5.0,
                  boundaryMargin: const EdgeInsets.all(400),
                  child: Center(
                    child: RotatedBox(
                      quarterTurns: _quarterTurns,
                      child: Image.file(
                        File(widget.imageFile.path),
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          
          // 2. Translucent Cutout Crop Mask Overlay (Outside RepaintBoundary so it's not captured)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: CropMaskPainter(cropSize: cropSize),
              ),
            ),
          ),

          // 3. Floating Toolbar at the bottom
          Positioned(
            left: 0,
            right: 0,
            bottom: 24,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: LitColors.clay.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: LitColors.border, width: 1.5),
                  boxShadow: const [
                    BoxShadow(color: Colors.black54, blurRadius: 15, offset: Offset(0, 6)),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.zoom_in, color: LitColors.bone),
                      onPressed: () => _zoom(1.2),
                      tooltip: 'Zoom In',
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.zoom_out, color: LitColors.bone),
                      onPressed: () => _zoom(0.8),
                      tooltip: 'Zoom Out',
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.rotate_right, color: LitColors.bone),
                      onPressed: _rotate,
                      tooltip: 'Rotate 90°',
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.refresh, color: LitColors.bone),
                      onPressed: _reset,
                      tooltip: 'Reset',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CropMaskPainter extends CustomPainter {
  final double cropSize;

  CropMaskPainter({required this.cropSize});

  @override
  void paint(Canvas canvas, Size size) {
    final maskPaint = Paint()
      ..color = Colors.black.withOpacity(0.75)
      ..style = PaintingStyle.fill;

    final maskPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    final cutoutPath = Path()
      ..addOval(
        Rect.fromCircle(
          center: Offset(size.width / 2, size.height / 2),
          radius: cropSize / 2,
        ),
      );

    final combinedPath = Path.combine(
      PathOperation.difference,
      maskPath,
      cutoutPath,
    );

    canvas.drawPath(combinedPath, maskPaint);

    // Draw circular border
    final borderPaint = Paint()
      ..color = LitColors.ember.withOpacity(0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawOval(
      Rect.fromCircle(
        center: Offset(size.width / 2, size.height / 2),
        radius: cropSize / 2,
      ),
      borderPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CropMaskPainter oldDelegate) =>
      cropSize != oldDelegate.cropSize;
}
