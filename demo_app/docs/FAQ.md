# よくある質問（FAQ）

ひらがな認識モデルに関するよくある質問と回答をまとめました。

## 一般的な質問

### Q1: どのような文字が認識できますか？

**A:** 基本的なひらがな71文字が認識できます：

- **基本文字** (46文字): あいうえお、かきくけこ、さしすせそ、たちつてと、なにぬねの、はひふへほ、まみむめも、やゆよ、らりるれろ、わをん
- **濁音** (20文字): がぎぐげご、ざじずぜぞ、だぢづでど、ばびぶべぼ
- **半濁音** (5文字): ぱぴぷぺぽ
- **小文字** (9文字): ぁぃぅぇぉ、ゃゅょ、っ

カタカナ、漢字、英数字、記号は認識できません。

### Q2: 認識精度はどの程度ですか？

**A:** 条件によって大きく変わりますが、目安として：

- **綺麗な手書き**: 90-95%
- **一般的な手書き**: 80-90%
- **雑な手書き**: 60-80%
- **非常に雑な手書き**: 50%以下

トップ3候補内での正解率は通常90%以上です。

### Q3: どのような端末で動作しますか？

**A:** Flutter対応の以下の端末で動作します：

- **iOS**: iPhone 6s以降、iPad Air 2以降
- **Android**: Android 5.0 (API 21)以降、RAM 2GB以上推奨
- **Web**: Chrome、Safari、Firefox（最新版推奨）
- **Desktop**: Windows、macOS、Linux

## 技術的な質問

### Q4: モデルサイズが大きいのですが、軽量化できませんか？

**A:** 現在のモデルは4.28MBです。軽量化の選択肢：

1. **量子化モデル**: 精度を少し犠牲にして2-3MBに削減可能
2. **ひらがな専用モデル**: ひらがなのみで学習し直せば1MB以下も可能
3. **オンデマンド読み込み**: 必要な文字セットのみを動的に読み込み

### Q5: 推論速度を向上させる方法は？

**A:** 以下の最適化手法があります：

1. **ハードウェア加速**: 
   ```dart
   // TensorFlow Liteの設定で有効化
   final options = InterpreterOptions()
     ..useNnApiForAndroid = true  // Android
     ..useMetalForIOS = true;     // iOS
   ```

2. **非同期処理**: UIスレッドをブロックしない
3. **事前初期化**: アプリ起動時に初期化
4. **画像サイズ最適化**: 64x64ピクセルで入力

### Q6: メモリ使用量を削減したいです

**A:** メモリ最適化の方法：

```dart
// シングルトンパターンでインスタンス共有
class RecognitionService {
  static final _instance = HiraganaRecognizer();
  static HiraganaRecognizer get instance => _instance;
}

// 適切なリソース解放
@override
void dispose() {
  recognizer.dispose();  // 必須
  super.dispose();
}

// オブジェクトプールの活用
class ImagePool {
  static final _pool = Queue<ui.Image>();
  static ui.Image? acquire() => _pool.isNotEmpty ? _pool.removeFirst() : null;
  static void release(ui.Image image) => _pool.add(image);
}
```

## 実装に関する質問

### Q7: カスタムUIで手書き入力を実装したいです

**A:** `HandwritingCanvas`をカスタマイズするか、独自実装が可能です：

```dart
class CustomCanvas extends StatefulWidget {
  final Function(ui.Image) onImageCapture;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanUpdate: (details) {
        // 描画処理
      },
      child: CustomPaint(
        painter: MyCustomPainter(),
      ),
    );
  }
}
```

### Q8: 認識結果をフィルタリングしたいです

**A:** 認識結果を後処理でフィルタできます：

```dart
Future<List<Recognition>> recognizeFiltered(ui.Image image, Set<String> allowedChars) async {
  final results = await recognizer.recognize(image);
  return results.where((r) => allowedChars.contains(r.character)).toList();
}

// 使用例: あいうえおのみを認識
final results = await recognizeFiltered(image, {'あ', 'い', 'う', 'え', 'お'});
```

### Q9: バッチ処理で複数画像を一度に認識できますか？

**A:** 現在のAPIは単一画像のみですが、非同期でバッチ処理可能です：

```dart
Future<List<List<Recognition>>> recognizeBatch(List<ui.Image> images) async {
  final futures = images.map((image) => recognizer.recognize(image));
  return await Future.wait(futures);
}
```

