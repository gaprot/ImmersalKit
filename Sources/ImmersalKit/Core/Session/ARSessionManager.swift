import ARKit
import Combine
import Foundation
import SwiftUI
import os.log

/// Manages ARKit session and provides camera frames and tracking data
@MainActor
@Observable
public final class ARSessionManager {
  var isSessionRunning = false
  var latestFrameData: ARFrameData?

  // MARK: - Combine Publishers

  private let frameSubject = CurrentValueSubject<ARFrameData?, Never>(nil)

  var cameraFramePublisher: AnyPublisher<ARFrameData, Never> {
    frameSubject
      .compactMap { $0 }
      .receive(on: RunLoop.main)
      .eraseToAnyPublisher()
  }

  var trackingDataPublisher: AnyPublisher<ARTrackingData, Never> {
    trackingDataSubject
      .receive(on: RunLoop.main)
      .eraseToAnyPublisher()
  }

  private var arSession: ARKitSession?
  private var cameraFrameProvider: CameraFrameProvider?
  private var worldTrackingProvider: WorldTrackingProvider?
  private var frameContinuation: AsyncStream<ARFrameData>.Continuation?

  private var trackingDataSubject = PassthroughSubject<ARTrackingData, Never>()

  private let errorReporter: ErrorReporting

  // MARK: - Initialization

  public init(errorReporter: ErrorReporting = DefaultErrorReporter()) {
    self.errorReporter = errorReporter
  }

  deinit {
    // Note: Cannot call stopSession() directly in deinit because it's @MainActor-isolated
    // Resources will be cleaned up when the object is deallocated
  }

  // MARK: - Public Methods

  /// Starts AR session
  public func startSession() -> Result<Void, ImmersalKitError> {

    guard !isSessionRunning else {
      return .success(())
    }

    do {
      // Initialize ARKit session
      arSession = ARKitSession()

      guard let arSession = arSession else {
        let error = ImmersalKitError.session(.sessionInitializationFailed)
        errorReporter.reportError(error, context: ErrorContext())
        return .failure(error)
      }

      return .success(())
    } catch {
      let immersalError = ImmersalKitError.session(.sessionInitializationFailed)
      errorReporter.reportError(
        immersalError, context: ErrorContext(additionalInfo: ["underlying_error": error]))
      return .failure(immersalError)
    }
  }

  /// Starts AR session asynchronously with permission checks
  public func startSessionAsync() async -> Result<Void, ImmersalKitError> {

    guard !isSessionRunning else {
      return .success(())
    }

    do {
      // Initialize ARKit session
      arSession = ARKitSession()

      guard let arSession = arSession else {
        let error = ImmersalKitError.session(.sessionInitializationFailed)
        errorReporter.reportError(error, context: ErrorContext())
        return .failure(error)
      }

      let query = await arSession.queryAuthorization(for: [.cameraAccess])

      if query[.cameraAccess] != .allowed {
        let req = await arSession.requestAuthorization(for: [.cameraAccess])
        if req[.cameraAccess] != .allowed {
          Logger.session.error("Camera permission denied")
          let error = ImmersalKitError.session(.permissionDenied)
          errorReporter.reportError(error, context: ErrorContext())
          return .failure(error)
        }
      }

      cameraFrameProvider = CameraFrameProvider()
      worldTrackingProvider = WorldTrackingProvider()

      if let cameraFrameProvider = cameraFrameProvider,
        let worldTrackingProvider = worldTrackingProvider
      {
        try await arSession.run([cameraFrameProvider, worldTrackingProvider])
      } else {
        let error = ImmersalKitError.session(.sessionInitializationFailed)
        errorReporter.reportError(
          error, context: ErrorContext(additionalInfo: ["reason": "Provider initialization failed"])
        )
        return .failure(error)
      }

      setupStreams()

      isSessionRunning = true
      return .success(())

    } catch {
      Logger.session.error("Failed to start AR session: \(error.localizedDescription)")
      let immersalError = ImmersalKitError.session(.sessionInitializationFailed)
      errorReporter.reportError(
        immersalError, context: ErrorContext(additionalInfo: ["underlying_error": error]))
      return .failure(immersalError)
    }
  }

  /// Stops AR session
  public func stopSession() -> Result<Void, ImmersalKitError> {
    guard isSessionRunning else {
      return .success(())
    }

    do {
      frameContinuation?.finish()
      frameContinuation = nil

      arSession = nil
      cameraFrameProvider = nil
      worldTrackingProvider = nil

      // Clean up Combine resources
      trackingDataSubject = PassthroughSubject<ARTrackingData, Never>()
      frameSubject.send(nil)

      isSessionRunning = false
      return .success(())

    } catch {
      let immersalError = ImmersalKitError.session(
        .unknown("Failed to stop session: \(error.localizedDescription)"))
      errorReporter.reportError(
        immersalError, context: ErrorContext(additionalInfo: ["underlying_error": error]))
      return .failure(immersalError)
    }
  }

