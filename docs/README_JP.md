# ImmersalKit

ImmersalのPosePluginやREST APIを使用して､ RealityKitでの空間位置合わせ機能を提供します｡  
visionOS 2.0+向けののSwift Packageです｡

## 前提条件

### visionOS Enterprise API

> [!IMPORTANT]
> このパッケージはカメラ機能にアクセスするため、visionOS Enterprise APIが必要です。
> Enterprise APIを使用するには、Enterpriseライセンスファイルをアプリバンドルに含める必要があります。
> 詳細は[Accessing The Main Camera](https://developer.apple.com/documentation/visionos/accessing-the-main-camera)および[ビジネスアプリ向け空間体験の構築](https://developer.apple.com/documentation/visionOS/building-spatial-experiences-for-business-apps-with-enterprise-apis)を参照してください。

### PosePluginライブラリのセットアップ

このパッケージはImmersal SDKのPosePlugin静的ライブラリが必要です：

1. https://developers.immersal.com からImmersal SDKコアパッケージをダウンロード
2. SDKから `libPosePlugin.a` を取得
3. プロジェクトに配置:
   ```
   YourApp/
   ├── lib/
   │   └── libPosePlugin.a  ← ここにライブラリを配置
   └── YourApp.xcodeproj
   ```
4. Xcodeプロジェクトを設定:
   - ターゲットの「Link Binary With Libraries」ビルドフェーズにライブラリを追加
   - Build Settingsで「Other Linker Flags」に `-lc++` を追加

> [!NOTE]
> ライセンスの関係上、`libPosePlugin.a` ファイルはこのリポジトリに含まれていません。Immersalの開発者ポータルから取得する必要があります。

## 要件

- **プラットフォーム**: visionOS 2.0+
- **Swift**: 5.8+ (Swift Tools 6.0+, Language Mode 5)
- **Xcode**: 16.0+

## インストール方法

### Swift Package Manager

1. Xcodeでプロジェクトを開く
2. **File > Add Package Dependencies...** を選択
3. パッケージURLを入力:
   ```
   https://github.com/gaprot/ImmersalKit.git
   ```
4. バージョンルールを選択して **Add Package** をクリック

### Package.swift

```swift
dependencies: [
    .package(url: "https://github.com/gaprot/ImmersalKit.git", from: "1.0.0")
]
```

## 基本的な使い方

### 1. 初期化

```swift
import ImmersalKit

// PosePluginローカライザー（オンデバイス）を使用
let immersalKit = ImmersalKit(
    localizerType: .posePlugin,
    arSessionManager: ARSessionManager()
)

// RESTローカライザーを使用
let immersalKit = ImmersalKit(
    localizerType: .restApi,
    arSessionManager: ARSessionManager(),
    tokenProvider: BundleTokenProvider()  // Info.plistからトークンを読み込み
)

```

### 2. Reality Composer Proでのマップ設定

#### RCP用のImmersalMapComponent準備

Reality Composer ProでImmersalMapComponentを使用するには、テンプレートファイルをコピーする必要があります：

1. 以下のファイルをRealityKitContentプロジェクトにコピー：
   - `Sources/ImmersalKit/RealityKitContentTemplates/ImmersalMapComponent.swift` → `YourApp/Packages/RealityKitContent/Sources/RealityKitContent/`
   - `Sources/ImmersalKit/RealityKitContentTemplates/Entity+Extensions.swift` → `YourApp/Packages/RealityKitContent/Sources/RealityKitContent/`
2. コピーしたファイルのコメントアウトを解除

#### Reality Composer Proでのシーン作成

1. Reality Composer Proでシーンを開く
2. マップを配置したいEntityを選択
3. InspectorでAdd Component → ImmersalMapComponentを追加
4. Map IDを入力（例：127558）
5. ARコンテンツをImmersalMapComponent entityの子として配置 - ローカライズ時に自動的に正しい位置に配置されます

#### マップの登録と読み込み

```swift
// RCPシーンに存在するマップを登録
if let scene = try? await Entity(named: "Scene", in: realityKitContentBundle) {
    content.add(scene)

    // すべてのImmersalMapComponentを探して登録
    scene.forEachDescendant(withComponent: ImmersalMapComponent.self) { entity, component in
        immersalKit.mapManager.registerMap(mapEntity: entity, mapId: component.mapId)
    }
}

// マップデータを読み込む - マップファイルは{mapId}-*.bytesとしてアプリバンドルに含める
immersalKit.mapManager.loadMap(mapId: 127558)
```

> [!NOTE]
> ImmersalKitは位置変換を自動的に処理しますが、表示制御はアプリの責務です。ローカライズが成功するまでマップを非表示にすることを推奨します。

### 3. マップリソース

マップファイルは以下の形式でアプリバンドルに含める必要があります：

- ファイル形式: `{mapId}-{名前}.bytes`
- 例: `127558-RoomL.bytes`

マップファイルは[Immersal Developer Portal](https://developers.immersal.com)からダウンロードしてください。

### 4. ローカライゼーションの開始/停止

```swift
// ローカライゼーション開始
Task {
    do {
        try await immersalKit.startLocalizing()
    } catch {
        print("ローカライゼーション開始エラー: \(error)")
    }
}

// ローカライゼーション停止
Task {
    await immersalKit.stopLocalizing()
}
```

### 5. 状態の監視

```swift
// SwiftUIでの使用例
struct ContentView: View {
    @State private var immersalKit: ImmersalKit

    var body: some View {
        VStack {
            Text("ローカライゼーション中: \(immersalKit.isLocalizing ? "はい" : "いいえ")")

            if let result = immersalKit.lastResult {
                Text("信頼度: \(result.confidence)")
                Text("位置: \(result.position)")
            }
        }
    }
}
```

## 設定オプション

### LocalizerType

- `.posePlugin`: オフラインローカライゼーション（デバイス上で処理）
- `.restApi`: オンラインローカライゼーション（クラウド処理）

### トークン管理

REST APIを使用する場合、開発者トークンが必要です：

```swift
// Info.plistから読み込み
// Info.plistに "ImmersalToken" キーでトークンを設定
let tokenProvider = BundleTokenProvider()

// 静的トークン
let tokenProvider = StaticTokenProvider(token: "your-token-here")

// Keychainを使用
let tokenProvider = SecureTokenProvider()
tokenProvider.setToken("your-token-here")
```

### 信頼度ベースの位置合わせ制御

位置合わせの精度を制御できます：

```swift
// デフォルト設定
let config = ConfidenceBasedAlignmentConfiguration()

// カスタム設定
let config = ConfidenceBasedAlignmentConfiguration(
    minimumConfidenceDelta: -2.0,      // 直近信頼度差分閾値
    absoluteMinimumConfidence: 15.0,   // 絶対最小信頼度
    maxHistorySize: 5                  // 履歴保持数
)
```

## サンプルコード

### 実装例

```swift
import SwiftUI
import ImmersalKit
import RealityKit

@main
struct MyARApp: App {
    @State private var immersalKit: ImmersalKit

    init() {
        immersalKit = ImmersalKit(
            localizerType: .posePlugin,
            arSessionManager: ARSessionManager()
        )
        
        // 初期マップを読み込む
        _ = immersalKit.mapManager.loadMap(mapId: 121385)
    }

    var body: some Scene {
        WindowGroup {
            ContentView(immersalKit: immersalKit)
        }

        ImmersiveSpace(id: "ARSpace") {
            ARView(immersalKit: immersalKit)
        }
    }
}

struct ContentView: View {
    let immersalKit: ImmersalKit
    @State private var isLocalizing = false

    var body: some View {
        VStack {
            Button(isLocalizing ? "停止" : "開始") {
                Task {
                    if isLocalizing {
                        await immersalKit.stopLocalizing()
                    } else {
                        try? await immersalKit.startLocalizing()
                    }
                    isLocalizing = immersalKit.isLocalizing
                }
            }

            if let result = immersalKit.lastResult {
                Text("信頼度: \(result.confidence, specifier: "%.1f")")
            }
        }
    }
}
```

## PosePluginLocalizer vs RestApiLocalizer

### PosePluginLocalizer

- **メリット**:
  - オフライン動作（インターネット接続不要）
  - 低レイテンシ
  - 実際の信頼度スコアを提供し、信頼度ベース位置合わせが正確に動作
- **デメリット**:
  - マップデータをアプリに含める必要がある
  - アプリサイズが増加

### RestApiLocalizer

- **メリット**:
  - ローカライゼーションにマップファイル不要（マップIDのみ必要）
  - アプリサイズが大幅に削減
- **デメリット**:
  - インターネット接続が必要
  - APIレイテンシ
  - トークン管理が必要
  - **固定信頼度値（100.0）** - REST APIは信頼度情報を提供しないため、信頼度ベース位置合わせ機能が制限される

## トラブルシューティング

### マップが読み込まれない

- マップファイル（`.bytes`）がアプリバンドルに含まれているか確認
- ファイル名が `{mapId}-*.bytes` の形式になっているか確認

### ローカライゼーションが機能しない

- カメラアクセス権限が許可されているか確認(Enterprise APIが必要)
- マップが正しく読み込まれているか確認

### 信頼度が低い

- より特徴的な環境でマップを作成
- 信頼度制御設定を調整（`ConfidenceBasedAlignmentConfiguration`）

### PosePluginの問題

- `libPosePlugin.a` が正しい場所にあるか確認
- ライブラリがターゲットのビルドフェーズに追加されているか確認

## 既知の問題

### 座標変換時の高さオフセット

座標変換後に約25cmの高さのズレが発生します。現在、パッケージ内でハードコーディングによる補正を行っています。

## ライセンス

このプロジェクトはMITライセンスで公開されています - 詳細は[LICENSE](../LICENSE)ファイルを参照してください。

このソフトウェアには[Immersal SDK iOS Samples](https://github.com/immersal/immersal-sdk-ios-samples)（MITライセンス）のコードが含まれています。

## サポート

技術的な質問や問題については、[GitHubのIssue](https://github.com/gaprot/ImmersalKit/issues)でお問い合わせください。
