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

    // Calculate transformation (scaling + centering)
    final transformation = _calculateTransformation(bounds);

    // Draw strokes with thicker lines for better recognition
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 12.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Apply transformation to canvas
    canvas.save();
    canvas.transform(transformation.storage);

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

    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  Matrix4 _calculateTransformation(Rect bounds) {
    const double canvasSize = 300.0;
    const double minSize = 80.0; // Minimum size for very small characters
    const double maxSize = 220.0; // Maximum size for very large characters

    // Calculate current size
    final currentWidth = bounds.width;
    final currentHeight = bounds.height;
    final currentSize = math.max(currentWidth, currentHeight);

    // Calculate target size
    double targetSize = currentSize;
    
    // Scale up very small characters
    if (currentSize < minSize) {
      targetSize = minSize;
    }
    // Scale down very large characters
    else if (currentSize > maxSize) {
      targetSize = maxSize;
    }

    // Calculate scale factor
    final scale = currentSize > 0 ? targetSize / currentSize : 1.0;

    // Calculate centering offset
    const targetCenter = Offset(canvasSize / 2, canvasSize / 2);

    // Create transformation matrix
    final transformation = Matrix4.identity();
    
    // 1. Translate to origin
    transformation.translate(-bounds.center.dx, -bounds.center.dy);
    
    // 2. Scale
    transformation.scale(scale, scale);
    
    // 3. Translate to target position
    transformation.translate(targetCenter.dx, targetCenter.dy);

    return transformation;
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