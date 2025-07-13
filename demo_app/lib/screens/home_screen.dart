import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import '../models/hiragana_recognizer.dart';
import '../widgets/handwriting_canvas.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final HiraganaRecognizer _recognizer = HiraganaRecognizer();
  final GlobalKey<HandwritingCanvasState> _canvasKey = GlobalKey();
  
  bool _isLoading = true;
  List<Recognition>? _results;
  String? _errorMessage;
  ui.Image? _lastProcessedImage;

  @override
  void initState() {
    super.initState();
    _initializeRecognizer();
  }

  Future<void> _initializeRecognizer() async {
    try {
      await _recognizer.initialize();
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = '初期化に失敗しました: $e';
      });
    }
  }

  Future<void> _recognizeImage(ui.Image image) async {
    setState(() {
      _results = null;
      _errorMessage = null;
      _lastProcessedImage = image;
    });

    try {
      final results = await _recognizer.recognize(image);
      setState(() {
        _results = results;
      });
    } catch (e) {
      setState(() {
        _errorMessage = '認識に失敗しました: $e';
      });
    }
  }


  @override
  void dispose() {
    _recognizer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ひらがな認識アプリ'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.red,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text(
                        'ひらがなを書いてください',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    // Fixed canvas area (no scrolling)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: HandwritingCanvas(
                        key: _canvasKey,
                        onImageReady: _recognizeImage,
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Fixed results area (no scrolling needed)
                    if (_results != null) ...[
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16.0),
                        child: Text(
                          '認識結果',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: _buildCompactResultsDisplay(),
                        ),
                      ),
                    ] else ...[
                      const Expanded(child: SizedBox()), // Empty space when no results
                    ],
                  ],
                ),
    );
  }


  Widget _buildCompactResultsDisplay() {
    if (_results == null || _results!.isEmpty) {
      return const Center(
        child: Text(
          '認識できませんでした',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    final topResult = _results![0];
    final otherResults = _results!.skip(1).take(4).toList(); // Top 4 candidates
    
    return Column(
      children: [
        // Top result display (more compact)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue, width: 2),
          ),
          child: Row(
            children: [
              // Preview area on the left
              Container(
                width: 60,
                height: 60,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: _lastProcessedImage != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CustomPaint(
                          painter: _ImagePreviewPainter(_lastProcessedImage!),
                          child: const SizedBox.expand(),
                        ),
                      )
                    : const Center(
                        child: Text(
                          '64×64',
                          style: TextStyle(
                            fontSize: 8,
                            color: Colors.grey,
                          ),
                        ),
                      ),
              ),
              // Character display
              Text(
                topResult.character,
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(width: 16),
              // Confidence badge
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '確信度: ${(topResult.confidence * 100).toStringAsFixed(1)}%',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Other candidates in a grid
        if (otherResults.isNotEmpty) ...[
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'その他の候補',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Fixed grid without scrolling
          Column(
            children: [
              // First row of candidates
              Row(
                children: [
                  for (int i = 0; i < 2 && i < otherResults.length; i++) ...[
                    Expanded(
                      child: Container(
                        height: 40,
                        margin: EdgeInsets.only(right: i == 0 ? 4 : 0, left: i == 1 ? 4 : 0),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              otherResults[i].character,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${(otherResults[i].confidence * 100).toStringAsFixed(1)}%',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              if (otherResults.length > 2) ...[
                const SizedBox(height: 8),
                // Second row of candidates
                Row(
                  children: [
                    for (int i = 2; i < 4 && i < otherResults.length; i++) ...[
                      Expanded(
                        child: Container(
                          height: 40,
                          margin: EdgeInsets.only(right: i == 2 ? 4 : 0, left: i == 3 ? 4 : 0),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                otherResults[i].character,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${(otherResults[i].confidence * 100).toStringAsFixed(1)}%',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }

}

class _ImagePreviewPainter extends CustomPainter {
  final ui.Image image;

  _ImagePreviewPainter(this.image);

  @override
  void paint(Canvas canvas, Size size) {
    final srcRect = Rect.fromLTWH(
      0,
      0,
      image.width.toDouble(),
      image.height.toDouble(),
    );
    
    final destRect = Rect.fromLTWH(
      0,
      0,
      size.width,
      size.height,
    );
    
    canvas.drawImageRect(image, srcRect, destRect, Paint());
  }

  @override
  bool shouldRepaint(covariant _ImagePreviewPainter oldDelegate) {
    return oldDelegate.image != image;
  }
}