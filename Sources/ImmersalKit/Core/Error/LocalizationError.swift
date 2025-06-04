//
//  LocalizationError.swift
//  ImmersalKit
//
//  Created by ryudai.kimura on 2025/05/27.
//

import ARKit
import Foundation

/// Errors related to localization processing.
public enum LocalizationError: Error, Equatable, LocalizedError {
  case networkError(String)
  case authenticationFailed
  case serverError(String)
  case invalidResponse
  case invalidMapIds
  case pixelBufferProcessingFailed
  case intrinsicsInitializationFailed
  case coreLocalizationFailed(String)
  case imageProcessingFailed
  case invalidCameraParameters
  case unknown(String)

  public var errorDescription: String? {
    switch self {
    case .networkError(let message):
      return "Network error: \(message)"
    case .authenticationFailed:
      return "Authentication failed"
    case .serverError(let message):
      return "Server error: \(message)"
    case .invalidResponse:
      return "Invalid response"
    case .invalidMapIds:
      return "Invalid map IDs specified"
    case .pixelBufferProcessingFailed:
      return "Pixel buffer processing failed"
    case .intrinsicsInitializationFailed:
      return "Camera intrinsics initialization failed"
    case .coreLocalizationFailed(let message):
      return "Core localization failed: \(message)"
    case .imageProcessingFailed:
      return "Image processing failed"
    case .invalidCameraParameters:
      return "Invalid camera parameters"
    case .unknown(let message):
      return "Unknown error: \(message)"
    }
  }

  public var failureReason: String? {
    switch self {
    case .networkError(let message):
      return "A problem occurred with network connection or communication: \(message)"
    case .authenticationFailed:
      return "The provided authentication credentials are invalid or expired"
    case .serverError(let message):
      return "A processing error occurred on the server side: \(message)"
    case .invalidResponse:
      return "Server response is not in the expected format"
    case .invalidMapIds:
      return "The specified map IDs are not loaded or do not exist"
    case .pixelBufferProcessingFailed:
      return "An error occurred while processing image data from the camera"
    case .intrinsicsInitializationFailed:
      return "An error occurred while setting up camera intrinsic parameters"
    case .coreLocalizationFailed(let message):
      return "An error occurred in low-level localization processing: \(message)"
    case .imageProcessingFailed:
      return "An error occurred during image conversion or processing"
    case .invalidCameraParameters:
      return "Camera parameter values are invalid or out of range"
    case .unknown(let message):
      return "An unexpected error occurred: \(message)"
    }
  }

  public var recoverySuggestion: String? {
    switch self {
    case .networkError(_):
      return "Please check your network connection and wait a moment before retrying."
    case .authenticationFailed:
      return "Please check your developer token and re-login if necessary."
    case .serverError(_):
      return "Please wait a moment and try again. If the problem persists, contact support."
    case .invalidResponse:
      return "Please verify that you are sending requests that comply with the API specification."
    case .invalidMapIds:
      return "Please specify valid map IDs and verify that the maps are loaded correctly."
    case .pixelBufferProcessingFailed:
      return "Please check camera permissions and ensure no other apps are using the camera."
    case .intrinsicsInitializationFailed:
      return "Please check camera parameter values and restart the device before retrying."
    case .coreLocalizationFailed(_):
      return "Please verify that map data is loaded correctly and improve lighting conditions."
    case .imageProcessingFailed:
      return
        "Please check camera quality settings and retry in an environment with adequate lighting."
    case .invalidCameraParameters:
      return
        "Please check camera parameter values and use values that conform to device specifications."
    case .unknown(_):
      return "Please restart the app. If the problem persists, check logs and contact support."
    }
  }
}