## 精度向上に関する質問

### Q10: 認識精度を向上させる書き方のコツは？

**A:** 以下のポイントに注意してください：

1. **文字サイズ**: キャンバスの70%程度を使って大きく書く
2. **線の太さ**: 適度な太さ（8-15px推奨）
3. **文字の位置**: 中央に配置
4. **文字の形**: 正しい字形で書く
5. **背景**: 白い背景に黒い線で描画

### Q11: 特定の文字の認識率が低いです

**A:** 文字によって認識の難易度が異なります：

- **認識しやすい文字**: あ、か、た、な、は、ま、ら
- **認識しにくい文字**: い、り、つ、し、ん

認識しにくい文字は特に丁寧に書くか、候補から選択する仕組みを検討してください。

### Q12: 個人の書き癖に対応できますか？

**A:** 現在のモデルは汎用的ですが、個人対応の選択肢：

1. **ファインチューニング**: 個人の文字で追加学習
2. **書き方ガイド**: 正しい書き方を表示
3. **複数候補提示**: トップ3-5候補を表示して選択

## トラブルシューティング

### Q13: アプリがクラッシュします

**A:** 以下を確認してください：

1. **メモリ不足**: 他のアプリを終了して再試行
2. **初期化エラー**: アセットファイルの配置確認
3. **デバイス互換性**: 対応端末・OSバージョン確認

```dart
// エラーハンドリングの実装
try {
  await recognizer.initialize();
} catch (e) {
  print('初期化エラー: $e');
  // フォールバック処理
}
```

### Q14: 認識結果が返ってきません

**A:** チェックポイント：

1. **初期化完了**: `initialize()`が完了しているか
2. **画像の有効性**: 空の画像でないか
3. **文字の有無**: 実際に文字が描画されているか

```dart
// デバッグ用ログの有効化
Future<List<Recognition>> debugRecognize(ui.Image image) async {
  print('認識開始: ${image.width}x${image.height}');
  final results = await recognizer.recognize(image);
  print('認識結果: ${results.length}件');
  return results;
}
```

### Q15: iOSとAndroidで動作が異なります

**A:** プラットフォーム差異の対処：

```dart
// プラットフォーム固有の設定
final options = InterpreterOptions();
if (Platform.isIOS) {
  options.useMetalForIOS = true;
} else if (Platform.isAndroid) {
  options.useNnApiForAndroid = true;
}
```

## ビジネス・法的な質問

### Q16: 商用利用は可能ですか？

**A:** 以下の点を確認してください：

1. **ETLデータベース**: 利用規約の確認が必要
2. **TensorFlow Lite**: Apache License 2.0（商用利用可）
3. **本実装コード**: 適切なライセンス表記

### Q17: モデルを改造・カスタマイズできますか？

**A:** 技術的には可能ですが：

1. **学習データ**: ETL Character Databaseの利用規約に従う
2. **モデル構造**: TensorFlow/Kerasで再学習可能
3. **ライセンス**: 元データの制約に注意

### Q18: サーバーサイドで動作させられますか？

**A:** 可能です：

```python
# Python/TensorFlow Liteでサーバー実装
import tflite_runtime.interpreter as tflite

interpreter = tflite.Interpreter(model_path="etlcb_9b_model.tflite")
interpreter.allocate_tensors()

# 推論実行
input_data = preprocess_image(image)
interpreter.set_tensor(input_details[0]['index'], input_data)
interpreter.invoke()
output_data = interpreter.get_tensor(output_details[0]['index'])
```

## パフォーマンスに関する質問

### Q19: 推論時間を短縮したいです

**A:** 最適化手法：

1. **ハードウェア加速**: GPU/NPU利用
2. **モデル量子化**: INT8量子化で高速化
3. **バッチ処理**: 複数画像を同時処理
4. **事前ウォームアップ**: 初回推論でのオーバーヘッド削減

### Q20: バッテリー消費を抑えたいです

**A:** 省電力化の方法：

1. **推論頻度の調整**: 描画完了後のみ実行
2. **スリープ制御**: 非使用時の適切な停止
3. **CPU使用率の監視**: 高負荷処理の回避

これらの情報で解決しない場合は、具体的な実装状況と共にサポートにお問い合わせください。