  /// Get camera frame stream
  public func cameraFrames() -> AsyncStream<ARFrameData> {
    return AsyncStream { continuation in
      self.frameContinuation = continuation
    }
  }

  /// Get current device anchor and return tracking data
  public func queryDeviceAnchorData(atTimestamp timestamp: TimeInterval? = nil) async -> Result<
    ARTrackingData, ImmersalKitError
  > {
    guard isSessionRunning, let worldTrackingProvider = worldTrackingProvider else {
      let error = ImmersalKitError.session(.sessionInitializationFailed)
      errorReporter.reportError(
        error, context: ErrorContext(additionalInfo: ["isSessionRunning": isSessionRunning]))
      return .failure(error)
    }

    // Use current time if no timestamp specified
    let currentTimestamp = timestamp ?? CACurrentMediaTime()

    // Get device anchor from WorldTrackingProvider
    guard let deviceAnchor = worldTrackingProvider.queryDeviceAnchor(atTimestamp: currentTimestamp)
    else {
      Logger.session.error("Device anchor not available")
      let error = ImmersalKitError.session(.trackingFailed)
      errorReporter.reportError(
        error, context: ErrorContext(additionalInfo: ["timestamp": currentTimestamp]))
      return .failure(error)
    }

    // Create tracking data
    let trackingData = ARTrackingData(
      device2World: deviceAnchor.originFromAnchorTransform,
      trackingState: worldTrackingProvider.state,
      timestamp: deviceAnchor.timestamp
    )

    // Publish tracking data
    trackingDataSubject.send(trackingData)

    return .success(trackingData)
  }

  /// Get current camera frame
  public func getCurrentFrame() -> Result<ARFrameData, ImmersalKitError> {
    guard isSessionRunning else {
      let error = ImmersalKitError.session(.sessionInitializationFailed)
      return .failure(error)
    }

    guard let frameData = latestFrameData else {
      Logger.session.error("Latest frame data not available")
      let error = ImmersalKitError.session(.frameDataNotAvailable)
      errorReporter.reportError(error, context: ErrorContext())
      return .failure(error)
    }

    return .success(frameData)
  }

  // MARK: - Private Methods

  private func setupStreams() {
    Task {
      await handleCameraUpdates()
    }
    Task {
      await handleAnchorUpdates()
    }
  }

  private func handleCameraUpdates() async {
    guard let cameraFrameProvider = cameraFrameProvider,
      let format = CameraVideoFormat.highestResolutionFormat(),
      let cameraFrameUpdates = cameraFrameProvider.cameraFrameUpdates(for: format)
    else {
      Logger.session.error("Failed to get camera frame updates")
      let error = ImmersalKitError.session(.cameraFrameCaptureFailed)
      errorReporter.reportError(error, context: ErrorContext())
      return
    }

    // Process camera frames
    do {
      for await update in cameraFrameUpdates {
        if let sample = update.sample(for: .left) {
          let frameData = ARFrameData(
            pixelBuffer: sample.pixelBuffer,
            captureTime: sample.parameters.captureTimestamp,
            cameraIntrinsics: sample.parameters.intrinsics,
            cameraExtrinsics: sample.parameters.extrinsics
          )

          await MainActor.run {
            self.latestFrameData = frameData
            // Notify changes via CurrentValueSubject
            self.frameSubject.send(frameData)
          }

          self.frameContinuation?.yield(frameData)
        }
      }
    } catch {
      Logger.session.error("Error in camera frame handling: \(error)")
      let immersalError = ImmersalKitError.session(.cameraFrameCaptureFailed)
      errorReporter.reportError(
        immersalError, context: ErrorContext(additionalInfo: ["underlying_error": error]))
    }
  }

  private func handleAnchorUpdates() async {
    guard let worldTrackingProvider = worldTrackingProvider else {
      Logger.session.error("worldTrackingProvider is nil")
      return
    }

    do {
      for await update in worldTrackingProvider.anchorUpdates {
        // Currently just monitoring anchor updates without specific processing
        switch update.event {
        case .added, .updated:
          break
        case .removed:
          break
        }
      }
    } catch {
      Logger.session.error("Error in anchor updates: \(error)")
      let immersalError = ImmersalKitError.session(.trackingFailed)
      errorReporter.reportError(
        immersalError, context: ErrorContext(additionalInfo: ["underlying_error": error]))
    }
  }
}

extension CameraVideoFormat {
  static func highestResolutionFormat() -> CameraVideoFormat? {
    let formats = supportedVideoFormats(for: .main, cameraPositions: [.left])
    return formats.max { $0.frameSize.height < $1.frameSize.height }
  }
}
