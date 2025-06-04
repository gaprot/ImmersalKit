import ImmersalKit
import RealityKit
import SwiftUI

/// Immersal map and localization control panel
public struct ImmersalControlPanel: View {
  // MARK: - Properties

  private let immersalKit: ImmersalKit
  @Binding private var isImmersiveActive: Bool
  @State private var selectedMapIds: Set<Int> = []
  @State private var statusMessage = "Ready"
  @State private var restMaps: [Job] = []
  @State private var isLoadingMaps = false
  @State private var developerToken = ""
  @State private var isTokenLoading = false

  /// Initialize
  /// - Parameters:
  ///   - immersalKit: ImmersalKit instance
  ///   - isImmersiveActive: Binding for immersive space active state
  public init(
    immersalKit: ImmersalKit,
    isImmersiveActive: Binding<Bool>
  ) {
    self.immersalKit = immersalKit
    self._isImmersiveActive = isImmersiveActive
    _developerToken = State(initialValue: immersalKit.client.tokenProvider.token ?? "")
  }

  public var body: some View {
    VStack(spacing: 20) {
      TitleSection()

      StatusMessageView(message: statusMessage)

      LocalizerTypePicker(immersalKit: immersalKit)
        .onChange(of: immersalKit.localizerType) { _, newValue in
          // Do not switch during localization
          guard !immersalKit.isLocalizing else { return }

          // Unload loaded maps
          for mapId in Array(immersalKit.mapManager.loadedMaps.keys) {
            _ = immersalKit.mapManager.unloadMap(mapId: mapId)
          }

          // Clear map selection
          selectedMapIds.removeAll()

          Task {
            async let t1: () = immersalKit.switchLocalizer(to: newValue)
            async let t2: () = fetchMaps()
            _ = await (t1, t2)
          }
        }

      // Show token field only for REST API
      if immersalKit.localizerType == .restApi {
        TokenField(
          token: $developerToken,
          isLoading: isTokenLoading
        ) {
          validateToken()
        }
      }

      LocalizerStatusSection(immersalKit: immersalKit)

      MapSelectionSection(
        immersalKit: immersalKit,
        isLoadingMaps: isLoadingMaps,
        availableMaps: restMaps,
        selectedMapIds: $selectedMapIds,
        onRefresh: {
          Task {
            await fetchMaps()
          }
        },
        onSelectMap: selectMap
      )

      ControlButtonsSection(
        immersalKit: immersalKit,
        isImmersiveActive: isImmersiveActive,
        selectedMapIds: selectedMapIds,
        onLoadMaps: loadSelectedMaps,
        onStartLocalizing: startLocalizing,
        onStopLocalizing: stopLocalizing,
        onReset: resetAll,
        isMapLoaded: isMapLoaded()
      )

      Spacer()
    }
    .padding()
    .animation(.easeInOut, value: immersalKit.localizerType)
    .animation(.easeInOut, value: isImmersiveActive)
  }

  // MARK: - Methods

  private func fetchMaps() async {
    guard immersalKit.localizerType == .restApi else { return }

    isLoadingMaps = true
    defer {
      isLoadingMaps = false
    }

    do {
      restMaps = try await immersalKit.client.listMaps()
    } catch {
      restMaps = []
      statusMessage = "Failed to load maps: \(error.localizedDescription)"
    }
  }

  private func selectMap(mapId: MapId) {
    // Deselect if already selected
    if selectedMapIds.contains(mapId) {
      selectedMapIds.remove(mapId)

      // Unload map if already loaded
      if immersalKit.mapManager.loadedMaps.keys.contains(mapId) {
        _ = immersalKit.mapManager.unloadMap(mapId: mapId)
      }
    } else {
      selectedMapIds.insert(mapId)
      statusMessage = "Map ID \(mapId) selected (selected: \(selectedMapIds.count))"
    }

  }

  private func loadSelectedMaps() {
    guard !selectedMapIds.isEmpty else { return }

    // For REST API, skip actual map loading as it's not required
    if immersalKit.localizerType == .restApi {
      statusMessage = "REST API: Ready with \(selectedMapIds.count) map(s) selected"
      return
    }

    var successCount = 0
    var failureCount = 0

    // Load all selected maps (loaded maps are automatically used for localization)
    for mapId in selectedMapIds {
      let success = immersalKit.mapManager.loadMap(mapId: mapId)

      switch success {
      case .success:
        successCount += 1
      case .failure(let err):
        failureCount += 1
      }
    }

    if failureCount == 0 {
      statusMessage = "Loaded all \(successCount) selected maps"
    } else if successCount == 0 {
      statusMessage = "Failed to load maps"
    } else {
      statusMessage = "Loaded \(successCount) maps (\(failureCount) failed)"
    }
  }

  private func isMapLoaded() -> Bool {
    // For REST API, check if maps are registered (selected)
    if immersalKit.localizerType == .restApi {
      return !selectedMapIds.isEmpty
    }
    // For PosePlugin, check if maps are actually loaded
    return immersalKit.mapManager.loadedMaps.count > 0
  }

  private func startLocalizing() {
    Task {
      do {
        try await immersalKit.startLocalizing()
        statusMessage = "Localization started"
      } catch {
        statusMessage = "Failed to start localization: \(error.localizedDescription)"
      }
    }
  }

  private func stopLocalizing() {
    Task {
      await immersalKit.stopLocalizing()
      statusMessage = "Localization stopped"
    }
  }

  private func resetAll() {
    Task {
      if immersalKit.isLocalizing {
        await immersalKit.stopLocalizing()
      }

      immersalKit.resetLocalizers()

      // Unload loaded maps only and hide 3D models (keep mapEntries)
      for mapId in Array(immersalKit.mapManager.loadedMaps.keys) {
        _ = immersalKit.mapManager.unloadMap(mapId: mapId)
      }

      selectedMapIds.removeAll()
      statusMessage = "All state reset"
    }
  }

  private func validateToken() {
    guard !developerToken.isEmpty else {
      statusMessage = "Please enter token"
      return
    }

    isTokenLoading = true

    // Set token to ImmersalKit API client
    immersalKit.client.tokenProvider.setToken(developerToken)

    Task {
      do {
        let status = try await immersalKit.client.getStatus()
        statusMessage = "Token is valid"
        isTokenLoading = false

        // Fetch map list if token is valid
        await fetchMaps()
      } catch {
        statusMessage = "Token is invalid: \(error.localizedDescription)"
        isTokenLoading = false
      }
    }
  }
}
