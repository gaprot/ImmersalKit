//
//  ConfigurationError.swift
//  ImmersalKit
//
//  Created by ryudai.kimura on 2025/05/27.
//

import ARKit
import Foundation

/// Configuration-related errors.
public enum ConfigurationError: Error, LocalizedError, Equatable {
  case invalidParameter(String)
  case missingRequiredConfiguration(String)
  case incompatibleConfiguration(String)
  case initializationFailed(String)

  public var errorDescription: String? {
    switch self {
    case .invalidParameter(let parameter):
      return "Invalid parameter: \(parameter)"
    case .missingRequiredConfiguration(let config):
      return "Missing required configuration: \(config)"
    case .incompatibleConfiguration(let reason):
      return "Incompatible configuration: \(reason)"
    case .initializationFailed(let reason):
      return "Initialization failed: \(reason)"
    }
  }

  public var failureReason: String? {
    switch self {
    case .invalidParameter(let parameter):
      return "The specified parameter '\(parameter)' has an invalid value or is out of range"
    case .missingRequiredConfiguration(let config):
      return "The required configuration setting '\(config)' is not configured"
    case .incompatibleConfiguration(let reason):
      return "Current configuration is incompatible with the environment: \(reason)"
    case .initializationFailed(let reason):
      return "An error occurred during system initialization: \(reason)"
    }
  }

  public var recoverySuggestion: String? {
    switch self {
    case .invalidParameter(_):
      return "Please verify the parameter value and set a valid value within the acceptable range."
    case .missingRequiredConfiguration(_):
      return "Please add the required configuration setting and set an appropriate value."
    case .incompatibleConfiguration(_):
      return
        "Please adjust the configuration to be compatible with the environment, or use default settings."
    case .initializationFailed(_):
      return "Please restart the app. If the problem persists, restart the device."
    }
  }
}
