import Combine
import Foundation
import PosePlugin
import RealityKit
import SwiftUI
import os.log

/// Core implementation of Immersal localization session management.
public final class ImmersalSession: ImmersalSessionProtocol {
  // MARK: - Public Properties

  /// Indicates whether localization processing is currently active
  public private(set) var isLocalizing: Bool = false

  /// The most recent successful localization result
  public private(set) var lastResult: LocalizationResult?

  /// Total number of localization attempts made
  public private(set) var attemptCount: Int = 0

  /// Total number of successful localizations
  public private(set) var successCount: Int = 0

  /// Controller for confidence-based alignment decisions
  public private(set) var alignmentController: ConfidenceBasedAlignmentController

  /// Number of scene alignments skipped due to low confidence
  public private(set) var alignmentSkippedCount: Int = 0

  // MARK: - Private Properties

  /// Reference to AR session manager for camera data
  private let arSessionManager: ARSessionManager

  private let localizer: ImmersalLocalizer

  private let mapManager: MapManager

  private let sceneUpdater = SceneUpdater()
  private let errorReporter: ErrorReporting

  /// Background task executing the localization loop
  private var localizationTask: Task<(), Never>?

  /// Most recently captured AR frame data
  private var lastFrame: ARFrameData?

  /// Timer controlling localization processing intervals
  private let localizationTimer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()

  /// Set managing Combine subscriptions
  private var cancellables = Set<AnyCancellable>()

  /// Continuation for event streaming
  private var eventContinuation: AsyncStream<LocalizationEvent>.Continuation?

  // MARK: - Computed Properties

  /// Whether at least one localization has succeeded
  public var hasSucceededOnce: Bool {
    return successCount > 0
  }

  /// Localization success rate (0.0 to 1.0)
  public var successRate: Float {
    guard attemptCount > 0 else { return 0.0 }
    return Float(successCount) / Float(attemptCount)
  }

  // MARK: - Initialization

  /// Initializes a new ImmersalSession instance.
  public init(
    localizer: ImmersalLocalizer,
    arSessionManager: ARSessionManager,
    mapManager: MapManager,
    alignmentConfiguration: ConfidenceBasedAlignmentConfiguration = .defaultConfiguration,
    errorReporter: ErrorReporting = DefaultErrorReporter()
  ) {
    self.localizer = localizer
    self.arSessionManager = arSessionManager
    self.mapManager = mapManager
    self.alignmentController = ConfidenceBasedAlignmentController(
      configuration: alignmentConfiguration)
    self.errorReporter = errorReporter
  }

  deinit {
    // Cancel any running localization task
    localizationTask?.cancel()

    // Clean up subscriptions
    cancellables.removeAll()
  }

  // MARK: - ImmersalSessionProtocol Implementation

  /// Pauses the localization session.
  public func pause() -> Result<Void, ImmersalKitError> {
    guard isLocalizing else {
      return .success(())
    }

    localizationTask?.cancel()
    isLocalizing = false
    return .success(())
  }

  /// Resumes a paused localization session.
  public func resume() -> Result<Void, ImmersalKitError> {
    guard !isLocalizing else {
      return .success(())
    }

    isLocalizing = true

    self.localizationTask = Task {
      await runLocalizationLoop()
    }

    return .success(())
  }

  /// Resets the localization session to initial state.
  public func reset() async -> Result<Void, ImmersalKitError> {
    if isLocalizing {
      let stopResult = await stop(cancelRunningTask: true)
      if case .failure(let error) = stopResult {
        return .failure(error)
      }
    }

    lastResult = nil
    attemptCount = 0
    successCount = 0
    alignmentSkippedCount = 0
    alignmentController.clearHistory()
    return .success(())
  }

  /// Stops the localization session.
  public func stop(cancelRunningTask: Bool) async -> Result<Void, ImmersalKitError> {
    guard isLocalizing else {
      return .success(())
    }

    if cancelRunningTask {
      localizationTask?.cancel()
    }

    isLocalizing = false
    eventContinuation?.yield(.stopped)
    return .success(())
  }

