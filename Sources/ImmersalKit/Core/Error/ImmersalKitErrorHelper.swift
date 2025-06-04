import ARKit
import Foundation

extension ImmersalKitError {
  /// Factory method to convert individual error types to ImmersalKitError (internal use only)
  internal static func from(_ error: Error) -> ImmersalKitError {
    if let immersalKitError = error as? ImmersalKitError {
      return immersalKitError
    }

    switch error {
    case let arSessionError as ARSessionError:
      return .session(arSessionError)
    case let localizationError as LocalizationError:
      return .localization(localizationError)
    case let immersalError as ImmersalError:
      return .network(immersalError)
    case let imageConversionError as ImageConversionError:
      return .imageProcessing(imageConversionError)
    case let mapManagementError as MapManagementError:
      return .mapManagement(mapManagementError)
    case let configurationError as ConfigurationError:
      return .configuration(configurationError)
    default:
      return .unknown(error.localizedDescription)
    }
  }
}

// MARK: - Result Type Extensions

extension Result where Failure == ImmersalKitError {
  /// Log error and return Result
  public func logError(
    category: String = "ImmersalKit",
    message: String = "Operation failed"
  ) -> Result<Success, Failure> {
    if case .failure(let error) = self {
      print("[\(category):\(error.category.rawValue)] \(message)")
      print("  Error: \(error.localizedDescription)")
      if let reason = error.failureReason {
        print("  Reason: \(reason)")
      }
      if let suggestion = error.recoverySuggestion {
        print("  Suggestion: \(suggestion)")
      }
    }
    return self
  }

  /// Adjust log level based on error severity
  public func logWithSeverity() -> Result<Success, Failure> {
    if case .failure(let error) = self {
      let prefix = severityPrefix(for: error.severity)
      print("\(prefix) [\(error.category.rawValue)] \(error.localizedDescription)")
    }
    return self
  }

  private func severityPrefix(for severity: ErrorSeverity) -> String {
    switch severity {
    case .low: return "ℹ️"
    case .medium: return "⚠️"
    case .high: return "❌"
    case .critical: return "🚨"
    }
  }
}

/// Structure that holds error context information
public struct ErrorContext {
  /// File where error occurred
  public let file: String

  /// Function where error occurred
  public let function: String

  /// Line number where error occurred
  public let line: Int

  /// Time when error occurred
  public let timestamp: Date

  /// Additional debug information
  public let additionalInfo: [String: Any]

  /// Initialize ErrorContext
  public init(
    file: String = #file,
    function: String = #function,
    line: Int = #line,
    additionalInfo: [String: Any] = [:]
  ) {
    self.file = URL(fileURLWithPath: file).lastPathComponent
    self.function = function
    self.line = line
    self.timestamp = Date()
    self.additionalInfo = additionalInfo
  }
}

/// DateFormatter for error reporting (internal use only)
extension DateFormatter {
  static let errorReportFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .medium
    return formatter
  }()
}
