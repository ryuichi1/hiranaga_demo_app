# ひらがな認識モデル統合ガイド

このドキュメントは、ETLCBデータベースで学習されたTensorFlow Liteモデルを使用して、ひらがな文字認識機能をFlutterアプリに統合する方法を説明します。

## 概要

- **モデル**: ETL Character Database (ETLCB) 9Bで学習されたTensorFlow Liteモデル
- **認識対象**: ひらがな文字（71文字）
- **入力**: 手書き文字の画像（64x64ピクセル、グレースケール）
- **出力**: 認識結果と確信度

## セットアップ

### 1. 依存パッケージの追加

`pubspec.yaml`に以下を追加：

```yaml
dependencies:
  tflite_flutter: ^0.11.0
  image: ^4.1.7

assets:
  - assets/etlcb_9b_model.tflite
  - assets/etlcb_9b_labels.txt
```

### 2. アセットファイルの配置

以下のファイルを`assets/`ディレクトリに配置：

- `etlcb_9b_model.tflite` (4.28MB) - 認識モデル
- `etlcb_9b_labels.txt` - ラベルファイル（3036文字のリスト）

## 基本的な使用方法

### 1. 認識器クラスのインポート

```dart
import 'package:your_app/models/hiragana_recognizer.dart';
```

### 2. 認識器の初期化

```dart
final HiraganaRecognizer recognizer = HiraganaRecognizer();

// 非同期で初期化
await recognizer.initialize();
```

### 3. 手書き文字の認識

```dart
// ui.Imageオブジェクトから認識
List<Recognition> results = await recognizer.recognize(image);

// 結果の取得
if (results.isNotEmpty) {
  final topResult = results[0];
  print('認識文字: ${topResult.character}');
  print('確信度: ${(topResult.confidence * 100).toStringAsFixed(1)}%');
}
```

### 4. リソースの解放

```dart
// アプリ終了時やウィジェット破棄時
recognizer.dispose();
```

## APIリファレンス

### HiraganaRecognizer クラス

#### メソッド

**`Future<void> initialize()`**
- モデルとラベルファイルを読み込みます
- アプリ起動時に一度だけ呼び出してください

**`Future<List<Recognition>> recognize(ui.Image image)`**
- 手書き文字を認識します
- **パラメータ**: `ui.Image image` - 認識対象の画像
- **戻り値**: `List<Recognition>` - 認識結果のリスト（確信度順）

**`void dispose()`**
- モデルリソースを解放します
- メモリリークを防ぐため必ず呼び出してください

### Recognition クラス

```dart
class Recognition {
  final String character;  // 認識された文字
  final double confidence; // 確信度（0.0〜1.0）
}
```

## 手書きキャンバスの実装

### HandwritingCanvas ウィジェット

```dart
HandwritingCanvas(
  onImageReady: (ui.Image image) async {
    final results = await recognizer.recognize(image);
    // 認識結果を処理
  },
)
```

## パフォーマンス考慮事項

### メモリ使用量
- モデルサイズ: 約4.28MB
- 推論時メモリ: 約10-15MB
- 初期化時間: 100-300ms（デバイス依存）

### 推論速度
- iPhone/iPad: 50-100ms
- Android中級機: 100-200ms
- Android低スペック機: 200-500ms

### 最適化のヒント

1. **非同期処理**: UI をブロックしないよう`await`を使用
2. **一度だけ初期化**: アプリ起動時にrecognizerを初期化し、使い回す
3. **適切なリソース管理**: `dispose()`を忘れずに呼び出す

## 画像前処理の詳細

### 入力要件
- **サイズ**: 64x64ピクセル
- **形式**: グレースケール
- **値の範囲**: 0.0〜1.0（正規化済み）
- **背景**: 白い背景に黒い文字（内部で反転処理）

### 自動前処理
`HiraganaRecognizer`は以下の前処理を自動で実行：

1. **リサイズ**: 入力画像を64x64に変換
2. **グレースケール変換**: RGBからグレースケールに変換
3. **正規化**: ピクセル値を0.0〜1.0に正規化
4. **色反転**: 白背景→黒背景、黒文字→白文字に変換

## エラーハンドリング

### 一般的なエラーと対処法

```dart
try {
  await recognizer.initialize();
} catch (e) {
  if (e.toString().contains('Failed to load model')) {
    // モデルファイルが見つからない
    print('assets/etlcb_9b_model.tfliteを確認してください');
  } else if (e.toString().contains('Failed to load labels')) {
    // ラベルファイルが見つからない
    print('assets/etlcb_9b_labels.txtを確認してください');
  }
}

try {
  final results = await recognizer.recognize(image);
} catch (e) {
  if (e.toString().contains('Recognizer not initialized')) {
    // 初期化されていない
    await recognizer.initialize();
  }
}
```

## トラブルシューティング

### よくある問題

**Q: 認識精度が低い**
- 文字を大きく、はっきりと書く
- 背景は白、文字は黒で描画する
- 線の太さを適切に設定（推奨12px）

**Q: 初期化に失敗する**
- アセットファイルのパスを確認
- `pubspec.yaml`のassets設定を確認
- ファイルサイズを確認（model: 4.28MB, labels: 数KB）

**Q: メモリエラーが発生する**
- `dispose()`を適切に呼び出す
- 複数のrecognizerインスタンスを作らない
- 大きな画像を直接渡さない

**Q: 推論が遅い**
- デバイスのスペックを確認
- 他の重い処理と同時実行を避ける
- デバッグモードではなくリリースモードで測定

## ライセンスと利用規約

### ETLデータベース
- ETL Character Databaseの利用規約に従ってください
- 商用利用時は適切なライセンス確認が必要

### TensorFlow Lite
- Apache License 2.0に従ってください

## サポート

### 認識可能文字
基本ひらがな71文字（濁音・半濁音・小文字含む）:
あいうえお、かきくけこ、さしすせそ、たちつてと、なにぬねの、はひふへほ、まみむめも、やゆよ、らりるれろ、わをん、がぎぐげご、ざじずぜぞ、だぢづでど、ばびぶべぼ、ぱぴぷぺぽ、ぁぃぅぇぉ、ゃゅょ、っ

### 認識対象外
- カタカナ
- 漢字
- 英数字
- 記号

詳細な実装例は`lib/`ディレクトリ内のコードを参照してください。