  /// Starts the localization session.
  public func start() async -> Result<Void, ImmersalKitError> {
    guard !isLocalizing else {
      return .success(())
    }

    // Start AR session
    let sessionResult = await arSessionManager.startSessionAsync()
    switch sessionResult {
    case .success:
      break
    case .failure(let error):
      errorReporter.reportError(error, context: ErrorContext())
      return .failure(error)
    }

    cancellables.removeAll()

    // Setup camera frame update loop
    await updateCameraFrameLoop()

    isLocalizing = true
    eventContinuation?.yield(.started)

    // Start localization loop
    self.localizationTask = Task {
      await runLocalizationLoop()
    }

    return .success(())
  }

  /// Performs a single localization attempt.
  public func localizeOnce() async -> Result<LocalizationResult?, ImmersalKitError> {
    guard let lastFrame = self.lastFrame else {
      let error = ImmersalKitError.session(.frameDataNotAvailable)
      errorReporter.reportError(error, context: ErrorContext())
      return .failure(error)
    }

    // Increment attempt count
    attemptCount += 1

    let result = await performSingleLocalization(with: lastFrame)

    if result != nil {
      // Increment success count
      successCount += 1
    }

    return .success(result)
  }

  /// Provides a stream of localization events.
  public func localizationEvents() -> AsyncStream<LocalizationEvent> {
    return AsyncStream { continuation in
      self.eventContinuation = continuation
    }
  }

  // MARK: - Confidence-based Alignment Control Methods

  /// Updates the confidence-based alignment control configuration.
  public func updateAlignmentConfiguration(_ configuration: ConfidenceBasedAlignmentConfiguration) {
    alignmentController.updateConfiguration(configuration)
  }

  /// Clears the confidence history buffer.
  public func clearConfidenceHistory() {
    alignmentController.clearHistory()
  }

  /// Gets current status information for confidence-based alignment control.
  public func getAlignmentControlStatus() -> [String: Any] {
    var status = alignmentController.getStatusInfo()
    status["alignmentSkippedCount"] = alignmentSkippedCount
    status["successRate"] = successRate
    status["hasSucceededOnce"] = hasSucceededOnce
    return status
  }

  /// Gets detailed statistics about alignment skipping behavior.
  public func getAlignmentSkipStatistics() -> (
    skippedCount: Int, totalAttempts: Int, skipRate: Float
  ) {
    let totalAttempts = successCount  // Number of successful localizations
    let skipRate: Float =
      totalAttempts > 0 ? Float(alignmentSkippedCount) / Float(totalAttempts) : 0.0
    return (alignmentSkippedCount, totalAttempts, skipRate)
  }

  // MARK: - Localization Methods

  /// Runs the continuous localization loop.
  private func runLocalizationLoop() async {
    while isLocalizing && !Task.isCancelled {
      await performLocalizationCycle()

      let intervalNanoseconds: UInt64 = hasSucceededOnce ? 500_000_000 : 100_000_000
      try? await Task.sleep(nanoseconds: intervalNanoseconds)
    }
  }

  /// Performs a single localization cycle.
  private func performLocalizationCycle() async {
    // Exit early if task is cancelled or session stopped
    if Task.isCancelled || !isLocalizing {
      return
    }

    // Ensure required data is available
    guard let lastFrame = lastFrame else {
      return
    }

    do {
      // Increment attempt count
      attemptCount += 1

      if let result = await performSingleLocalization(with: lastFrame) {
        // Increment success count
        successCount += 1

        let applyResult = await applyLocalizationResult(result)
        if case .failure(let error) = applyResult {
          await handleLocalizationError(error)
        }
      }
    } catch {
      let immersalError = ImmersalKitError.localization(.unknown(error.localizedDescription))
      await handleLocalizationError(immersalError)
    }
  }

  /// Handles localization errors by reporting and emitting events.
  private func handleLocalizationError(_ error: ImmersalKitError) async {
    errorReporter.reportError(error, context: ErrorContext())
    eventContinuation?.yield(.failed(error))
  }

