# ImmersalKit

[JP](docs/README_JP.md)

Provides spatial alignment functionality in RealityKit using Immersal's PosePlugin and REST API.
A Swift Package for visionOS 2.0+.

## Prerequisites

### visionOS Enterprise API

> ⚠️ **Important**: This package requires visionOS Enterprise API access for camera functionality.
> You must include an Enterprise license file in your app bundle to use Enterprise APIs.
> See [Apple's documentation](https://developer.apple.com/documentation/visionos/accessing-the-main-camera) and [Building spatial experiences for business apps](https://developer.apple.com/documentation/visionOS/building-spatial-experiences-for-business-apps-with-enterprise-apis) for details.

### PosePlugin Library Setup

This package requires the PosePlugin static library from Immersal SDK:

1. Download the Immersal SDK core package from https://developers.immersal.com
2. Extract `libPosePlugin.a` from the SDK
3. Place it in your project:
   ```
   YourApp/
   ├── lib/
   │   └── libPosePlugin.a  ← Place the library here
   └── YourApp.xcodeproj
   ```
4. Configure your Xcode project:
   - Add the library to your target's "Link Binary With Libraries" build phase
   - In Build Settings, add `-lc++` to "Other Linker Flags"

> **Note**: The `libPosePlugin.a` file is not included in this repository due to licensing. You must obtain it from Immersal's developer portal.

## Requirements

- **Platform**: visionOS 2.0+
- **Swift**: 5.8+ (Swift Tools 6.0+, Language Mode 5)
- **Xcode**: 16.0+

## Installation

### Swift Package Manager

1. Open your project in Xcode
2. Select **File > Add Package Dependencies...**
3. Enter the package URL:
   ```
   https://github.com/gaprot/ImmersalKit.git
   ```
4. Choose version rules and click **Add Package**

### Package.swift

```swift
dependencies: [
    .package(url: "https://github.com/gaprot/ImmersalKit.git", from: "1.0.0")
]
```

## Basic Usage

### 1. Initialization

```swift
import ImmersalKit

// Using PosePlugin localizer (on-device)
let immersalKit = ImmersalKit(
    localizerType: .posePlugin,
    arSessionManager: ARSessionManager()
)

// Using REST API localizer (cloud)
let immersalKit = ImmersalKit(
    localizerType: .restApi,
    arSessionManager: ARSessionManager(),
    tokenProvider: BundleTokenProvider()  // Load token from Info.plist
)
```

### 2. Setting up Maps with Reality Composer Pro

#### Preparing ImmersalMapComponent for RCP

To use ImmersalMapComponent in Reality Composer Pro, you need to copy template files:

1. Copy these files to your RealityKitContent project:
   - `Sources/ImmersalKit/RealityKitContentTemplates/ImmersalMapComponent.swift` → `YourApp/Packages/RealityKitContent/Sources/RealityKitContent/`
   - `Sources/ImmersalKit/RealityKitContentTemplates/Entity+Extensions.swift` → `YourApp/Packages/RealityKitContent/Sources/RealityKitContent/`
2. Uncomment the code in the copied files

#### Creating Scene in Reality Composer Pro

1. Open your scene in Reality Composer Pro
2. Select the Entity where you want to place your map
3. In Inspector, click Add Component → ImmersalMapComponent
4. Enter the Map ID (e.g., 127558)
5. Place your AR content as children of the ImmersalMapComponent entity - they will automatically be positioned correctly when localized

#### Map Registration and Loading

```swift
// Register maps existing in RCP scene
if let scene = try? await Entity(named: "Scene", in: realityKitContentBundle) {
    content.add(scene)

    // Find and register all ImmersalMapComponents
    scene.forEachDescendant(withComponent: ImmersalMapComponent.self) { entity, component in
        immersalKit.mapManager.registerMap(mapEntity: entity, mapId: component.mapId)
    }
}

// Load map data - map files must be in app bundle as {mapId}-*.bytes
immersalKit.mapManager.loadMap(mapId: 127558)
```

**Note**: ImmersalKit automatically handles position transformation, but visibility control is the app's responsibility. You may want to hide maps until localization succeeds.

### 3. Map Resources

Map files must be included in your app bundle with the naming format:

- File format: `{mapId}-{name}.bytes`
- Example: `127558-RoomL.bytes`

Download map files from [Immersal Developer Portal](https://developers.immersal.com).

### 4. Start/Stop Localization

```swift
// Start localization
Task {
    do {
        try await immersalKit.startLocalizing()
    } catch {
        print("Localization start error: \(error)")
    }
}

// Stop localization
Task {
    await immersalKit.stopLocalizing()
}
```

### 5. Monitoring State

```swift
// SwiftUI usage example
struct ContentView: View {
    @State private var immersalKit: ImmersalKit

    var body: some View {
        VStack {
            Text("Localizing: \(immersalKit.isLocalizing ? "Yes" : "No")")

            if let result = immersalKit.lastResult {
                Text("Confidence: \(result.confidence)")
                Text("Position: \(result.position)")
            }
        }
    }
}
```

## Configuration Options

### LocalizerType

- `.posePlugin`: Offline localization (on-device processing)
- `.restApi`: Online localization (cloud processing)

### Token Management

Developer token is required when using REST API:

```swift
// Load from Info.plist
// Set token with "ImmersalToken" key in Info.plist
let tokenProvider = BundleTokenProvider()

// Static token
let tokenProvider = StaticTokenProvider(token: "your-token-here")

// Using Keychain
let tokenProvider = SecureTokenProvider()
tokenProvider.setToken("your-token-here")
```

### Confidence-Based Alignment Control

Control alignment precision:

```swift
// Default configuration
let config = ConfidenceBasedAlignmentConfiguration()

// Custom configuration
let config = ConfidenceBasedAlignmentConfiguration(
    minimumConfidenceDelta: -2.0,      // Recent confidence delta threshold
    absoluteMinimumConfidence: 15.0,   // Absolute minimum confidence
    maxHistorySize: 5                  // History size
)
```

## Error Handling

ImmersalKit provides comprehensive error handling:

```swift
do {
    try await immersalKit.startLocalizing()
} catch ImmersalKitError.session(.permissionDenied) {
    // Camera access permission error
    print("Please allow camera access")
} catch ImmersalKitError.configuration(.missingRequiredConfiguration(let param)) {
    // Configuration error
    print("Missing required configuration: \(param)")
} catch ImmersalKitError.mapManagement(.mapNotFound(let mapId)) {
    // Map not found
    print("Map \(mapId) not found")
} catch {
    // Other errors
    print("Error: \(error.localizedDescription)")
}
```

## Sample Code

### Implementation Example

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
        
        // Load initial maps
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
            Button(isLocalizing ? "Stop" : "Start") {
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
                Text("Confidence: \(result.confidence, specifier: "%.1f")")
            }
        }
    }
}
```

## Breaking Changes in v2.0

If you're upgrading from an earlier version, please note these important API changes:

- **Removed APIs**:

  - `setSelectedMapIds()` - Maps are now automatically selected when loaded
  - `setInitialMapIds()` in Builder - Load maps directly using `mapManager.loadMap()`
  - `setMapIds()` - Use `mapManager.loadMap()` instead

- **New behavior**:
  - `loadMap()` now automatically makes the map available for localization
  - No need to separately select maps after loading

## PosePluginLocalizer vs RestApiLocalizer

### PosePluginLocalizer

- **Pros**:
  - Offline operation (no internet required)
  - Low latency
  - Provides actual confidence scores for accurate confidence-based alignment
- **Cons**:
  - Map data must be included in app
  - Increased app size

### RestApiLocalizer

- **Pros**:
  - No map files required for localization (only map IDs needed)
  - Significantly smaller app size
- **Cons**:
  - Internet connection required
  - API latency
  - Token management required
  - **Fixed confidence value (100.0)** - REST API does not provide confidence information, limiting confidence-based alignment functionality

## Troubleshooting

### Maps not loading

- Verify map files (`.bytes`) are included in app bundle
- Check file naming follows `{mapId}-*.bytes` format (e.g., `121385-mapname.bytes`)
- Ensure maps are registered before loading
- Confirm `loadMap()` is called for each map you want to use

### Localization not working

- Verify camera access permission is granted (Enterprise API required)
- Ensure maps are loaded correctly

### Low confidence

- Create maps in more distinctive environments
- Adjust confidence control settings (`ConfidenceBasedAlignmentConfiguration`)

### PosePlugin Issues

- Verify `libPosePlugin.a` is in the correct location
- Check that the library is added to your target's build phases

## Demo App

A complete sample application is included in the `Demo/` folder:

1. Open `Demo/Demo.xcodeproj` in Xcode
2. Select visionOS simulator or device
3. Build and run

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

This software includes code from [Immersal SDK iOS Samples](https://github.com/immersal/immersal-sdk-ios-samples) (MIT License).

## Support

For technical questions or issues, please contact us through [GitHub Issues](https://github.com/gaprot/ImmersalKit/issues).
