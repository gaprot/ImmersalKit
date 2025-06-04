import ARKit
import Foundation

/// Unified error type encompassing all individual error types.
public enum ImmersalKitError: Error, LocalizedError, Equatable {
  case session(ARSessionError)
  case localization(LocalizationError)
  case network(ImmersalError)
  case imageProcessing(ImageConversionError)
  case mapManagement(MapManagementError)
  case configuration(ConfigurationError)
  case unknown(String)

  // MARK: - LocalizedError Implementation

  public var errorDescription: String? {
    switch self {
    case .session(let error):
      return "AR session error: \(error.errorDescription ?? "Unknown error")"
    case .localization(let error):
      return "Localization error: \(error.errorDescription ?? "Unknown error")"
    case .network(let error):
      return "Network error: \(error.errorDescription ?? "Unknown error")"
    case .imageProcessing(let error):
      return "Image processing error: \(error.errorDescription ?? "Unknown error")"
    case .mapManagement(let error):
      return "Map management error: \(error.errorDescription ?? "Unknown error")"
    case .configuration(let error):
      return "Configuration error: \(error.errorDescription ?? "Unknown error")"
    case .unknown(let message):
      return "Unknown error: \(message)"
    }
  }

  public var failureReason: String? {
    switch self {
    case .session(let error):
      return error.failureReason
    case .localization(let error):
      return error.failureReason
    case .network(let error):
      return error.failureReason
    case .imageProcessing(let error):
      return error.failureReason
    case .mapManagement(let error):
      return error.failureReason
    case .configuration(let error):
      return error.failureReason
    case .unknown(let message):
      return message
    }
  }

  public var recoverySuggestion: String? {
    switch self {
    case .session(.permissionDenied):
      return "Please allow camera access from Settings app."
    case .localization(.invalidMapIds):
      return "Please specify valid map IDs."
    case .network(.missingToken):
      return "Please set the developer token."
    case .mapManagement(.mapNotFound):
      return "The specified map was not found. Please verify that the map is loaded correctly."
    case .configuration(.invalidParameter):
      return "Please check the parameters and try again."
    case .session(let error):
      return error.recoverySuggestion
    case .localization(let error):
      return error.recoverySuggestion
    case .network(let error):
      return error.recoverySuggestion
    case .imageProcessing(let error):
      return error.recoverySuggestion
    case .mapManagement(let error):
      return error.recoverySuggestion
    case .configuration(let error):
      return error.recoverySuggestion
    default:
      return "Please restart the app or wait a moment and try again."
    }
  }

  public var helpAnchor: String? {
    switch self {
    case .session(_):
      return "ar_session_help"
    case .localization(_):
      return "localization_help"
    case .network(_):
      return "network_help"
    case .imageProcessing(_):
      return "image_processing_help"
    case .mapManagement(_):
      return "map_management_help"
    case .configuration(_):
      return "configuration_help"
    case .unknown(_):
      return "general_troubleshooting"
    }
  }

  // MARK: - Equatable Implementation

  public static func == (lhs: ImmersalKitError, rhs: ImmersalKitError) -> Bool {
    switch (lhs, rhs) {
    case (.session(let lhsError), .session(let rhsError)):
      return lhsError == rhsError
    case (.localization(let lhsError), .localization(let rhsError)):
      return lhsError == rhsError
    case (.network(let lhsError), .network(let rhsError)):
      return lhsError == rhsError
    case (.imageProcessing(let lhsError), .imageProcessing(let rhsError)):
      return lhsError == rhsError
    case (.mapManagement(let lhsError), .mapManagement(let rhsError)):
      return lhsError == rhsError
    case (.configuration(let lhsError), .configuration(let rhsError)):
      return lhsError == rhsError
    case (.unknown(let lhsMessage), .unknown(let rhsMessage)):
      return lhsMessage == rhsMessage
    default:
      return false
    }
  }

  // MARK: - Utility Methods

  /// Gets the error category.
  public var category: ErrorCategory {
    switch self {
    case .session(_): return .session
    case .localization(_): return .localization
    case .network(_): return .network
    case .imageProcessing(_): return .imageProcessing
    case .mapManagement(_): return .mapManagement
    case .configuration(_): return .configuration
    case .unknown(_): return .unknown
    }
  }

  /// Gets the error severity level.
  public var severity: ErrorSeverity {
    switch self {
    case .session(.permissionDenied), .configuration(.missingRequiredConfiguration(_)):
      return .critical
    case .localization(.networkError(_)), .network(.networkError(_)):
      return .high
    case .session(.frameDataNotAvailable), .localization(.coreLocalizationFailed(_)):
      return .medium
    default:
      return .low
    }
  }

  /// Determines if the error is retryable.
  public var isRetryable: Bool {
    switch self {
    case .session(.sessionInitializationFailed),
      .localization(.networkError(_)),
      .network(.networkError(_)):
      return true
    case .session(.permissionDenied),
      .localization(.invalidMapIds),
      .configuration(.invalidParameter(_)):
      return false
    default:
      return false
    }
  }
}

// MARK: - Error Category

/// Categorization of error types for filtering and handling.
public enum ErrorCategory: String, CaseIterable {
  case session = "session"
  case localization = "localization"
  case network = "network"
  case imageProcessing = "image_processing"
  case mapManagement = "map_management"
  case configuration = "configuration"
  case unknown = "unknown"
}

// MARK: - Error Severity

/// Error severity levels for prioritizing error handling.
public enum ErrorSeverity: String, CaseIterable, Comparable {
  case low = "LOW"
  case medium = "MEDIUM"
  case high = "HIGH"
  case critical = "CRITICAL"

  public static func < (lhs: ErrorSeverity, rhs: ErrorSeverity) -> Bool {
    let order: [ErrorSeverity] = [.low, .medium, .high, .critical]
    guard let lhsIndex = order.firstIndex(of: lhs),
      let rhsIndex = order.firstIndex(of: rhs)
    else {
      return false
    }
    return lhsIndex < rhsIndex
  }
}
