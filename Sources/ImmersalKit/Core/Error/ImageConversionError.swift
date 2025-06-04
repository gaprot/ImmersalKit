//
//  ImageConversionError.swift
//  ImmersalKit
//
//  Created by ryudai.kimura on 2025/05/27.
//

import ARKit
import Foundation

/// Errors related to image conversion and processing.
public enum ImageConversionError: Error, CustomStringConvertible, LocalizedError, Equatable {
  case invalidPixelBuffer(String)
  case conversionFailed(String)
  case invalidData(String)

  public var description: String {
    switch self {
    case .invalidPixelBuffer(let message):
      return "Invalid PixelBuffer: \(message)"
    case .conversionFailed(let message):
      return "Conversion Error: \(message)"
    case .invalidData(let message):
      return "Invalid Data: \(message)"
    }
  }

  public var errorDescription: String? {
    switch self {
    case .invalidPixelBuffer(let message):
      return "Invalid pixel buffer: \(message)"
    case .conversionFailed(let message):
      return "Image conversion failed: \(message)"
    case .invalidData(let message):
      return "Invalid image data: \(message)"
    }
  }

  public var failureReason: String? {
    switch self {
    case .invalidPixelBuffer(let message):
      return "Pixel buffer is invalid or corrupted: \(message)"
    case .conversionFailed(let message):
      return "An error occurred during image format conversion: \(message)"
    case .invalidData(let message):
      return "Image data is invalid or cannot be read: \(message)"
    }
  }

  public var recoverySuggestion: String? {
    switch self {
    case .invalidPixelBuffer(_):
      return "Please verify image capture from camera and ensure valid pixel buffer is provided."
    case .conversionFailed(_):
      return "Please use supported image formats and ensure sufficient memory is available."
    case .invalidData(_):
      return "Please check image data size and format, and use non-corrupted data."
    }
  }
}
