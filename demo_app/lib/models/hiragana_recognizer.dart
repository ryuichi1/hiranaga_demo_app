import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

class Recognition {
  final String character;
  final double confidence;

  Recognition({required this.character, required this.confidence});
}

class HiraganaRecognizer {
  static const String _modelPath = 'assets/etlcb_9b_model.tflite';
  static const String _labelsPath = 'assets/etlcb_9b_labels.txt';
  
  Interpreter? _interpreter;
  List<String>? _labels;
  Map<int, String>? _hiraganaIndexMap;
  
  Future<void> initialize() async {
    await _loadModel();
    await _loadLabels();
    _filterHiraganaLabels();
  }
  
  Future<void> _loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset(_modelPath);
      // Model loaded successfully
    } catch (e) {
      print('Failed to load model: $e');
      throw Exception('Failed to load model: $e');
    }
  }
  
  Future<void> _loadLabels() async {
    try {
      final labelsData = await rootBundle.loadString(_labelsPath);
      _labels = labelsData.split('\n').where((label) => label.isNotEmpty).toList();
      // Labels loaded: ${_labels!.length} labels
    } catch (e) {
      print('Failed to load labels: $e');
      throw Exception('Failed to load labels: $e');
    }
  }
  
  void _filterHiraganaLabels() {
    _hiraganaIndexMap = {};
    
    for (int i = 0; i < _labels!.length; i++) {
      final label = _labels![i];
      // Take the first character from each label (following Android implementation)
      if (label.isNotEmpty) {
        final firstChar = label[0];
        if (_isHiragana(firstChar)) {
          _hiraganaIndexMap![i] = firstChar;
        }
      }
    }
    
    // Filtered ${_hiraganaIndexMap!.length} hiragana characters
  }
  
  bool _isHiragana(String char) {
    if (char.isEmpty) return false;
    final codeUnit = char.codeUnitAt(0);
    // Unicode range for Hiragana: 0x3040 - 0x309F
    return codeUnit >= 0x3040 && codeUnit <= 0x309F;
  }
  
  Future<List<Recognition>> recognize(ui.Image image) async {
    if (_interpreter == null || _labels == null || _hiraganaIndexMap == null) {
      throw Exception('Recognizer not initialized');
    }
    
    // Convert ui.Image to img.Image for processing
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final imgImage = img.decodeImage(byteData!.buffer.asUint8List())!;
    
    // Preprocess image
    final input = _preprocessImage(imgImage);
    
    // Run inference
    final output = List.filled(_labels!.length, 0.0).reshape([1, _labels!.length]);
    _interpreter!.run(input, output);
    
    final outputList = output[0] as List<double>;
    
    // Process results
    return _processResults(outputList);
  }
  
  List<List<List<List<double>>>> _preprocessImage(img.Image image) {
    // Resize to 64x64 first
    final resized = img.copyResize(image, width: 64, height: 64, interpolation: img.Interpolation.cubic);
    
    // Image preprocessing
    
    // Create 4D array [1, 64, 64, 1] following the Android implementation
    final input = List.generate(1, (batch) =>
      List.generate(64, (y) =>
        List.generate(64, (x) =>
          List.generate(1, (channel) {
            final pixel = resized.getPixel(x, y);
            // Convert to grayscale using the same formula as Android code
            final r = pixel.r.toDouble();
            final g = pixel.g.toDouble();
            final b = pixel.b.toDouble();
            // Ensure RGB values don't exceed 255
            final clampedR = r.clamp(0.0, 255.0);
            final clampedG = g.clamp(0.0, 255.0);
            final clampedB = b.clamp(0.0, 255.0);
            final gray = (0.299 * clampedR + 0.597 * clampedG + 0.114 * clampedB) / 255.0;
            
            // ETL models often expect black background with white characters
            // So we need to invert: white background (1.0) -> 0.0, black strokes (0.0) -> 1.0
            return 1.0 - gray;
          })
        )
      )
    );
    
    
    return input;
  }
  
  List<Recognition> _processResults(List<double> output) {
    final List<Recognition> recognitions = [];
    
    // First, collect hiragana values from raw output
    final hiraganaValues = <double>[];
    for (final entry in _hiraganaIndexMap!.entries) {
      final index = entry.key;
      final character = entry.value;
      final rawValue = output[index];
      
      recognitions.add(Recognition(
        character: character,
        confidence: rawValue,
      ));
      hiraganaValues.add(rawValue);
    }
    
    // Sort by raw confidence
    recognitions.sort((a, b) => b.confidence.compareTo(a.confidence));
    
    // Calculate relative confidence within hiragana characters only
    final maxHiraganaValue = hiraganaValues.reduce((a, b) => a > b ? a : b);
    final minHiraganaValue = hiraganaValues.reduce((a, b) => a < b ? a : b);
    final range = maxHiraganaValue - minHiraganaValue;
    
    // Normalize confidence relative to hiragana characters only
    for (int i = 0; i < recognitions.length; i++) {
      final normalizedConfidence = range > 0 
        ? (recognitions[i].confidence - minHiraganaValue) / range
        : 0.0;
      
      recognitions[i] = Recognition(
        character: recognitions[i].character,
        confidence: normalizedConfidence,
      );
    }
    
    // Sort again by normalized confidence
    recognitions.sort((a, b) => b.confidence.compareTo(a.confidence));
    
    // Optional: Enable for debugging
    // print('Top 3 results (relative confidence):');
    // for (int i = 0; i < math.min(3, recognitions.length); i++) {
    //   final r = recognitions[i];
    //   print('  ${r.character}: ${(r.confidence * 100).toStringAsFixed(1)}%');
    // }
    
    // Return top 5 results
    return recognitions.take(5).toList();
  }
  
  
  void dispose() {
    _interpreter?.close();
  }
}