# パフォーマンスガイド

ひらがな認識モデルのパフォーマンス特性と最適化方法について説明します。

## パフォーマンス指標

### メモリ使用量

| コンポーネント | サイズ | 説明 |
|---------------|--------|------|
| モデルファイル | 4.28MB | TensorFlow Liteモデル |
| ラベルファイル | ~10KB | 文字ラベルリスト |
| 推論時メモリ | 10-15MB | 推論実行時の一時メモリ |
| 画像バッファ | ~16KB | 64x64x1のfloat32配列 |

### 推論速度（参考値）

| デバイス | 初期化時間 | 推論時間 | 備考 |
|----------|------------|----------|------|
| iPhone 14 Pro | 100-150ms | 30-50ms | A16 Bionic |
| iPhone 12 | 150-200ms | 50-80ms | A14 Bionic |
| iPad Air (5th) | 120-180ms | 40-70ms | M1チップ |
| Galaxy S23 | 200-300ms | 80-120ms | Snapdragon 8 Gen 2 |
| Pixel 7 | 180-250ms | 70-100ms | Google Tensor G2 |
| 中級Android | 300-500ms | 150-300ms | Snapdragon 7xx系 |
| エントリーAndroid | 500-1000ms | 300-600ms | Snapdragon 6xx系以下 |

## 最適化戦略

### 1. 初期化の最適化

#### シングルトンパターン

```dart
class HiraganaRecognitionService {
  static HiraganaRecognitionService? _instance;
  static final HiraganaRecognizer _recognizer = HiraganaRecognizer();
  static bool _isInitialized = false;

  static HiraganaRecognitionService get instance {
    _instance ??= HiraganaRecognitionService._();
    return _instance!;
  }

  HiraganaRecognitionService._();

  Future<void> initialize() async {
    if (_isInitialized) return;
    
    await _recognizer.initialize();
    _isInitialized = true;
  }

  Future<List<Recognition>> recognize(ui.Image image) async {
    if (!_isInitialized) {
      throw StateError('Service not initialized. Call initialize() first.');
    }
    return await _recognizer.recognize(image);
  }

  void dispose() {
    _recognizer.dispose();
    _isInitialized = false;
    _instance = null;
  }
}
```

#### アプリ起動時の事前初期化

```dart
class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    _preloadServices();
  }

  Future<void> _preloadServices() async {
    // バックグラウンドで事前初期化
    HiraganaRecognitionService.instance.initialize();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: SplashScreen(), // 初期化中はスプラッシュ画面
    );
  }
}
```

### 2. 推論の最適化

#### 非同期処理とキューイング

```dart
class OptimizedRecognizer {
  final HiraganaRecognizer _recognizer = HiraganaRecognizer();
  final StreamController<RecognitionTask> _taskController = StreamController();
  
  late StreamSubscription _subscription;

  Future<void> initialize() async {
    await _recognizer.initialize();
    
    // 専用のIsolateで推論処理を実行
    _subscription = _taskController.stream.listen(_processTask);
  }

  Future<List<Recognition>> recognize(ui.Image image) async {
    final completer = Completer<List<Recognition>>();
    final task = RecognitionTask(image, completer);
    
    _taskController.add(task);
    
    return completer.future;
  }

  void _processTask(RecognitionTask task) async {
    try {
      final results = await _recognizer.recognize(task.image);
      task.completer.complete(results);
    } catch (e) {
      task.completer.completeError(e);
    }
  }

  void dispose() {
    _subscription.cancel();
    _taskController.close();
    _recognizer.dispose();
  }
}

class RecognitionTask {
  final ui.Image image;
  final Completer<List<Recognition>> completer;

  RecognitionTask(this.image, this.completer);
}
```

#### 画像前処理の最適化

```dart
class OptimizedImageProcessor {
  // 事前にByteBufferを確保してGCを削減
  static final ByteBuffer _reusableBuffer = 
      Uint8List(64 * 64 * 4).buffer;

  static List<List<List<List<double>>>> preprocessImage(ui.Image image) {
    // キャッシュされたバッファを再利用
    final buffer = _reusableBuffer.asUint8List();
    
    // 最適化された前処理ロジック
    // ...
    
    return processedData;
  }
}
```

### 3. メモリ管理の最適化

#### オブジェクトプーリング

```dart
class ImagePool {
  static final Queue<ui.Image> _pool = Queue();
  static const int maxPoolSize = 5;

  static ui.Image? acquire() {
    return _pool.isNotEmpty ? _pool.removeFirst() : null;
  }

  static void release(ui.Image image) {
    if (_pool.length < maxPoolSize) {
      _pool.add(image);
    }
  }

  static void clear() {
    _pool.clear();
  }
}
```

#### WeakReference の活用

```dart
class RecognitionCache {
  static final Map<String, WeakReference<List<Recognition>>> _cache = {};

  static List<Recognition>? get(String imageHash) {
    final weakRef = _cache[imageHash];
    return weakRef?.target;
  }

  static void put(String imageHash, List<Recognition> results) {
    _cache[imageHash] = WeakReference(results);
    
    // 古いエントリを定期的にクリーンアップ
    if (_cache.length > 100) {
      _cleanupCache();
    }
  }

  static void _cleanupCache() {
    _cache.removeWhere((key, weakRef) => weakRef.target == null);
  }
}
```

### 4. UI最適化

#### フレームレート維持

