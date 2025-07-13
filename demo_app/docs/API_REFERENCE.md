# API リファレンス

ひらがな認識モデルのAPI詳細リファレンスです。

## クラス一覧

### HiraganaRecognizer

メインの認識エンジンクラス。ETLCBモデルを使用してひらがな文字を認識します。

#### コンストラクタ

```dart
HiraganaRecognizer()
```

新しいHiraganaRecognizerインスタンスを作成します。

#### プロパティ

| プロパティ | 型 | 説明 |
|-----------|-----|------|
| `isInitialized` | `bool` | 初期化が完了しているかどうか（読み取り専用） |

#### メソッド

##### `Future<void> initialize()`

認識器を初期化します。モデルファイルとラベルファイルを読み込みます。

**例外:**
- `Exception` - モデルまたはラベルファイルの読み込みに失敗した場合

**使用例:**
```dart
final recognizer = HiraganaRecognizer();
try {
  await recognizer.initialize();
  print('初期化完了');
} catch (e) {
  print('初期化失敗: $e');
}
```

##### `Future<List<Recognition>> recognize(ui.Image image)`

手書き文字を認識します。

**パラメータ:**
- `image` (`ui.Image`) - 認識対象の画像

**戻り値:**
- `Future<List<Recognition>>` - 認識結果のリスト（確信度順、最大5件）

**例外:**
- `Exception` - 認識器が初期化されていない場合
- `Exception` - 画像の処理に失敗した場合

**使用例:**
```dart
final results = await recognizer.recognize(image);
if (results.isNotEmpty) {
  print('認識結果: ${results[0].character}');
  print('確信度: ${results[0].confidence}');
}
```

##### `void dispose()`

認識器のリソースを解放します。メモリリークを防ぐため、使用後は必ず呼び出してください。

**使用例:**
```dart
@override
void dispose() {
  recognizer.dispose();
  super.dispose();
}
```

---

### Recognition

認識結果を表すデータクラス。

#### コンストラクタ

```dart
Recognition({
  required String character,
  required double confidence,
})
```

**パラメータ:**
- `character` - 認識された文字
- `confidence` - 確信度（0.0〜1.0）

#### プロパティ

| プロパティ | 型 | 説明 |
|-----------|-----|------|
| `character` | `String` | 認識された文字 |
| `confidence` | `double` | 確信度（0.0〜1.0の範囲） |

**使用例:**
```dart
final recognition = Recognition(
  character: 'あ',
  confidence: 0.95,
);

print('文字: ${recognition.character}');
print('確信度: ${(recognition.confidence * 100).toStringAsFixed(1)}%');
```

---

### HandwritingCanvas

手書き入力用のウィジェット。

#### コンストラクタ

```dart
HandwritingCanvas({
  Key? key,
  required Function(ui.Image) onImageReady,
})
```

**パラメータ:**
- `key` - ウィジェットキー（オプション）
- `onImageReady` - 画像が準備できた時に呼び出されるコールバック

#### プロパティ

| プロパティ | 型 | 説明 |
|-----------|-----|------|
| `onImageReady` | `Function(ui.Image)` | 認識ボタンが押された時のコールバック |

#### 公開メソッド

##### `void clear()`

キャンバスをクリアします。

**使用例:**
```dart
final GlobalKey<HandwritingCanvasState> canvasKey = GlobalKey();

// キャンバスをクリア
canvasKey.currentState?.clear();
```

---

## 定数

### モデル仕様

```dart
class ModelSpecs {
  static const String modelPath = 'assets/etlcb_9b_model.tflite';
  static const String labelsPath = 'assets/etlcb_9b_labels.txt';
  static const int inputSize = 64;  // 64x64ピクセル
  static const int totalLabels = 3036;  // 全文字数
  static const int hiraganaCount = 71;  // ひらがな文字数
}
```

### 認識可能文字

