import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:flutter/material.dart';

class HandwritingCanvas extends StatefulWidget {
  final Function(ui.Image) onImageReady;
  
  const HandwritingCanvas({
    super.key,
    required this.onImageReady,
  });

  @override
  State<HandwritingCanvas> createState() => HandwritingCanvasState();
}

class HandwritingCanvasState extends State<HandwritingCanvas> {
  final List<List<Offset>> _strokes = [];
  List<Offset> _currentStroke = [];

  void _startStroke(Offset position) {
    setState(() {
      _currentStroke = [position];
    });
  }

  void _updateStroke(Offset position) {
    setState(() {
      _currentStroke.add(position);
    });
  }

  void _endStroke() {
    setState(() {
      if (_currentStroke.isNotEmpty) {
        _strokes.add(List.from(_currentStroke));
        _currentStroke = [];
      }
    });
  }

  void clear() {
    setState(() {
      _strokes.clear();
      _currentStroke.clear();
    });
  }

  Future<void> _captureImage() async {
    // Calculate bounding box of all strokes
    final bounds = _calculateStrokeBounds();
    
    if (bounds == null) {
      // No strokes drawn
      return;
    }

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, 300, 300),
    );

    // Draw white background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, 300, 300),
      Paint()..color = Colors.white,
    );

    // Draw strokes with thicker lines for better recognition
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 12.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Calculate scale to fit the strokes in the center
    const double targetSize = 180.0;
    const double canvasSize = 300.0;
    final strokeAreaSize = math.max(bounds.width, bounds.height);
    final scale = targetSize / strokeAreaSize;

    // Calculate translation to center the strokes
    final scaledWidth = bounds.width * scale;
    final scaledHeight = bounds.height * scale;
    final offsetX = (canvasSize - scaledWidth) / 2;
    final offsetY = (canvasSize - scaledHeight) / 2;

    // Apply transformation
    canvas.save();
    // First translate to the target position
    canvas.translate(offsetX, offsetY);
    // Then scale
    canvas.scale(scale, scale);
    // Finally translate to compensate for the bounds offset
    canvas.translate(-bounds.left, -bounds.top);

    // Draw all strokes
    for (final stroke in _strokes) {
      if (stroke.length > 1) {
        final path = Path();
        path.moveTo(stroke[0].dx, stroke[0].dy);
        for (int i = 1; i < stroke.length; i++) {
          path.lineTo(stroke[i].dx, stroke[i].dy);
        }
        canvas.drawPath(path, paint);
      }
    }

    // Draw current stroke
    if (_currentStroke.length > 1) {
      final path = Path();
      path.moveTo(_currentStroke[0].dx, _currentStroke[0].dy);
      for (int i = 1; i < _currentStroke.length; i++) {
        path.lineTo(_currentStroke[i].dx, _currentStroke[i].dy);
      }
      canvas.drawPath(path, paint);
    }

    canvas.restore();

    final picture = recorder.endRecording();
    final image = await picture.toImage(300, 300);
    widget.onImageReady(image);
  }

  Rect? _calculateStrokeBounds() {
    if (_strokes.isEmpty && _currentStroke.isEmpty) {
      return null;
    }

    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = double.negativeInfinity;
    double maxY = double.negativeInfinity;

    // Calculate bounds for completed strokes
    for (final stroke in _strokes) {
      for (final point in stroke) {
        minX = math.min(minX, point.dx);
        minY = math.min(minY, point.dy);
        maxX = math.max(maxX, point.dx);
        maxY = math.max(maxY, point.dy);
      }
    }

    // Calculate bounds for current stroke
    for (final point in _currentStroke) {
      minX = math.min(minX, point.dx);
      minY = math.min(minY, point.dy);
      maxX = math.max(maxX, point.dx);
      maxY = math.max(maxY, point.dy);
    }

    // Return null if no valid bounds found
    if (minX == double.infinity) {
      return null;
    }

    // Add small padding to account for stroke width and improve bounds
    const double padding = 6.0; // Half of stroke width (12.0 / 2)
    
    minX = math.max(0, minX - padding);
    minY = math.max(0, minY - padding);
    maxX = math.min(300, maxX + padding);
    maxY = math.min(300, maxY + padding);

    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }



  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 300,
          height: 300,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey, width: 2.0),
            color: Colors.white,
          ),
          child: GestureDetector(
            onPanStart: (details) {
              _startStroke(details.localPosition);
            },
            onPanUpdate: (details) {
              _updateStroke(details.localPosition);
            },
            onPanEnd: (details) {
              _endStroke();
            },
            child: CustomPaint(
              painter: _HandwritingPainter(
                strokes: _strokes,
                currentStroke: _currentStroke,
              ),
              size: const Size(300, 300),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ElevatedButton.icon(
              onPressed: clear,
              icon: const Icon(Icons.clear),
              label: const Text('クリア'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
            ),
            ElevatedButton.icon(
              onPressed: _strokes.isNotEmpty ? _captureImage : null,
              icon: const Icon(Icons.check),
              label: const Text('認識'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _HandwritingPainter extends CustomPainter {
  final List<List<Offset>> strokes;
  final List<Offset> currentStroke;

  _HandwritingPainter({
    required this.strokes,
    required this.currentStroke,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 12.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Draw completed strokes
    for (final stroke in strokes) {
      if (stroke.length > 1) {
        final path = Path();
        path.moveTo(stroke[0].dx, stroke[0].dy);
        for (int i = 1; i < stroke.length; i++) {
          path.lineTo(stroke[i].dx, stroke[i].dy);
        }
        canvas.drawPath(path, paint);
      }
    }

    // Draw current stroke
    if (currentStroke.length > 1) {
      final path = Path();
      path.moveTo(currentStroke[0].dx, currentStroke[0].dy);
      for (int i = 1; i < currentStroke.length; i++) {
        path.lineTo(currentStroke[i].dx, currentStroke[i].dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _HandwritingPainter oldDelegate) {
    return true;
  }
}