```dart
class PerformantCanvas extends StatefulWidget {
  @override
  _PerformantCanvasState createState() => _PerformantCanvasState();
}

class _PerformantCanvasState extends State<PerformantCanvas>
    with TickerProviderStateMixin {
  
  Timer? _recognitionTimer;

  void _onStrokeEnd() {
    // デバウンス: 描画終了から500ms後に認識実行
    _recognitionTimer?.cancel();
    _recognitionTimer = Timer(Duration(milliseconds: 500), () {
      _performRecognition();
    });
  }

  void _performRecognition() async {
    // 重い処理はcompute()で別スレッドで実行
    final results = await compute(_recognizeImage, canvasImage);
    
    if (mounted) {
      setState(() {
        _results = results;
      });
    }
  }

  static Future<List<Recognition>> _recognizeImage(ui.Image image) async {
    // 認識処理（isolateで実行）
    return HiraganaRecognitionService.instance.recognize(image);
  }
}
```

#### レイジーローディング

```dart
class LazyRecognitionWidget extends StatefulWidget {
  @override
  _LazyRecognitionWidgetState createState() => _LazyRecognitionWidgetState();
}

class _LazyRecognitionWidgetState extends State<LazyRecognitionWidget> {
  HiraganaRecognitionService? _service;
  bool _isLoading = false;

  Future<void> _ensureServiceLoaded() async {
    if (_service != null) return;
    
    setState(() {
      _isLoading = true;
    });

    _service = HiraganaRecognitionService.instance;
    await _service!.initialize();

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return _isLoading 
        ? CircularProgressIndicator()
        : RecognitionCanvas(service: _service);
  }
}
```

## ベンチマークとプロファイリング

### パフォーマンス測定

```dart
class PerformanceBenchmark {
  static Future<BenchmarkResult> runBenchmark() async {
    final recognizer = HiraganaRecognizer();
    
    // 初期化時間測定
    final initStopwatch = Stopwatch()..start();
    await recognizer.initialize();
    initStopwatch.stop();

    // 推論時間測定（10回の平均）
    final inferenceStopwatch = Stopwatch();
    final inferenceTimes = <int>[];

    for (int i = 0; i < 10; i++) {
      inferenceStopwatch.reset();
      inferenceStopwatch.start();
      
      await recognizer.recognize(testImage);
      
      inferenceStopwatch.stop();
      inferenceTimes.add(inferenceStopwatch.elapsedMilliseconds);
    }

    recognizer.dispose();

    return BenchmarkResult(
      initTime: initStopwatch.elapsedMilliseconds,
      avgInferenceTime: inferenceTimes.reduce((a, b) => a + b) / inferenceTimes.length,
      minInferenceTime: inferenceTimes.reduce(math.min),
      maxInferenceTime: inferenceTimes.reduce(math.max),
    );
  }
}

class BenchmarkResult {
  final int initTime;
  final double avgInferenceTime;
  final int minInferenceTime;
  final int maxInferenceTime;

  BenchmarkResult({
    required this.initTime,
    required this.avgInferenceTime,
    required this.minInferenceTime,
    required this.maxInferenceTime,
  });

  @override
  String toString() {
    return '''
初期化時間: ${initTime}ms
平均推論時間: ${avgInferenceTime.toStringAsFixed(1)}ms
最短推論時間: ${minInferenceTime}ms
最長推論時間: ${maxInferenceTime}ms
    ''';
  }
}
```

### メモリ使用量監視

```dart
class MemoryMonitor {
  static void startMonitoring() {
    Timer.periodic(Duration(seconds: 5), (timer) {
      _logMemoryUsage();
    });
  }

  static void _logMemoryUsage() {
    final info = ProcessInfo.currentRss;
    print('現在のメモリ使用量: ${(info / 1024 / 1024).toStringAsFixed(1)}MB');
  }
}
```

## パフォーマンスチューニングのベストプラクティス

### 1. 初期化タイミング

- **推奨**: アプリ起動時に非同期で初期化
- **避ける**: 認識が必要になってから初期化

### 2. リソース管理

- **推奨**: シングルトンパターンでインスタンス共有
- **避ける**: 複数のRecognizerインスタンス作成

### 3. UI応答性

- **推奨**: 推論処理を非同期で実行
- **避ける**: UIスレッドでブロッキング処理

### 4. メモリ使用量

- **推奨**: 適切なdispose()呼び出し
- **避ける**: メモリリークの放置

### 5. バッテリー消費

- **推奨**: 必要時のみ認識実行
- **避ける**: 連続的な認識処理

## トラブルシューティング

### 性能が出ない場合

1. **リリースビルドで測定**: デバッグビルドは大幅に遅い
2. **デバイス性能確認**: 低スペック端末では性能低下は正常
3. **他の重い処理確認**: 同時実行している処理をチェック
4. **メモリ不足確認**: 他のアプリを終了して再測定

### メモリリークの特定

```dart
// 開発時のみ有効にする
class MemoryLeakDetector {
  static final Set<HiraganaRecognizer> _instances = {};

  static void register(HiraganaRecognizer instance) {
    _instances.add(instance);
    print('認識器インスタンス作成。総数: ${_instances.length}');
  }

  static void unregister(HiraganaRecognizer instance) {
    _instances.remove(instance);
    print('認識器インスタンス破棄。総数: ${_instances.length}');
  }

  static void checkForLeaks() {
    if (_instances.isNotEmpty) {
      print('警告: ${_instances.length}個の認識器インスタンスが残っています');
    }
  }
}
```

このガイドを参考に、アプリケーションのパフォーマンス要件に合わせて最適化を行ってください。