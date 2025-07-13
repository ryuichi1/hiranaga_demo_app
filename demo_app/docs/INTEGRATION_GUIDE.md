# 統合実装ガイド

既存のFlutterアプリにひらがな認識機能を統合するための詳細ガイドです。

## ステップバイステップ統合

### Step 1: ファイルのコピー

既存プロジェクトに以下のファイルをコピー：

#### 必須ファイル
```
lib/models/hiragana_recognizer.dart    # 認識エンジン
lib/widgets/handwriting_canvas.dart    # 手書きキャンバス（オプション）
assets/etlcb_9b_model.tflite          # モデルファイル
assets/etlcb_9b_labels.txt             # ラベルファイル
```

### Step 2: 依存関係の追加

`pubspec.yaml`を更新：

```yaml
dependencies:
  flutter:
    sdk: flutter
  tflite_flutter: ^0.11.0  # 追加
  image: ^4.1.7             # 追加
  # 既存の依存関係...

flutter:
  uses-material-design: true
  assets:
    - assets/etlcb_9b_model.tflite  # 追加
    - assets/etlcb_9b_labels.txt    # 追加
    # 既存のアセット...
```

```bash
flutter pub get
```

### Step 3: 基本統合パターン

#### パターン1: シンプルな認識機能のみ

```dart
import 'package:flutter/material.dart';
import 'package:your_app/models/hiragana_recognizer.dart';

class SimpleRecognitionPage extends StatefulWidget {
  @override
  _SimpleRecognitionPageState createState() => _SimpleRecognitionPageState();
}

class _SimpleRecognitionPageState extends State<SimpleRecognitionPage> {
  final HiraganaRecognizer _recognizer = HiraganaRecognizer();
  bool _isInitialized = false;
  List<Recognition>? _results;

  @override
  void initState() {
    super.initState();
    _initializeRecognizer();
  }

  Future<void> _initializeRecognizer() async {
    try {
      await _recognizer.initialize();
      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      print('認識器の初期化に失敗: $e');
    }
  }

  @override
  void dispose() {
    _recognizer.dispose();
    super.dispose();
  }

  // 外部から画像を受け取って認識
  Future<void> recognizeFromImage(ui.Image image) async {
    if (!_isInitialized) return;
    
    try {
      final results = await _recognizer.recognize(image);
      setState(() {
        _results = results;
      });
    } catch (e) {
      print('認識に失敗: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('ひらがな認識')),
      body: Center(
        child: _isInitialized
            ? Column(
                children: [
                  // ここに手書き入力や画像選択UI
                  if (_results != null) ...[
                    Text('認識結果: ${_results![0].character}'),
                    Text('確信度: ${(_results![0].confidence * 100).toStringAsFixed(1)}%'),
                  ],
                ],
              )
            : CircularProgressIndicator(),
      ),
    );
  }
}
```

#### パターン2: 手書きキャンバス付き

```dart
import 'package:your_app/widgets/handwriting_canvas.dart';

class FullRecognitionPage extends StatefulWidget {
  @override
  _FullRecognitionPageState createState() => _FullRecognitionPageState();
}

class _FullRecognitionPageState extends State<FullRecognitionPage> {
  final HiraganaRecognizer _recognizer = HiraganaRecognizer();
  List<Recognition>? _results;

  @override
  void initState() {
    super.initState();
    _recognizer.initialize();
  }

  @override
  void dispose() {
    _recognizer.dispose();
    super.dispose();
  }

  Future<void> _onImageReady(ui.Image image) async {
    final results = await _recognizer.recognize(image);
    setState(() {
      _results = results;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('手書きひらがな認識')),
      body: Column(
        children: [
          // 手書きキャンバス
          HandwritingCanvas(
            onImageReady: _onImageReady,
          ),
          // 認識結果表示
          if (_results != null) ...[
            _buildResults(),
          ],
        ],
      ),
    );
  }

  Widget _buildResults() {
    if (_results!.isEmpty) return Text('認識できませんでした');
    
    return Column(
      children: [
        // トップ結果
        Text(
          _results![0].character,
          style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
        ),
        Text('確信度: ${(_results![0].confidence * 100).toStringAsFixed(1)}%'),
        
        // 候補
        Wrap(
          children: _results!.skip(1).take(4).map((result) =>
            Chip(label: Text('${result.character} (${(result.confidence * 100).toStringAsFixed(1)}%)'))
          ).toList(),
        ),
      ],
    );
  }
}
```

### Step 4: 既存アプリへの統合例

#### 例1: フォーム入力支援