```dart
class HiraganaCharacters {
  // 基本文字
  static const List<String> basic = [
    'あ', 'い', 'う', 'え', 'お',
    'か', 'き', 'く', 'け', 'こ',
    'さ', 'し', 'す', 'せ', 'そ',
    'た', 'ち', 'つ', 'て', 'と',
    'な', 'に', 'ぬ', 'ね', 'の',
    'は', 'ひ', 'ふ', 'へ', 'ほ',
    'ま', 'み', 'む', 'め', 'も',
    'や', 'ゆ', 'よ',
    'ら', 'り', 'る', 'れ', 'ろ',
    'わ', 'を', 'ん'
  ];

  // 濁音
  static const List<String> dakuten = [
    'が', 'ぎ', 'ぐ', 'げ', 'ご',
    'ざ', 'じ', 'ず', 'ぜ', 'ぞ',
    'だ', 'ぢ', 'づ', 'で', 'ど',
    'ば', 'び', 'ぶ', 'べ', 'ぼ'
  ];

  // 半濁音
  static const List<String> handakuten = [
    'ぱ', 'ぴ', 'ぷ', 'ぺ', 'ぽ'
  ];

  // 小文字
  static const List<String> small = [
    'ぁ', 'ぃ', 'ぅ', 'ぇ', 'ぉ',
    'ゃ', 'ゅ', 'ょ', 'っ'
  ];

  // 全文字
  static List<String> get all => [
    ...basic,
    ...dakuten,
    ...handakuten,
    ...small,
  ];
}
```

## エラーコード

### 初期化エラー

| エラーメッセージ | 原因 | 対処法 |
|------------------|------|--------|
| `Failed to load model: *` | モデルファイルが見つからない | アセット配置とpubspec.yamlを確認 |
| `Failed to load labels: *` | ラベルファイルが見つからない | アセット配置とpubspec.yamlを確認 |

### 認識エラー

| エラーメッセージ | 原因 | 対処法 |
|------------------|------|--------|
| `Recognizer not initialized` | initialize()が呼ばれていない | 認識前にinitialize()を実行 |
| `Image processing failed` | 画像の形式が不正 | 正しいui.Imageオブジェクトを渡す |

## 使用例集

### 基本的な使用パターン

```dart
class RecognitionService {
  static final HiraganaRecognizer _recognizer = HiraganaRecognizer();
  static bool _isInitialized = false;

  static Future<void> initialize() async {
    if (!_isInitialized) {
      await _recognizer.initialize();
      _isInitialized = true;
    }
  }

  static Future<String?> recognizeCharacter(ui.Image image) async {
    if (!_isInitialized) await initialize();
    
    final results = await _recognizer.recognize(image);
    return results.isNotEmpty ? results[0].character : null;
  }

  static void dispose() {
    _recognizer.dispose();
    _isInitialized = false;
  }
}
```

### エラーハンドリング付きの使用

```dart
class SafeRecognitionService {
  final HiraganaRecognizer _recognizer = HiraganaRecognizer();

  Future<RecognitionResult> recognize(ui.Image image) async {
    try {
      final results = await _recognizer.recognize(image);
      
      if (results.isEmpty) {
        return RecognitionResult.noMatch();
      }

      return RecognitionResult.success(results);
    } catch (e) {
      return RecognitionResult.error(e.toString());
    }
  }
}

class RecognitionResult {
  final bool isSuccess;
  final List<Recognition>? results;
  final String? error;

  RecognitionResult._(this.isSuccess, this.results, this.error);

  factory RecognitionResult.success(List<Recognition> results) =>
      RecognitionResult._(true, results, null);

  factory RecognitionResult.noMatch() =>
      RecognitionResult._(false, [], null);

  factory RecognitionResult.error(String error) =>
      RecognitionResult._(false, null, error);
}
```

### 非同期処理の最適化

```dart
class OptimizedRecognitionService {
  final HiraganaRecognizer _recognizer = HiraganaRecognizer();
  final Queue<Completer<List<Recognition>>> _recognitionQueue = Queue();
  bool _isProcessing = false;

  Future<void> initialize() async {
    await _recognizer.initialize();
  }

  Future<List<Recognition>> recognize(ui.Image image) async {
    final completer = Completer<List<Recognition>>();
    _recognitionQueue.add(completer);
    
    _processQueue();
    
    return completer.future;
  }

  Future<void> _processQueue() async {
    if (_isProcessing || _recognitionQueue.isEmpty) return;
    
    _isProcessing = true;
    
    while (_recognitionQueue.isNotEmpty) {
      final completer = _recognitionQueue.removeFirst();
      
      try {
        // 実際の認識処理は省略（実装依存）
        final results = await _recognizer.recognize(/* image */);
        completer.complete(results);
      } catch (e) {
        completer.completeError(e);
      }
    }
    
    _isProcessing = false;
  }
}
```

この API リファレンスを参考に、適切にひらがな認識機能を実装してください。