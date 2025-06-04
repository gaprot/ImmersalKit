import Combine
import Foundation
import RealityKit
import SwiftUI

/// Core class for AR session management and localization processing
@Observable
public final class ImmersalKit {
  // MARK: - Public Properties

  /// Current localizer type
  public var localizerType: LocalizerType {
    didSet {
      if oldValue != localizerType {
        // Localizer type changed
      }
    }
  }

  /// Map manager instance
  public let mapManager: MapManager

  /// API client
  public let client: ImmersalAPI

  /// Current localization session
  public private(set) var session: ImmersalSessionProtocol?

  /// Whether localization is currently running
  public var isLocalizing: Bool {
    return (session as? ImmersalSession)?.isLocalizing ?? false
  }

  /// Last successful localization result
  public private(set) var lastResult: LocalizationResult?

  // MARK: - Internal Properties

  let arSessionManager: ARSessionManager

  // MARK: - Private Properties

  private var localizers: [LocalizerType: ImmersalLocalizer] = [:]
  private var cancellables = Set<AnyCancellable>()
  private let errorReporter: ErrorReporting
  private var localizationEventSubject = PassthroughSubject<LocalizationEvent, Never>()

  // MARK: - Computed Properties

  /// Returns the active localizer for the current type
  public var activeLocalizer: ImmersalLocalizer {
    if !localizers.keys.contains(localizerType) {
      createLocalizer(for: localizerType)
    }
    return localizers[localizerType]!
  }

  // MARK: - Initialization

  /// Public initializer for ImmersalKit
  /// - Parameters:
  ///   - localizerType: Type of localizer to use (default: .posePlugin)
  ///   - arSessionManager: AR session manager instance
  ///   - tokenProvider: Token provider for REST API authentication (default: BundleTokenProvider)
  ///   - errorReporter: Error reporting instance (default: DefaultErrorReporter)
  public init(
    localizerType: LocalizerType = .posePlugin,
    arSessionManager: ARSessionManager,
    tokenProvider: TokenProvider? = nil,
    errorReporter: ErrorReporting = DefaultErrorReporter()
  ) {
    self.localizerType = localizerType
    self.arSessionManager = arSessionManager
    self.errorReporter = errorReporter
    
    let provider = tokenProvider ?? BundleTokenProvider()
    self.client = RestClient(tokenProvider: provider)
    
    self.mapManager = MapManager(errorReporter: errorReporter)
  }
  
  /// Internal initializer for ImmersalKit (used for testing)
  internal init(
    localizerType: LocalizerType,
    arSessionManager: ARSessionManager,
    client: ImmersalAPI,
    errorReporter: ErrorReporting
  ) {
    self.localizerType = localizerType
    self.arSessionManager = arSessionManager
    self.client = client
    self.errorReporter = errorReporter
    self.mapManager = MapManager(errorReporter: errorReporter)
  }

  private func createLocalizer(for type: LocalizerType) {
    switch type {
    case .posePlugin:
      localizers[type] = PosePluginLocalizer(errorReporter: errorReporter)
    case .restApi:
      localizers[type] = RestApiLocalizer(api: client, errorReporter: errorReporter)
    }
  }

  // MARK: - Localizer Management

  /// Switches to a different localizer type
  public func switchLocalizer(to newType: LocalizerType) async {
    if localizerType == newType {
      return
    }

    if isLocalizing {
      await stopLocalizing()
    }

    localizerType = newType
  }

  // MARK: - Localization

  /// Starts localization process
  public func startLocalizing() async throws {
    session = ImmersalSession(
      localizer: activeLocalizer,
      arSessionManager: arSessionManager,
      mapManager: mapManager,
      errorReporter: errorReporter
    )
    try await session?.start()

    // Start monitoring localization events
    Task {
      guard let session = session else { return }
      for await event in session.localizationEvents() {
        await handleLocalizationEvent(event)
        localizationEventSubject.send(event)
      }
    }
  }

  /// Stops localization process
  public func stopLocalizing() async {
    await session?.stop(cancelRunningTask: true)
  }

  /// Resets localizers
  public func resetLocalizers() {
    lastResult = nil
    Task {
      await session?.reset()
    }
  }

  /// Handles localization events from session
  @MainActor
  private func handleLocalizationEvent(_ event: LocalizationEvent) async {
    switch event {
    case .result(let result):
      lastResult = result
    case .stopped:
      // Keep lastResult when stopped, don't clear it
      break
    case .started, .failed:
      break
    }
  }

  /// Returns async stream for localization events
  public func localizationEvents() -> AsyncStream<LocalizationEvent> {
    return AsyncStream { continuation in
      let cancellable = localizationEventSubject.sink { event in
        continuation.yield(event)
      }
      continuation.onTermination = { _ in
        cancellable.cancel()
      }
    }
  }

  deinit {
    cancellables.removeAll()
  }

  // MARK: - Map Management
}