```dart
class HiraganaInputField extends StatefulWidget {
  final TextEditingController controller;
  final String labelText;

  const HiraganaInputField({
    required this.controller,
    required this.labelText,
  });

  @override
  _HiraganaInputFieldState createState() => _HiraganaInputFieldState();
}

class _HiraganaInputFieldState extends State<HiraganaInputField> {
  final HiraganaRecognizer _recognizer = HiraganaRecognizer();

  @override
  void initState() {
    super.initState();
    _recognizer.initialize();
  }

  void _showHandwritingInput() {
    showModalBottomSheet(
      context: context,
      builder: (context) => HandwritingInput(
        onCharacterRecognized: (character) {
          widget.controller.text += character;
          Navigator.pop(context);
        },
        recognizer: _recognizer,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      decoration: InputDecoration(
        labelText: widget.labelText,
        suffixIcon: IconButton(
          icon: Icon(Icons.edit),
          onPressed: _showHandwritingInput,
        ),
      ),
    );
  }
}
```

#### 例2: ゲームアプリとの統合

```dart
class HiraganaGameScreen extends StatefulWidget {
  @override
  _HiraganaGameScreenState createState() => _HiraganaGameScreenState();
}

class _HiraganaGameScreenState extends State<HiraganaGameScreen> {
  final HiraganaRecognizer _recognizer = HiraganaRecognizer();
  String _targetCharacter = 'あ';
  int _score = 0;

  Future<void> _checkAnswer(ui.Image image) async {
    final results = await _recognizer.recognize(image);
    
    if (results.isNotEmpty && results[0].character == _targetCharacter) {
      setState(() {
        _score += 10;
        _targetCharacter = _getNextCharacter();
      });
      _showSuccessAnimation();
    } else {
      _showRetryMessage();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Text('この文字を書いてください: $_targetCharacter', style: TextStyle(fontSize: 24)),
          Text('スコア: $_score'),
          HandwritingCanvas(onImageReady: _checkAnswer),
        ],
      ),
    );
  }
}
```

### Step 5: カスタマイズ

#### 認識結果のフィルタリング

```dart
// 特定の文字のみを認識対象にする
class CustomHiraganaRecognizer extends HiraganaRecognizer {
  final Set<String> allowedCharacters;

  CustomHiraganaRecognizer(this.allowedCharacters);

  @override
  Future<List<Recognition>> recognize(ui.Image image) async {
    final results = await super.recognize(image);
    
    // 許可された文字のみをフィルタ
    return results.where((r) => allowedCharacters.contains(r.character)).toList();
  }
}

// 使用例: あいうえおのみを認識
final recognizer = CustomHiraganaRecognizer({'あ', 'い', 'う', 'え', 'お'});
```

#### UIのカスタマイズ

```dart
// カスタム手書きキャンバス
class CustomHandwritingCanvas extends HandwritingCanvas {
  CustomHandwritingCanvas({
    required Function(ui.Image) onImageReady,
    Color strokeColor = Colors.blue,
    double strokeWidth = 15.0,
  }) : super(
    onImageReady: onImageReady,
    // カスタムプロパティを追加可能
  );
}
```

### Step 6: テストとデバッグ

#### ユニットテスト

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:your_app/models/hiragana_recognizer.dart';

void main() {
  group('HiraganaRecognizer', () {
    late HiraganaRecognizer recognizer;

    setUp(() async {
      recognizer = HiraganaRecognizer();
      await recognizer.initialize();
    });

    tearDown(() {
      recognizer.dispose();
    });

    test('should initialize successfully', () {
      expect(recognizer, isNotNull);
    });

    // 実際の画像テストは統合テストで実行
  });
}
```

#### パフォーマンステスト

```dart
void performanceTest() async {
  final recognizer = HiraganaRecognizer();
  await recognizer.initialize();

  final stopwatch = Stopwatch()..start();
  
  // テスト画像で複数回認識
  for (int i = 0; i < 10; i++) {
    await recognizer.recognize(testImage);
  }
  
  stopwatch.stop();
  print('平均認識時間: ${stopwatch.elapsedMilliseconds / 10}ms');
  
  recognizer.dispose();
}
```

## トラブルシューティング

### よくある統合エラー

1. **アセットが見つからない**
   ```
   Error: Unable to load asset: assets/etlcb_9b_model.tflite
   ```
   → `pubspec.yaml`のassets設定とファイルパスを確認

2. **依存関係エラー**
   ```
   Error: Could not find package tflite_flutter
   ```
   → `flutter pub get`を実行、バージョンを確認

3. **メモリ不足**
   ```
   Error: Out of memory
   ```
   → 複数のrecognizerインスタンス作成を避ける、適切にdispose()を呼ぶ

### デバッグのヒント

- 認識精度が低い場合は、デバッグログを有効にして画像前処理を確認
- パフォーマンスが悪い場合は、リリースビルドで測定
- クラッシュする場合は、初期化の完了を確認

このガイドに従って統合すれば、既存アプリにひらがな認識機能を安全に追加できます。