import CoreImage
import CoreVideo
import Foundation
import UIKit

extension CVPixelBuffer {
  /// Convert CVPixelBuffer to Base64 encoded PNG string
  /// - Returns: Base64 encoded PNG image (8-bit grayscale)
  public func toBase64EncodedPNG() async throws -> String {
    // Extract grayscale data from pixel buffer
    let grayscaleData = try self.toGrayscaleData()

    // Generate PNG data from grayscale data
    let width = CVPixelBufferGetWidth(self)
    let height = CVPixelBufferGetHeight(self)
    let pngData = try grayscaleData.toPNGData(width: width, height: height)

    // Base64 encode PNG data
    return pngData.base64EncodedString()
  }

  /// Extract grayscale data from CVPixelBuffer (internal use only)
  /// - Returns: Grayscale data (UInt8 array)
  internal func toGrayscaleData() throws -> [UInt8] {
    let width = CVPixelBufferGetWidth(self)
    let height = CVPixelBufferGetHeight(self)

    // Size validation
    if width <= 0 || height <= 0 {
      throw ImageConversionError.invalidPixelBuffer(
        "Invalid pixel buffer size: \(width)x\(height)"
      )
    }

    // Check pixel buffer format
    let pixelFormat = CVPixelBufferGetPixelFormatType(self)
    var grayscaleData = [UInt8](repeating: 0, count: width * height)

    // Lock pixel buffer
    CVPixelBufferLockBaseAddress(self, .readOnly)
    defer { CVPixelBufferUnlockBaseAddress(self, .readOnly) }

    // For YUV format (common camera output)
    if pixelFormat == kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
      || pixelFormat == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
    {

      // Use only Y component (luminance) plane
      guard CVPixelBufferGetPlaneCount(self) >= 1 else {
        throw ImageConversionError.conversionFailed(
          "No planes in YUV format"
        )
      }

      let yPlaneBaseAddress = CVPixelBufferGetBaseAddressOfPlane(self, 0)
      let yPlaneBytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(self, 0)

      guard let yPlanePtr = yPlaneBaseAddress else {
        throw ImageConversionError.conversionFailed("Failed to get Y plane address")
      }

      // Copy Y component
      for y in 0..<height {
        let srcRowPtr = yPlanePtr.advanced(by: y * yPlaneBytesPerRow)
          .assumingMemoryBound(to: UInt8.self)
        for x in 0..<width {
          grayscaleData[y * width + x] = srcRowPtr[x]
        }
      }
    }
    // For RGB/BGRA format
    else {
      let baseAddress = CVPixelBufferGetBaseAddress(self)
      let bytesPerRow = CVPixelBufferGetBytesPerRow(self)

      guard let basePtr = baseAddress else {
        throw ImageConversionError.conversionFailed("Failed to get base address")
      }

      // RGB to grayscale weights
      let redWeight: Float = 0.299
      let greenWeight: Float = 0.587
      let blueWeight: Float = 0.114

      switch pixelFormat {
      case kCVPixelFormatType_32ARGB:
        for y in 0..<height {
          let rowPtr = basePtr.advanced(by: y * bytesPerRow)
            .assumingMemoryBound(to: UInt8.self)
          for x in 0..<width {
            let pixelOffset = x * 4
            let alpha = rowPtr[pixelOffset]  // A
            let red = rowPtr[pixelOffset + 1]  // R
            let green = rowPtr[pixelOffset + 2]  // G
            let blue = rowPtr[pixelOffset + 3]  // B

            // Correct for premultiplied alpha
            let alphaFactor: Float =
              alpha > 0 ? Float(255) / Float(alpha) : 1.0

            // Calculate grayscale value with weighted average
            let gray = UInt8(
              min(
                255,
                max(
                  0,
                  Float(red) * redWeight * alphaFactor
                    + Float(green) * greenWeight
                    * alphaFactor + Float(blue) * blueWeight
                    * alphaFactor
                )
              )
            )

            grayscaleData[y * width + x] = gray
          }
        }

      case kCVPixelFormatType_32BGRA:
        for y in 0..<height {
          let rowPtr = basePtr.advanced(by: y * bytesPerRow)
            .assumingMemoryBound(to: UInt8.self)
          for x in 0..<width {
            let pixelOffset = x * 4
            let blue = rowPtr[pixelOffset]  // B
            let green = rowPtr[pixelOffset + 1]  // G
            let red = rowPtr[pixelOffset + 2]  // R
            let alpha = rowPtr[pixelOffset + 3]  // A

            // Correct for premultiplied alpha
            let alphaFactor: Float =
              alpha > 0 ? Float(255) / Float(alpha) : 1.0

            // Calculate grayscale value with weighted average
            let gray = UInt8(
              min(
                255,
                max(
                  0,
                  Float(red) * redWeight * alphaFactor
                    + Float(green) * greenWeight
                    * alphaFactor + Float(blue) * blueWeight
                    * alphaFactor
                )
              )
            )

            grayscaleData[y * width + x] = gray
          }
        }

      default:
        // For unsupported formats, convert via CIImage
        try grayscaleData = self.convertUnsupportedFormat()
      }
    }

    return grayscaleData
  }

