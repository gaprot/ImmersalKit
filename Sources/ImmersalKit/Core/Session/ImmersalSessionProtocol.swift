import Combine
import Foundation
import PosePlugin
import RealityKit

/// Protocol for managing Immersal localization sessions.
public protocol ImmersalSessionProtocol {

  // MARK: - Session Lifecycle

  /// Pauses the localization session.
  func pause() -> Result<Void, ImmersalKitError>

  /// Resumes a paused localization session.
  func resume() -> Result<Void, ImmersalKitError>

  /// Resets the localization session to initial state.
  func reset() async -> Result<Void, ImmersalKitError>

  /// Stops the localization session.
  func stop(cancelRunningTask: Bool) async -> Result<Void, ImmersalKitError>

  /// Starts the localization session.
  func start() async -> Result<Void, ImmersalKitError>

  // MARK: - Single-shot Localization

  /// Performs a single localization attempt.
  func localizeOnce() async -> Result<LocalizationResult?, ImmersalKitError>

  // MARK: - Status Properties

  /// Indicates whether localization processing is currently active.
  var isLocalizing: Bool { get }

  /// The most recent successful localization result.
  var lastResult: LocalizationResult? { get }

  // MARK: - Event Streaming

  /// Provides a stream of localization events.
  func localizationEvents() -> AsyncStream<LocalizationEvent>
}
