import CoreImage
import CoreVideo
import Foundation
import UIKit

// UInt8 array extension for grayscale data
// Note: Internal implementation. End users should use toBase64EncodedPNG()
extension Array where Element == UInt8 {
  /// Convert grayscale data to 8-bit grayscale PNG data
  /// - Parameters:
  ///   - width: Image width
  ///   - height: Image height
  /// - Returns: PNG format data
  func toPNGData(width: Int, height: Int) throws -> Data {
    // Data size validation
    guard self.count >= width * height else {
      throw ImageConversionError.invalidData(
        "Invalid grayscale data size: \(self.count) < \(width * height)"
      )
    }

    // Grayscale color space
    guard let colorSpace = CGColorSpace(name: CGColorSpace.linearGray)
    else {
      throw ImageConversionError.conversionFailed("Failed to create grayscale color space")
    }

    // Create data provider
    guard let provider = CGDataProvider(data: Data(self) as CFData) else {
      throw ImageConversionError.conversionFailed("Failed to create data provider")
    }

    // Create CGImage
    guard
      let cgImage = CGImage(
        width: width,
        height: height,
        bitsPerComponent: 8,
        bitsPerPixel: 8,
        bytesPerRow: width,
        space: colorSpace,
        bitmapInfo: CGBitmapInfo(rawValue: 0),
        provider: provider,
        decode: nil,
        shouldInterpolate: false,
        intent: .defaultIntent
      )
    else {
      throw ImageConversionError.conversionFailed("Failed to create CGImage")
    }

    // Generate 8-bit grayscale PNG explicitly using Core Graphics
    let mutableData = CFDataCreateMutable(nil, 0)
    guard
      let destination = CGImageDestinationCreateWithData(
        mutableData!,
        "public.png" as CFString,
        1,
        nil
      )
    else {
      throw ImageConversionError.conversionFailed(
        "Failed to create CGImageDestination"
      )
    }

    // Configure PNG output settings
    let options: [CFString: Any] = [
      kCGImagePropertyPNGInterlaceType: 0,  // No interlacing
      kCGImagePropertyPNGGamma: 2.2,
      kCGImagePropertyColorModel: kCGImagePropertyColorModelGray,
      kCGImagePropertyDepth: 8,
    ]

    // Set PNG properties
    let properties: CFDictionary =
      [
        kCGImagePropertyPNGDictionary: options as CFDictionary
      ] as CFDictionary

    // Add image
    CGImageDestinationAddImage(destination, cgImage, properties)

    // Write to file
    if !CGImageDestinationFinalize(destination) {
      throw ImageConversionError.conversionFailed("Failed to generate PNG data")
    }

    // Return generated data
    guard let data = mutableData as Data? else {
      throw ImageConversionError.conversionFailed("Failed to convert data")
    }

    return data
  }
}