  /// Convert unsupported format pixel buffer via CIImage
  private func convertUnsupportedFormat() throws -> [UInt8] {
    let width = CVPixelBufferGetWidth(self)
    let height = CVPixelBufferGetHeight(self)

    // Convert via CIImage
    let ciImage = CIImage(cvPixelBuffer: self)

    // Apply grayscale filter
    guard let grayscaleFilter = CIFilter(name: "CIColorMonochrome") else {
      throw ImageConversionError.conversionFailed("Failed to create grayscale filter")
    }

    grayscaleFilter.setValue(ciImage, forKey: kCIInputImageKey)
    grayscaleFilter.setValue(
      CIColor(red: 0.5, green: 0.5, blue: 0.5),
      forKey: kCIInputColorKey
    )
    grayscaleFilter.setValue(1.0, forKey: kCIInputIntensityKey)

    guard let outputImage = grayscaleFilter.outputImage else {
      throw ImageConversionError.conversionFailed("Failed to get grayscale filter output")
    }

    // Convert CIImage to CGImage
    let context = CIContext(options: nil)
    guard
      let cgImage = context.createCGImage(
        outputImage,
        from: outputImage.extent
      )
    else {
      throw ImageConversionError.conversionFailed(
        "Failed to convert CIImage to CGImage"
      )
    }

    // Extract grayscale data from CGImage
    guard let data = cgImage.dataProvider?.data,
      let bytes = CFDataGetBytePtr(data)
    else {
      throw ImageConversionError.conversionFailed("Failed to get CGImage pixel data")
    }

    var grayscaleData = [UInt8](repeating: 0, count: width * height)
    let bytesPerRow = cgImage.bytesPerRow
    let bitsPerComponent = cgImage.bitsPerComponent
    let bytesPerPixel = cgImage.bitsPerPixel / 8

    // For 4 components per pixel (RGBA etc.)
    if bytesPerPixel == 4 {
      for y in 0..<height {
        for x in 0..<width {
          let offset = y * bytesPerRow + x * bytesPerPixel
          // Average RGB values (simplified)
          grayscaleData[y * width + x] = UInt8(
            (UInt32(bytes[offset]) + UInt32(bytes[offset + 1])
              + UInt32(bytes[offset + 2])) / 3
          )
        }
      }
    } else {
      throw ImageConversionError.conversionFailed("Unsupported pixel format")
    }

    return grayscaleData
  }
  /// Create CVPixelBuffer from raw data (internal use only)
  /// - Warning: Manual memory management - misuse can cause crashes
  internal static func from(_ data: Data, width: Int, height: Int, pixelFormat: OSType)
    -> CVPixelBuffer
  {
    data.withUnsafeBytes { buffer in
      var pixelBuffer: CVPixelBuffer!

      let result = CVPixelBufferCreate(
        kCFAllocatorDefault, width, height, pixelFormat, nil, &pixelBuffer)
      guard result == kCVReturnSuccess else { fatalError() }

      CVPixelBufferLockBaseAddress(pixelBuffer, [])
      defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }

      var source = buffer.baseAddress!

      for plane in 0..<CVPixelBufferGetPlaneCount(pixelBuffer) {
        let dest = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, plane)
        let height = CVPixelBufferGetHeightOfPlane(pixelBuffer, plane)
        let bytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, plane)
        let planeSize = height * bytesPerRow

        memcpy(dest, source, planeSize)
        source += planeSize
      }

      return pixelBuffer
    }
  }
}
