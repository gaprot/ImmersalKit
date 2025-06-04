import Foundation

/// Configuration for confidence-based alignment control
public struct ConfidenceBasedAlignmentConfiguration {
  /// Whether to enable confidence comparison functionality
  public let isEnabled: Bool

  /// Minimum confidence delta required to perform alignment
  /// Alignment is performed only when: current confidence - latest confidence >= minimumConfidenceDelta
  public let minimumConfidenceDelta: Float

  /// Absolute minimum confidence threshold (alignment is always skipped below this value)
  public let absoluteMinimumConfidence: Float

  /// Maximum number of confidence history entries to retain
  public let maxHistorySize: Int

  /// Default configuration
  public static let defaultConfiguration = ConfidenceBasedAlignmentConfiguration(
    isEnabled: true,
    minimumConfidenceDelta: -2.0,
    absoluteMinimumConfidence: 15.0,
    maxHistorySize: 5
  )

  public init(
    isEnabled: Bool = true,
    minimumConfidenceDelta: Float = -2.0,
    absoluteMinimumConfidence: Float = 15.0,
    maxHistorySize: Int = 5
  ) {
    self.isEnabled = isEnabled
    self.minimumConfidenceDelta = minimumConfidenceDelta
    self.absoluteMinimumConfidence = absoluteMinimumConfidence
    self.maxHistorySize = max(1, maxHistorySize)
  }
}

/// Manages confidence-based alignment control
public final class ConfidenceBasedAlignmentController {
  // MARK: - Properties

  /// Configuration
  public private(set) var configuration: ConfidenceBasedAlignmentConfiguration

  /// Confidence history (newest first)
  private var confidenceHistory: [Float] = []

  /// Latest confidence value (from last successful localization)
  public var latestConfidence: Float? {
    return confidenceHistory.first
  }

  /// Average of confidence history
  public var averageConfidence: Float {
    guard !confidenceHistory.isEmpty else { return 0.0 }
    return confidenceHistory.reduce(0, +) / Float(confidenceHistory.count)
  }

  // MARK: - Initialization

  public init(configuration: ConfidenceBasedAlignmentConfiguration = .defaultConfiguration) {
    self.configuration = configuration
  }

  // MARK: - Public Methods

  /// Updates the configuration
  /// - Parameter configuration: New configuration
  public func updateConfiguration(_ configuration: ConfidenceBasedAlignmentConfiguration) {
    self.configuration = configuration

    if confidenceHistory.count > configuration.maxHistorySize {
      confidenceHistory = Array(confidenceHistory.prefix(configuration.maxHistorySize))
    }
  }

  /// Records new confidence and determines whether to perform alignment
  /// - Parameter newConfidence: New confidence value
  /// - Returns: Whether alignment should be performed
  public func shouldPerformAlignment(withNewConfidence newConfidence: Float) -> Bool {
    guard configuration.isEnabled else {
      addConfidenceToHistory(newConfidence)
      return true
    }

    if newConfidence <= configuration.absoluteMinimumConfidence {
      addConfidenceToHistory(newConfidence)
      return false
    }

    guard let previousConfidence = latestConfidence else {
      addConfidenceToHistory(newConfidence)
      return true
    }

    let confidenceDelta = newConfidence - previousConfidence

    let averageConf = averageConfidence
    let averageDelta = newConfidence - averageConf

    let shouldPerform =
      confidenceDelta >= configuration.minimumConfidenceDelta && averageDelta >= -3.0

    addConfidenceToHistory(newConfidence)

    return shouldPerform
  }

  /// Clears confidence history
  public func clearHistory() {
    confidenceHistory.removeAll()
  }

  /// Gets current status information for debugging
  public func getStatusInfo() -> [String: Any] {
    return [
      "isEnabled": configuration.isEnabled,
      "latestConfidence": latestConfidence ?? "nil",
      "averageConfidence": averageConfidence,
      "historyCount": confidenceHistory.count,
      "confidenceHistory": confidenceHistory,
      "minimumConfidenceDelta": configuration.minimumConfidenceDelta,
      "absoluteMinimumConfidence": configuration.absoluteMinimumConfidence,
    ]
  }

  // MARK: - Private Methods

  /// Adds confidence value to history
  /// - Parameter confidence: Confidence value to add
  private func addConfidenceToHistory(_ confidence: Float) {
    confidenceHistory.insert(confidence, at: 0)

    if confidenceHistory.count > configuration.maxHistorySize {
      confidenceHistory.removeLast()
    }
  }
}

// MARK: - Extensions

extension ConfidenceBasedAlignmentController {
  /// Analyzes confidence trend
  /// - Returns: String indicating whether confidence is increasing, decreasing, or stable
  public func getConfidenceTrend() -> String {
    guard confidenceHistory.count >= 2 else {
      return "insufficient_data"
    }

    let recent = confidenceHistory.prefix(min(3, confidenceHistory.count))
    let recentArray = Array(recent)

    var increasingCount = 0
    var decreasingCount = 0

    for i in 0..<(recentArray.count - 1) {
      if recentArray[i] > recentArray[i + 1] {
        increasingCount += 1
      } else if recentArray[i] < recentArray[i + 1] {
        decreasingCount += 1
      }
    }

    if increasingCount > decreasingCount {
      return "increasing"
    } else if decreasingCount > increasingCount {
      return "decreasing"
    } else {
      return "stable"
    }
  }
}
