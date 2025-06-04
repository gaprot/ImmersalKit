import ARKit
import Foundation
import os.log

public protocol ErrorReporting {
  func reportError(_ error: ImmersalKitError, context: ErrorContext)
}

public struct DefaultErrorReporter: ErrorReporting {
  public init() {}

  public func reportError(_ error: ImmersalKitError, context: ErrorContext) {
    let message = """
      ImmersalKit Error at \(context.file):\(context.line) in \(context.function)
      Category: \(error.category.rawValue.uppercased())
      Severity: \(error.severity.rawValue)
      Error: \(error.localizedDescription)
      """

    var additionalDetails: [String] = []

    if let reason = error.failureReason {
      additionalDetails.append("Reason: \(reason)")
    }

    if let suggestion = error.recoverySuggestion {
      additionalDetails.append("Suggestion: \(suggestion)")
    }

    if !context.additionalInfo.isEmpty {
      additionalDetails.append("Additional Info: \(context.additionalInfo)")
    }

    if error.isRetryable {
      additionalDetails.append("This error is retryable")
    }

    let fullMessage =
      additionalDetails.isEmpty
      ? message : "\(message)\n\(additionalDetails.joined(separator: "\n"))"

    // Use appropriate log level based on severity
    switch error.severity {
    case .low:
      Logger.error.info("\(fullMessage)")
    case .medium:
      Logger.error.notice("\(fullMessage)")
    case .high:
      Logger.error.error("\(fullMessage)")
    case .critical:
      Logger.error.critical("\(fullMessage)")
    }
  }
}