  /// Performs a single localization attempt with the given frame.
  private func performSingleLocalization(with frame: ARFrameData) async -> LocalizationResult? {

    // Get device anchor data
    let trackingResult = await arSessionManager.queryDeviceAnchorData(
      atTimestamp: frame.captureTime)

    let trackingData: ARTrackingData
    switch trackingResult {
    case .success(let data):
      trackingData = data
    case .failure(let error):
      Logger.localization.error("Failed to get device info: \(error)")
      await handleLocalizationError(error)
      return nil
    }

    // Execute image localization
    let mapIds = self.localizer.getRequiredMapIds(from: self.mapManager)
    let result = await self.localizer.localizeImage(
      mapIds: mapIds,
      pixelBuffer: frame.pixelBuffer,
      cameraParams: .init(
        fx: frame.cameraIntrinsics[0][0],
        fy: frame.cameraIntrinsics[1][1],
        ox: frame.cameraIntrinsics[0][2],
        oy: frame.cameraIntrinsics[1][2]
      )
    )

    switch result {
    case .success(let localizationResult):

      return await self.processLocalizationResult(
        localizationResult,
        trackingData: trackingData,
        extrinsics: frame.cameraExtrinsics,
        atTimestamp: frame.captureTime
      )

    case .failure(let error):
      if case .localization(.invalidMapIds) = error {
        let mapIds = Array(self.mapManager.loadedMaps.keys)
        Logger.localization.debug("Requested maps: \(mapIds)")
      }
      await handleLocalizationError(error)
      return nil
    }
  }

  /// Processes localization result (internal use only).
  internal func processLocalizationResult(
    _ result: LocalizationResponse,
    trackingData: ARTrackingData,
    extrinsics: simd_float4x4,
    atTimestamp: TimeInterval
  ) async -> LocalizationResult? {
    let mapId = result.mapId

    // Extract position and rotation from localization result
    let position = result.position
    let rotation = result.rotation

    // Camera to device transformation matrix
    let cam2Device = extrinsics

    // Calculate camera to world transformation
    let cam2World = trackingData.device2World * cam2Device

    // Create localization result object
    let localizationResult = LocalizationResult(
      mapId: mapId,
      position: position,
      rotation: rotation,
      confidence: result.confidence,
      timestamp: atTimestamp,
      cameraToWorldTransform: cam2World
    )

    // Save result
    self.lastResult = localizationResult
    eventContinuation?.yield(.result(localizationResult))

    return localizationResult
  }

  /// Applies localization result to the scene.
  public func applyLocalizationResult(_ result: LocalizationResult) async -> Result<
    Void, ImmersalKitError
  > {
    // Confidence check: determine if alignment should be performed
    let shouldPerformAlignment = alignmentController.shouldPerformAlignment(
      withNewConfidence: result.confidence)

    // Output debug information
    let statusInfo = alignmentController.getStatusInfo()
    if let latestConfidence = statusInfo["latestConfidence"] {
    }

    // Skip alignment if confidence is too low
    if !shouldPerformAlignment {
      alignmentSkippedCount += 1
      return .success(())
    }

    // Find corresponding map entry
    guard let mapEntry = mapManager.mapEntries[result.mapId] else {
      let error = ImmersalKitError.mapManagement(.mapNotFound(result.mapId))
      return .failure(error)
    }

    // Get latest camera frame
    let frameResult = await arSessionManager.getCurrentFrame()
    let frame: ARFrameData

    switch frameResult {
    case .success(let frameData):
      frame = frameData
    case .failure(let error):
      return .failure(error)
    }

    // Execute scene update
    let updateResult = await sceneUpdater.updateScene(
      entry: mapEntry,
      result: result,
      deviceToWorldTransform: frame.cameraExtrinsics
    )

    if updateResult != nil {
      return .success(())
    } else {
      let error = ImmersalKitError.configuration(.initializationFailed("Scene update failed"))
      return .failure(error)
    }
  }

  /// Sets up the camera frame update loop.
  @MainActor
  private func updateCameraFrameLoop() {
    // Setup camera frame subscription
    arSessionManager.cameraFramePublisher.sink { [weak self] frameData in
      guard let self = self else {
        return
      }
      // Store latest frame data
      self.lastFrame = frameData
    }
    .store(in: &self.cancellables)
  }
}
