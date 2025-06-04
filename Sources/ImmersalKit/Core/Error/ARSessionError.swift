//
//  ARSessionError.swift
//  ImmersalKit
//
//  Created by ryudai.kimura on 2025/05/27.
//

import ARKit
import Foundation

/// Errors related to AR session management.
public enum ARSessionError: Error, Equatable, LocalizedError {
  case cameraNotSupported
  case permissionDenied
  case sessionInitializationFailed
  case cameraFrameCaptureFailed
  case frameDataNotAvailable
  case trackingFailed
  case invalidConfiguration
  case unknown(String)

  public var errorDescription: String? {
    switch self {
    case .cameraNotSupported:
      return "Device does not support camera"
    case .permissionDenied:
      return "Camera access permission denied"
    case .sessionInitializationFailed:
      return "AR session initialization failed"
    case .cameraFrameCaptureFailed:
      return "Camera frame capture failed"
    case .frameDataNotAvailable:
      return "Camera frame data not available"
    case .trackingFailed:
      return "Spatial tracking failed"
    case .invalidConfiguration:
      return "Invalid configuration specified"
    case .unknown(let message):
      return "Unknown error occurred: \(message)"
    }
  }

  public var failureReason: String? {
    switch self {
    case .cameraNotSupported:
      return "This device does not support camera features required by ARKit"
    case .permissionDenied:
      return "User denied camera access"
    case .sessionInitializationFailed:
      return "An error occurred during ARKit session initialization"
    case .cameraFrameCaptureFailed:
      return "An error occurred during frame capture from camera"
    case .frameDataNotAvailable:
      return "Could not retrieve frame data from AR session"
    case .trackingFailed:
      return "An error occurred during device tracking processing"
    case .invalidConfiguration:
      return "AR session configuration parameters are invalid"
    case .unknown(let message):
      return "An unexpected error occurred in AR session: \(message)"
    }
  }

  public var recoverySuggestion: String? {
    switch self {
    case .cameraNotSupported:
      return "Please use an ARKit-compatible device."
    case .permissionDenied:
      return "Please allow camera access from Settings app."
    case .sessionInitializationFailed:
      return "Please restart the device or close other camera apps before retrying."
    case .cameraFrameCaptureFailed:
      return "Please ensure no other apps are using the camera and restart the device."
    case .frameDataNotAvailable:
      return
        "Please verify that the AR session has started correctly and wait a moment before retrying."
    case .trackingFailed:
      return "Please move to a well-lit area and retry in an environment with distinctive objects."
    case .invalidConfiguration:
      return "Please check AR session settings and use configurations supported by the device."
    case .unknown(_):
      return "Please restart the app. If the problem persists, restart the device."
    }
  }
}
